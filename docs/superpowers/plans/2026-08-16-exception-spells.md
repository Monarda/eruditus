# Exception Spells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record the six published spells the rulebook itself says guideline
arithmetic doesn't apply to (*Wizard's Communion*, *Wizard's Vigil*, *Aegis of
the Hearth*, *Whispering Winds*, *Watching Ward*, *Mists of Change*) as a new
read-only `ExceptionSpell` collection — distinct from `Spell`/`SpellTemplate`
— instead of leaving them permanently blocked and absent from the library.

**Architecture:** A new `ExceptionSpell`/`ResolvedException` model pair,
parallel to how `SpellTemplate`/`ResolvedTemplate` already sit alongside
`Spell`. Free-text Range/Duration/Target instead of catalog references, a
required `rationale` citation instead of computed arithmetic, no
`SpellLevelCalculator` involvement. A new closed table,
`scripts/spell_import/exceptions.py`'s `EXCEPTION_SPELLS`, intercepts these
six spell names at the very top of `extract_spells.py`'s import loop —
before any design-line tokenization is attempted — and routes them to a new
`spell_exceptions.json` asset via `emit.build_exception_spell`. The Flutter
side adds a third section to `SpellLibraryScreen`, below Templates and
Spells, reusing the existing `SpellCard`/`LibraryEntry` machinery with one
new chip.

**Tech Stack:** Python 3 stdlib (`unittest`) for the import pipeline; Dart/
Flutter (`flutter_test`, `bloc_test`, `mocktail`) for the app. No new
dependencies either side.

## Global Constraints

- **Closed, exact-name allow-lists only — never a heuristic or a "looks like
  this shape" match.** `EXCEPTION_SPELLS`' six entries are the only spells
  this mechanism ever touches; a future spell that merely resembles one of
  these must not be added without the same citation-backed investigation the
  spec (`docs/superpowers/specs/2026-08-15-exception-spells-design.md`)
  already did.
- **No common parent class for `Spell`/`SpellTemplate`/`ExceptionSpell`.**
  Decided in the spec's §1 — do not introduce one while implementing.
- **`ExceptionSpell` never touches `SpellLevelCalculator` or any catalog
  parameter/base-effect resolution.** Range/Duration/Target are plain
  strings, read straight off `SpellBlock.stat`, never resolved against
  `parameters.json`.
- **After any change to `extract_spells.py`/`emit.py`/`exceptions.py`,
  regenerate the assets and re-run the Python suite**, in that order:
  `python -m scripts.spell_import.extract_spells --write` then
  `python -m unittest discover -s scripts/spell_import -t .` — a committed
  test asserts the committed JSON matches a fresh run byte-for-byte for
  `spell_library.json` and (this plan adds) `spell_exceptions.json`, so a
  stale asset shows up as a failure there, not silently.
- **Full verification before any task is considered done:**
  `python -m unittest discover -s scripts/spell_import -t .` (Python),
  `flutter test` (Dart), `flutter test integration_test/ -d windows`
  (integration). All three, every task, no exceptions.
- **`ARS_RULEBOOK_ROOT` env var:** set
  `ARS_RULEBOOK_ROOT=C:/Development/personal/Ars-Magica-Open-License` before
  running any Python command in this repo (the rulebook is a sibling
  checkout, and this repo's own layout does not resolve it by relative path
  from every working directory).
- **Commit style:** end every commit message with
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Look at `git
  log` for message tone (imperative, one-line summary, body explains why not
  just what).
- **Backwards compatibility is not a goal.** Eruditus is a prototype with no
  users; no migration path is designed and none should be added.

---

## Task 1: `emit.build_exception_spell` and the `EXCEPTION_SPELLS` table

Pure data/function layer — no wiring into the import loop yet. Testable in
isolation against synthetic `SpellBlock`s, the same way `test_emit.py`
already pins `emit.build_spell`'s adjustment/elaborate-effect handling.

**Files:**
- Create: `scripts/spell_import/exceptions.py`
- Modify: `scripts/spell_import/emit.py`
- Test: `scripts/spell_import/tests/test_emit.py`

**Interfaces:**
- Produces: `exceptions.EXCEPTION_SPELLS: dict[str, str]` (spell name →
  rationale), `emit.build_exception_spell(block, rationale: str) -> dict`.
- Consumes: `blocks.SpellBlock` (existing — `.name`, `.technique`, `.form`,
  `.printed_level`, `.stat.range_name`/`.duration_name`/`.target_name`/
  `.is_ritual`, `.prose`), `catalog_module.slug_id` (existing),
  `emit._template_summary`/`emit._description` (existing).

- [ ] **Step 1: Write the failing tests**

Add to `scripts/spell_import/tests/test_emit.py`, as a new class placed
after `AdjustmentEmissionTest` (following the file's own placement
convention of grouping related emission tests together):

```python
class ExceptionSpellEmissionTest(unittest.TestCase):
    """Direct pins for emit.build_exception_spell, independent of whether any
    real spell is currently routed to it -- ExceptionSpellsTest in
    test_extract.py covers the real six against the live corpus.
    """

    def _exception_block(
        self, name, technique, form, level,
        range_name="Touch", duration_name="Sun", target_name="Ind",
        is_ritual=False, prose="Test prose.",
    ) -> blocks.SpellBlock:
        return blocks.SpellBlock(
            name=name, technique=technique, form=form, printed_level=level,
            stat=statline.StatLine(
                range_name=range_name, duration_name=duration_name,
                target_name=target_name, is_ritual=is_ritual,
                requisite_arts=[], trailing="",
            ),
            prose=prose, design_line=None, line_no=1,
        )

    def test_a_general_kind_exception_has_no_printed_level(self):
        block = self._exception_block("Test Exception", "Muto", "Vim", None)
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertNotIn("printedLevel", exception)

    def test_a_fixed_level_exception_carries_its_printed_level(self):
        block = self._exception_block("Test Exception", "Intellego", "Auram", 15)
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertEqual(exception["printedLevel"], 15)

    def test_range_duration_target_are_the_raw_stat_line_strings(self):
        block = self._exception_block(
            "Test Exception", "Muto", "Corpus", 60,
            range_name="Voice", duration_name="Sun & Year", target_name="Bound",
        )
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertEqual(exception["range"], "Voice")
        self.assertEqual(exception["duration"], "Sun & Year")
        self.assertEqual(exception["target"], "Bound")

    def test_the_rationale_is_carried_verbatim(self):
        block = self._exception_block("Test Exception", "Muto", "Vim", None)
        exception = emit.build_exception_spell(block, "a specific citation")
        self.assertEqual(exception["rationale"], "a specific citation")

    def test_the_id_uses_the_exc_prefix_not_lib(self):
        block = self._exception_block("Whispering Winds", "Intellego", "Auram", 15)
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertEqual(exception["id"], "exc-inau-whispering-winds")

    def test_ritual_is_read_straight_off_the_stat_line(self):
        block = self._exception_block("Test Exception", "Rego", "Vim", None, is_ritual=True)
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertTrue(exception["isRitual"])

    def test_technique_and_form_are_carried(self):
        block = self._exception_block("Test Exception", "Rego", "Vim", None)
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertEqual(exception["technique"], "Rego")
        self.assertEqual(exception["form"], "Vim")

    def test_source_and_citation_match_every_other_published_entry(self):
        block = self._exception_block("Test Exception", "Muto", "Vim", None)
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertEqual(exception["source"], "published")
        self.assertEqual(exception["citations"], [{"bookId": "arm5-core"}])

    def test_summary_has_no_level_suffix(self):
        # _template_summary, not _summary -- an exception spell may have no
        # printed level at all, and "_summary" would emit the literal string
        # "Level None." the same way it would for a General template.
        block = self._exception_block(
            "Test Exception", "Muto", "Vim", None, prose="Some test prose here."
        )
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertEqual(exception["summary"], "Some test prose here.")

    def test_empty_prose_omits_the_description_key(self):
        block = self._exception_block("Test Exception", "Muto", "Vim", None, prose="")
        exception = emit.build_exception_spell(block, "test rationale")
        self.assertNotIn("description", exception)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_emit.ExceptionSpellEmissionTest -v`
Expected: every test FAILS with `AttributeError: module 'scripts.spell_import.emit' has no attribute 'build_exception_spell'`.

- [ ] **Step 3: Create `scripts/spell_import/exceptions.py`**

```python
"""Spells the rulebook itself says guideline arithmetic doesn't apply to.

Two shapes -- see docs/superpowers/specs/2026-08-15-exception-spells-design.md
for the full investigation: the spell's own prose disclaims normal Hermetic
design ("rulebook-disclaimed"), or the spell's real shape doesn't fit the
Range/Duration/Target model at all regardless of what the prose says
("schema-mismatched"). Either way there is no arithmetic to recover -- these
spells never route through build_spell/build_template, and no future
tokenizer or ledger change should try to make them.

A closed, exact-name table, the same discipline as extract_spells.py's
HAND_DERIVED/KNOWN_UNRESOLVABLE/DESIGN_LINE_INCOMPLETE. Each value is the
citation-backed reason a human read off the spell's own printed text, quoted
or closely paraphrased -- never inferred from a shape or a heuristic.
"""

EXCEPTION_SPELLS: dict[str, str] = {
    "Wizard's Communion": (
        'Design line prints "(Base effect)" but the spell\'s own prose '
        'disclaims it: "Communion is a remnant of Mercurian rituals, so it '
        'does not perfectly fit into the guidelines of Hermetic theory."'
    ),
    "Wizard's Vigil": (
        "No design line at all -- defined purely relative to Wizard's "
        'Communion ("treat it as a Wizard\'s Communion of two magnitudes '
        'lower"), itself an exception.'
    ),
    "Aegis of the Hearth": (
        "No design-line marker of any kind. The rulebook's own text says "
        'why: a Major Breakthrough combining Mercurian ritual with Hermetic '
        'theory, "more powerful than it ought to be, and has no Perdo '
        'requisite."'
    ),
    "Whispering Winds": (
        'Design line is "(Unique spell)", not a variant of "(Base effect)". '
        'Prose: "fits poorly into the normal framework of Hermetic magic."'
    ),
    "Watching Ward": (
        'Duration is event-triggered ("until the conditions you specify '
        'come to pass") -- not a missing catalog value, a missing concept. '
        'Confirmed General-kind (no printed level) independently by another '
        'spell\'s own cross-reference: Suppressing the Wizard\'s Handiwork '
        'calls it "a Watching Ward [ReVi Gen]" in passing.'
    ),
    "Mists of Change": (
        'Prints two Durations in one stat line ("D: Sun & Year") plus its '
        'own "slightly nonstandard effect" clause -- the R/D/T model has '
        "exactly one Duration slot."
    ),
}
```

