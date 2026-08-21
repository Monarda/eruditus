"""Printed page numbers, recovered from the rulebook's own curated indexes.

Three tables answer questions this importer needs, by direct lookup rather
than by inference from a nearby heading:

- Spells Index: spell name -> page.
- Spell Guidelines Index: (technique, form) -> page.
- Traditional Index: a qualified parameter name (e.g. "Voice (Range)") ->
  page.

A missing key means no page. Nothing here widens a key or guesses from a
neighbour -- a wrong page sends a reader to the wrong place, which is worse
than sending them nowhere.

See docs/superpowers/specs/2026-08-21-page-references-design.md.
"""

import re

from scripts.spell_import import sources

# `[313](#anchor)` and `[158-159](#anchor)`. The range's first page is what a
# citation carries; the pattern must still recognise the form, or the row is
# silently skipped rather than parsed.
_ANCHOR = re.compile(r"\[(\d+)(?:-\d+)?\]\(#([^)]+)\)")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")


def slugify(heading):
    """GitHub's heading-slug rules, which is what the anchors were built with."""
    text = heading.strip().lstrip("#").strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    return re.sub(r"\s+", "-", text).strip("-")


class PageIndex:
    def __init__(self, spell_index_pages, guideline_index_pages, topic_index_pages):
        self.spell_index_pages = spell_index_pages
        self.guideline_index_pages = guideline_index_pages
        self.topic_index_pages = topic_index_pages


def _find_heading(lines, text):
    """The 1-based line of the first heading whose text equals `text`."""
    for offset, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("#") and stripped.lstrip("#").strip().lower() == text:
            return offset + 1
    return None


def _spell_index_pages(lines):
    """The Spells Index's curated name -> page table.

    Authoritative, and nothing may second-guess it: the first occurrence of a
    spell name in the PDF matches this page only 57% of the time.
    """
    out = {}
    heading = _find_heading(lines, "spells index")
    if heading is None:
        return out
    for text in lines[heading:]:
        stripped = text.strip()
        if stripped.startswith("#"):
            break
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 4:
            continue
        match = _ANCHOR.search(cells[-1])
        if not match:
            continue
        name = _LINK.sub(r"\1", cells[0]).strip()
        if name:
            out[name] = int(match.group(1))
    return out


def _guideline_index_pages(lines):
    """The Spell Guidelines Index's (technique, form) -> page table.

    Columns are `| Form | Technique | page |` -- Form first, which is not
    the order the key uses.
    """
    out = {}
    heading = _find_heading(lines, "spell guidelines index")
    if heading is None:
        return out
    for text in lines[heading:]:
        stripped = text.strip()
        if stripped.startswith("#"):
            break
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 3:
            continue
        match = _ANCHOR.search(cells[-1])
        if not match:
            continue
        form, technique = cells[0], cells[1]
        if form and technique:
            out[(technique, form)] = int(match.group(1))
    return out


def _topic_index_pages(lines):
    """The Traditional Index's qualified-name -> page table.

    Runs from its own heading to end of file. Entry text has its `&nbsp;`
    stripped and is lowercased before use as a key.
    """
    out = {}
    heading = _find_heading(lines, "traditional index")
    if heading is None:
        return out
    for text in lines[heading:]:
        stripped = text.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 2:
            continue
        match = _ANCHOR.search(cells[-1])
        if not match:
            continue
        name = cells[0].replace("&nbsp;", "").strip().lower()
        if name:
            out[name] = int(match.group(1))
    return out


def build_index(lines):
    return PageIndex(
        spell_index_pages=_spell_index_pages(lines),
        guideline_index_pages=_guideline_index_pages(lines),
        topic_index_pages=_topic_index_pages(lines),
    )


def load_index():
    """Build a PageIndex from the pinned rulebook."""
    path = sources.resolve_book(sources.DE_TITLE)
    return build_index(sources.read_lines(path))
