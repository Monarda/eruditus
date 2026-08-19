# Standing Decisions and Constraints

Organised by topic. Each entry cites the item it came from.

## Notes — standing constraints

**Source of truth for the import:**
`Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md`,
Chapter 9 (lines 12020–16004). One supplement is also in the catalog as of item 17:
*Houses of Hermes: Mystery Cults* (`arm5-hohmc`).

**Source precedence:** the rulebook repo holds the same book in `reviewed/` and `wip/`,
in descending quality. **Always resolve `reviewed` → `wip` and stop at the first hit.**
Filenames differ between folders, so match on book title. (`raw-md/` was unreviewed OCR
and has been removed upstream.) The original base effects came from `raw-md` — item 22
reconciles the two.

**Aquam MVP limitation:** the Aquam Form has 5 distinct base-Individual sub-types
(water/liquids/poisons/blood/wine), each with slightly different guideline
progressions. The Size MVP supports one sub-type per spell via `aquam-base-individual`,
recorded in its base option's `baseIndividual` field. Mixed sub-types within Size
calculations are deferred.

**Prototype, not production:** backwards compatibility is not a goal and the database
is droppable, so a serialized-shape change needs no migration story. Correctness beats
compatibility.

**Verification rule of thumb:** a change to a screen's widget tree is **not** verified
by `flutter test` alone — `flutter test` does not run `integration_test/`, which needs
a device (`flutter test integration_test/... -d windows`). Run both, plus the Python
suite. All three commands and their current results are in *Where the import stands*.