- [ ] **Step 4: Implement `emit.build_exception_spell`**

In `scripts/spell_import/emit.py`, add after `_description` (the last
function in the file):

```python


def build_exception_spell(block, rationale: str) -> dict:
    """Build an `ExceptionSpell.fromMap`-shaped entry for a spell the
    rulebook itself says guideline arithmetic doesn't apply to.

    No design-line tokenization is attempted -- there is nothing in
    exceptions.EXCEPTION_SPELLS this function could tokenize correctly, by
    construction (that's what routes a spell here instead of build_spell/
    build_template). Reuses SpellBlock's already-parsed prose/stat-line
    fields untouched. See
    docs/superpowers/specs/2026-08-15-exception-spells-design.md.
    """
    slug = catalog_module.slug_id(block.technique, block.form, block.name)
    exception = {
        "id": "exc-" + slug.removeprefix("lib-"),
        "name": block.name,
        "technique": block.technique,
        "form": block.form,
        "range": block.stat.range_name,
        "duration": block.stat.duration_name,
        "target": block.stat.target_name,
        "isRitual": block.stat.is_ritual,
        "source": "published",
        "summary": _template_summary(block),
        "rationale": rationale,
        "citations": [{"bookId": CORE_BOOK_ID}],
    }
    if block.printed_level is not None:
        exception["printedLevel"] = block.printed_level
    description = _description(block)
    if description:
        exception["description"] = description
    return exception
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_emit.ExceptionSpellEmissionTest -v`
Expected: `Ran 10 tests ... OK`

- [ ] **Step 6: Commit**

```bash
git add scripts/spell_import/exceptions.py scripts/spell_import/emit.py scripts/spell_import/tests/test_emit.py
git commit -m "feat: add EXCEPTION_SPELLS table and emit.build_exception_spell

Pure data/function layer, not yet wired into extract_spells.py's import
loop. EXCEPTION_SPELLS is a closed, exact-name table (the same discipline
as HAND_DERIVED/KNOWN_UNRESOLVABLE) naming the six spells the rulebook
itself says guideline arithmetic doesn't apply to -- see
docs/superpowers/specs/2026-08-15-exception-spells-design.md.
build_exception_spell reuses SpellBlock's already-parsed prose/stat-line
fields verbatim, with no design-line tokenization attempted.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Wire `EXCEPTION_SPELLS` into the import loop

Routes the six real spells to `spell_exceptions.json`, removes their now-dead
entries from other closed tables, and updates every test that currently
asserts they stay blocked.

**Files:**
- Modify: `scripts/spell_import/extract_spells.py`
- Test: `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `exceptions.EXCEPTION_SPELLS`, `emit.build_exception_spell` (Task 1).
- Produces: `Report.exceptions: list[dict]`, `EXCEPTIONS_PATH` constant,
  `assets/data/spell_exceptions.json`.

- [ ] **Step 1: Write the failing tests**

Add to `scripts/spell_import/tests/test_extract.py`. First, add the new path
constant near the existing `LIBRARY` constant at the top of the file:

```python
LIBRARY = REPO_ROOT / "assets" / "data" / "spell_library.json"
EXCEPTIONS = REPO_ROOT / "assets" / "data" / "spell_exceptions.json"
```

Add the import needed by the new test classes, alongside the existing
imports at the top of the file:

```python
from scripts.spell_import import extract_spells
from scripts.spell_import import exceptions as exceptions_module
from scripts.spell_import import ledger as ledger_module
from scripts.spell_import.sources import REPO_ROOT
```

Add three new test classes, placed after `KnownUnresolvableStalenessTest`:

```python
class ExceptionSpellsTest(unittest.TestCase):
    """The six spells the rulebook itself says guideline arithmetic doesn't
    apply to -- see docs/superpowers/specs/2026-08-15-exception-spells-design.md.
    """

    @classmethod
    def setUpClass(cls):
        cls.report = extract_spells.run(write=False)

    def test_all_six_spells_import_as_exceptions_not_blocked(self):
        names = {e["name"] for e in self.report.exceptions}
        blocked_names = {name for name, _ in self.report.blocked}
        for name in exceptions_module.EXCEPTION_SPELLS:
            self.assertIn(name, names, msg=name)
            self.assertNotIn(name, blocked_names, msg=name)

    def test_the_four_general_kind_exceptions_have_no_printed_level(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        for name in ("Wizard's Communion", "Wizard's Vigil",
                     "Aegis of the Hearth", "Watching Ward"):
            self.assertNotIn("printedLevel", by_name[name], msg=name)

    def test_the_two_fixed_level_exceptions_carry_their_printed_level(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        self.assertEqual(by_name["Whispering Winds"]["printedLevel"], 15)
        self.assertEqual(by_name["Mists of Change"]["printedLevel"], 60)

    def test_every_exception_carries_a_rationale(self):
        for exception in self.report.exceptions:
            self.assertTrue(exception["rationale"], msg=exception["name"])

    def test_ids_use_the_exc_prefix(self):
        by_name = {e["name"]: e for e in self.report.exceptions}
        self.assertEqual(by_name["Whispering Winds"]["id"], "exc-inau-whispering-winds")
        self.assertEqual(by_name["Wizard's Communion"]["id"], "exc-muvi-wizards-communion")


class ExceptionSpellsStalenessTest(unittest.TestCase):
    """Guards EXCEPTION_SPELLS against a name that stops existing in the
    corpus. Mirrors KnownUnresolvableStalenessTest's shape.
    """

    def test_every_exception_name_is_still_a_real_parsed_spell(self):
        from scripts.spell_import import blocks, sources

        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        parsed, _ = blocks.parse_de(lines)
        parsed_names = {b.name for b in parsed}
        stale = [name for name in exceptions_module.EXCEPTION_SPELLS
                 if name not in parsed_names]
        self.assertEqual(stale, [], msg=f"no longer a parsed spell at all: {stale}")


class ExceptionSpellsDisjointnessTest(unittest.TestCase):
    """Each blocked/excepted spell has exactly one home. A name in
    EXCEPTION_SPELLS that also appears in another closed table would be
    ambiguous about which mechanism actually handles it.
    """

    def test_no_exception_spell_appears_in_another_name_keyed_table(self):
        exception_names = set(exceptions_module.EXCEPTION_SPELLS)
        other_tables = {
            "HAND_DERIVED": set(extract_spells.HAND_DERIVED),
            "DESIGN_LINE_TYPOS": set(extract_spells.DESIGN_LINE_TYPOS),
            "HAND_DERIVED_ADJUSTMENT": set(extract_spells.HAND_DERIVED_ADJUSTMENT),
        }
        for table_name, names in other_tables.items():
            overlap = exception_names & names
            self.assertEqual(overlap, set(), msg=f"also in {table_name}: {overlap}")

    def test_no_exception_spell_appears_in_another_slug_keyed_table(self):
        # DESIGN_LINE_INCOMPLETE, KNOWN_UNRESOLVABLE and
        # LEVEL_NEEDS_RULES_DECISION are keyed by spell_id (technique+form+
        # name slug), not bare name -- compare against the slug form instead.
        from scripts.spell_import import blocks, catalog as catalog_module, sources

        lines = sources.read_lines(sources.resolve_book(sources.DE_TITLE))
        parsed, _ = blocks.parse_de(lines)
        by_name = {b.name: b for b in parsed}
        exception_ids = {
            catalog_module.slug_id(by_name[name].technique, by_name[name].form, name)
            for name in exceptions_module.EXCEPTION_SPELLS if name in by_name
        }
        for table_name, ids in {
            "DESIGN_LINE_INCOMPLETE": set(extract_spells.DESIGN_LINE_INCOMPLETE),
            "KNOWN_UNRESOLVABLE": set(extract_spells.KNOWN_UNRESOLVABLE),
            "LEVEL_NEEDS_RULES_DECISION": set(extract_spells.LEVEL_NEEDS_RULES_DECISION),
        }.items():
            overlap = exception_ids & ids
            self.assertEqual(overlap, set(), msg=f"also in {table_name}: {overlap}")
```

Add one test to `RegenerationTest` (after `test_two_runs_are_byte_identical`):

```python
    def test_committed_exceptions_match_a_fresh_run(self):
        report = extract_spells.run(write=False)
        committed = json.loads(EXCEPTIONS.read_text(encoding="utf-8"))
        self.assertEqual(
            extract_spells.serialize(report.exceptions),
            extract_spells.serialize(committed),
        )
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_extract.ExceptionSpellsTest -v`
Expected: FAIL with `AttributeError: 'Report' object has no attribute 'exceptions'`.

- [ ] **Step 3: Add `EXCEPTIONS_PATH`, the `exceptions` import, and the loop interception**

In `scripts/spell_import/extract_spells.py`, add the import alongside the
existing ones (top of file):

```python
from . import blocks, catalog as catalog_module, designline, ledger as ledger_module
from . import emit, exceptions as exceptions_module, provenance, report as report_module, sources
```

Add the path constant next to `TEMPLATES_PATH`:

```python
LIBRARY_PATH = catalog_module.DATA_DIR / "spell_library.json"
TEMPLATES_PATH = catalog_module.DATA_DIR / "spell_templates.json"
EXCEPTIONS_PATH = catalog_module.DATA_DIR / "spell_exceptions.json"
```

In `run()`, add the local list next to `blocked`/`unresolved`:

```python
    spells: list[dict] = []
    templates: list[dict] = []
    exception_spells: list[dict] = []
    blocked: list[tuple[str, str]] = []
    unresolved: list[str] = []
```

Insert the interception as the very first statement inside the loop body —
before `design_text = HAND_DERIVED.get(block.name) or block.design_line` —
so none of these six spells ever reaches design-line tokenization:

```python
    for block in parsed:
        if block.name in exceptions_module.EXCEPTION_SPELLS:
            exception_spells.append(emit.build_exception_spell(
                block, exceptions_module.EXCEPTION_SPELLS[block.name]
            ))
            continue

        # HAND_DERIVED is checked before block.design_line, not as a
```

- [ ] **Step 4: Remove the now-dead `Wizard's Communion` entry from `DESIGN_LINE_INCOMPLETE`**

That entry is unreachable now — the block never gets there, since the
interception above `continue`s first. Change:

