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

        try:
            base_effect_id = book.resolve(spell_id, candidates)
        except ledger_module.MissingEntry as error:
            unresolved.append(str(error))
            if candidates:
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
