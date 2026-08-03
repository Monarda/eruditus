"""Record which rulebook revision produced assets/data/spell_library.json.

The rulebook lives outside this repository and is not versioned with it, so
nothing else can attribute a change in the generated asset to a change in its
input. This module answers exactly one question — "which source produced
this?" — and knows nothing about spells.

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
    book: str
    path: str
    sha256: str
    rulebook: RulebookRevision | None
    spells_parsed: int | None = None
    spells_imported: int | None = None

    def to_dict(self) -> dict:
        return {
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
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if finished.returncode != 0 or not finished.stdout.strip():
        return None
    parts = finished.stdout.strip().split("\0")
    if len(parts) != 3:
        return None
    return RulebookRevision(commit=parts[0], date=parts[1], subject=parts[2])


def describe(
    book: str,
    path: pathlib.Path,
    root: pathlib.Path,
    parsed: int | None = None,
    imported: int | None = None,
) -> SourceIdentity:
    relative = path.relative_to(root).as_posix()
    return SourceIdentity(
        book=book,
        path=relative,
        sha256=sha256_of(path),
        rulebook=git_revision(root, relative),
        spells_parsed=parsed,
        spells_imported=imported,
    )


def load(path: pathlib.Path = LOCK_PATH) -> SourceIdentity | None:
    if not path.is_file():
        return None
    return SourceIdentity.from_dict(json.loads(path.read_text(encoding="utf-8")))


def write(identity: SourceIdentity, path: pathlib.Path = LOCK_PATH) -> None:
    path.write_text(
        json.dumps(identity.to_dict(), indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def matches(lock: SourceIdentity | None, current: SourceIdentity) -> bool:
    """Only the hash decides. Everything else in the lock is advisory."""
    return lock is not None and lock.sha256 == current.sha256


def describe_change(lock: SourceIdentity | None, current: SourceIdentity) -> str:
    accept = "  python -m scripts.spell_import.extract_spells --write --accept-source"
    if lock is None:
        return (
            "no source.lock exists, so the rulebook revision behind "
            "assets/data/spell_library.json is unrecorded.\n\n"
            f"  current  : {current.label()}\n"
            f"             {current.spells_parsed} parsed\n\n"
            "Create it, reviewing the result:\n" + accept
        )
    return (
        "rulebook source moved since spell_library.json was generated.\n\n"
        f"  recorded : {lock.label()}\n"
        f"             {lock.spells_parsed} parsed, {lock.spells_imported} imported\n"
        f"  current  : {current.label()}\n"
        f"             {current.spells_parsed} parsed\n\n"
        "This is not a code failure. Regenerate and review:\n" + accept
    )
