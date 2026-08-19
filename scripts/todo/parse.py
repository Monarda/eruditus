"""Parse a todo-style markdown file into addressable items.

Shared by migrate.py (one-time) and check.py (forever). The body of an item
runs to the next `### ` heading OR the next `## ` section heading, whichever
comes first -- the last item of a section must not swallow the heading that
ends it.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

# Two closed headings name two ids at once -- `### 35 / 37.`, `### 43 / 45.`.
# The first id owns the body; the second has a heading of its own elsewhere.
ITEM_RE = re.compile(
    r"^### (?P<id>\d+[a-z]?)(?: */ *\d+[a-z]?)*\.\s*(?P<title>.*)$")
SECTION_RE = re.compile(r"^## (?P<title>.*)$")
OPEN_BULLET_RE = re.compile(r"^\s*- \[ \]")
DONE_BULLET_RE = re.compile(r"^\s*- \[x\]")


@dataclass
class Item:
    id: str
    title: str
    heading: str        # the raw `### ` line, carried verbatim on migration
    start: int          # 1-based line number of the ### heading
    end: int            # 1-based, inclusive, last line of the body
    body: list[str]
    open_bullets: int
    done_bullets: int

    @property
    def total_bullets(self) -> int:
        return self.open_bullets + self.done_bullets


def parse_items(lines: list[str]) -> list[Item]:
    heads = [(n, m) for n, line in enumerate(lines, 1)
             if (m := ITEM_RE.match(line))]
    # EVERY `### ` line stops a body, not just the ones carrying an id. An
    # unnumbered heading (`### Base Effect Extraction`) would otherwise be
    # swallowed by the preceding item AND re-emitted by _unclaimed_blocks,
    # duplicating it in the archive and blurring that item's boundary.
    stops = sorted(n for n, line in enumerate(lines, 1)
                   if line.startswith("### ") or SECTION_RE.match(line))
    items = []
    for line_no, match in heads:
        later = [s for s in stops if s > line_no]
        end = (later[0] - 1) if later else len(lines)
        body = lines[line_no:end]
        items.append(Item(
            id=match.group("id"),
            title=match.group("title").strip(),
            heading=lines[line_no - 1],
            start=line_no,
            end=end,
            body=body,
            open_bullets=sum(1 for b in body if OPEN_BULLET_RE.match(b)),
            done_bullets=sum(1 for b in body if DONE_BULLET_RE.match(b)),
        ))
    return items


def section_of(lines: list[str], line_no: int) -> str:
    """The `## ` heading enclosing a 1-based line number, or "" if none."""
    current = ""
    for n, line in enumerate(lines, 1):
        if n > line_no:
            break
        if m := SECTION_RE.match(line):
            current = m.group("title").strip()
    return current