```python
DESIGN_LINE_INCOMPLETE = {
    "lib-reim-restore-moved-image":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    "lib-invi-invisible-eye-revealed":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    "lib-muvi-wizards-communion":
        "prose disclaims guideline arithmetic: a remnant of Mercurian rituals",
}
```

to:

```python
DESIGN_LINE_INCOMPLETE = {
    "lib-reim-restore-moved-image":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    "lib-invi-invisible-eye-revealed":
        "prints (Base effect) but the stat line costs 2 magnitudes",
    # Wizard's Communion used to be here. It now imports as an exception
    # spell (scripts/spell_import/exceptions.py) -- see
    # docs/superpowers/specs/2026-08-15-exception-spells-design.md.
}
```

- [ ] **Step 5: Trim the stale comment block above `HAND_DERIVED`**

The large comment above `HAND_DERIVED` (currently starting `# Three further
spells also lack a design line and are General-level...`) narrates
*Whispering Winds*, *Aegis of the Hearth* and (by cross-reference) *Wizard's
Vigil* at length as permanently-blocked spells. They are no longer blocked —
correct the comment so it does not contradict what the code now does.
Replace this paragraph:

```python
# Three further spells also lack a design line and are General-level, so
# belong to todo item 25, not here (a General guideline has no numeric level
# for assertion 1 to check a derivation against, which is why they are not
# folded into this dict): Aegis of the Hearth, Wizard's Vigil, Sight of the
# True Form. A fourth, Ward against Faeries of the Mountain, used to be in
# that list too -- see its own entry below for why it moved out.
#
# Only one of the three actually resolves this way. All three spells' own
# prose explicitly disclaims normal Hermetic guideline arithmetic
# ("does not conform to the normal InAq guidelines" / "old Mercurian ritual",
# "fits poorly into the normal framework of Hermetic magic", "Mercurian
# Ritual"), so each was checked, not assumed, against the real InAq/InAu/ReTe
# guideline tables:
```

with:

```python
# One further no-design-line spell, Sight of the True Form, is General-level
# and belongs to todo item 25, not here (a General guideline has no numeric
# level for assertion 1 to check a derivation against). Aegis of the Hearth
# and Wizard's Vigil used to be listed alongside it here too -- both now
# import as exception spells instead (scripts/spell_import/exceptions.py),
# since their own prose disclaims guideline arithmetic entirely rather than
# merely lacking a printed derivation. See
# docs/superpowers/specs/2026-08-15-exception-spells-design.md.
```

Then replace the *Whispering Winds* paragraph:

```python
# - Whispering Winds (R: Sight, D: Conc, T: Ind, level 15) has no working
#   derivation. InAu's only base levels are 1, 2, 4, 15 (checked against
#   the printed Intellego Auram Guidelines table); with Sight(3) + Conc(1) +
#   Ind(0) fixed by the stat line, base 2 computes to 10 and base 4 to 20 --
#   15 sits exactly one magnitude short/over either way, with no legitimate
#   token to bridge it: the stat line carries no Req: art, the prose
#   names none, and size-auram's scope explicitly excludes Intellego. The
#   only numeric fits (base 2 + a fabricated +1 requisite, or base 1 + a
#   fabricated +2) require inventing a requisite the text does not support --
#   exactly the "picking a candidate because the math works, not because the
#   text forces it" mistake this file's KNOWN_UNRESOLVABLE comment already
#   warns against. Left blocked; its own prose ("fits poorly into the normal
#   framework of Hermetic magic") is the rulebook's own explanation for why.
#
```

with:

```python
# Whispering Winds (R: Sight, D: Conc, T: Ind, level 15) used to be
# investigated here as a hand-derivation candidate and left blocked -- see
# git history for that reasoning. It now imports as an exception spell
# instead: its design line is printed as the literal marker "(Unique
# spell)", and its own prose says "fits poorly into the normal framework of
# Hermetic magic". See scripts/spell_import/exceptions.py and
# docs/superpowers/specs/2026-08-15-exception-spells-design.md.
#
```

And replace the *Aegis of the Hearth* paragraph:

```python
# - Aegis of the Hearth (R: Touch, D: Year, T: Boundary, level 30) prints no
#   design line at all. Touch(1) + Year(4) + Boundary(4) is nine magnitudes,
#   so a level-30 spell needs base -15 -- there is no General base effect
#   that low, and none is meant to exist here: the rulebook itself calls
#   Aegis of the Hearth a Major Breakthrough that is "more powerful than it
#   ought to be", i.e. explicitly outside the guidelines. Permanently
#   blocked, not pending -- there is no future ledger entry or catalog fix
#   that resolves this one.
#
```

with:

```python
# Aegis of the Hearth used to be investigated here and left permanently
# blocked -- see git history. It now imports as an exception spell instead:
# no design-line marker of any kind is printed, and the rulebook's own text
# explains why (a Major Breakthrough, "more powerful than it ought to be").
# See scripts/spell_import/exceptions.py.
#
```

Finally, in the *Ward against Faeries of the Mountain* paragraph, correct its
closing cross-reference:

```python
# realm (Faerie, same as the spell it points to). Two siblings that use the
# identical "As Ward Against Faeries of the Waters..." phrasing --
# Ward against Faeries of the Air, Ward against Faeries of the Wood -- both
# print "(Base effect)" and already import via REALM_BY_SPELL_ID; the text
# here supplies exactly the marker those two print literally, not new
# information. Checked 2026-08-15; the other three no-design-line General
# spells above (Aegis of the Hearth, Wizard's Vigil, Sight of the True
# Form) have no comparable sibling reference and stay blocked under item 25.
```

with:

```python
# realm (Faerie, same as the spell it points to). Two siblings that use the
# identical "As Ward Against Faeries of the Waters..." phrasing --
# Ward against Faeries of the Air, Ward against Faeries of the Wood -- both
# print "(Base effect)" and already import via REALM_BY_SPELL_ID; the text
# here supplies exactly the marker those two print literally, not new
# information. Checked 2026-08-15. Of the other no-design-line General
# spells, Sight of the True Form has no comparable sibling reference and
# stays blocked under item 25; Aegis of the Hearth and Wizard's Vigil import
# as exception spells instead (scripts/spell_import/exceptions.py).
```

- [ ] **Step 6: Add the `exceptions` field to `Report`, the write logic, and `main()`'s output**

Change the `Report` dataclass:

```python
@dataclasses.dataclass
class Report:
    spells: list[dict]
    templates: list[dict]
    exceptions: list[dict]
    blocked: list[tuple[str, str]]
    unresolved: list[str]
    problems: list[str]
    identity: provenance.SourceIdentity
    design_lines: dict[str, str]
```

In `run()`'s write block, add exceptions serialization right after the
existing templates block (which ends `if fresh_templates != committed_templates:
TEMPLATES_PATH.write_text(fresh_templates, encoding="utf-8")`):

```python
        fresh_exceptions = serialize(exception_spells)
        if EXCEPTIONS_PATH.is_file():
            committed_exceptions = EXCEPTIONS_PATH.read_text(encoding="utf-8")
        else:
            committed_exceptions = ""
        if fresh_exceptions != committed_exceptions:
            EXCEPTIONS_PATH.write_text(fresh_exceptions, encoding="utf-8")
```

Update the `Report(...)` construction at the end of `run()`:

```python
    return Report(
        spells=spells, templates=templates, exceptions=exception_spells,
        blocked=blocked, unresolved=unresolved,
        problems=problems, identity=identity, design_lines=design_lines,
    )
```

In `main()`, add a printed count line after `templates`:

```python
    print(f"imported : {len(report.spells)}")
    print(f"templates: {len(report.templates)}")
    print(f"exceptions: {len(report.exceptions)}")
    print(f"blocked  : {len(report.blocked)}")
    print(f"unresolved: {len(report.unresolved)}")
```

And add a third "wrote" line at the end, alongside the existing two:

```python
    if args.write:
        print(f"wrote {LIBRARY_PATH}")
        print(f"wrote {TEMPLATES_PATH}")
        print(f"wrote {EXCEPTIONS_PATH}")
    return 0
```

- [ ] **Step 7: Run the new tests — expect the shape tests to pass, staleness/disjointness to pass, but check `Report` callers**

Run: `python -m unittest scripts.spell_import.tests.test_extract -v 2>&1 | tail -60`

Expected at this point: `ExceptionSpellsTest`, `ExceptionSpellsStalenessTest`,
and `ExceptionSpellsDisjointnessTest` all PASS. `RegenerationTest.
test_committed_exceptions_match_a_fresh_run` FAILS (no
`spell_exceptions.json` committed yet — fixed in Step 9). Some other tests
will FAIL because they still assert the old blocked/comment shape — fixed in
Step 8.

- [ ] **Step 8: Update the now-stale tests**

In `HandDerivedTest`, remove
`test_the_one_remaining_non_derivable_spell_stays_correctly_blocked` (its
assertion that `"Whispering Winds"` stays blocked is now false — Whispering
Winds imports as an exception, covered by `ExceptionSpellsTest` instead) and
update the class docstring. Replace:

```python
class HandDerivedTest(unittest.TestCase):
    """Of the 3 spells with no printed design line, only 2 have a legitimate
    hand-derivation. The other 1 was investigated, not skipped: its own
    prose explicitly disclaims normal Hermetic guideline arithmetic
    ("does not conform to the normal InAq guidelines", "fits poorly into
    the normal framework of Hermetic magic", Mercurian Ritual), and no
    combination of real base level + real magnitude token reproduces their
    printed level without inventing a requisite or an unimplemented
    modifier the text doesn't support. See HAND_DERIVED's module docstring
    in extract_spells.py for the full per-spell reasoning.
    """

    def test_the_derivable_spell_is_imported(self):
        report = extract_spells.run(write=False)
        names = {s["name"] for s in report.spells}
        self.assertIn("Enchantment of the Scrying Pool", names)

    def test_the_one_remaining_non_derivable_spell_stays_correctly_blocked(self):
        report = extract_spells.run(write=False)
        blocked_names = {name for name, _ in report.blocked}
        self.assertIn("Whispering Winds", blocked_names)

    def test_hermes_portal_is_now_derivable(self):
```

with:

```python
class HandDerivedTest(unittest.TestCase):
    """Of the 3 spells with no printed design line, 2 have a legitimate
    hand-derivation. The third, Whispering Winds, was investigated and found
    genuinely non-derivable -- see git history for that reasoning -- and now
    imports as an exception spell instead (ExceptionSpellsTest in this file),
    not as a blocked spell. See HAND_DERIVED's module docstring in
    extract_spells.py for the two derivable spells' per-spell reasoning.
    """

    def test_the_derivable_spell_is_imported(self):
        report = extract_spells.run(write=False)
        names = {s["name"] for s in report.spells}
        self.assertIn("Enchantment of the Scrying Pool", names)

    def test_hermes_portal_is_now_derivable(self):
```

