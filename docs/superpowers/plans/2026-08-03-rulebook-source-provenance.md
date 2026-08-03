# Rulebook Source Provenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record which rulebook revision produced `assets/data/spell_library.json`, so a source change is diagnosable as a source change and cannot be adopted without a human reading a readable summary of what it did.

**Architecture:** Two new stdlib-only modules under `scripts/spell_import/`. `provenance.py` computes and stores a source identity (sha256 + advisory git metadata) in a committed `source.lock`. `report.py` diffs two versions of the generated asset into a readable markdown summary. `extract_spells.py` gains an `--accept-source` gate that refuses to rewrite the asset while the lock disagrees. The lock is **diagnostic, not gating** — `RegenerationTest` stays the only test that fails on drift, because asset-equivalence is precise where a file hash is not.

**Tech Stack:** Python 3.13 standard library only (`hashlib`, `json`, `subprocess`, `dataclasses`, `difflib`, `pathlib`, `unittest`). No new dependencies. GitHub Actions for the weekly freshness job.

**Spec:** `docs/superpowers/specs/2026-08-03-rulebook-source-provenance-design.md`

## Global Constraints

- **Python 3.13, standard library only.** No new dependencies in this repo or in CI.
- **Test command:** `python -m unittest discover -s scripts/spell_import/tests -t .` run from the repo root. `-t .` matters — the modules import as `scripts.spell_import.*`.
- **Determinism is load-bearing.** `test_two_runs_are_byte_identical` must keep passing. Never introduce wall-clock time, dict iteration order dependence, or unsorted output into anything the asset or the lock contains.
- **`assets/data/spell_library.json`'s schema does not change.** It is the Flutter app's data contract. Provenance lives in a sidecar, never in the asset.
- **`sha256` is the only field ever compared.** Everything in the lock's `rulebook` block is advisory: printed in messages, never used for a correctness decision.
- **Git is optional at runtime.** Every git call is best-effort and must degrade to `None` without raising when the rulebook is not a checkout, the revision is unfetched, or `git` is absent.
- **Shell:** developer machine is Windows with Git Bash available; the Bash tool takes POSIX syntax. Commit messages use a heredoc, never PowerShell here-strings.
- **Branch:** `feature/rulebook-source-provenance`, already created, spec already committed at `451ee62`.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `scripts/spell_import/provenance.py` | Compute a source identity; load/write `source.lock`; compare. Knows nothing about spells. |
| `scripts/spell_import/source.lock` | Committed record of the last source revision known to produce the asset. |
| `scripts/spell_import/report.py` | Diff two asset lists; render markdown. Pure data in, string out. |
| `scripts/spell_import/import_report.md` | Committed, human-readable record of the last adoption that changed the asset. |
| `scripts/spell_import/tests/test_provenance.py` | Fixture-based, no rulebook needed. |
| `scripts/spell_import/tests/test_report.py` | Fixture-based, no rulebook needed. |
| `.github/workflows/rulebook-freshness.yml` | Weekly job that runs the Python suite against the rulebook at `origin/main`. |

**Modified:**

| File | Change |
|---|---|
| `scripts/spell_import/sources.py` | Remove dead raw-md handling; add `ARS_RULEBOOK_ROOT` override; add "did you mean…" to the not-found error. |
| `scripts/spell_import/extract_spells.py` | Carry design lines on `Report`; add `--accept-source`; enforce the write gate; write lock and report. |
| `scripts/spell_import/tests/test_sources.py` | Remove the six raw-md tests; cover the new suggestion behaviour. |
| `scripts/spell_import/tests/test_extract.py` | Make `RegenerationTest`'s failure message drift-aware. |

`provenance.py` and `report.py` are deliberately separate: one knows about files and git, the other about spell dicts and markdown. Neither imports the other, and `extract_spells.py` is the only module that uses both. Both are testable with no rulebook present, which begins the source-independent test split item 29 wants.

---

### Task 1: Retire the dead raw-md handling in `sources.py`

Upstream deleted the `raw-md` folder (rulebook commit `8b6c4d6`). Everything in `sources.py` that exists to accommodate it is now unreachable. This task also adds the environment override CI needs, because `actions/checkout` cannot clone outside the workspace.

**Files:**
- Modify: `scripts/spell_import/sources.py` (whole file)
- Test: `scripts/spell_import/tests/test_sources.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `sources.RULEBOOK_ROOT` (now env-overridable), `sources.all_books(root) -> dict[str, pathlib.Path]`, `sources.resolve_book(title, root) -> pathlib.Path`, `sources.title_of(path) -> str`, `sources.read_lines(path) -> list[str]`, `sources.DE_TITLE`. Signatures are unchanged from today; only behaviour narrows.

- [ ] **Step 1: Delete the six raw-md tests**

Remove these from `scripts/spell_import/tests/test_sources.py` entirely:
`test_uses_raw_only_as_last_resort`, `test_do_not_use_files_are_never_returned`,
`test_sanctuary_of_ice_raw_md_collapses_into_reviewed_entry`,
`test_against_the_dark_raw_md_collapses_into_reviewed_entry`,
`test_definitive_edition_raw_md_duplicates_collapse_into_reviewed_entry`,
`test_every_raw_md_title_is_triaged_against_reviewed_and_wip`.

Keep `test_prefers_reviewed_over_raw`, `test_falls_back_to_wip_when_not_reviewed`, `test_unknown_book_raises`, `test_read_lines_strips_newlines_but_keeps_blockquotes`. Rename the first to `test_de_resolves_to_reviewed` — its old name refers to a folder that no longer exists.

Two of the six were passing vacuously (globbing an absent directory yields nothing), so removing them loses no coverage that existed.

- [ ] **Step 2: Write the failing tests for the new behaviour**

Add to `scripts/spell_import/tests/test_sources.py`:

```python
import os
import pathlib
import tempfile
import unittest

from scripts.spell_import import sources


