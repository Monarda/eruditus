"""Printed page numbers, recovered from the rulebook's four index tables.

Every row in those tables cites a page as `[313](#anchor)`, and an anchor
resolves to a heading whose line we know -- so a line's page is the page of
the nearest anchored heading above it. Both guards below return None rather
than a guess: a wrong page sends a reader to the wrong place, which is worse
than sending them nowhere.

See docs/superpowers/specs/2026-08-21-page-references-design.md.
"""

import bisect
import re

from scripts.spell_import import sources

# How far above a line its nearest anchor may sit before inference becomes a
# guess. Measured distance from a guideline to its nearest anchor is median
# 13 / p90 22 lines, and a printed page spans roughly 44 markdown lines -- so
# 60 accepts every real case while refusing the 789-line gap that exists
# elsewhere in the document.
MAX_ANCHOR_DISTANCE = 60

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
    def __init__(self, anchor_pages, line_pages, spell_index_pages,
                 heading_lines, heading_slugs):
        self.anchor_pages = anchor_pages
        self.line_pages = line_pages
        self.spell_index_pages = spell_index_pages
        self.heading_lines = heading_lines
        self.heading_slugs = heading_slugs
        self._lines = [line for line, _ in line_pages]

    def page_for_line(self, line):
        """The printed page of `line`, or None when the evidence is too thin."""
        position = bisect.bisect_right(self._lines, line) - 1
        if position < 0:
            return None
        anchor_line, page = self.line_pages[position]
        if line - anchor_line > MAX_ANCHOR_DISTANCE:
            return None
        return page

    def monotonicity_violations(self):
        """Adjacent calibration points whose page decreases as the line grows.

        A decrease means an anchor is being read out of its section, and
        `page_for_line` walks backwards -- so one bad anchor gives a wrong
        page to every line after it until the next one.
        """
        out = []
        for i in range(len(self.line_pages) - 1):
            line_a, page_a = self.line_pages[i]
            line_b, page_b = self.line_pages[i + 1]
            if page_b < page_a:
                out.append((line_a, page_a, line_b, page_b))
        return out


def _headings(lines):
    """Slug every heading, deduping repeats the way GitHub does."""
    seen = {}
    slugs = {}
    heading_lines = []
    for offset, text in enumerate(lines):
        if not text.strip().startswith("#"):
            continue
        line = offset + 1
        heading_lines.append(line)
        base = slugify(text)
        count = seen.get(base, 0)
        seen[base] = count + 1
        slugs[base if count == 0 else "%s-%d" % (base, count)] = line
    return heading_lines, slugs


def _spell_index_pages(lines, slugs):
    """The Spells Index's curated name -> page table.

    Authoritative, and nothing may second-guess it: the first occurrence of a
    spell name in the PDF matches this page only 57% of the time.
    """
    out = {}
    heading = next(
        (i for i, t in enumerate(lines)
         if t.strip().startswith("#")
         and t.strip().lstrip("#").strip().lower() == "spells index"),
        None)
    if heading is None:
        return out
    for text in lines[heading + 1:]:
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


def build_index(lines):
    heading_lines, slugs = _headings(lines)
    anchor_pages = {}
    line_pages = {}
    for text in lines:
        for match in _ANCHOR.finditer(text):
            page, slug = int(match.group(1)), match.group(2)
            if slug not in slugs:
                continue   # an anchor with no heading is dropped, never guessed
            anchor_pages.setdefault(slug, page)
            line_pages.setdefault(slugs[slug], page)
    return PageIndex(
        anchor_pages=anchor_pages,
        line_pages=sorted(line_pages.items()),
        spell_index_pages=_spell_index_pages(lines, slugs),
        heading_lines=heading_lines,
        heading_slugs=slugs,
    )


def load_index():
    """Build a PageIndex from the pinned rulebook."""
    path = sources.resolve_book(sources.DE_TITLE)
    return build_index(sources.read_lines(path))
