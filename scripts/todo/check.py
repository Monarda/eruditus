# scripts/todo/check.py
"""Structural invariants for the split todo tree.

Run by CI and by the closing-an-item skill. Encodes the design spec's
Verification section:

  * every index row's Home file really holds that heading
  * every heading in a theme or the archive really has an index row
  * the index's `open a/b` counts match the bodies
  * every `item N` cross-reference resolves to an index row
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from scripts.todo.parse import Item, parse_items

ROW_RE = re.compile(
    r"^\|\s*(?P<id>\d+[a-z]?)\s*\|"      # id
    r"\s*(?P<kind>[^|]*)\|"              # kind
    r"\s*(?P<status>[^|]*)\|"            # status
    r"\s*(?P<home>[^|]*)\|"              # home
)
COUNT_RE = re.compile(r"open\s+(?P<open>\d+)/(?P<total>\d+)")
# Deliberately under-detects: catches `item 25`, but only the FIRST number of
# `items 65, 57, 27`. A green run therefore proves that no DETECTED reference
# dangles -- not that every reference in the tree resolves. Widening this to
# comma lists is a fine later change; never weaken it to silence a failure.
XREF_RE = re.compile(r"\bitems?\s+(\d+[a-z]?)")


TRACKED = ("todo.md", "DECISIONS.md", "STATUS.md", "ARCHIVE.md")


def _read(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").split("\n")


def _tracked_files(root: Path):
    """Only the todo tree.

    `.superpowers/` also holds git-ignored scratch -- the SDD workspace and
    base_effects_extraction -- whose prose is not ours to police. Task briefs
    in particular quote item numbers out of the plan, so an rglob here would
    fail on this run's own working files.
    """
    for name in TRACKED:
        if (root / name).exists():
            yield root / name
    yield from sorted(root.glob("themes/*.md"))


def _index_rows(lines: list[str]) -> list[dict[str, str]]:
    rows = []
    for line in lines:
        if m := ROW_RE.match(line):
            rows.append({k: v.strip() for k, v in m.groupdict().items()})
    return rows


def check(root: Path) -> list[str]:
    problems: list[str] = []
    index_lines = _read(root / "todo.md")
    rows = _index_rows(index_lines)

    seen: set[str] = set()
    for row in rows:
        if row["id"] in seen:
            problems.append(f"item {row['id']}: listed twice in the index")
        seen.add(row["id"])

    # A theme body is an item's home and must match its index row. An ARCHIVE
    # body is history and is legal for any indexed id -- item 4 has an open
    # body in a theme AND an archived predecessor under the same number.
    theme_bodies: dict[str, tuple[str, Item]] = {}
    for path in sorted(root.glob("themes/*.md")):
        for item in parse_items(_read(path)):
            if item.id in theme_bodies:
                problems.append(
                    f"item {item.id}: body appears in two theme files")
            theme_bodies[item.id] = (path.name, item)

    archive_bodies: dict[str, Item] = {}
    archive = root / "ARCHIVE.md"
    if archive.exists():
        for item in parse_items(_read(archive)):
            archive_bodies[item.id] = item

    by_id = {row["id"]: row for row in rows}

    for row in rows:
        home, item_id = row["home"], row["id"]
        if home == "ARCHIVE.md":
            if item_id not in archive_bodies:
                problems.append(
                    f"item {item_id}: index says ARCHIVE.md, no body there")
            continue
        found = theme_bodies.get(item_id)
        if found is None or found[0] != home:
            where = "nowhere" if found is None else found[0]
            problems.append(
                f"item {item_id}: index says {home}, body found in {where}")
            continue
        if m := COUNT_RE.search(row["status"]):
            item = found[1]
            actual = (item.open_bullets, item.total_bullets)
            claimed = (int(m.group("open")), int(m.group("total")))
            if actual != claimed:
                problems.append(
                    f"item {item_id}: index claims open {claimed[0]}/{claimed[1]}, "
                    f"body has {actual[0]}/{actual[1]}")

    for item_id, (name, _) in sorted(theme_bodies.items()):
        if item_id not in by_id:
            problems.append(f"item {item_id}: orphan heading in {name}, no index row")
    for item_id in sorted(archive_bodies):
        if item_id not in by_id:
            problems.append(f"item {item_id}: orphan heading in ARCHIVE.md, no index row")

    for path in _tracked_files(root):
        for n, line in enumerate(_read(path), 1):
            if line.lstrip().startswith("|"):
                continue        # index rows are not cross-references
            for ref in XREF_RE.findall(line):
                if ref not in by_id:
                    problems.append(
                        f"{path.name}:{n}: 'item {ref}' resolves to no index row")

    return problems


def main() -> int:
    problems = check(Path(".superpowers"))
    for problem in problems:
        print(problem)
    print(f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