class RootOverrideTest(unittest.TestCase):
    def test_all_books_reads_an_explicit_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            (root / "reviewed" / "Some Book.md").write_text("x", encoding="utf-8")
            self.assertEqual(set(sources.all_books(root)), {"Some Book"})

    def test_reviewed_wins_over_wip_for_the_same_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            for folder in ("reviewed", "wip"):
                (root / folder).mkdir()
                (root / folder / "Some Book.md").write_text(folder, encoding="utf-8")
            self.assertEqual(sources.resolve_book("Some Book", root).parent.name, "reviewed")

    def test_env_var_overrides_the_default_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.environ["ARS_RULEBOOK_ROOT"] = tmp
            try:
                self.assertEqual(sources.default_root(), pathlib.Path(tmp))
            finally:
                del os.environ["ARS_RULEBOOK_ROOT"]

    def test_default_root_without_the_env_var_is_the_sibling_directory(self):
        os.environ.pop("ARS_RULEBOOK_ROOT", None)
        self.assertEqual(sources.default_root().name, "Ars-Magica-Open-License")


class SuggestionTest(unittest.TestCase):
    def test_unknown_title_close_to_a_real_one_is_suggested(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            (root / "reviewed" / "Ars Magica - Definitive Edition.md").write_text("x", encoding="utf-8")
            with self.assertRaises(FileNotFoundError) as caught:
                sources.resolve_book("Ars Magica - Definitive Editon", root)
            self.assertIn("did you mean", str(caught.exception).lower())
            self.assertIn("Ars Magica - Definitive Edition", str(caught.exception))

    def test_unknown_title_with_no_close_match_still_raises_cleanly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            (root / "reviewed" / "Ars Magica - Definitive Edition.md").write_text("x", encoding="utf-8")
            with self.assertRaises(FileNotFoundError) as caught:
                sources.resolve_book("Completely Unrelated", root)
            self.assertNotIn("did you mean", str(caught.exception).lower())
```

`default_root()` is a new function; the env var must be read per-call rather than at import, or tests cannot override it.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_sources -v`
Expected: FAIL — `AttributeError: module 'scripts.spell_import.sources' has no attribute 'default_root'`.

- [ ] **Step 4: Rewrite `sources.py`**

Replace the whole file with:

```python
"""Resolve an Ars Magica rulebook to the best available markdown copy.

The rulebook repo publishes two tiers of the same corpus. `reviewed` has had
at least one full manual pass with the official errata applied — the upstream
README says "USE THESE!". `wip` is manually-fixed work in progress, to be used
only until a book reaches `reviewed`. Precedence is not a preference: reading
the lesser copy produces wrong data that looks plausible.

`3rd-party` is deliberately excluded. It holds third-party material rather
than the licensed corpus this importer cites as `arm5-core`.

A third tier, `raw-md`, held unreviewed OCR and was deleted upstream (rulebook
commit 8b6c4d6). Nothing here accommodates it any more.
"""
import difflib
import os
import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# Descending quality. First hit wins.
FOLDERS = ("reviewed", "wip")

DE_TITLE = "Ars Magica - Definitive Edition (Core Rules)"


def default_root() -> pathlib.Path:
    """The rulebook checkout, overridable for CI.

    Read per call, not at import: `actions/checkout` cannot clone outside the
    workspace, so CI sets ARS_RULEBOOK_ROOT rather than reproducing the
    sibling-directory layout.
    """
    override = os.environ.get("ARS_RULEBOOK_ROOT")
    if override:
        return pathlib.Path(override)
    return REPO_ROOT.parent / "Ars-Magica-Open-License"


def title_of(path: pathlib.Path) -> str:
    return path.name[: -len(".md")] if path.name.endswith(".md") else path.name


def all_books(root: pathlib.Path | None = None) -> dict[str, pathlib.Path]:
    """Every book title mapped to its best available copy."""
    root = default_root() if root is None else root
    resolved: dict[str, pathlib.Path] = {}
    for folder in FOLDERS:
        directory = root / folder
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.md")):
            resolved.setdefault(title_of(path), path)
    return resolved


def resolve_book(title: str, root: pathlib.Path | None = None) -> pathlib.Path:
    root = default_root() if root is None else root
    books = all_books(root)
    if title not in books:
        message = f"no markdown copy of {title!r} under {root} (looked in {', '.join(FOLDERS)})"
        close = difflib.get_close_matches(title, books, n=3, cutoff=0.8)
        if close:
            message += " — did you mean " + ", ".join(repr(c) for c in close) + "?"
        raise FileNotFoundError(message)
    return books[title]


def read_lines(path: pathlib.Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="strict").split("\n")
```

Note `RULEBOOK_ROOT` is gone as a module constant — it captured the environment at import time. Any remaining reference must become `sources.default_root()`.

- [ ] **Step 5: Update the one other reference to `RULEBOOK_ROOT`**

Run: `grep -rn "RULEBOOK_ROOT" scripts/ docs/ --include=*.py`
The only hit outside `sources.py` is in the corpus-audit test deleted in Step 1. If any other module references it, change it to `sources.default_root()`.

- [ ] **Step 6: Run the whole Python suite**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS, with the test count down by six from 86 (the six deleted) and up by six (the six added) — 86 again.

- [ ] **Step 7: Commit**

```bash
git add scripts/spell_import/sources.py scripts/spell_import/tests/test_sources.py
git commit -m "$(cat <<'EOF'
refactor: retire the dead raw-md handling in sources.py

Upstream deleted the raw-md folder (rulebook 8b6c4d6), so the third
precedence tier, the OCR-suffix and edition-tag regexes, the title
aliases and the DO NOT USE filter are all unreachable. Two of the six
tests removed here were passing vacuously by globbing a directory that
no longer exists.

Adds ARS_RULEBOOK_ROOT so CI can place the checkout inside the
workspace, and a "did you mean" suggestion so an upstream rename is
diagnosable without listing the corpus by hand.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `provenance.py` — source identity and the lock file

**Files:**
- Create: `scripts/spell_import/provenance.py`
- Test: `scripts/spell_import/tests/test_provenance.py`

**Interfaces:**
- Consumes: `sources.default_root()` from Task 1.
- Produces:
  - `provenance.LOCK_PATH: pathlib.Path`
  - `provenance.RulebookRevision(commit: str, date: str, subject: str)` — frozen dataclass
  - `provenance.SourceIdentity(book: str, path: str, sha256: str, rulebook: RulebookRevision | None, spells_parsed: int | None, spells_imported: int | None)` — frozen dataclass, with `.to_dict()` and `.from_dict(raw)`
  - `provenance.describe(book, path, root, parsed=None, imported=None) -> SourceIdentity`
  - `provenance.load(path=LOCK_PATH) -> SourceIdentity | None` — `None` when the file is absent
  - `provenance.write(identity, path=LOCK_PATH) -> None`
  - `provenance.matches(lock, current) -> bool` — compares `sha256` only
  - `provenance.describe_change(lock, current) -> str` — the multi-line drift message

- [ ] **Step 1: Write the failing tests**

Create `scripts/spell_import/tests/test_provenance.py`:

```python
import json
import pathlib
import tempfile
import unittest

from scripts.spell_import import provenance


def identity(sha="a" * 64, rev=None, parsed=360, imported=250):
    return provenance.SourceIdentity(
        book="Ars Magica - Definitive Edition (Core Rules)",
        path="reviewed/Ars Magica - Definitive Edition (Core Rules).md",
        sha256=sha,
        rulebook=rev,
        spells_parsed=parsed,
        spells_imported=imported,
    )


REV = provenance.RulebookRevision(commit="97cc62d", date="2026-07-18", subject="Review chapter 16")


class DescribeTest(unittest.TestCase):
    def test_hashes_the_file_and_records_a_posix_relative_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            book = root / "reviewed" / "Some Book.md"
            book.write_text("hello", encoding="utf-8")
            found = provenance.describe("Some Book", book, root, parsed=3, imported=2)
            self.assertEqual(found.path, "reviewed/Some Book.md")
            # sha256("hello")
            self.assertEqual(
                found.sha256,
                "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
            )
            self.assertEqual((found.spells_parsed, found.spells_imported), (3, 2))

    def test_a_non_git_root_yields_no_revision_rather_than_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "reviewed").mkdir()
            book = root / "reviewed" / "Some Book.md"
            book.write_text("hello", encoding="utf-8")
            self.assertIsNone(provenance.describe("Some Book", book, root).rulebook)