In `GENERAL_BLOCKED`, remove the four entries for spells that no longer
block. Replace:

```python
GENERAL_BLOCKED = {
    "Aegis of the Hearth": "no design line; a Major Breakthrough outside the guidelines",
    "Wizard's Vigil": "no design line",
    "Sight of the True Form": "no design line",
    # Ward against Faeries of the Mountain: WAS here ("no design line; a prose
    # cross-reference to another spell") until 2026-08-15, when that same
    # cross-reference ("As Ward Against Faeries of the Waters (ReAq Gen)...")
    # turned out to be a complete specification, not just a description --
    # see extract_spells.HAND_DERIVED's comment. It now imports as a
    # template. This is exactly the staleness this test class exists to
    # catch, and it caught it.
    "Dispel the Phantom Image": "no Perdo Imaginem General row in the rulebook",
    "Lay to Rest the Haunting Spirit": "no Perdo Mentem General row in the rulebook",
    "Watching Ward": "design line token 'Duration is non-standard' — todo item 26",
    "Restore the Moved Image": "design line does not account for the stat line",
    "The Invisible Eye Revealed": "design line does not account for the stat line",
    "Wizard's Communion": "prose disclaims guideline arithmetic",
}
```

with:

```python
GENERAL_BLOCKED = {
    "Sight of the True Form": "no design line",
    # Ward against Faeries of the Mountain: WAS here ("no design line; a prose
    # cross-reference to another spell") until 2026-08-15, when that same
    # cross-reference ("As Ward Against Faeries of the Waters (ReAq Gen)...")
    # turned out to be a complete specification, not just a description --
    # see extract_spells.HAND_DERIVED's comment. It now imports as a
    # template. This is exactly the staleness this test class exists to
    # catch, and it caught it.
    #
    # Aegis of the Hearth, Wizard's Vigil, Watching Ward and Wizard's
    # Communion: WERE here until 2026-08-16, when they moved to
    # ExceptionSpellsTest instead -- each now imports as an exception spell
    # (scripts/spell_import/exceptions.py), not blocked at all. This is the
    # same staleness this test class exists to catch.
    "Dispel the Phantom Image": "no Perdo Imaginem General row in the rulebook",
    "Lay to Rest the Haunting Spirit": "no Perdo Mentem General row in the rulebook",
    "Restore the Moved Image": "design line does not account for the stat line",
    "The Invisible Eye Revealed": "design line does not account for the stat line",
}
```

In `HandDerivedAdjustmentTest`, replace the now-false
`test_mists_of_change_stays_blocked_on_its_two_durations`:

```python
    def test_mists_of_change_stays_blocked_on_its_two_durations(self):
        # D: Sun & Year -- two durations, which no adjustment can express.
        # (It blocks one token earlier, on the numberless "slightly nonstandard
        # effect"; both blockers are real and neither is derivable, so no
        # hand-derived magnitude is offered for it.)
        self.assertIn("Mists of Change", {name for name, _ in self.report.blocked})
```

with:

```python
    def test_mists_of_change_is_an_exception_not_blocked(self):
        # D: Sun & Year -- two durations, which no adjustment or ledger fix
        # can express; it now imports as an exception spell instead of
        # staying blocked. See ExceptionSpellsTest for the full shape.
        exception_names = {e["name"] for e in extract_spells.run(write=False).exceptions}
        self.assertIn("Mists of Change", exception_names)
        self.assertNotIn("Mists of Change", {name for name, _ in self.report.blocked})
```

- [ ] **Step 9: Regenerate the assets and run the full Python suite**

Run: `python -m scripts.spell_import.extract_spells --write`
Expected output includes `imported : 320`, `exceptions: 6`, `blocked  : 10`
(16 − 6). `git status --short` shows a new file,
`assets/data/spell_exceptions.json`, and no changes to
`assets/data/spell_library.json` or `assets/data/spell_templates.json` (none
of these six spells were ever in either file — they moved from "blocked" to
"exceptions", not into the library or templates).

Run: `python -m unittest discover -s scripts/spell_import -t .`
Expected: all green.

- [ ] **Step 10: Verify the six exceptions by hand**

```bash
python -c "
import json
data = json.load(open('assets/data/spell_exceptions.json', encoding='utf-8'))
for e in sorted(data, key=lambda e: e['name']):
    print(e['name'], '|', e.get('printedLevel'), '|', e['range'], e['duration'], e['target'], '| ritual=', e['isRitual'])
"
```
Expected:
```
Aegis of the Hearth | None | Touch Year Bound | ritual= True
Mists of Change | 60 | Voice Sun & Year Bound | ritual= True
Watching Ward | None | Touch Spec Ind | ritual= True
Whispering Winds | 15 | Sight Conc Ind | ritual= False
Wizard's Communion | None | Voice Mom Group | ritual= False
Wizard's Vigil | None | Voice Sun Group | ritual= False
```

- [ ] **Step 11: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_extract.py assets/data/spell_exceptions.json
git commit -m "feat: route the six exception spells to spell_exceptions.json

extract_spells.py's import loop now checks exceptions.EXCEPTION_SPELLS as
the very first thing inside the loop, before any design-line tokenization
-- Wizard's Communion, Wizard's Vigil, Aegis of the Hearth, Whispering
Winds, Watching Ward and Mists of Change move from blocked (16 -> 10) to a
new exceptions collection (0 -> 6), via emit.build_exception_spell.

Removed their now-dead entries from DESIGN_LINE_INCOMPLETE and the giant
comment above HAND_DERIVED, both of which narrated these spells as
permanently blocked -- they no longer are. Updated every test that
asserted the old blocked shape: HandDerivedTest's Whispering-Winds
assertion, GENERAL_BLOCKED's four now-stale entries, and
HandDerivedAdjustmentTest's Mists-of-Change assertion.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: `ExceptionSpell` Dart model

**Files:**
- Create: `lib/models/exception_spell.dart`
- Test: `test/models/exception_spell_test.dart`

**Interfaces:**
- Consumes: `Provenance` (existing, `lib/models/provenance.dart`),
  `validateSpellProse` (existing, `lib/models/spell.dart`), `requireField`
  (existing, `lib/utils/map_serialization.dart`).
- Produces: `ExceptionSpell` class, consumed by Task 4's `ResolvedException`.

- [ ] **Step 1: Write the failing test**

Create `test/models/exception_spell_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';

void main() {
  ExceptionSpell buildException({
    String? summary = 'Test summary.',
    String? description,
    int? printedLevel,
    bool isRitual = false,
    PublicationSource source = PublicationSource.published,
  }) {
    return ExceptionSpell(
      id: 'exc-1',
      name: 'Test Exception',
      technique: 'Muto',
      form: 'Vim',
      range: 'Voice',
      duration: 'Sun & Year',
      target: 'Bound',
      isRitual: isRitual,
      printedLevel: printedLevel,
      summary: summary,
      description: description,
      rationale: 'Test rationale.',
      provenance: Provenance(
        source: source,
        citations: source == PublicationSource.published
            ? const [Citation(bookId: 'arm5-core')]
            : const [],
      ),
    );
  }

  test('a published exception needs a summary or description', () {
    expect(
      () => buildException(summary: null, description: null),
      throwsA(isA<FormatException>()),
    );
  });

  test('a published exception with only a description is valid', () {
    final exception = buildException(summary: null, description: 'Verbatim text.');
    expect(exception.description, 'Verbatim text.');
  });

  test('printedLevel is null for a General-kind exception', () {
    final exception = buildException(printedLevel: null);
    expect(exception.printedLevel, isNull);
  });

  test('printedLevel carries through for a fixed-level exception', () {
    final exception = buildException(printedLevel: 15);
    expect(exception.printedLevel, 15);
  });

  test('range/duration/target are the free-text strings as given', () {
    final exception = buildException();
    expect(exception.range, 'Voice');
    expect(exception.duration, 'Sun & Year');
    expect(exception.target, 'Bound');
  });

  test('toMap/fromMap round-trips every field', () {
    final original = buildException(printedLevel: 60, isRitual: true);
    final restored = ExceptionSpell.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.technique, original.technique);
    expect(restored.form, original.form);
    expect(restored.range, original.range);
    expect(restored.duration, original.duration);
    expect(restored.target, original.target);
    expect(restored.isRitual, original.isRitual);
    expect(restored.printedLevel, original.printedLevel);
    expect(restored.summary, original.summary);
    expect(restored.rationale, original.rationale);
    expect(restored.provenance.source, original.provenance.source);
    expect(restored.provenance.citations, original.provenance.citations);
  });

  test('a round trip with a null printedLevel stays null', () {
    final original = buildException(printedLevel: null);
    final restored = ExceptionSpell.fromMap(original.toMap());
    expect(restored.printedLevel, isNull);
  });

  test('fromMap throws a descriptive FormatException for a missing required field', () {
    final map = buildException().toMap()..remove('rationale');
    expect(
      () => ExceptionSpell.fromMap(map),
      throwsA(isA<FormatException>().having(
          (e) => e.message, 'message', contains('rationale'))),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/exception_spell_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/models/exception_spell.dart': No such file or directory`.

- [ ] **Step 3: Implement `ExceptionSpell`**

Create `lib/models/exception_spell.dart`:

