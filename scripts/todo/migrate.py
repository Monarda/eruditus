"""The one-time split of todo.md into an index, themes and an archive.

Pure: `split` returns {relative path: text} and touches no disk. Bodies are
copied verbatim; the only edit is sub-id insertion.
"""
from __future__ import annotations

import re

from scripts.todo.mapping import ALL_IDS, MISFILED, THEMES, TOMBSTONES
from scripts.todo.parse import Item, parse_items, section_of

CHECKBOX_RE = re.compile(r"^(?P<lead>\s*- \[(?: |x)\] )(?P<rest>.*)$")

INDEX_HEADER = """# Eruditus — Item Index

**Now:** _(set during re-triage)_

**How this works:** item numbers are stable global ids, never reused and never
renumbered. Themes are files; the table below is the only thing that maps a
number to its home. `open 3/7` means three of seven sub-ids remain open.
Standing constraints live in `DECISIONS.md`; closed bodies in `ARCHIVE.md`.

| #  | Kind | Status | Home | Title |
|----|------|--------|------|-------|
"""


def add_sub_ids(body: list[str], item_id: str) -> list[str]:
    out, n = [], 0
    for line in body:
        if m := CHECKBOX_RE.match(line):
            n += 1
            out.append(f"{m.group('lead')}**{item_id}.{n}** {m.group('rest')}")
        else:
            out.append(line)
    return out


def _unclaimed_blocks(lines: list[str]) -> list[str]:
    """`### ` blocks carrying no parseable id, e.g. `### Base Effect Extraction`.

    They are real closed-work summary and must reach the archive. Only the band
    headers and the status section are deliberate deletions -- an unnumbered
    heading is not on that list, and dropping it would be a silent loss.
    """
    claimed = {item.start for item in parse_items(lines)}
    out: list[str] = []
    for n, line in enumerate(lines, 1):
        if not line.startswith("### ") or n in claimed:
            continue
        end = next((m for m, later in enumerate(lines[n:], n + 1)
                    if later.startswith(("### ", "## "))), len(lines) + 1)
        out.extend(lines[n - 1:end - 1] + [""])
    return out


def _status(item: Item, closed: bool) -> str:
    if closed:
        return "closed"
    if item.total_bullets:
        return f"open {item.open_bullets}/{item.total_bullets}"
    return "open"


def split(lines: list[str],
          expected_ids: frozenset[str] | None = None) -> dict[str, str]:
    """Split todo.md. Refuses to run against a file mapping.py does not match.

    The guard lives here rather than in a test because a test reading the live
    todo.md would go red the moment the migration replaces that file.
    """
    expected = ALL_IDS if expected_ids is None else expected_ids
    found = {item.id for item in parse_items(lines)}
    if found != expected:
        raise ValueError(
            f"todo.md has moved since mapping.py was written: "
            f"{sorted(found ^ expected)} -- reconcile ALL_IDS and THEMES first")

    files: dict[str, list[str]] = {}
    rows: dict[str, str] = {}

    def emit(path: str, text: list[str]) -> None:
        files.setdefault(path, []).extend(text)

    for item in parse_items(lines):
        in_completed = section_of(lines, item.start).startswith("Completed")
        # A tombstone is the redirect STUB in a band section -- NEVER the real
        # closed item sharing its number under `## Completed`. Ids 59, 60 and 61
        # each appear twice; filtering on bare id would delete 109 lines of real
        # closed history along with the 10 lines of stub.
        if item.id in TOMBSTONES and not in_completed:
            continue
        closed = in_completed and item.id not in MISFILED
        home = "ARCHIVE.md" if closed else f"themes/{THEMES[item.id]}"
        body = item.body if closed else add_sub_ids(item.body, item.id)
        emit(home, [item.heading] + body + [""])
        shown = home.split("/")[-1]
        # One row per id. An id with BOTH an open body and an archived
        # predecessor (item 4) is indexed at its open home -- the archive is
        # history, not a second home, so it must not claim a second row.
        if item.id not in rows or not closed:
            rows[item.id] = (f"| {item.id} |  | {_status(item, closed)} "
                             f"| {shown} | {item.title} |")

    tail = _unclaimed_blocks(lines)
    if tail:
        emit("ARCHIVE.md", tail)

    def sort_key(row: tuple[str, str]) -> tuple[int, str]:
        digits = re.match(r"(\d+)([a-z]?)", row[0])
        return int(digits.group(1)), digits.group(2)

    index = (INDEX_HEADER
             + "\n".join(r for _, r in sorted(rows.items(), key=sort_key))
             + "\n")

    out = {"todo.md": index}
    for path, text in files.items():
        title = path.split("/")[-1].removesuffix(".md").replace("-", " ").title()
        out[path] = f"# {title}\n\n" + "\n".join(text).rstrip() + "\n"
    return out