class LockFileTest(unittest.TestCase):
    def test_round_trips_with_a_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            provenance.write(identity(rev=REV), path)
            self.assertEqual(provenance.load(path), identity(rev=REV))

    def test_round_trips_without_a_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            provenance.write(identity(rev=None), path)
            loaded = provenance.load(path)
            self.assertIsNone(loaded.rulebook)
            self.assertEqual(loaded, identity(rev=None))

    def test_absent_lock_loads_as_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(provenance.load(pathlib.Path(tmp) / "nope.lock"))

    def test_written_lock_is_readable_json_ending_in_a_newline(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "source.lock"
            provenance.write(identity(rev=REV), path)
            text = path.read_text(encoding="utf-8")
            self.assertTrue(text.endswith("\n"))
            self.assertEqual(json.loads(text)["rulebook"]["commit"], "97cc62d")

    def test_writing_twice_is_byte_identical(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = pathlib.Path(tmp) / "a.lock"
            second = pathlib.Path(tmp) / "b.lock"
            provenance.write(identity(rev=REV), first)
            provenance.write(identity(rev=REV), second)
            self.assertEqual(first.read_bytes(), second.read_bytes())


class MatchesTest(unittest.TestCase):
    def test_only_the_hash_decides(self):
        other_rev = provenance.RulebookRevision(commit="ffffff", date="2026-08-01", subject="x")
        self.assertTrue(provenance.matches(identity(rev=REV), identity(rev=other_rev)))

    def test_a_different_hash_is_a_mismatch(self):
        self.assertFalse(provenance.matches(identity(sha="a" * 64), identity(sha="b" * 64)))

    def test_an_absent_lock_never_matches(self):
        self.assertFalse(provenance.matches(None, identity()))


class DescribeChangeTest(unittest.TestCase):
    def test_names_both_revisions_and_both_counts(self):
        old = identity(sha="a" * 64, rev=REV, parsed=360, imported=250)
        new = identity(
            sha="b" * 64,
            rev=provenance.RulebookRevision("005a33c", "2026-07-13", "Merge pull request #54"),
            parsed=346,
            imported=241,
        )
        message = provenance.describe_change(old, new)
        self.assertIn("97cc62d", message)
        self.assertIn("Review chapter 16", message)
        self.assertIn("005a33c", message)
        self.assertIn("360", message)
        self.assertIn("346", message)
        self.assertIn("--accept-source", message)

    def test_reads_sensibly_when_no_lock_exists_yet(self):
        message = provenance.describe_change(None, identity())
        self.assertIn("no source.lock", message)
        self.assertIn("--accept-source", message)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_provenance -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.provenance'`.

- [ ] **Step 3: Write `provenance.py`**

```python
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_provenance -v`
Expected: PASS, 12 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/provenance.py scripts/spell_import/tests/test_provenance.py
git commit -m "$(cat <<'EOF'
feat: add source identity and the rulebook lock file

Computes a sha256 plus advisory git metadata for the rulebook file the
extractor reads, and stores it in a committed source.lock. Only the hash
is ever compared; git metadata is for legibility and degrades to null
without raising when the rulebook is not a checkout.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `report.py` — diff two assets into readable markdown

**Files:**
- Create: `scripts/spell_import/report.py`
- Test: `scripts/spell_import/tests/test_report.py`

**Interfaces:**
- Consumes: `provenance.SourceIdentity` from Task 2 (for the header line only).
- Produces:
  - `report.AssetDiff(added: list[dict], removed: list[dict], changed: list[tuple[dict, dict]])` — frozen dataclass with `.is_empty` property
  - `report.diff_assets(old, new) -> AssetDiff`
  - `report.render(diff, lock, current, imported, blocked, unresolved, old_design_lines=None, new_design_lines=None) -> str`

**Counts note — do not add fields to the lock for this.** The report's "before"
side derives from the lock: `blocked_before = spells_parsed - spells_imported`,
and `unresolved_before` is always `0`, because `extract_spells.run()` only
writes the asset when `not unresolved`. Any committed lock therefore describes a
run with zero unresolved spells.

- [ ] **Step 1: Write the failing tests**

Create `scripts/spell_import/tests/test_report.py`:

```python
import unittest

from scripts.spell_import import provenance, report


def spell(spell_id, name="A Spell", base="cran-5a", **extra):
    entry = {"id": spell_id, "name": name, "baseEffectId": base, "summary": "Prose. Level 20."}
    entry.update(extra)
    return entry


LOCK = provenance.SourceIdentity(
    book="Book", path="reviewed/Book.md", sha256="a" * 64,
    rulebook=provenance.RulebookRevision("97cc62d", "2026-07-18", "Review chapter 9"),
    spells_parsed=346, spells_imported=241,
)
CURRENT = provenance.SourceIdentity(
    book="Book", path="reviewed/Book.md", sha256="b" * 64,
    rulebook=provenance.RulebookRevision("f36ac84", "2026-07-29", "Merge pull request #66"),
    spells_parsed=360, spells_imported=250,
)


class DiffAssetsTest(unittest.TestCase):
    def test_identical_lists_produce_an_empty_diff(self):
        old = [spell("lib-a"), spell("lib-b")]
        found = report.diff_assets(old, list(reversed(old)))
        self.assertTrue(found.is_empty)

    def test_detects_added_removed_and_changed(self):
        old = [spell("lib-a"), spell("lib-b", base="cran-5a")]
        new = [spell("lib-b", base="cran-5c"), spell("lib-c")]
        found = report.diff_assets(old, new)
        self.assertEqual([s["id"] for s in found.added], ["lib-c"])
        self.assertEqual([s["id"] for s in found.removed], ["lib-a"])
        self.assertEqual([(o["id"], n["id"]) for o, n in found.changed], [("lib-b", "lib-b")])

    def test_results_are_sorted_by_id(self):
        old = []
        new = [spell("lib-z"), spell("lib-a")]
        self.assertEqual([s["id"] for s in report.diff_assets(old, new).added], ["lib-a", "lib-z"])


class RenderTest(unittest.TestCase):
    def setUp(self):
        self.diff = report.diff_assets(
            [spell("lib-a"), spell("lib-b", base="cran-5a")],
            [spell("lib-b", base="cran-5c"), spell("lib-c", name="New Spell")],
        )

    def test_header_names_both_revisions_and_the_count_transitions(self):
        text = report.render(self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0)
        self.assertIn("97cc62d", text)
        self.assertIn("f36ac84", text)
        self.assertIn("346 → 360", text)
        self.assertIn("241 → 250", text)
        # blocked before is derived: 346 - 241 = 105
        self.assertIn("105 → 110", text)

    def test_lists_each_changed_spell_with_what_changed(self):
        text = report.render(self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0)
        self.assertIn("New Spell", text)
        self.assertIn("baseEffectId", text)
        self.assertIn("cran-5a", text)
        self.assertIn("cran-5c", text)

    def test_quotes_design_lines_when_both_are_supplied(self):
        text = report.render(
            self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0,
            old_design_lines={"lib-b": "(Base 3, +1 Touch)"},
            new_design_lines={"lib-b": "(Base 5, +1 Touch)"},
        )
        self.assertIn("(Base 3, +1 Touch) → (Base 5, +1 Touch)", text)

    def test_omits_design_lines_with_a_note_when_the_old_text_is_unavailable(self):
        text = report.render(
            self.diff, LOCK, CURRENT, imported=250, blocked=110, unresolved=0,
            old_design_lines=None,
            new_design_lines={"lib-b": "(Base 5, +1 Touch)"},
        )
        self.assertNotIn("→ (Base 5, +1 Touch)", text)
        self.assertIn("design lines unavailable", text)

    def test_no_lock_renders_as_an_initial_import(self):
        text = report.render(self.diff, None, CURRENT, imported=250, blocked=110, unresolved=0)
        self.assertIn("initial import", text.lower())
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_report -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.spell_import.report'`.

- [ ] **Step 3: Write `report.py`**

```python
"""Turn two versions of the generated asset into something a human will read.

A diff across 250 JSON objects is not a review surface. This renders the same
information as a short markdown summary, which is what makes the
`--accept-source` gate meaningful rather than ceremonial.

Pure: dicts and identities in, a string out. No file or git access, so it is
fully testable with no rulebook present.
"""
import dataclasses

from . import provenance

# Keys that carry no reviewable meaning when they change.
_IGNORED_KEYS = frozenset({"createdAt", "updatedAt"})


@dataclasses.dataclass(frozen=True)
class AssetDiff:
    added: list[dict]
    removed: list[dict]
    changed: list[tuple[dict, dict]]

    @property
    def is_empty(self) -> bool:
        return not (self.added or self.removed or self.changed)


def _comparable(spell: dict) -> dict:
    return {k: v for k, v in spell.items() if k not in _IGNORED_KEYS}


def diff_assets(old: list[dict], new: list[dict]) -> AssetDiff:
    old_by_id = {s["id"]: s for s in old}
    new_by_id = {s["id"]: s for s in new}
    added = [new_by_id[i] for i in sorted(new_by_id.keys() - old_by_id.keys())]
    removed = [old_by_id[i] for i in sorted(old_by_id.keys() - new_by_id.keys())]
    changed = [
        (old_by_id[i], new_by_id[i])
        for i in sorted(old_by_id.keys() & new_by_id.keys())
        if _comparable(old_by_id[i]) != _comparable(new_by_id[i])
    ]
    return AssetDiff(added=added, removed=removed, changed=changed)


def _changed_fields(old: dict, new: dict) -> list[str]:
    keys = sorted((old.keys() | new.keys()) - _IGNORED_KEYS)
    return [
        f"{key}: {old.get(key)!r} → {new.get(key)!r}"
        for key in keys
        if old.get(key) != new.get(key)
    ]


def render(
    diff: AssetDiff,
    lock: provenance.SourceIdentity | None,
    current: provenance.SourceIdentity,
    imported: int,
    blocked: int,
    unresolved: int,
    old_design_lines: dict[str, str] | None = None,
    new_design_lines: dict[str, str] | None = None,
) -> str:
    lines = ["# Import change report", ""]

    if lock is None:
        lines.append(f"Initial import at {current.label().splitlines()[0]}")
        lines.append(f"Parsed {current.spells_parsed} · imported {imported} · "
                     f"blocked {blocked} · unresolved {unresolved}")
    else:
        old_commit = "unknown" if lock.rulebook is None else lock.rulebook.commit
        new_commit = "unknown" if current.rulebook is None else current.rulebook.commit
        subject = "" if current.rulebook is None else f' ("{current.rulebook.subject}")'
        lines.append(f"Source: {old_commit} → {new_commit}{subject}")
        # unresolved is always 0 in a committed lock: run() refuses to write otherwise.
        blocked_before = (lock.spells_parsed or 0) - (lock.spells_imported or 0)
        lines.append(
            f"Parsed {lock.spells_parsed} → {current.spells_parsed} · "
            f"imported {lock.spells_imported} → {imported} · "
            f"blocked {blocked_before} → {blocked} · "
            f"unresolved 0 → {unresolved}"
        )
    lines.append("")

    lines.append(f"## Newly imported ({len(diff.added)})")
    lines.extend(f"- {s['name']} (`{s['id']}`)" for s in diff.added) or lines.append("- none")
    lines.append("")

    lines.append(f"## No longer imported ({len(diff.removed)})")
    lines.extend(f"- {s['name']} (`{s['id']}`)" for s in diff.removed) or lines.append("- none")
    lines.append("")

    lines.append(f"## Changed ({len(diff.changed)})")
    if not diff.changed:
        lines.append("- none")
    for old, new in diff.changed:
        lines.append(f"- {new['name']} (`{new['id']}`)")
        lines.extend(f"  - {field}" for field in _changed_fields(old, new))
        before = (old_design_lines or {}).get(new["id"])
        after = (new_design_lines or {}).get(new["id"])
        if before and after and before != after:
            lines.append(f"  - design line: {before} → {after}")
    lines.append("")

    if diff.changed and old_design_lines is None:
        lines.append("_Old design lines unavailable — the recorded rulebook revision "
                     "could not be read from git._")
        lines.append("")

    return "\n".join(lines)
```

Note the `lines.extend(...) or lines.append("- none")` idiom: `list.extend` returns `None`, so the `append` runs exactly when the generator was empty. If that reads as too clever for this codebase, expand it to an explicit `if`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_report -v`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/report.py scripts/spell_import/tests/test_report.py
git commit -m "$(cat <<'EOF'
feat: render an asset diff as a readable import change report

A diff across 250 JSON objects is not a review surface. This summarises
added, removed and changed spells in ~15 lines, which is what makes the
--accept-source gate meaningful rather than ceremonial.

Blocked counts on the "before" side derive from the lock rather than
needing new fields: unresolved is always zero in a committed lock,
because run() refuses to write the asset otherwise.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Best-effort retrieval of the old design lines

Splitting the git read from the parse keeps the parse unit-testable without a git fixture.

**Files:**
- Modify: `scripts/spell_import/report.py` (append two functions)
- Test: `scripts/spell_import/tests/test_report.py` (append one test class)

**Interfaces:**
- Consumes: `blocks.parse_de`, `catalog.slug_id` from the existing codebase.
- Produces:
  - `report.design_lines_of(text: str) -> dict[str, str]` — spell id to design line, for any rulebook markdown
  - `report.old_design_lines(root, commit, relative) -> dict[str, str] | None` — `None` on any git failure

- [ ] **Step 1: Write the failing tests**

Append to `scripts/spell_import/tests/test_report.py`:

```python
import pathlib
import tempfile


class DesignLinesTest(unittest.TestCase):
    MARKDOWN = "\n".join([
        "### Creo Animal Spells",
        "#### LEVEL 20",
        "##### Soothe Pains of the Beast",
        "R: Touch, D: Mom, T: Ind, Ritual",
        "Prose about the spell.",
        "(Base level 15, +1 Touch)",
    ])

    def test_maps_spell_id_to_its_design_line(self):
        found = report.design_lines_of(self.MARKDOWN)
        self.assertEqual(found, {"lib-cran-soothe-pains-beast": "(Base level 15, +1 Touch)"})

    def test_text_with_no_spells_yields_an_empty_mapping(self):
        self.assertEqual(report.design_lines_of("# Just a heading\n\nSome prose."), {})

    def test_old_design_lines_returns_none_outside_a_git_checkout(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(
                report.old_design_lines(pathlib.Path(tmp), "deadbee", "reviewed/Book.md")
            )
```

**Before writing the implementation, confirm the expected id.** Run:

```bash
python -c "from scripts.spell_import.catalog import slug_id; print(slug_id('Creo','Animal','Soothe Pains of the Beast'))"
```

Use whatever that prints as the expected key in `test_maps_spell_id_to_its_design_line` — `slug_id` applies stopword removal, so do not guess it.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_report -v`
Expected: FAIL — `AttributeError: module 'scripts.spell_import.report' has no attribute 'design_lines_of'`.

- [ ] **Step 3: Implement both functions**

Append to `scripts/spell_import/report.py`:

```python
def design_lines_of(text: str) -> dict[str, str]:
    """Spell id to printed design line, for any revision of the rulebook."""
    from . import blocks, catalog as catalog_module

    parsed, _ = blocks.parse_de(text.split("\n"))
    return {
        catalog_module.slug_id(block.technique, block.form, block.name): block.design_line
        for block in parsed
        if block.design_line
    }


def old_design_lines(root, commit: str, relative: str) -> dict[str, str] | None:
    """The design lines as of a past rulebook revision. Best effort.

    Returns None when the rulebook is not a git checkout, the revision is
    not fetched, or git is unavailable. The report degrades to omitting the
    design-line column; it never fails because of this.
    """
    import subprocess

    try:
        finished = subprocess.run(
            ["git", "-C", str(root), "show", f"{commit}:{relative}"],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if finished.returncode != 0:
        return None
    return design_lines_of(finished.stdout)
```

The imports sit inside the functions deliberately: `report.py`'s core stays free of the parsing stack, so `test_report.py`'s other tests keep running with no rulebook and no catalog files present.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_report -v`
Expected: PASS, 11 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/spell_import/report.py scripts/spell_import/tests/test_report.py
git commit -m "$(cat <<'EOF'
feat: quote old design lines in the change report, best effort

Retrieves the recorded rulebook revision with git show and parses its
design lines, so a changed spell shows the rulebook prose that moved
rather than only the computed result. Degrades to omitting the column
when the revision cannot be read; never fails because of it.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Wire the gate into `extract_spells.py` and bootstrap the lock

**Files:**
- Modify: `scripts/spell_import/extract_spells.py`
- Create: `scripts/spell_import/source.lock` (generated, then committed)
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: `Report` gains `design_lines: dict[str, str]` and `identity: provenance.SourceIdentity`; `run(write=False, accept_source=False)`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/spell_import/tests/test_extract.py`:

```python
class WriteGateTest(unittest.TestCase):
    """The gate is exercised through run()'s return value, not by writing.

    These must never call run(write=True) against the real asset — a test
    that rewrites committed data is a test that can destroy it.
    """

    def test_report_carries_the_source_identity(self):
        report = extract_spells.run(write=False)
        self.assertIsNotNone(report.identity.sha256)
        self.assertEqual(len(report.identity.sha256), 64)
        self.assertEqual(report.identity.spells_parsed, 360)

    def test_report_carries_a_design_line_per_imported_spell(self):
        report = extract_spells.run(write=False)
        for spell in report.spells:
            self.assertIn(spell["id"], report.design_lines, msg=spell["id"])

    def test_the_committed_lock_matches_the_current_source(self):
        from scripts.spell_import import provenance
        lock = provenance.load()
        self.assertIsNotNone(lock, "source.lock is missing — run --write --accept-source")
        report = extract_spells.run(write=False)
        self.assertTrue(
            provenance.matches(lock, report.identity),
            msg="\n\n" + provenance.describe_change(lock, report.identity),
        )
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_extract -v`
Expected: FAIL — `AttributeError: 'Report' object has no attribute 'identity'`.

- [ ] **Step 3: Modify `extract_spells.py`**

Add to the imports at the top:

```python
from . import blocks, catalog as catalog_module, designline, ledger as ledger_module
from . import emit, provenance, report as report_module, sources
```

Add the report path constant beside the others:

```python
REPORT_PATH = ledger_module.LEDGER_PATH.with_name("import_report.md")
```

Extend the dataclass:

```python
@dataclasses.dataclass
class Report:
    spells: list[dict]
    blocked: list[tuple[str, str]]
    unresolved: list[str]
    problems: list[str]
    identity: provenance.SourceIdentity
    design_lines: dict[str, str]
```

Change `run`'s signature and its opening:

```python
def run(write: bool = False, accept_source: bool = False) -> Report:
    root = sources.default_root()
    path = sources.resolve_book(sources.DE_TITLE, root)
    lines = sources.read_lines(path)
    parsed, problems = blocks.parse_de(lines)
    catalog = catalog_module.Catalog.load()
    book = ledger_module.Ledger.load()

    design_lines: dict[str, str] = {}
```

Inside the per-block loop, immediately after `spell_id` is computed, record the
design line so the report can quote the new side:

```python
        spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
        design_lines[spell_id] = design_text
```

Replace the write block at the end of `run` with:

```python
    identity = provenance.describe(
        sources.DE_TITLE, path, root, parsed=len(parsed), imported=len(spells)
    )

    if write and not unresolved and not problems:
        lock = provenance.load()
        fresh = serialize(spells)
        committed = LIBRARY_PATH.read_text(encoding="utf-8") if LIBRARY_PATH.is_file() else ""
        would_change = fresh != committed

        # An absent lock refuses unconditionally: nothing can be attested, so
        # "the asset happens to match" is not a reason to proceed quietly. A
        # merely-moved source refuses only when it would actually rewrite the
        # asset, since otherwise --write is a no-op anyway.
        if not provenance.matches(lock, identity) and not accept_source:
            if would_change or lock is None:
                raise SourceMoved(provenance.describe_change(lock, identity))

        if would_change:
            LIBRARY_PATH.write_text(fresh, encoding="utf-8")

        if accept_source:
            if would_change:
                old = json.loads(committed) if committed else []
                previous = None
                if lock is not None and lock.rulebook is not None:
                    previous = report_module.old_design_lines(
                        root, lock.rulebook.commit, lock.path
                    )
                REPORT_PATH.write_text(
                    report_module.render(
                        report_module.diff_assets(old, spells),
                        lock, identity,
                        imported=len(spells), blocked=len(blocked), unresolved=len(unresolved),
                        old_design_lines=previous, new_design_lines=design_lines,
                    ),
                    encoding="utf-8",
                )
            provenance.write(identity)

    return Report(
        spells=spells, blocked=blocked, unresolved=unresolved, problems=problems,
        identity=identity, design_lines=design_lines,
    )
```

Add the exception near the top of the module, below `PROPOSALS_PATH`:

```python
class SourceMoved(Exception):
    """The rulebook changed since the committed asset was generated."""
```

Update `main` to add the flag, reject the meaningless combination, and print the drift message rather than a traceback:

```python
    parser.add_argument("--write", action="store_true", help="rewrite spell_library.json")
    parser.add_argument(
        "--accept-source", action="store_true",
        help="adopt a changed rulebook: rewrite source.lock and the change report",
    )
    args = parser.parse_args(argv)

    if args.accept_source and not args.write:
        parser.error("--accept-source is only meaningful with --write")

    try:
        report = run(write=args.write, accept_source=args.accept_source)
    except SourceMoved as error:
        print(error, file=sys.stderr)
        return 1
```

- [ ] **Step 4: Run the suite; two tests are expected to fail for the right reason**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: `test_the_committed_lock_matches_the_current_source` FAILS with "source.lock is missing". Everything else passes. That failure is the bootstrap gap the next step closes.

- [ ] **Step 5: Bootstrap the lock**

```bash
python -m scripts.spell_import.extract_spells --write --accept-source
```

Expected output: `imported : 250`, `blocked : 110`, `unresolved: 0`, then `wrote …spell_library.json`.

Then confirm nothing but the lock appeared:

```bash
git status --porcelain
```

Expected: `?? scripts/spell_import/source.lock` **only**. `spell_library.json` must be unmodified — the source has not changed since it was generated, so the asset does not change and (per the design) no `import_report.md` is written. If `spell_library.json` shows as modified, stop: something in Tasks 1–5 altered generator output, and that must be understood before committing.

- [ ] **Step 6: Run the full suite**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS, all green.

- [ ] **Step 7: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_extract.py scripts/spell_import/source.lock
git commit -m "$(cat <<'EOF'
feat: gate asset regeneration on an explicit source acceptance

--write now refuses when the rulebook has moved since the committed
asset was generated, unless --accept-source is passed, and accepting
writes both the lock and a readable change report. The pre-existing
unresolved/problems guard still runs first, so adopting a source can
never bypass it.

Bootstraps source.lock at the current rulebook revision. The asset is
unchanged, so no change report is written -- correct per the design,
which writes one only when the asset actually moves.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Make `RegenerationTest`'s failure message drift-aware

The message that misdirected a real debugging session — blaming the asset for being "stale or hand-edited" when the asset was correct and the source had moved.

**Files:**
- Modify: `scripts/spell_import/tests/test_extract.py:44-60`

**Interfaces:**
- Consumes: `provenance.load`, `provenance.matches`, `provenance.describe_change` from Task 2; `Report.identity` from Task 5.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing test**

Append to `scripts/spell_import/tests/test_extract.py`:

```python
class RegenerationMessageTest(unittest.TestCase):
    """The message must name the real cause, not the likeliest-looking one."""

    def test_names_the_source_when_the_lock_disagrees(self):
        from scripts.spell_import import provenance
        lock = provenance.SourceIdentity(
            book="B", path="reviewed/B.md", sha256="0" * 64,
            rulebook=provenance.RulebookRevision("aaaaaaa", "2026-01-01", "old"),
            spells_parsed=1, spells_imported=1,
        )
        current = dataclasses.replace(lock, sha256="1" * 64)
        message = extract_spells.regeneration_failure_message(lock, current)
        self.assertIn("rulebook source moved", message)
        self.assertNotIn("hand-edited", message)

    def test_blames_the_asset_when_the_lock_agrees(self):
        from scripts.spell_import import provenance
        lock = provenance.SourceIdentity(
            book="B", path="reviewed/B.md", sha256="0" * 64, rulebook=None,
            spells_parsed=1, spells_imported=1,
        )
        message = extract_spells.regeneration_failure_message(lock, lock)
        self.assertIn("hand-edited", message)
        self.assertNotIn("rulebook source moved", message)
```

Add `import dataclasses` to the top of `test_extract.py`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `python -m unittest scripts.spell_import.tests.test_extract.RegenerationMessageTest -v`
Expected: FAIL — `AttributeError: module ... has no attribute 'regeneration_failure_message'`.

- [ ] **Step 3: Add the helper to `extract_spells.py`**

```python
def regeneration_failure_message(
    lock: provenance.SourceIdentity | None, current: provenance.SourceIdentity
) -> str:
    """Why does a fresh run disagree with the committed asset?

    Two very different causes, and the wrong guess costs real time: either
    the rulebook moved under a correct asset, or the asset was edited by
    hand. The lock is what tells them apart.
    """
    if not provenance.matches(lock, current):
        return provenance.describe_change(lock, current)
    return (
        "assets/data/spell_library.json is stale or was hand-edited — "
        "re-run `python -m scripts.spell_import.extract_spells --write`"
    )
```

- [ ] **Step 4: Use it in `RegenerationTest`**

Replace `test_committed_library_matches_a_fresh_run`'s body:

```python
    def test_committed_library_matches_a_fresh_run(self):
        from scripts.spell_import import provenance

        report = extract_spells.run(write=False)
        committed = json.loads(LIBRARY.read_text(encoding="utf-8"))
        self.assertEqual(
            extract_spells.serialize(report.spells),
            extract_spells.serialize(committed),
            msg="\n\n" + extract_spells.regeneration_failure_message(
                provenance.load(), report.identity
            ),
        )
```

- [ ] **Step 5: Run the full suite**

Run: `python -m unittest discover -s scripts/spell_import/tests -t .`
Expected: PASS.

- [ ] **Step 6: Verify the message end to end, then restore**

This proves the message actually fires, which no unit test can show:

```bash
python - <<'PY'
import json, pathlib
p = pathlib.Path("scripts/spell_import/source.lock")
d = json.loads(p.read_text(encoding="utf-8"))
d["sha256"] = "0" * 64
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
python -m unittest scripts.spell_import.tests.test_extract -v 2>&1 | grep -A6 "rulebook source moved"
git checkout scripts/spell_import/source.lock
```

Expected: the drift message appears, naming both revisions. Then `git status --porcelain` must be clean.

- [ ] **Step 7: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_extract.py
git commit -m "$(cat <<'EOF'
fix: make the regeneration failure name the real cause

The message blamed the asset for being "stale or hand-edited" whichever
had happened. When the rulebook had moved under a correct asset -- the
case that cost half an hour of debugging -- it actively misdirected.
The lock now tells the two apart.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Weekly rulebook-freshness workflow

The freshness job needs no new comparison logic: running the existing Python suite with the rulebook at `origin/main` fails precisely when an upstream change reaches the library, via `RegenerationTest`, and stays quiet for chapter reviews that touch no spells.

**Files:**
- Create: `.github/workflows/rulebook-freshness.yml`

**Interfaces:**
- Consumes: `ARS_RULEBOOK_ROOT` from Task 1; the drift message from Task 6.
- Produces: nothing other tasks depend on.

**Scope note:** this repository has no `.github/` directory yet. The push/PR
`tests` workflow is **item 29's deliverable**, not this task's — see the spec's
§5. Only the freshness job belongs here.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/rulebook-freshness.yml`:

```yaml
# Is the committed spell library still what the current rulebook produces?
#
# Deliberately unpinned: it clones the rulebook at origin/main, so a failure
# means "upstream improved, go adopt it" rather than "something broke". It is
# quiet when a rulebook change touches no spell, because RegenerationTest
# compares the generated asset rather than the source bytes.
name: rulebook-freshness

on:
  schedule:
    - cron: "0 6 * * 1"   # Mondays, 06:00 UTC
  workflow_dispatch:

jobs:
  freshness:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"

      - name: Clone the rulebook at origin/main
        run: |
          git clone --depth 1 \
            https://github.com/OriginalMadman/Ars-Magica-Open-License.git \
            "${{ runner.temp }}/rulebook"

      - name: Report the recorded versus current source
        env:
          ARS_RULEBOOK_ROOT: ${{ runner.temp }}/rulebook
        run: |
          python - <<'PY'
          from scripts.spell_import import provenance, sources
          root = sources.default_root()
          path = sources.resolve_book(sources.DE_TITLE, root)
          current = provenance.describe(sources.DE_TITLE, path, root)
          lock = provenance.load()
          if provenance.matches(lock, current):
              print("Rulebook unchanged since the asset was generated.")
          else:
              print("NOTE: the rulebook has moved. Harmless unless the suite fails below.")
              print(provenance.describe_change(lock, current))
          PY

      - name: Run the import harness suite against upstream
        env:
          ARS_RULEBOOK_ROOT: ${{ runner.temp }}/rulebook
        run: python -m unittest discover -s scripts/spell_import/tests -t .
```

The `--depth 1` clone means `old_design_lines` cannot reach the recorded
revision on a runner, so a CI-side report would omit that column. That is the
intended best-effort degradation and is why the report is generated locally at
adoption time, not in CI.

- [ ] **Step 2: Validate the workflow parses**

There is no YAML parser in the standard library, and the Global Constraints
forbid adding a dependency for this. Use whichever of these is available,
in order:

```bash
# 1. If the GitHub CLI is installed, it validates against the real schema:
gh workflow view rulebook-freshness 2>/dev/null || echo "gh unavailable or branch unpushed"

# 2. Otherwise, if PyYAML happens to be present, a parse check is enough:
python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/rulebook-freshness.yml')); print('parses')" 2>/dev/null \
  || echo "PyYAML absent — inspect by eye, then confirm on the Actions tab after pushing"
```

Neither is a substitute for the job actually running. The step that genuinely
verifies the mechanism is Step 3.

- [ ] **Step 3: Verify the job's core command works locally with the override**

```bash
ARS_RULEBOOK_ROOT="$(cd ../Ars-Magica-Open-License && pwd)" \
  python -m unittest discover -s scripts/spell_import/tests -t .
```

Expected: PASS. This proves `ARS_RULEBOOK_ROOT` is honoured on a path the
default resolution would also have found, which is the mechanism CI depends on.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/rulebook-freshness.yml
git commit -m "$(cat <<'EOF'
ci: add a weekly rulebook freshness check

Clones the rulebook at origin/main -- deliberately unpinned -- and runs
the import harness suite against it. Fails only when an upstream change
actually reaches the generated library, so chapter reviews that touch no
spells stay quiet.

The push/PR test workflow remains item 29's deliverable.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Final verification

- [ ] **Both suites green**

```bash
python -m unittest discover -s scripts/spell_import/tests -t .
flutter test
```

Expected: Python OK; Flutter "All tests passed!". The Flutter suite must be run
because `spell_library.json` is an asset it asserts against — even though this
branch should leave it byte-identical.

- [ ] **The asset is untouched by this branch**

```bash
git diff main...HEAD --stat -- assets/
```

Expected: **empty**. This branch adds provenance around the generator; it must
not change generator output. Any diff here is a defect.

- [ ] **Update `.superpowers/todo.md`**

Add item 30 to section A recording what landed, and add to item 29 that the
push/PR `tests` job should read the rulebook SHA from `source.lock`. Add to
item 22 that `raw-md` no longer exists upstream and its file is retrievable
only via `git -C <rulebook> show 8b6c4d6^:"raw-md/Ars Magica 5e - Core Rules.md"`.

```bash
git add .superpowers/todo.md
git commit -m "$(cat <<'EOF'
docs: record item 30 and its consequences for items 22 and 29

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```