```dart
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/spell.dart' show validateSpellProse;
import 'package:eruditus/utils/map_serialization.dart';

/// A published spell the rulebook itself says guideline arithmetic doesn't
/// apply to — its own prose disclaims normal Hermetic design, or its real
/// shape (an event-triggered Duration, two Durations at once) doesn't fit
/// the Range/Duration/Target model regardless of what the prose says.
///
/// A read-only canon record, not a designable spell: [range]/[duration]/
/// [target] are plain strings taken straight from the rulebook's stat line,
/// never catalog ids, and there is no `SpellLevelCalculator` involvement —
/// [rationale] is required precisely because nothing here is computed.
/// See docs/superpowers/specs/2026-08-15-exception-spells-design.md for the
/// full design rationale, including why this is not a subclass of [Spell]
/// or [SpellTemplate].
class ExceptionSpell {
  final String id;
  final String name;
  final String technique;
  final String form;
  final String range;
  final String duration;
  final String target;
  final bool isRitual;

  /// The spell's printed level, or null for the four General-kind entries
  /// (Wizard's Communion, Wizard's Vigil, Aegis of the Hearth, Watching
  /// Ward) which print no level at all.
  final int? printedLevel;

  final String? summary;
  final String? description;

  /// Why this spell doesn't compute — required, unlike [Spell]'s optional
  /// citations, because every entry here must say why it exists outside the
  /// normal guideline system.
  final String rationale;

  final Provenance provenance;
  final List<String> tags;

  ExceptionSpell({
    required this.id,
    required this.name,
    required this.technique,
    required this.form,
    required this.range,
    required this.duration,
    required this.target,
    this.isRitual = false,
    this.printedLevel,
    this.summary,
    this.description,
    required this.rationale,
    required this.provenance,
    this.tags = const [],
  }) {
    final problems = validateSpellProse(
      source: provenance.source,
      summary: summary,
      description: description,
    );
    if (problems.isNotEmpty) {
      throw FormatException('ExceptionSpell: ${problems.join('; ')}');
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'technique': technique,
        'form': form,
        'range': range,
        'duration': duration,
        'target': target,
        'isRitual': isRitual,
        'printedLevel': printedLevel,
        'summary': summary,
        'description': description,
        'rationale': rationale,
        ...provenance.toMap(),
        'tags': tags,
      };

  factory ExceptionSpell.fromMap(Map<String, dynamic> map) => ExceptionSpell(
        id: requireField<String>(map, 'id', 'ExceptionSpell'),
        name: requireField<String>(map, 'name', 'ExceptionSpell'),
        technique: requireField<String>(map, 'technique', 'ExceptionSpell'),
        form: requireField<String>(map, 'form', 'ExceptionSpell'),
        range: requireField<String>(map, 'range', 'ExceptionSpell'),
        duration: requireField<String>(map, 'duration', 'ExceptionSpell'),
        target: requireField<String>(map, 'target', 'ExceptionSpell'),
        isRitual: (map['isRitual'] as bool?) ?? false,
        printedLevel: map['printedLevel'] as int?,
        summary: map['summary'] as String?,
        description: map['description'] as String?,
        rationale: requireField<String>(map, 'rationale', 'ExceptionSpell'),
        provenance: Provenance.fromMap(map),
        tags: (map['tags'] as List?)?.map((t) => t as String).toList() ?? const [],
      );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/models/exception_spell_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/exception_spell.dart test/models/exception_spell_test.dart
git commit -m "feat: add the ExceptionSpell model

Everything a citation-worthy library entry needs and nothing that implies
computability: free-text range/duration/target instead of catalog ids, a
required rationale instead of computed arithmetic. Reuses
validateSpellProse unchanged for the published-needs-prose invariant, the
same way Spell and SpellTemplate already do.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: `ResolvedException` — the `LibraryEntry` wrapper

**Files:**
- Create: `lib/models/resolved_exception.dart`
- Test: `test/models/resolved_exception_test.dart`

**Interfaces:**
- Consumes: `ExceptionSpell` (Task 3), `LibraryEntry` (existing,
  `lib/models/library_entry.dart`).
- Produces: `ResolvedException`, consumed by Task 5's repository and Task 8's
  screen.

- [ ] **Step 1: Write the failing test**

Create `test/models/resolved_exception_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/provenance.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/resolved_exception.dart';

void main() {
  final record = ExceptionSpell(
    id: 'exc-1',
    name: 'Test Exception',
    technique: 'Muto',
    form: 'Vim',
    range: 'Voice',
    duration: 'Sun & Year',
    target: 'Bound',
    isRitual: true,
    printedLevel: 60,
    summary: 'Test summary.',
    rationale: 'Test rationale.',
    provenance: Provenance(
      source: PublicationSource.published,
      citations: const [Citation(bookId: 'arm5-core')],
    ),
  );

  test('is always resolved, with no unresolved references', () {
    final resolved = ResolvedException(record: record);
    expect(resolved.isResolved, isTrue);
    expect(resolved.unresolvedReferences, isEmpty);
  });

  test('implements LibraryEntry', () {
    final ResolvedException resolved = ResolvedException(record: record);
    expect(resolved, isA<LibraryEntry>());
  });

  test('delegates name/technique/form/summary/description/source to the record', () {
    final resolved = ResolvedException(record: record);
    expect(resolved.name, 'Test Exception');
    expect(resolved.technique, 'Muto');
    expect(resolved.form, 'Vim');
    expect(resolved.summary, 'Test summary.');
    expect(resolved.description, isNull);
    expect(resolved.source, PublicationSource.published);
  });

  test('exposes rationale, isRitual and printedLevel', () {
    final resolved = ResolvedException(record: record);
    expect(resolved.rationale, 'Test rationale.');
    expect(resolved.isRitual, isTrue);
    expect(resolved.printedLevel, 60);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/resolved_exception_test.dart`
Expected: FAIL — `resolved_exception.dart` does not exist.

- [ ] **Step 3: Implement `ResolvedException`**

Create `lib/models/resolved_exception.dart`:

```dart
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/library_entry.dart';
import 'package:eruditus/models/publication_source.dart';

/// The [LibraryEntry] view of an [ExceptionSpell].
///
/// Trivial today — [isResolved] is always true, because nothing in
/// [ExceptionSpell] references the catalog, so there is nothing to fail to
/// resolve. Kept as a distinct wrapper rather than having [ExceptionSpell]
/// implement [LibraryEntry] directly, mirroring how [Spell] and
/// [SpellTemplate] themselves never implement it either — only their
/// `Resolved*` views do — and leaving a seam if [technique]/[form] ever
/// become real catalog references later.
class ResolvedException implements LibraryEntry {
  final ExceptionSpell record;

  const ResolvedException({required this.record});

  @override
  bool get isResolved => true;

  @override
  List<String> get unresolvedReferences => const [];

  @override
  String? get name => record.name;

  @override
  String? get technique => record.technique;

  @override
  String? get form => record.form;

  @override
  String? get summary => record.summary;

  @override
  String? get description => record.description;

  @override
  PublicationSource get source => record.provenance.source;

  String get id => record.id;
  String get rationale => record.rationale;
  bool get isRitual => record.isRitual;
  int? get printedLevel => record.printedLevel;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/models/resolved_exception_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/resolved_exception.dart test/models/resolved_exception_test.dart
git commit -m "feat: add ResolvedException, the LibraryEntry view of ExceptionSpell

Mirrors ResolvedSpell/ResolvedTemplate's raw-record/resolved-view split.
isResolved is always true -- there is nothing in ExceptionSpell that
references the catalog, so nothing can fail to resolve.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Asset loading and repository

**Files:**
- Modify: `lib/data/datasources/asset_data_loader.dart`
- Modify: `lib/data/repositories/library_repository.dart`
- Test: `test/data/datasources/asset_data_loader_test.dart`
- Test: `test/data/repositories/library_repository_test.dart`

**Interfaces:**
- Consumes: `ExceptionSpell`, `ResolvedException` (Tasks 3–4).
- Produces: `AssetDataLoader.loadSpellExceptions()`,
  `LibraryRepository.getExceptions()`.

- [ ] **Step 1: Write the failing tests**

Add to `test/data/datasources/asset_data_loader_test.dart`, after the
existing `'loads every template in the asset'`/`'every template references
a General base effect'` tests:

```dart
  test('loads every exception in the asset', () async {
    final raw = jsonDecode(
        await File('assets/data/spell_exceptions.json').readAsString()) as List;

    final exceptions = await AssetDataLoader().loadSpellExceptions();

    expect(exceptions, hasLength(raw.length));
    expect(exceptions, hasLength(6));
  });

  test('every exception carries a rationale', () async {
    for (final exception in await AssetDataLoader().loadSpellExceptions()) {
      expect(exception.rationale, isNotEmpty, reason: exception.name);
    }
  });

  test('exactly four exceptions have no printed level', () async {
    final exceptions = await AssetDataLoader().loadSpellExceptions();
    final generalKind = exceptions.where((e) => e.printedLevel == null);
    expect(generalKind.length, 4);
  });
```

Add to `test/data/repositories/library_repository_test.dart`, after
`getBuiltInSpells returns every built-in library spell` (matching that
test's "derived, not a literal" convention for the expected count):

```dart
  test('getExceptions returns every built-in exception spell', () async {
    final exceptions = await repository.getExceptions();
    final rawCount = (await AssetDataLoader().loadSpellExceptions()).length;
    expect(exceptions.length, rawCount);
    expect(exceptions.every((e) => e.isResolved), isTrue);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart test/data/repositories/library_repository_test.dart`
Expected: FAIL — `AssetDataLoader` has no `loadSpellExceptions` method,
`LibraryRepository` has no `getExceptions` method.

- [ ] **Step 3: Add `loadSpellExceptions` to `AssetDataLoader`**

In `lib/data/datasources/asset_data_loader.dart`, add the import:

```dart
import 'package:eruditus/models/exception_spell.dart';
```

Add the cache field next to `_spellTemplates`:

```dart
  Future<List<SpellTemplate>>? _spellTemplates;
  Future<List<ExceptionSpell>>? _spellExceptions;
```

Add the loader method next to `loadSpellTemplates`:

```dart
  Future<List<SpellTemplate>> loadSpellTemplates() =>
      _spellTemplates ??=
          _load('assets/data/spell_templates.json', SpellTemplate.fromMap);

  Future<List<ExceptionSpell>> loadSpellExceptions() =>
      _spellExceptions ??=
          _load('assets/data/spell_exceptions.json', ExceptionSpell.fromMap);
```

- [ ] **Step 4: Add `getExceptions` to `LibraryRepository`**

In `lib/data/repositories/library_repository.dart`, add the imports:

```dart
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/resolved_exception.dart';
```

Add the method next to `getTemplates` (no catalog resolution step needed —
`ExceptionSpell` references no catalog ids, so unlike `getTemplates` there
is no `_refreshResolver()` call here):

```dart
  Future<List<ResolvedException>> getExceptions() async {
    final exceptions = await assetLoader.loadSpellExceptions();
    return exceptions.map((record) => ResolvedException(record: record)).toList();
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart test/data/repositories/library_repository_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/data/datasources/asset_data_loader.dart lib/data/repositories/library_repository.dart test/data/datasources/asset_data_loader_test.dart test/data/repositories/library_repository_test.dart
git commit -m "feat: load exception spells through AssetDataLoader and LibraryRepository

loadSpellExceptions mirrors loadSpellTemplates exactly. getExceptions is
simpler than getTemplates: ExceptionSpell references no catalog ids, so
there is no resolver refresh step -- just decode and wrap.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: `SpellCard`'s exception chip

**Files:**
- Modify: `lib/presentation/widgets/spell_card.dart`
- Test: `test/presentation/widgets/spell_card_test.dart`

**Interfaces:**
- Produces: `SpellCard(isException: bool)`, a
  `Key('exception-chip')`/`Text('Exception')` chip.

- [ ] **Step 1: Write the failing test**

Add to `test/presentation/widgets/spell_card_test.dart`, after the existing
`'shows a Gen chip only when isGeneral is true'` test:

```dart
  testWidgets('shows an Exception chip only when isException is true', (tester) async {
    final template = buildTemplate(summary: 'Test summary.');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(entry: template, isException: true)),
    ));
    expect(find.byKey(const Key('exception-chip')), findsOneWidget);
    expect(find.text('Exception'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(entry: template)),
    ));
    expect(find.byKey(const Key('exception-chip')), findsNothing);
  });

  testWidgets('a null level renders the subtitle with no level suffix', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpellCard(entry: buildTemplate(summary: 'Test summary.'))),
    ));
    expect(find.textContaining('Creo Ignem'), findsOneWidget);
    expect(find.textContaining('Level'), findsNothing);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: the first new test FAILS (`isException` is not a named parameter
of `SpellCard`); the second passes already (pinning existing behavior).

