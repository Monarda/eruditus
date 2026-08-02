"""Extract published spells from the rulebook into assets/data/spell_library.json.

Maintained and re-runnable, unlike scripts/flag_ritual_effects.py. Running it
against an unchanged ledger and unchanged catalogs produces byte-identical
output; `test_extract.py` asserts exactly that.

    python -m scripts.spell_import.extract_spells          # report only
    python -m scripts.spell_import.extract_spells --write  # rewrite the asset
"""
import argparse
import dataclasses
import json
import sys

from . import blocks, catalog as catalog_module, designline, ledger as ledger_module, emit, sources

LIBRARY_PATH = catalog_module.DATA_DIR / "spell_library.json"
PROPOSALS_PATH = ledger_module.LEDGER_PATH.with_name("resolutions.proposed.json")

# Spells that genuinely cannot be resolved by a ledger entry: the rulebook's
# own text supports two or more candidates about equally, with no textual
# signal for which is primary (checked twice — a first pass resolved these,
# a review pass found the rationale was picking the most general-sounding
# candidate rather than a textually forced one, and pulled them). Recorded
# here rather than left as `unresolved` because "unresolved" means "add a
# ledger entry" — these don't have one to add. See .superpowers/todo.md
# item 27. Remove an entry once a rules decision actually resolves it.
KNOWN_UNRESOLVABLE = {
    "lib-inte-tracks-faerie-glow": "ambiguous between inte-4a/4b, no textual discriminator",
    "lib-inte-sense-feet-that-thread-earth": "ambiguous between inte-4a/4b, no textual discriminator",
    "lib-mute-crystal-dart": "ambiguous between mute-3a/3b/3c, stone-vs-crystal boundary",
    "lib-peig-conjuration-indubitable-cold": "ambiguous between peig-4a/4b/4c, three co-equal readings",
}


# The rulebook prints no design line for these three. Each derivation below is
# done by hand from the spell's stat line and a chosen guideline, and each is
# then checked by assertion 1 — if a derivation is wrong the computed level
# will not equal the printed one. Hand-derivation under a test is a different
# thing from hand-derivation on trust.
#
# Five further spells also lack a design line but are General-level and so
# belong to todo item 25, not here.
#
# Only one of the three actually resolves this way. All three spells' own
# prose explicitly disclaims normal Hermetic guideline arithmetic
# ("does not conform to the normal InAq guidelines" / "old Mercurian ritual",
# "fits poorly into the normal framework of Hermetic magic", "Mercurian
# Ritual"), so each was checked, not assumed, against the real InAq/InAu/ReTe
# guideline tables:
#
# - Enchantment of the Scrying Pool (R: Touch, D: Year, T: Ind, level 30):
#   Base 5 (inaq-5, "Learn the magical properties of a liquid" — the sole
#   candidate at level 5, so no ledger entry is needed) + Touch(1) + Year(4)
#   computes to exactly 30 via SpellLevelCalculator, and is the *only*
#   InAq base level (1, 2, 3a/3b, 4, 5, 10, 15, 20) that does. The "does not
#   conform" text turns out to describe the *range* mechanism (the pool
#   reaches another body of water via what "appears to be" an Arcane
#   Connection, without the usual +4 Range: Arcane Connection surcharge) —
#   not the base-effect arithmetic itself, which lines up exactly once the
#   stat line's actual Range (Touch, to the pool touched when cast) is used.
#
# - Whispering Winds (R: Sight, D: Conc, T: Ind, level 15) has no working
#   derivation. InAu's only base levels are 1, 2, 4, 15 (checked against
#   the printed Intellego Auram Guidelines table); with Sight(3) + Conc(1) +
#   Ind(0) fixed by the stat line, base 2 computes to 10 and base 4 to 20 —
#   15 sits exactly one magnitude short/over either way, with no legitimate
#   token to bridge it: the stat line carries no Req: art, the prose
#   names none, and size-auram's scope explicitly excludes Intellego. The
#   only numeric fits (base 2 + a fabricated +1 requisite, or base 1 + a
#   fabricated +2) require inventing a requisite the text does not support —
#   exactly the "picking a candidate because the math works, not because the
#   text forces it" mistake this file's KNOWN_UNRESOLVABLE comment already
#   warns against. Left blocked; its own prose ("fits poorly into the normal
#   framework of Hermetic magic") is the rulebook's own explanation for why.
#
# - Hermes' Portal (R: Arc, D: Year, T: Ind, level 75) has no working
#   derivation within this importer's current modelling. The only
#   thematically-grounded guideline is rete-4 ("Transport a non-living
#   object instantly up to 5 paces... add magnitudes for distance/Arcane
#   Connection"); with Arc(4) + Year(4) + Ind(0) fixed by the stat line,
#   Base 4 computes to 40, leaving a 35-level (7-magnitude) gap that only
#   closes with rete-4's own distance ladder at its top rung (Arcane
#   Connection, magnitude 5, modifiers.json id "rego-transport-distance")
#   plus 2 magnitudes of size. `emit.build_spell` only maps "size" tokens to
#   a modifiers.json option today (see `_selected_modifiers`'s docstring);
#   "rego-transport-distance" is modelled in the catalog (scoped to exactly
#   rete-4/rehe-10b/reig-3c) but not yet wired up. Extending that mapping is
#   a real fix, just a different and larger one than "correct this string" —
#   left blocked rather than forced through an unimplemented modifier or an
#   unrelated candidate whose math happens to work (rete-10/15 reach 75 too,
#   but describe hurling projectiles, not a travel portal).
HAND_DERIVED: dict[str, str] = {
    "Enchantment of the Scrying Pool": "(Base 5, +1 Touch, +4 Year)",
}


