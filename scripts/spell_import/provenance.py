"""Record which rulebook revision produced assets/data/spell_library.json.

The rulebook lives outside this repository and is not versioned with it, so
nothing else can attribute a change in the generated asset to a change in its
input. This module answers exactly one question — "which source produced
this?" — performing no parsing, catalog access, or spell logic. It records
the spell counts it is handed for the drift message.

The lock it maintains is a *record*, not a pin: it never constrains which
rulebook is read. Its meaning is "the last source revision known to produce
this asset", so a rulebook change that leaves the asset untouched leaves the
lock valid.
"""
import dataclasses
import hashlib
import json
import pathlib
import subprocess

LOCK_PATH = pathlib.Path(__file__).resolve().parent / "source.lock"


@dataclasses.dataclass(frozen=True)
class RulebookRevision:
    commit: str
    date: str
    subject: str


@dataclasses.dataclass(frozen=True)
class SourceIdentity:
    book_id: str
    book: str
    path: str
    sha256: str
    rulebook: RulebookRevision | None
    spells_parsed: int | None = None
    spells_imported: int | None = None

    def to_dict(self) -> dict:
        return {
            "bookId": self.book_id,
            "book": self.book,
            "path": self.path,
            "sha256": self.sha256,
            "rulebook": None if self.rulebook is None else dataclasses.asdict(self.rulebook),
            "spellsParsed": self.spells_parsed,
            "spellsImported": self.spells_imported,
        }

    @classmethod
    def from_dict(cls, raw: dict) -> "SourceIdentity":
        revision = raw.get("rulebook")
        return cls(
            book_id=raw["bookId"],
            book=raw["book"],
            path=raw["path"],
            sha256=raw["sha256"],
            rulebook=None if revision is None else RulebookRevision(**revision),
            spells_parsed=raw.get("spellsParsed"),
            spells_imported=raw.get("spellsImported"),
        )

    def label(self) -> str:
        """One-line human form, used in messages."""
        if self.rulebook is None:
            return f"(no git metadata) sha256 {self.sha256[:7]}"
        return (
            f"{self.rulebook.commit} {self.rulebook.subject!r} ({self.rulebook.date})\n"
            f"             sha256 {self.sha256[:7]}"
        )


def sha256_of(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_revision(root: pathlib.Path, relative: str) -> RulebookRevision | None:
    """Best effort. Any failure means "no metadata", never an exception.

    The rulebook may be a downloaded zip rather than a checkout, git may be
    absent, or the file may be untracked. None of those is an error here —
    the sha256 is what carries correctness.
    """
    try:
        finished = subprocess.run(
            ["git", "-C", str(root), "log", "-1",
             "--format=%h%x00%ad%x00%s", "--date=short", "--", relative],
            capture_output=True, text=True, timeout=10,
            encoding="utf-8", errors="replace",
        )
    except (OSError, subprocess.SubprocessError, UnicodeDecodeError):
        return None
    if finished.returncode != 0 or not finished.stdout.strip():
        return None
    parts = finished.stdout.strip().split("\0")
    if len(parts) != 3:
        return None
    return RulebookRevision(commit=parts[0], date=parts[1], subject=parts[2])


def describe(
    book_id: str,
    book: str,
    path: pathlib.Path,
    root: pathlib.Path,
    parsed: int | None = None,
    imported: int | None = None,
) -> SourceIdentity:
    relative = path.relative_to(root).as_posix()
    return SourceIdentity(
        book_id=book_id,
        book=book,
        path=relative,
        sha256=sha256_of(path),
        rulebook=git_revision(root, relative),
        spells_parsed=parsed,
        spells_imported=imported,
    )


def load(path: pathlib.Path = LOCK_PATH) -> dict[str, SourceIdentity]:
    """Every recorded book, by id. An absent lock is an empty mapping.

    A mapping rather than a single identity because the importer reads more
    than one book, and a book that has not moved must not be re-attested
    because a different one did.
    """
    if not path.is_file():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    try:
        return {book_id: SourceIdentity.from_dict(entry) for book_id, entry in raw.items()}
    except AttributeError as error:
        raise ValueError(
            f"{path} looks like the old single-identity source.lock format "
            "(from before the {book_id: entry} mapping) rather than a mapping "
            "of book id to identity. Delete it and re-run "
            "`python -m scripts.spell_import.extract_spells --write --accept-source` "
            "to regenerate it in the current format."
        ) from error


def write(identities: dict[str, SourceIdentity], path: pathlib.Path = LOCK_PATH) -> None:
    payload = {book_id: identities[book_id].to_dict() for book_id in sorted(identities)}
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def matches(lock: dict[str, SourceIdentity], current: SourceIdentity) -> bool:
    """Only the hash decides, and only for the book being asked about."""
    recorded = lock.get(current.book_id)
    return recorded is not None and recorded.sha256 == current.sha256


def describe_change(lock: dict[str, SourceIdentity], current: SourceIdentity) -> str:
    accept = "  python -m scripts.spell_import.extract_spells --write --accept-source"
    recorded = lock.get(current.book_id)
    if recorded is None:
        return (
            f"source.lock has no record of {current.book_id} ({current.book}), so "
            "the rulebook revision behind the generated assets is unrecorded.\n\n"
            f"  current  : {current.label()}\n"
            f"             {current.spells_parsed} parsed\n\n"
            "Create it, reviewing the result:\n" + accept
        )
    return (
        f"the source for {current.book_id} ({current.book}) moved since the "
        "generated assets were built.\n\n"
        f"  recorded : {recorded.label()}\n"
        f"             {recorded.spells_parsed} parsed, "
        f"{recorded.spells_imported} imported\n"
        f"  current  : {current.label()}\n"
        f"             {current.spells_parsed} parsed\n\n"
        "This is not a code failure. Regenerate and review:\n" + accept
    )


def pinned_revision(lock: dict[str, SourceIdentity]) -> str | None:
    """The rulebook commit CI should check out, or None if nothing is recorded.

    Every registered book is a file in the *same* rulebook repository, so one
    checkout has to serve them all, and the newest recorded revision is the
    one that does. A book recorded at an older commit cannot have changed
    between then and the newest -- if it had, its own record would name the
    later commit, since `git_revision` records the last commit to touch that
    file. So at the newest recorded revision every book still hashes to the
    sha256 the lock holds for it.

    This lives here rather than in the workflow because the workflow used to
    reach into the lock's JSON itself, reading a top-level "rulebook" key.
    Keying the lock by book id removed that key and broke CI with nothing in
    the suite to catch it -- YAML is not reachable from the tests. Any future
    change to the lock's shape now breaks a test first.
    """
    revisions = [
        identity.rulebook for identity in lock.values() if identity.rulebook is not None
    ]
    if not revisions:
        return None
    return max(revisions, key=lambda revision: revision.date).commit