- [ ] **Step 3: Add `isException` to `SpellCard`**

In `lib/presentation/widgets/spell_card.dart`, add the field next to
`isGeneral`:

```dart
  final bool isGeneral;

  /// True for an [ExceptionSpell] — a spell the rulebook itself says
  /// guideline arithmetic doesn't apply to. Distinct from [isGeneral]:
  /// an exception spell is never instantiable, whether or not it happens to
  /// print a level.
  final bool isException;
```

Add it to the constructor:

```dart
  const SpellCard({
    super.key,
    required this.entry,
    this.level,
    this.onTap,
    this.isRitual = false,
    this.isGeneral = false,
    this.isException = false,
    this.actions = const [],
  });
```

Add the chip in `build`, alongside the existing `isRitual`/`isGeneral` chips:

```dart
                if (isGeneral)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('general-chip'),
                      label: Text('Gen'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isException)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Chip(
                      key: Key('exception-chip'),
                      label: Text('Exception'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/presentation/widgets/spell_card_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/spell_card.dart test/presentation/widgets/spell_card_test.dart
git commit -m "feat: add SpellCard's Exception chip

Mirrors the existing ritual-chip/general-chip pattern. Distinct from
isGeneral: an exception spell is never instantiable regardless of whether
it happens to print a level.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: `SpellLibraryState`/`SpellLibraryBloc` wiring

**Files:**
- Modify: `lib/bloc/spell_library/spell_library_state.dart`
- Modify: `lib/bloc/spell_library/spell_library_bloc.dart`
- Test: `test/bloc/spell_library_bloc_test.dart`

**Interfaces:**
- Consumes: `ResolvedException` (Task 4), `LibraryRepository.getExceptions()`
  (Task 5).
- Produces: `SpellLibraryState.exceptions`, `SpellLibraryState.
  visibleExceptions`, consumed by Task 8's screen.

- [ ] **Step 1: Write the failing tests**

Add to `test/bloc/spell_library_bloc_test.dart`. First, add the imports
needed by the new fixtures and tests, alongside the existing ones:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/resolved_exception.dart';
```

