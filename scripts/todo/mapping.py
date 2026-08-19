"""Which theme file each item lands in.

Data, not logic. Derived from the spec's appendix. Changing an item's home
later is a one-line edit here plus a re-run of check.py -- nothing
cross-references a file, only a number.
"""
from __future__ import annotations

RULES = "rules-fidelity.md"
APP = "app.md"
MODEL = "model.md"
IMPORTER = "importer.md"
MULTIBOOK = "multibook.md"

THEMES: dict[str, str] = {
    # catalog vs. what the rulebook prints
    "4": RULES, "4b": RULES, "4c": RULES, "12": RULES, "20": RULES,
    "21": RULES, "22": RULES, "36": RULES, "41": RULES, "42": RULES,
    "50": RULES, "63": RULES,
    # the Flutter app and project chores
    "7": APP, "9": APP, "10": APP, "11": APP, "16": APP, "18": APP,
    "23": APP, "33": APP, "56": APP, "58": APP,
    # what the spell model can't yet express
    "47": MODEL, "53": MODEL, "54": MODEL, "57": MODEL, "67": MODEL,
    "69": MODEL, "74": MODEL,
    # scripts/spell_import, ledger, provenance
    "31": IMPORTER, "32": IMPORTER, "38": IMPORTER, "70": IMPORTER,
    "73": IMPORTER,
    # the second-book program
    "66": MULTIBOOK, "71": MULTIBOOK,
}

# Redirect-only headings in section C. Deleted; the index carries the redirect.
TOMBSTONES: frozenset[str] = frozenset({"59", "60", "61"})

# Filed under `## Completed` but carrying only open bullets.
MISFILED: dict[str, str] = {"73": IMPORTER}

# Every id `todo.md` currently holds, closed ones included.
ALL_IDS: frozenset[str] = frozenset(
    {str(n) for n in range(1, 75)} | {"4b", "4c"}
)


def theme_for(item_id: str) -> str:
    return THEMES[item_id]
