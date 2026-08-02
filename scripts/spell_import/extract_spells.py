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
        if block.design_line is None:
            blocked.append((block.name, "no design line printed"))
            continue

        try:
            design = designline.parse_design(block.design_line)
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
