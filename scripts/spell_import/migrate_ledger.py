"""Carry ledger decisions forward when the catalog grows underneath them.

Adding a base effect widens the candidate set of every spell at that
Technique/Form/level, and `ledger.resolve` rejects an entry whose recorded
candidates no longer match what the catalog offers. That check is right —
a new row might be the better pick, and nothing else in the build would
notice — but it fires even when the recorded choice is plainly unaffected,
which turns "add one supplement guideline" into "re-read N unrelated
spells" (todo item 55, where one row invalidated three).

This command splits that in two:

  * **A widening** — rows were only added, and the recorded choice is still
    among them. The decision stands, so the entry is rewritten with the new
    candidate list, keeping `baseEffectId` and `rationale` verbatim.
  * **Anything else** — a candidate disappeared, or the chosen row did.
    Never touched here. `ledger.StaleEntry` keeps demanding a human.

**A widened entry is not a reviewed entry**, and the file says so: the added
ids are recorded in `unreviewedCandidates`, because the rationale was
written without them and pretending otherwise is exactly the failure todo
item 32 exists to catch. Clear that field by hand once the entry has
genuinely been re-read against them.

This lives outside `extract_spells.py` on purpose. The extractor must never
write the ledger (see `ledger.py`'s module docstring); it only reports what
widened, and running this is a separate, deliberate act.

    python -m scripts.spell_import.migrate_ledger            # show
    python -m scripts.spell_import.migrate_ledger --write    # apply
"""
import argparse
import json
import sys

from . import extract_spells, ledger as ledger_module


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write", action="store_true",
        help="rewrite resolutions.json; without it, only report what would change",
    )
    args = parser.parse_args(argv)

    report = extract_spells.run(write=False)
    raw = json.loads(ledger_module.LEDGER_PATH.read_text(encoding="utf-8"))

    if not report.widenings:
        print("no widened ledger entries — nothing to migrate")
        # Unresolved entries that are NOT widenings need a human, and saying
        # "nothing to migrate" without saying so would read as "all clear".
        if report.unresolved:
            print(f"\n{len(report.unresolved)} entries still unresolved for other "
                  "reasons — these need a re-read, not a migration:", file=sys.stderr)
            for message in report.unresolved[:20]:
                print(f"  {message}", file=sys.stderr)
            return 1
        return 0

    for spell_id, candidates in sorted(report.widenings.items()):
        added = [c for c in candidates if c not in raw[spell_id]["candidates"]]
        print(f"{spell_id}: keeps {raw[spell_id]['baseEffectId']}, "
              f"records {added} as unreviewed")

    if not args.write:
        print(f"\n{len(report.widenings)} entr"
              f"{'y' if len(report.widenings) == 1 else 'ies'} would be migrated — "
              "re-run with --write to apply")
        return 0

    migrated = ledger_module.migrate_raw(raw, report.widenings)
    ledger_module.LEDGER_PATH.write_text(
        json.dumps(migrated, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"\nwrote {ledger_module.LEDGER_PATH}")
    print("re-run the extractor to confirm, then re-read each unreviewed "
          "candidate and clear the field by hand")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