@dataclasses.dataclass
class Report:
    spells: list[dict]
    blocked: list[tuple[str, str]]
    unresolved: list[str]
    problems: list[str]


def serialize(spells: list[dict]) -> str:
    """Canonical form. Sorting by id is what makes the output stable."""
    ordered = sorted(spells, key=lambda s: s["id"])
    return json.dumps(ordered, indent=2, ensure_ascii=False) + "\n"


def run(write: bool = False) -> Report:
    lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
    parsed, problems = blocks.parse_de(lines)
    catalog = catalog_module.Catalog.load()
    book = ledger_module.Ledger.load()

    spells: list[dict] = []
    blocked: list[tuple[str, str]] = []
    unresolved: list[str] = []
    proposals: dict[str, dict] = {}

    for block in parsed:
        design_text = block.design_line or HAND_DERIVED.get(block.name)
        if design_text is None:
            blocked.append((block.name, "no design line printed"))
            continue

        try:
            design = designline.parse_design(design_text)
        except designline.UnknownToken as error:
            blocked.append((block.name, str(error)))
            continue

        if design.base_level is None or block.printed_level is None:
            blocked.append((block.name, "General level — todo item 25"))
            continue

        spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
        candidates = catalog.candidates(block.technique, block.form, design.base_level)

        if not candidates:
            blocked.append((block.name, "no base effect at that Technique/Form/level"))
            continue

        if spell_id in KNOWN_UNRESOLVABLE:
            blocked.append((block.name, f"unresolvable: {KNOWN_UNRESOLVABLE[spell_id]}"))
            continue

        try:
            base_effect_id = book.resolve(spell_id, candidates)
        except ledger_module.MissingEntry as error:
            unresolved.append(str(error))
            proposals[spell_id] = {
                "baseEffectId": "",
                "candidates": candidates,
                "rationale": "",
                "_name": block.name,
                "_line": block.line_no,
                "_descriptions": [
                    e["description"] for e in catalog.base_effects if e["id"] in candidates
                ],
            }
            continue
        except ledger_module.LedgerError as error:
            unresolved.append(str(error))
            continue

        try:
            spells.append(emit.build_spell(block, base_effect_id, catalog, design))
        except (designline.UnknownToken, KeyError) as error:
            blocked.append((block.name, str(error)))

    if proposals:
        PROPOSALS_PATH.write_text(
            json.dumps(proposals, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

    if write and not unresolved and not problems:
        LIBRARY_PATH.write_text(serialize(spells), encoding="utf-8")

    return Report(spells=spells, blocked=blocked, unresolved=unresolved, problems=problems)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="rewrite spell_library.json")
    args = parser.parse_args(argv)

    report = run(write=args.write)

    print(f"imported : {len(report.spells)}")
    print(f"blocked  : {len(report.blocked)}")
    print(f"unresolved: {len(report.unresolved)}")

    for problem in report.problems:
        print(f"  PARSE  {problem}", file=sys.stderr)
    for message in report.unresolved[:20]:
        print(f"  LEDGER {message}", file=sys.stderr)
    if report.unresolved:
        print(f"\nwrote {PROPOSALS_PATH} — copy decisions into resolutions.json by hand",
              file=sys.stderr)

    if report.problems or report.unresolved:
        return 1
    if args.write:
        print(f"wrote {LIBRARY_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
