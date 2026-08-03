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
