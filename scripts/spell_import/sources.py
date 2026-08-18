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
import dataclasses
import difflib
import os
import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# Descending quality. First hit wins.
FOLDERS = ("reviewed", "wip")

DE_TITLE = "Ars Magica - Definitive Edition (Core Rules)"


@dataclasses.dataclass(frozen=True)
class Book:
    """A book the importer reads, and how to read it.

    `title` is the markdown filename stem in the rulebook checkout, which is
    NOT the display title assets/data/books.json carries -- the checkout
    writes "Houses of Hermes - Mystery Cults" where books.json says
    "Houses of Hermes: Mystery Cults". Deriving one from the other would be a
    guess about punctuation across 54 filenames, so the mapping is explicit
    and a test joins the two files.
    """
    id: str      # the assets/data/books.json id, e.g. "arm5-hohmc"
    title: str   # the markdown filename stem in the rulebook checkout
    parser: str  # a key into blocks.PARSERS


BOOKS: tuple[Book, ...] = (
    Book(id="arm5-core", title=DE_TITLE, parser="de"),
)


def book_by_id(book_id: str) -> Book:
    for book in BOOKS:
        if book.id == book_id:
            return book
    raise KeyError(f"no registered book with id {book_id!r}")


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
