"""Turn two versions of the generated asset into something a human will read.

A diff across 250 JSON objects is not a review surface. This renders the same
information as a short markdown summary, which is what makes the
`--accept-source` gate meaningful rather than ceremonial.

The diff and rendering functions are pure: dicts and identities in, a string out,
fully testable with no rulebook present. One function (old_design_lines) reaches
git on a best-effort basis to enrich the report; it gracefully degrades when
unavailable.
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
    locks: dict[str, provenance.SourceIdentity],
    currents: list[provenance.SourceIdentity],
    imported: int,
    blocked: int,
    unresolved: int,
    old_design_lines: dict[str, str] | None = None,
    new_design_lines: dict[str, str] | None = None,
) -> str:
    lines = ["# Import change report", ""]

    for current in sorted(currents, key=lambda i: i.book_id):
        recorded = locks.get(current.book_id)
        lines.append(f"## {current.book} (`{current.book_id}`)")
        if recorded is None:
            lines.append(f"Initial import at {current.label().splitlines()[0]}")
            lines.append(f"Parsed {current.spells_parsed}")
        else:
            old_commit = "unknown" if recorded.rulebook is None else recorded.rulebook.commit
            new_commit = "unknown" if current.rulebook is None else current.rulebook.commit
            subject = "" if current.rulebook is None else f' ("{current.rulebook.subject}")'
            lines.append(f"Source: {old_commit} → {new_commit}{subject}")
            lines.append(
                f"Parsed {recorded.spells_parsed} → {current.spells_parsed} · "
                f"imported {recorded.spells_imported} → {current.spells_imported}")
        lines.append("")

    # Asset-wide totals: the assets are one file each, so their diff is one
    # diff no matter how many books fed it.
    lines.append(f"Imported {imported} · blocked {blocked} · unresolved {unresolved}")
    lines.append("")

    lines.append(f"## Newly imported ({len(diff.added)})")
    newly_imported = [f"- {s['name']} (`{s['id']}`)" for s in diff.added]
    if newly_imported:
        lines.extend(newly_imported)
    else:
        lines.append("- none")
    lines.append("")

    lines.append(f"## No longer imported ({len(diff.removed)})")
    no_longer_imported = [f"- {s['name']} (`{s['id']}`)" for s in diff.removed]
    if no_longer_imported:
        lines.extend(no_longer_imported)
    else:
        lines.append("- none")
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


def design_lines_of(text: str) -> dict[str, str]:
    """Spell id to printed design line, for any revision of the rulebook."""
    # Local import to keep this function testable without catalog files.
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
    # Local import to keep render() and diff_assets() testable without git.
    import subprocess

    try:
        finished = subprocess.run(
            ["git", "-C", str(root), "show", f"{commit}:{relative}"],
            capture_output=True, text=True, timeout=30,
            encoding="utf-8", errors="replace",
        )
    except (OSError, subprocess.SubprocessError, UnicodeDecodeError):
        return None
    if finished.returncode != 0:
        return None
    return design_lines_of(finished.stdout)