Add exception fixtures next to the existing `templateRecordA`/`templateA`
fixtures (same file, same "built by hand rather than loaded from the asset
file" reasoning already documented there):

```dart
  final exceptionRecordA = ExceptionSpell(
    id: 'exc-a',
    name: 'Exception Alpha',
    technique: 'Muto',
    form: 'Vim',
    range: 'Voice',
    duration: 'Mom',
    target: 'Group',
    rationale: 'Test rationale A.',
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );
  final exceptionRecordB = ExceptionSpell(
    id: 'exc-b',
    name: 'Exception Beta',
    technique: 'Rego',
    form: 'Vim',
    range: 'Touch',
    duration: 'Year',
    target: 'Bound',
    printedLevel: 60,
    rationale: 'Test rationale B.',
    provenance: Provenance(
        source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
  );
  final exceptionA = ResolvedException(record: exceptionRecordA);
  final exceptionB = ResolvedException(record: exceptionRecordB);

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'LibraryRequested populates exceptions with every exception the repository returns',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getExceptions())
          .thenAnswer((_) async => [exceptionA, exceptionB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) => bloc.add(const LibraryRequested()),
    verify: (bloc) {
      expect(bloc.state.status, SpellLibraryStatus.loaded);
      expect(bloc.state.exceptions, [exceptionA, exceptionB]);
    },
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'visibleExceptions narrows by name under a query, case-insensitively',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getExceptions())
          .thenAnswer((_) async => [exceptionA, exceptionB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const SearchQueryChanged('alpha'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) {
      expect(bloc.state.visibleExceptions.length, 1);
      expect(bloc.state.visibleExceptions.single.id, 'exc-a');
    },
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'exceptions is empty under the "My Spells" filter',
    // An exception spell is published catalog data and can never be one of
    // the user's own spells -- same rule visibleTemplates already follows.
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getExceptions())
          .thenAnswer((_) async => [exceptionA, exceptionB]);
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) {
      bloc.add(const LibraryRequested());
      bloc.add(const FilterChanged('My Spells'));
    },
    wait: const Duration(milliseconds: 300),
    verify: (bloc) => expect(bloc.state.visibleExceptions, isEmpty),
  );

  blocTest<SpellLibraryBloc, SpellLibraryState>(
    'a repository that throws from getExceptions puts the bloc in error, like any other load failure',
    setUp: () {
      when(() => mockLibraryRepository.getAllSpells()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getTemplates()).thenAnswer((_) async => []);
      when(() => mockLibraryRepository.getExceptions()).thenThrow(Exception('boom'));
    },
    build: () => SpellLibraryBloc(
        libraryRepository: mockLibraryRepository, spellEngine: spellEngine),
    act: (bloc) => bloc.add(const LibraryRequested()),
    expect: () => [
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.loading),
      isA<SpellLibraryState>().having((s) => s.status, 'status', SpellLibraryStatus.error),
    ],
  );
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/bloc/spell_library_bloc_test.dart`
Expected: FAIL to compile — `SpellLibraryState` has no `exceptions`/
`visibleExceptions`, `MockLibraryRepository` has no `getExceptions` (mocktail
generates it dynamically via `Mock`, so this specific failure surfaces as
"getExceptions" being unstubbed once the bloc tries to call it — the
compile error is `bloc.state.exceptions`/`visibleExceptions` not existing).

- [ ] **Step 3: Add `exceptions`/`visibleExceptions` to `SpellLibraryState`**

In `lib/bloc/spell_library/spell_library_state.dart`, add the import:

```dart
import 'package:eruditus/models/resolved_exception.dart';
```

Add the field next to `templates`:

```dart
  final List<ResolvedTemplate> templates;
  // Published exception spells -- alongside allSpells/templates rather than
  // merged into either: an ExceptionSpell has no level to sort by and is
  // never instantiable, the same reason templates get their own list.
  final List<ResolvedException> exceptions;
```

Add it to the constructor:

```dart
  const SpellLibraryState({
    required this.status,
    this.allSpells = const [],
    this.templates = const [],
    this.exceptions = const [],
    this.query = '',
    this.filter = 'All',
    this.spellLevels = const {},
    this.ritualSpellIds = const {},
    this.errorMessage,
  });
```

Add the `visibleExceptions` getter next to `visibleTemplates`, following its
identical three-rule shape:

```dart
  // Same three rules as visibleSpells/visibleTemplates: an exception spell
  // is published catalog data and can never be one of the user's own
  // spells, so it is always empty under "My Spells".
  List<ResolvedException> get visibleExceptions {
    var result = exceptions;
    if (filter == 'Published') {
      result = result.where((e) => e.source == PublicationSource.published).toList();
    } else if (filter == 'My Spells') {
      result = result.where((e) => e.source == PublicationSource.userCreated).toList();
    }
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      result = result.where((e) => (e.name ?? '').toLowerCase().contains(lowerQuery)).toList();
    }
    return result;
  }
```

Add it to `copyWith`:

```dart
  SpellLibraryState copyWith({
    SpellLibraryStatus? status,
    List<ResolvedSpell>? allSpells,
    List<ResolvedTemplate>? templates,
    List<ResolvedException>? exceptions,
    String? query,
    String? filter,
    Map<String, int>? spellLevels,
    Set<String>? ritualSpellIds,
    String? errorMessage,
  }) {
    return SpellLibraryState(
      status: status ?? this.status,
      allSpells: allSpells ?? this.allSpells,
      templates: templates ?? this.templates,
      exceptions: exceptions ?? this.exceptions,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      spellLevels: spellLevels ?? this.spellLevels,
      ritualSpellIds: ritualSpellIds ?? this.ritualSpellIds,
      errorMessage: errorMessage,
    );
  }
```

Add it to `props`:

```dart
  @override
  List<Object?> get props => [
        status,
        allSpells,
        templates,
        exceptions,
        query,
        filter,
        spellLevels,
        ritualSpellIds,
        errorMessage,
      ];
```

- [ ] **Step 4: Fetch exceptions in `SpellLibraryBloc`**

In `lib/bloc/spell_library/spell_library_bloc.dart`, in `_onEvent`'s
`LibraryRequested` branch, add the fetch right after `templates` and pass it
into the emitted state:

```dart
        final spells = await libraryRepository.getAllSpells();
        final templates = await libraryRepository.getTemplates();
        final exceptions = await libraryRepository.getExceptions();
        final levels = <String, int>{};
```

```dart
        emit(state.copyWith(
          status: SpellLibraryStatus.loaded,
          allSpells: spells,
          templates: templates,
          exceptions: exceptions,
          spellLevels: levels,
          ritualSpellIds: ritualIds,
        ));
```

- [ ] **Step 5: Stub `getExceptions` on every existing `mockLibraryRepository.getTemplates()` call**

The bloc now calls `getExceptions()` on every `LibraryRequested`, so every
existing test that reaches a `loaded` state through `mockLibraryRepository`
needs a matching stub, or the unstubbed mocktail call throws and the bloc
lands in `error` instead — breaking those tests. In
`test/bloc/spell_library_bloc_test.dart`, there are two recurring literal
patterns to update.

First pattern — appears twice, identically, at the "ritual spells" and "one
uncomputable spell" tests:

```dart
      when(() => mockLibraryRepository.getTemplates()).thenAnswer((_) async => []);
```

Add this immediately after each occurrence of that exact line:

```dart
      when(() => mockLibraryRepository.getExceptions()).thenAnswer((_) async => []);
```

Second pattern — appears identically six times, in every
templates/visibleTemplates test added by the general-base-effects work:

```dart
      when(() => mockLibraryRepository.getTemplates())
          .thenAnswer((_) async => [templateA, templateB]);
```

Add this immediately after each occurrence:

```dart
      when(() => mockLibraryRepository.getExceptions()).thenAnswer((_) async => []);
```

The ninth `getTemplates` stub — `.thenThrow(Exception('boom'))`, in the
"repository that throws from getTemplates" test — needs no change: the bloc
call sequence is `getAllSpells` → `getTemplates` → `getExceptions`, so a
throw from `getTemplates` means `getExceptions` is never reached.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/bloc/spell_library_bloc_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/bloc/spell_library/spell_library_state.dart lib/bloc/spell_library/spell_library_bloc.dart test/bloc/spell_library_bloc_test.dart
git commit -m "feat: wire exception spells through SpellLibraryState/Bloc

exceptions/visibleExceptions mirror templates/visibleTemplates exactly,
including the My-Spells-is-always-empty rule (exception spells are
published catalog data). LibraryRequested now fetches getExceptions()
alongside getAllSpells()/getTemplates(), so every existing mock-repository
test that reaches a loaded state needed a matching getExceptions stub --
otherwise the unstubbed call throws and the bloc lands in error instead.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: `SpellLibraryScreen`'s Exceptions section

**Files:**
- Modify: `lib/presentation/screens/spell_library_screen.dart`
- Test: `test/presentation/screens/spell_library_screen_test.dart`

**Interfaces:**
- Consumes: `SpellLibraryState.visibleExceptions` (Task 7), `SpellCard(
  isException: true)` (Task 6).

- [ ] **Step 1: Write the failing tests**

Add to `test/presentation/screens/spell_library_screen_test.dart`, the
imports and a fixture builder alongside the existing `buildTemplate`:

```dart
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/resolved_exception.dart';
```

```dart
  ResolvedException buildException(String id, String name) {
    final record = ExceptionSpell(
      id: id,
      name: name,
      technique: 'Muto',
      form: 'Vim',
      range: 'Voice',
      duration: 'Mom',
      target: 'Group',
      description: 'A test exception.',
      rationale: 'Test rationale.',
      provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    );
    return ResolvedException(record: record);
  }
```

Add a new group, after the existing `'General templates section'` group:

```dart
  group('Exceptions section', () {
    testWidgets('renders exceptions below the spells, under a heading', (tester) async {
      final template = buildTemplate('tpl-1', 'Ward against Faeries of the Waters');
      final exception = buildException('exc-1', "Wizard's Communion");
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(
          status: SpellLibraryStatus.loaded,
          allSpells: [builtInSpell],
          templates: [template],
          exceptions: [exception],
        ),
      );

      expect(find.text('Exceptions — recorded from the rulebook directly, not derived from the guidelines'),
          findsOneWidget);
      expect(find.text("Wizard's Communion"), findsOneWidget);
      expect(find.byKey(const Key('exception-chip')), findsOneWidget);

      final spellY = tester.getTopLeft(find.text('Phantasm of the Talking Head')).dy;
      final exceptionY = tester.getTopLeft(find.text("Wizard's Communion")).dy;
      expect(spellY, lessThan(exceptionY));
    });

    testWidgets('an exception card offers no instantiation action', (tester) async {
      final exception = buildException('exc-1', "Wizard's Communion");
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(status: SpellLibraryStatus.loaded, exceptions: [exception]),
      );

      expect(find.text('Learn at level…'), findsNothing);
      expect(find.byKey(const Key('general-chip')), findsNothing);
    });

    testWidgets('a state with no exceptions renders no heading and no empty section',
        (tester) async {
      await pumpScreenWithCreationBloc(
        tester,
        SpellLibraryState(status: SpellLibraryStatus.loaded, allSpells: [builtInSpell]),
      );

      expect(
          find.text('Exceptions — recorded from the rulebook directly, not derived from the guidelines'),
          findsNothing);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/spell_library_screen_test.dart`
Expected: FAIL to compile — `SpellLibraryState` accepts `exceptions:` (Task
7 already added it, so this compiles), but the heading text and
`exception-chip` are never found — `findsOneWidget` assertions FAIL because
`SpellLibraryScreen` never renders an Exceptions section yet.

- [ ] **Step 3: Add the Exceptions section to `SpellLibraryScreen`**

In `lib/presentation/screens/spell_library_screen.dart`, add the import:

```dart
import 'package:eruditus/models/resolved_exception.dart';
```

Add the section to the `ListView`'s children, after the existing
`...state.visibleSpells.map(...)` entry:

```dart
                    ...state.visibleSpells.map((s) => SpellCard(
                          entry: s,
                          level: state.spellLevels[s.id],
                          isRitual: state.ritualSpellIds.contains(s.id),
                        )),
                    // Exceptions get their own section below the leveled
                    // spells, the same reasoning as the Templates section
                    // above them: these six are curiosities the rulebook
                    // itself says don't follow guideline design, not the
                    // primary actionable content this screen exists for.
                    // Omitted entirely when empty, matching the Templates
                    // section's own convention.
                    if (state.visibleExceptions.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                            'Exceptions — recorded from the rulebook directly, not derived from the guidelines'),
                      ),
                      ...state.visibleExceptions.map((e) => _ExceptionCard(entry: e)),
                    ],
```

Add the `_ExceptionCard` widget at the end of the file, after
`_TemplateCard`:

```dart
/// One exception spell's card. No `isGeneral` chip and no action — an
/// exception spell is never instantiable, whether or not it happens to
/// print a level (SpellCard already renders a null [level] as plain
/// "Technique Form" with no level suffix, so the four General-kind
/// exceptions need no special-casing here).
class _ExceptionCard extends StatelessWidget {
  final ResolvedException entry;

  const _ExceptionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SpellCard(entry: entry, level: entry.printedLevel, isException: true);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_library_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Run the full Dart test suite**

Run: `flutter test`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/spell_library_screen.dart test/presentation/screens/spell_library_screen_test.dart
git commit -m "feat: render the Exceptions section on the Library screen

Below Templates and Spells, using SpellCard directly via LibraryEntry --
no new rendering path needed. No instantiation action and no General chip:
an exception spell is never instantiable regardless of whether it prints a
level.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: Integration test

**Files:**
- Modify: `integration_test/spell_creation_flow_test.dart`

**Interfaces:**
- Consumes: the real `LibraryRepository`/`SpellLibraryBloc` wiring from
  Tasks 5–8, against the real `assets/data/spell_exceptions.json` written
  in Task 2.

- [ ] **Step 1: Write the failing test**

Add to `integration_test/spell_creation_flow_test.dart`, as a new
`testWidgets` block after the existing `'end-to-end: learning a ward
template produces a levelled spell'` test (the last one in the file). It
reuses the same bootstrap pattern every existing test in this file already
repeats (see the first test in the file for the full `AppDatabase`/
`ConfigurationRepository`/... setup this mirrors):

```dart
  testWidgets(
    'end-to-end: the Exceptions section lists a real exception spell and offers no action',
    (tester) async {
      final database = await AppDatabase.open(path: inMemoryDatabasePath);
      final assetLoader = AssetDataLoader();
      final configRepository = ConfigurationRepository(
        assetLoader: assetLoader,
        configDatasource: LocalConfigurationDatasource(database: database),
      );
      final resolver = SpellResolver(
        effects: await configRepository.getAllEffects(),
        parameters: await configRepository.getAllParameters(),
        modifiers: await configRepository.getAllModifiers(),
      );
      final spellRepository = SpellRepository(
        datasource: LocalSpellDatasource(database: database),
        resolver: resolver,
        configRepository: configRepository,
      );
      final libraryRepository = LibraryRepository(
        assetLoader: assetLoader,
        spellRepository: spellRepository,
        resolver: resolver,
        configRepository: configRepository,
      );
      final backupService = BackupService(spellRepository: spellRepository, configRepository: configRepository);

      final allSpells = await libraryRepository.getAllSpells();
      final spellEngine = SpellEngine(allSpells: allSpells);

      final spellCreationBloc = SpellCreationBloc(spellEngine: spellEngine, spellRepository: spellRepository);
      final spellLibraryBloc = SpellLibraryBloc(libraryRepository: libraryRepository, spellEngine: spellEngine);
      final configurationBloc = ConfigurationBloc(configRepository: configRepository);

      await tester.pumpWidget(EruditusApp(
        spellCreationBloc: spellCreationBloc,
        spellLibraryBloc: spellLibraryBloc,
        configurationBloc: configurationBloc,
        backupService: backupService,
      ));
      await tester.pumpAndSettle();

      await openLibraryTab(tester);

      // Wizard's Communion is one of the six real exception spells written
      // to assets/data/spell_exceptions.json.
      await tester.dragUntilVisible(
        find.text("Wizard's Communion"),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text("Wizard's Communion"), findsOneWidget);
      expect(find.byKey(const Key('exception-chip')), findsWidgets);
      expect(find.text('Learn at level…'), findsNothing);
    },
  );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: FAIL — before Task 2–8 landed, `spell_exceptions.json`/the
Exceptions section wouldn't exist; if run after those tasks (as this plan's
ordering has it), this test should already pass on the first try — treat a
failure here as a signal to re-check Tasks 2–8's wiring, not as expected
red/green TDD churn.

- [ ] **Step 3: If it fails, fix the wiring; otherwise proceed**

Since Tasks 2–8 already implemented every piece this test exercises, no new
production code should be needed here. If the test fails, diagnose against
the real `assets/data/spell_exceptions.json` (confirm "Wizard's Communion"
is present — `python -c "import json; print([e['name'] for e in
json.load(open('assets/data/spell_exceptions.json'))])"`) and against the
bloc/screen wiring from Tasks 7–8 before assuming this test's code itself is
wrong.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: all tests in the file pass, including the new one.

- [ ] **Step 5: Commit**

