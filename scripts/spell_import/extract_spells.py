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

from . import blocks, catalog as catalog_module, designline, ledger as ledger_module
from . import emit, provenance, report as report_module, sources

LIBRARY_PATH = catalog_module.DATA_DIR / "spell_library.json"
PROPOSALS_PATH = ledger_module.LEDGER_PATH.with_name("resolutions.proposed.json")
REPORT_PATH = ledger_module.LEDGER_PATH.with_name("import_report.md")


class SourceMoved(Exception):
    """The rulebook changed since the committed asset was generated."""


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


# General spells whose printed design line cannot be reconciled with their
# stat line. Not a wrong ledger pick and not an ambiguity between candidates
# -- KNOWN_UNRESOLVABLE means "two candidates fit equally", which is a
# different thing. Deliberately a hand-maintained list and NOT an inline
# assertion-6 check: ReferenceOracleTest exists to catch a template that
# violates assertion 6, and a filter that removes exactly what the test
# looks for would make the test unable to fail.
DESIGN_LINE_INCOMPLETE = {
    "lib-reim-restore-moved-image":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    "lib-invi-invisible-eye-revealed":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    "lib-muvi-wizards-communion":
        "prose disclaims guideline arithmetic: a remnant of Mercurian rituals",
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
#   unrelated candidate whose math happens to work: rete-15b (+4 size) lands
#   on exactly 75, but describes hurling a projectile, not a travel portal.
#
# - Aegis of the Hearth (R: Touch, D: Year, T: Boundary, level 30) prints no
#   design line at all. Touch(1) + Year(4) + Boundary(4) is nine magnitudes,
#   so a level-30 spell needs base -15 -- there is no General base effect
#   that low, and none is meant to exist here: the rulebook itself calls
#   Aegis of the Hearth a Major Breakthrough that is "more powerful than it
#   ought to be", i.e. explicitly outside the guidelines. Permanently
#   blocked, not pending -- there is no future ledger entry or catalog fix
#   that resolves this one.
HAND_DERIVED: dict[str, str] = {
    "Enchantment of the Scrying Pool": "(Base 5, +1 Touch, +4 Year)",
}


# One published design line names an adjustment and prints no magnitude for it.
# The magnitude below is a literal, worked out by hand and then *checked by*
# assertion 1 (published_spell_import_test.dart) -- it is never computed as
# `printed - computed`, which would make that assertion tautological here and
# unable to fail.
#
# The Shadow of Human Life (Creo Imaginem, R: Touch, D: Sun, T: Ind, Req:
# Mentem), printed LEVEL 40, design line:
#
#     (Base 2, +1 Touch, +2 Sun, +1 intricacy, +6 Mentem requisite,
#      for a very elaborate effect)
#
# In the rulebook's own arithmetic the numbered tokens already reach 40 --
# 2 -> 3 (Touch) -> 5 (Sun) -> 10 (intricacy) -> 40 (+6 requisite) -- and "for
# a very elaborate effect" is the text's *justification* for charging six
# magnitudes on a requisite instead of the usual one. This app does not model a
# requisite that way: `Requisite.magnitude` is 1 for every `adding` requisite
# (lib/models/requisite.dart), so the six-magnitude charge has to be split into
# the one magnitude the requisite carries and the five that the elaborateness
# carries. Hence:
#
#     base 2, additive capacity 3 (5 - 2)
#     +1 Touch                 -> 3   (additive tier)
#     +2 Sun                   -> 5   (additive tier, capacity spent)
#     +1 intricacy             -> 10  (crim-intricate-design, magnitude 1)
#     +1 Mentem requisite      -> 15  (adding requisite, magnitude 1)
#     +5 very elaborate effect -> 40  (5 x 5)
#
#     40 == the printed level. Any other magnitude misses it by 5 per step, so
#     assertion 1 discriminates this value exactly.
#
# Not modelled as an `elaborate-effect` modifier option: that modifier tops out
# at magnitude 3 (assets/data/modifiers.json), and inventing a magnitude-5
# option to fit one spell would be fitting the catalog to the arithmetic. A
# per-spell LevelAdjustment is what the rulebook's phrasing actually is.
#
# Mists of Change is the other numberless case and stays blocked. It prints
# "slightly nonstandard effect" (no magnitude) and its stat line carries
# "D: Sun & Year" -- two durations, which no adjustment can express. A
# hand-derived magnitude could paper over the first but not the second.
#
# Keyed by spell name -> (magnitude, the printed phrase to attach it to).
HAND_DERIVED_ADJUSTMENT: dict[str, tuple[int, str]] = {
    "The Shadow of Human Life": (5, "for a very elaborate effect"),
}


@dataclasses.dataclass
class Report:
    spells: list[dict]
    templates: list[dict]
    blocked: list[tuple[str, str]]
    unresolved: list[str]
    problems: list[str]
    identity: provenance.SourceIdentity
    design_lines: dict[str, str]


def serialize(spells: list[dict]) -> str:
    """Canonical form. Sorting by id is what makes the output stable."""
    ordered = sorted(spells, key=lambda s: s["id"])
    return json.dumps(ordered, indent=2, ensure_ascii=False) + "\n"


def regeneration_failure_message(
    lock: provenance.SourceIdentity | None, current: provenance.SourceIdentity
) -> str:
    """Why does a fresh run disagree with the committed asset?

    Two very different causes, and the wrong guess costs real time: either
    the rulebook moved under a correct asset, or the asset was edited by
    hand. The lock is what tells them apart.
    """
    if not provenance.matches(lock, current):
        return provenance.describe_change(lock, current)
    return (
        "assets/data/spell_library.json is stale or was hand-edited — "
        "re-run `python -m scripts.spell_import.extract_spells --write`"
    )


def run(write: bool = False, accept_source: bool = False) -> Report:
    root = sources.default_root()
    path = sources.resolve_book(sources.DE_TITLE, root)
    lines = sources.read_lines(path)
    parsed, problems = blocks.parse_de(lines)
    catalog = catalog_module.Catalog.load()
    book = ledger_module.Ledger.load()

    design_lines: dict[str, str] = {}

    spells: list[dict] = []
    templates: list[dict] = []
    blocked: list[tuple[str, str]] = []
    unresolved: list[str] = []
    proposals: dict[str, dict] = {}

    for block in parsed:
        design_text = block.design_line or HAND_DERIVED.get(block.name)
        if design_text is None:
            blocked.append((block.name, "no design line printed"))
            continue

        # The printed line is what the report records; only the parsed copy
        # gains the hand-derived magnitude, so import_report.md keeps showing
        # the rulebook's own words.
        parsed_text = design_text
        derived = HAND_DERIVED_ADJUSTMENT.get(block.name)
        if derived is not None:
            magnitude, phrase = derived
            if phrase not in parsed_text:
                blocked.append(
                    (block.name, f"hand-derived adjustment {phrase!r} is not in the design line")
                )
                continue
            parsed_text = parsed_text.replace(phrase, f"+{magnitude} {phrase}", 1)

        try:
            design = designline.parse_design(parsed_text)
        except designline.UnknownToken as error:
            blocked.append((block.name, str(error)))
            continue

        if design.base_level is None or block.printed_level is None:
            spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
            design_lines[spell_id] = design_text
            general_candidates = catalog.general_candidates(block.technique, block.form)

            if not general_candidates:
                blocked.append((block.name, "no General base effect for that Technique/Form"))
                continue

            if spell_id in DESIGN_LINE_INCOMPLETE:
                blocked.append(
                    (block.name, f"design line incomplete: {DESIGN_LINE_INCOMPLETE[spell_id]}")
                )
                continue

            if spell_id in KNOWN_UNRESOLVABLE:
                blocked.append((block.name, f"unresolvable: {KNOWN_UNRESOLVABLE[spell_id]}"))
                continue

            try:
                base_effect_id = book.resolve(spell_id, general_candidates)
            except ledger_module.MissingEntry as error:
                unresolved.append(str(error))
                proposals[spell_id] = {
                    "baseEffectId": "",
                    "candidates": general_candidates,
                    "rationale": "",
                    "_name": block.name,
                    "_line": block.line_no,
                    "_descriptions": [
                        e["description"] for e in catalog.base_effects
                        if e["id"] in general_candidates
                    ],
                }
                continue
            except ledger_module.LedgerError as error:
                unresolved.append(str(error))
                continue

            try:
                templates.append(emit.build_template(block, base_effect_id, catalog, design))
            except (designline.UnknownToken, KeyError) as error:
                blocked.append((block.name, str(error)))
            continue

        spell_id = catalog_module.slug_id(block.technique, block.form, block.name)
        design_lines[spell_id] = design_text
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

    identity = provenance.describe(
        sources.DE_TITLE, path, root, parsed=len(parsed), imported=len(spells)
    )

    if write and not unresolved and not problems:
        lock = provenance.load()
        fresh = serialize(spells)
        committed = LIBRARY_PATH.read_text(encoding="utf-8") if LIBRARY_PATH.is_file() else ""
        would_change = fresh != committed

        # An absent lock refuses unconditionally: nothing can be attested, so
        # "the asset happens to match" is not a reason to proceed quietly. A
        # merely-moved source refuses only when it would actually rewrite the
        # asset, since otherwise --write is a no-op anyway.
        if not provenance.matches(lock, identity) and not accept_source:
            if would_change or lock is None:
                raise SourceMoved(provenance.describe_change(lock, identity))

        if would_change:
            LIBRARY_PATH.write_text(fresh, encoding="utf-8")

        if accept_source:
            if would_change:
                old = json.loads(committed) if committed else []
                previous = None
                if lock is not None and lock.rulebook is not None:
                    previous = report_module.old_design_lines(
                        root, lock.rulebook.commit, lock.path
                    )
                REPORT_PATH.write_text(
                    report_module.render(
                        report_module.diff_assets(old, spells),
                        lock, identity,
                        imported=len(spells), blocked=len(blocked), unresolved=len(unresolved),
                        old_design_lines=previous, new_design_lines=design_lines,
                    ),
                    encoding="utf-8",
                )
            provenance.write(identity)

    return Report(
        spells=spells, templates=templates, blocked=blocked, unresolved=unresolved,
        problems=problems, identity=identity, design_lines=design_lines,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="rewrite spell_library.json")
    parser.add_argument(
        "--accept-source", action="store_true",
        help="adopt a changed rulebook: rewrite source.lock and the change report",
    )
    args = parser.parse_args(argv)

    if args.accept_source and not args.write:
        parser.error("--accept-source is only meaningful with --write")

    try:
        report = run(write=args.write, accept_source=args.accept_source)
    except SourceMoved as error:
        print(error, file=sys.stderr)
        return 1

    print(f"imported : {len(report.spells)}")
    print(f"templates: {len(report.templates)}")
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
