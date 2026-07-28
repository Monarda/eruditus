"""Resolve an Ars Magica rulebook to the best available markdown copy.

The rulebook repo holds the same book in three folders of descending quality.
`reviewed` has been proof-read; `raw-md` is unreviewed OCR with word-internal
case errors ("tHe Bitten toad") and split ligatures ("infl icted"). Parsing
raw OCR produces wrong data that looks plausible, so precedence is not a
preference — it is a correctness requirement.
"""
import pathlib
import re

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
RULEBOOK_ROOT = REPO_ROOT.parent / "Ars-Magica-Open-License"

# Descending quality. First hit wins.
FOLDERS = ("reviewed", "wip", "raw-md")

DE_TITLE = "Ars Magica - Definitive Edition (Core Rules)"

# raw-md filenames carry OCR-run suffixes and digital-edition tags that the
# reviewed copies do not, so books must be matched on title, not filename.
_SUFFIX = re.compile(r"\s*-\s*(ForceOCRfixed|RedoOCR)$")
_EDITION_TAG = re.compile(r"\s*\[digital edition\].*$")

# A handful of raw-md filenames diverge from their reviewed counterpart by
# more than an OCR-run suffix or edition tag (a missing subtitle, an extra
# word inserted before the title). These are known, specific mismatches, not
# a pattern worth solving with fuzzy matching, so they are listed explicitly:
# raw-md-derived title -> canonical (reviewed) title.
_TITLE_ALIASES = {
    "Ars Magica 4e - Sanctuary of Ice": (
        "Ars Magica 4e - Sanctuary of Ice - The Greater Alps Tribunal"
    ),
    "Ars Magica 5e - Tribunal - Against the Dark - The Transylvanian Tribunal": (
        "Ars Magica 5e - Against the Dark - The Transylvanian Tribunal"
    ),
    "Ars Magica Definitive Digital _alt version": DE_TITLE,
    "Ars Magica Definitive High Contrast": DE_TITLE,
}


def title_of(path: pathlib.Path) -> str:
    stem = path.name[: -len(".md")] if path.name.endswith(".md") else path.name
    stem = _EDITION_TAG.sub("", stem)
    stem = _SUFFIX.sub("", stem).strip()
    return _TITLE_ALIASES.get(stem, stem)


def all_books(root: pathlib.Path = RULEBOOK_ROOT) -> dict[str, pathlib.Path]:
    """Every book title mapped to its best available copy."""
    resolved: dict[str, pathlib.Path] = {}
    for folder in FOLDERS:
        directory = root / folder
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.md")):
            if "DO NOT USE" in path.name:
                continue
            resolved.setdefault(title_of(path), path)
    return resolved


def resolve_book(title: str, root: pathlib.Path = RULEBOOK_ROOT) -> pathlib.Path:
    books = all_books(root)
    if title not in books:
        raise FileNotFoundError(
            f"no markdown copy of {title!r} under {root} "
            f"(looked in {', '.join(FOLDERS)})"
        )
    return books[title]


def read_lines(path: pathlib.Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="strict").split("\n")
