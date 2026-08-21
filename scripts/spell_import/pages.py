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

# The Reference Guide (the rulebook's appendix of quick-reference tables)
# reprints material from earlier chapters and cites the *body's* page for its
# own headings -- e.g. "### Ease Factors" links back to "Definitive Edition
# [p8](#ease-factor)", the page of Chapter 1's own Ease Factor heading, not
# of this one. An anchor whose heading sits in this range legitimately points
# backwards. Bounds: '# Reference Guide' (line 22629) to the line before
# '## Spells Index' (23778), the first of the four citation tables that
# follow it -- found by locating those two headings in the pinned rulebook,
# 2026-08-21.
REFERENCE_GUIDE_RANGE = (22629, 23777)

# The Spell Guidelines Index -- a `### ` table nested inside the Spells
# Index, one row per Technique/Form pair (e.g. "Rego Aquam") -- locates a
# *section*, not a guideline: see
# docs/superpowers/specs/2026-08-21-page-references-design.md, "Core
# guidelines, parameters, modifiers". Its citation measures where the
# guideline table begins, which is consistently a page ahead of the
# section's own first worked example, cited precisely by the Spells Index.
# Every row is excluded, not only the ones observed to violate monotonicity,
# because the imprecision is structural to the table rather than particular
# to a few of its 50 rows. Bounds: '### Spell Guidelines Index' (line 24143)
# to the line before '## Bestiary Index' (24198).
_SPELL_GUIDELINES_INDEX_RANGE = (24143, 24197)

# Isolated citations that contradict the pages measured, by the same index,
# immediately either side of them -- verified against the pinned rulebook,
# 2026-08-21. None of these share a duplicate heading or a conflicting
# citation (the two mechanical checks below already catch those); the only
# evidence is that each one disagrees with pages read independently on both
# sides of it:
#
#   933  Tribunals (a Code of Hermes clause) cites p22; its neighbours
#        (lines 923, 927, 937, 941) all cite p21.
#   2334 Hermetic Houses Summary cites p46; Virtues and Flaws immediately
#        after it cites p45 and fits its own neighbours (44 before, 47
#        after).
#   2956 Social Statuses by Culture cites p65, bracketed by p64 on both
#        sides (2952 before, 3026/3032 after).
#   4113 Guild Dean cites p85 and 4117 Guild Master cites p84 -- reversed
#        relative to their neighbours (84, 84 before; 85, 85 after). Nothing
#        in the markdown says which of the pair is transposed, so the
#        earlier one is dropped.
#   6490 Meddler and 6494 Mentor both cite p137, a two-line island inside a
#        ten-line run of p136 (six lines before, four after); both are
#        excluded, or the pair still reads as a decrease into Missing Ear.
#   7793 Sense Passions (Ability) cites p107 -- identical to the *Virtue*
#        row at line 4998, a different entry entirely -- while its own
#        neighbours (7785, 7813) both cite p170.
#   15912 Masking the Odor of Magic cites p369, the only such citation
#        inside a run of seven p370 citations either side of it.
#   16776 Damage Table cites p404, bracketed by p394 (16752 before, 16791
#        after).
#   17603 The Faerie Realm cites p417; Faerie Auras immediately after it
#        cites p416 and fits its own neighbours (415 before, 418 after).
#   21219 Gabriel, the Archangel of Prophecy cites p455, between citations
#        of p489 and p490.
#   22443 Mundane Interactions cites p518, between citations of p532 and
#        p533.
#
# Excluding these is not a guess at which of two numbers is correct -- it is
# refusing to calibrate from either, the same "return None rather than a
# guess" rule the two guards above already apply.
_ISOLATED_UNRELIABLE_LINES = frozenset({
    933, 2334, 2956, 4113, 6490, 6494, 7793,
    15912, 16776, 17603, 21219, 22443,
})

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


def _in_range(line, span):
    start, end = span
    return start <= line <= end


def build_index(lines):
    heading_lines, slugs = _headings(lines)
    anchor_pages = {}
    citations = {}   # slug -> [(citing_line, page), ...], document order
    for offset, text in enumerate(lines):
        for match in _ANCHOR.finditer(text):
            page, slug = int(match.group(1)), match.group(2)
            if slug not in slugs:
                continue   # an anchor with no heading is dropped, never guessed
            anchor_pages.setdefault(slug, page)
            citations.setdefault(slug, []).append((offset + 1, page))

    line_pages = {}
    for slug, cites in citations.items():
        heading_line = slugs[slug]
        if heading_line in _ISOLATED_UNRELIABLE_LINES:
            continue
        if _in_range(heading_line, REFERENCE_GUIDE_RANGE):
            continue   # reproduces body content; cites the body's page
        if len({page for _, page in cites}) > 1:
            continue   # the tables disagree on this anchor's page -- untrustworthy
        if all(_in_range(citing_line, _SPELL_GUIDELINES_INDEX_RANGE)
               for citing_line, _ in cites):
            continue   # locates a section, not this heading
        line_pages[heading_line] = cites[0][1]

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