```bash
git add integration_test/spell_creation_flow_test.dart
git commit -m "test: add an end-to-end check for the Exceptions section

Confirms a real exception spell (Wizard's Communion, from the actual
committed spell_exceptions.json) renders in the Library screen's
Exceptions section with no instantiation action -- the mocked-bloc widget
tests already cover the shape in isolation; this is the real
repository/bloc/screen wiring together.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: `todo.md` updates

**Files:**
- Modify: `.superpowers/todo.md`

- [ ] **Step 1: Amend the standing goal**

Find:

```
**Standing goal:** every published spell in the Definitive Edition core rules
is in the spell library, with its computed level matching its printed level.
```

Replace with:

```
**Standing goal:** every published spell in the Definitive Edition core rules
is either (a) in the spell library with its computed level matching its
printed level, or (b) recorded as an exception spell with a citation-backed
reason the guidelines don't apply to it. See item 46.
```

- [ ] **Step 2: Update the "Where the import stands" summary block**

Find the `> **320 imported · 24 emitted as templates · 16 blocked · 0
unresolved**` line and the blocker-family table below it. Update the counts
line to:

```
> **320 imported · 24 emitted as templates · 6 recorded as exceptions · 10
> blocked · 0 unresolved**
> — 360 published spells in Chapter 9, all accounted for.
```

In the blocker-family table, update the three affected rows. The
"Non-standard Range/Duration/Target" row (currently `2 | **26**...`) becomes:

```
| Non-standard Range/Duration/Target (mechanism done, spells still blocked) | 0 | **26** — corrected from 2: *Watching Ward* and *Mists of Change* both now import as exception spells (item 46) rather than staying blocked |
```

The "General-level, each blocked for an unrelated reason" row (currently `8
| see item **25**...`) becomes:

```
| General-level, each blocked for an unrelated reason | 5 | see item **25** — corrected from 8: *Aegis of the Hearth* and *Wizard's Vigil* now import as exception spells (item 46) |
```

The "No printed design line and no legitimate derivation" row (currently `1
| permanent — see item **27**...`) becomes:

```
| No printed design line and no legitimate derivation | 0 | see item **27** — corrected from 1: *Whispering Winds* now imports as an exception spell (item 46) rather than staying permanently blocked |
```

Add a new row for the new mechanism:

```
| Rulebook says guideline arithmetic doesn't apply at all | 6 | new — item **46**: *Wizard's Communion*, *Wizard's Vigil*, *Aegis of the Hearth*, *Whispering Winds*, *Watching Ward*, *Mists of Change* |
```

Update the table's closing line:

```
**Table total: 10, reconciled to the live count.**
```

- [ ] **Step 3: Update item 26's body**

In item 26's section, find the *Watching Ward* sentence inside its first
bullet:

```
      Split Asunder* all import now. **`Watching Ward` does not and will not
      via this mechanism** — its own clause, `Duration is non-standard`, names no
      basis at all (no "based on X"), so there is nothing to resolve it to
      without guessing. It remains this item's sole open case, General-level
      (item 25 doesn't block it), blocked purely on this.
```

Replace with:

```
      Split Asunder* all import now. **`Watching Ward` does not and will not
      via this mechanism** — its own clause, `Duration is non-standard`, names no
      basis at all (no "based on X"), so there is nothing to resolve it to
      without guessing. **✅ It now imports as an exception spell instead,
      2026-08-16 — see item 46.**
```

Find the "Deliberately left blocked" *Mists of Change* bullet:

```
- **Deliberately left blocked:** *Mists of Change* prints `D: Sun & Year`. Two
  durations in one stat line contradicts item 1's rules-correct one-Duration
  invariant; it also prints a numberless "slightly nonstandard effect". **Do not
  weaken the model for one spell.**
```

Replace with:

```
- **✅ Now an exception spell, 2026-08-16 — see item 46.** *Mists of Change*
  prints `D: Sun & Year`. Two durations in one stat line contradicts item 1's
  rules-correct one-Duration invariant; it also prints a numberless "slightly
  nonstandard effect". The model was correctly never weakened for this one
  spell — it is recorded outside the model instead, via ExceptionSpell's
  free-text Range/Duration/Target.
```

- [ ] **Step 4: Update item 25's body**

Find:

```
**Nine of the 33 remain blocked, each for a reason unrelated to this item.**
(Was ten: *Ward against Faeries of the Mountain* moved out 2026-08-15 — its
"no design line" turned out to be a complete specification once its own
cross-reference to *Ward against Faeries of the Waters* was followed. See
`extract_spells.HAND_DERIVED`'s comment and item 27's correction below.)
- **No design line printed (3):** *Aegis of the Hearth*, *Wizard's Vigil*, *Sight of
  the True Form*.
```

Replace with:

```
**Six of the 33 remain blocked, each for a reason unrelated to this item.**
(Was ten, then nine: *Ward against Faeries of the Mountain* moved out
2026-08-15 — its "no design line" turned out to be a complete specification
once its own cross-reference to *Ward against Faeries of the Waters* was
followed; *Aegis of the Hearth* and *Wizard's Vigil* moved out 2026-08-16 —
both now import as exception spells instead, item 46. See
`extract_spells.HAND_DERIVED`'s comment, item 27's correction, and item 46.)
- **No design line printed (1):** *Sight of the True Form*.
```

Find the "Unrecognised token (1): *Watching Ward*" bullet:

```
- **Unrecognised token (1):** *Watching Ward* — a `Special`-Duration problem, **item
  26's**.
```

Replace with:

```
- **✅ Watching Ward moved to item 46, 2026-08-16** — it now imports as an
  exception spell rather than staying blocked on its `Special`-Duration
  problem.
```

- [ ] **Step 5: Update item 27's body**

Find the *Whispering Winds* bullet:

```
  - *Whispering Winds* (InAu 15, line 13251) — ❌ **permanently blocked.** InAu's only
    base levels are 1/2/4/15; with Sight(3)/Conc(1)/Ind(0) fixed by the stat line, no
    real base level + real magnitude token reproduces 15 without inventing a requisite
    the text does not support. The spell's own prose says why: "fits poorly into the
    normal framework of Hermetic magic."
```

Replace with:

```
  - *Whispering Winds* (InAu 15, line 13251) — ✅ **now imports as an exception
    spell, 2026-08-16 — see item 46.** InAu's only base levels are 1/2/4/15;
    with Sight(3)/Conc(1)/Ind(0) fixed by the stat line, no real base level +
    real magnitude token reproduces 15 without inventing a requisite the
    text does not support. The spell's own prose says why, and its design
    line prints the literal marker `(Unique spell)`.
```

- [ ] **Step 6: Add item 46**

Add a new section after item 45 (find `### 45.` and its section, then insert
after its closing content, before the next `###` heading):

```markdown
### 46. Exception Spells — ✅ DONE 2026-08-16

Six published spells share a failure mode distinct from every other blocked
spell: the rulebook itself, in the spell's own printed text, says guideline
arithmetic doesn't apply — not a missing catalog row, not an ambiguous
resolution, a genuine "this was never designed that way." *Wizard's
Communion*, *Wizard's Vigil* and *Aegis of the Hearth* (General-kind, no
printed level, moved out of item 25); *Whispering Winds* (moved out of item
27); *Watching Ward* and *Mists of Change* (moved out of item 26).

- [x] A new `ExceptionSpell`/`ResolvedException` model pair, parallel to how
      `SpellTemplate` sits alongside `Spell` — free-text Range/Duration/
      Target instead of catalog references, a required `rationale` citation
      instead of computed arithmetic, no `SpellLevelCalculator` involvement.
      No common parent class with `Spell`/`SpellTemplate` — `lib/models` has
      zero `extends` relationships, and the one field most worth sharing
      (R/D/T) is exactly the field that can't be identical between typed and
      free-text shapes.
- [x] A closed, exact-name table, `scripts/spell_import/exceptions.py`'s
      `EXCEPTION_SPELLS`, intercepted as the very first check in
      `extract_spells.py`'s import loop, before any design-line
      tokenization — these six spells never route through
      `build_spell`/`build_template`.
- [x] A third `SpellLibraryScreen` section, below Templates and Spells,
      reusing `SpellCard`/`LibraryEntry` via one new chip. No instantiation
      action — these are read-only canon records.
- [x] The standing goal statement amended to carve out this category
      explicitly, rather than silently failing to cover six real spells.

**Spec/Plan:** `docs/superpowers/specs/2026-08-15-exception-spells-design.md`,
`docs/superpowers/plans/2026-08-16-exception-spells.md`
```

- [ ] **Step 7: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: sync todo.md against the exception-spells work (item 46)

320 imported / 24 templates / 6 exceptions / 10 blocked, down from 16
blocked. Items 25, 26 and 27 each lose the spells that moved to the new
exception-spell mechanism; the standing goal statement now carves out
exception spells explicitly instead of silently failing to cover them.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: Final verification

**Depends on:** Tasks 1–10, all committed.

- [ ] **Step 1: Full three-suite verification from a clean state**

```bash
export ARS_RULEBOOK_ROOT="C:/Development/personal/Ars-Magica-Open-License"
python -m unittest discover -s scripts/spell_import -t .
python -m scripts.spell_import.extract_spells --write
git status --short   # must be empty after --write
python -m unittest discover -s scripts/spell_import -t .   # again, per house convention
flutter test
flutter test integration_test/ -d windows
```
Expected: all green, `git status --short` empty after regeneration.

- [ ] **Step 2: Confirm the final counts**

```bash
python -m scripts.spell_import.extract_spells --write 2>&1 | head -5
```
Expected: `imported : 320`, `templates: 24`, `exceptions: 6`, `blocked  :
10`, `unresolved: 0`.

- [ ] **Step 3: Whole-plan review**

Read the final diff of all 10 prior commits together (`git log --oneline
-10`, `git diff <task-1-commit>~1..HEAD`). Check specifically for:
- `EXCEPTION_SPELLS` still reads as a closed, exact-name table — no
  generalized matching crept in anywhere.
- Every place `git grep -n "Whispering Winds\|Wizard's Communion\|Wizard's
  Vigil\|Aegis of the Hearth\|Watching Ward\|Mists of Change" -- .superpowers
  scripts/spell_import` still reads consistently with the new mechanism (no
  stale "permanently blocked" claim left standing anywhere).
- That `ExceptionSpell` never appears alongside a `SpellLevelCalculator`
  call, a `baseEffectId`, or any other catalog-resolution code path.
- That `todo.md`'s item 46 cross-references (items 25/26/27) are mutually
  consistent — an item referencing item 46's status should match what item
  46's own section now says.

Report findings; fix inline if anything is wrong, no need for a second pass.

- [ ] **Step 4: Commit the final sync, if Step 3 found anything to fix**

```bash
git add -A
git commit -m "docs: whole-plan review fixes for the exception-spells work

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
