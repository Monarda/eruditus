# Bucket B Import Blockers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unblock the 5 spells "Bucket B" named — *Wind at the Back*, *Trackless Step*, *The Earth Split Asunder* (item 26's "Special" family), *The Bountiful Feast* (item 26's other spell), *Hermes' Portal* (item 45) — and make a final, documented decision on the one spell in Bucket B that cannot be unblocked at all, *Conjuration of the Indubitable Cold* (item 39). Blocked count: 21 → 16 (5 spells import; Conjuration stays blocked, correctly, with its final reasoning recorded; *Watching Ward*, item 26's 4th "Special" spell, also stays blocked — see Task 1).

**Architecture:** Two small, independent additions to the existing Python import pipeline (`scripts/spell_import/`), reusing patterns already in the codebase — no new files, no model changes, no Dart changes. (1) `emit._parameter_name` gains a narrow fallback: when a spell's stat line prints `Spec`/`Special` for its Range, Duration or Target, resolve it via a closed table keyed on the spell's own printed "based on X" adjustment clause, rather than treating it as a fifth catalog parameter. (2) `extract_spells.HAND_DERIVED` and `designline.MODIFIER_LABELS` are extended so a fully-derived (not printed) design line for *Hermes' Portal* can be tokenized and costed, closing a rulebook-corroborated 35-level gap identified in todo item 27/45.

**Tech Stack:** Python 3 stdlib only (`unittest`), no new dependencies. Existing modules: `scripts/spell_import/designline.py`, `scripts/spell_import/emit.py`, `scripts/spell_import/extract_spells.py`, `scripts/spell_import/resolutions.json`.

## Global Constraints

- **Closed, exact-text allow-lists only — never a permissive regex or a "looks like this shape" match.** Every new dict/frozenset entry in this plan is a string verified character-for-character against the rulebook (`c:\Development\personal\Ars-Magica-Open-License\reviewed\Ars Magica - Definitive Edition (Core Rules).md`, Chapter 9). This is the house style throughout `designline.py`/`emit.py` — do not deviate.
- **A base-effect ledger entry (`resolutions.json`) must be forced by the spell's own text, never "the most general-sounding candidate."** Where this plan already worked out a forced reading, it's given verbatim below — do not re-derive it differently. Where a spell has exactly one candidate at its computed base level, no ledger entry is needed or wanted (`ledger.py`'s `resolve()` raises `UnnecessaryEntry` if one is added anyway).
- **Assertion 1 is the check that matters:** a spell's computed level (from `SpellLevelCalculator`-equivalent magnitude summing) must equal its printed level. Every task below states the expected printed level and the magnitude arithmetic that reaches it — verify both, don't just trust a green test run.
- **After any change to `designline.py`/`emit.py`/`extract_spells.py`, regenerate the asset and re-run the Python suite**, in that order: `python -m scripts.spell_import.extract_spells --write` then `python -m unittest discover -s scripts/spell_import -t .` — one committed test asserts the committed JSON matches a fresh run byte-for-byte, so a stale asset shows up as a failure there, not silently.
- **`.superpowers/todo.md`'s item numbers are stable IDs, never reused or renumbered.** This plan touches items 18 (already closed, no change needed), 26, 27, 29 (no change needed — Bountiful Feast's bug turned out not to be a `_split_parts` issue at all, see Task 2), 39, and 45. Update each in place, following the existing style (see how items 43/44 were closed in the file's own history for tone).
- **Full verification before any task is considered done:** `python -m unittest discover -s scripts/spell_import -t .` (Python), `flutter test` (Dart), `flutter test integration_test/ -d windows` (integration — `flutter test` alone does not run these). All four commands, every task, no exceptions.
- **Commit style:** end every commit message with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Look at `git log` for message tone (imperative, one-line summary, body explains why not just what).
- **`ARS_RULEBOOK_ROOT` env var:** if working inside a nested worktree (e.g. `.claude/worktrees/...`), the sibling rulebook checkout won't resolve by relative path. Set `ARS_RULEBOOK_ROOT=C:/Development/personal/Ars-Magica-Open-License` before running Python commands if you hit `FileNotFoundError: no markdown copy of 'Ars Magica - Definitive Edition (Core Rules)'`.

---

## Task 1: Special-Duration/Target parameter resolution

Unblocks *Wind at the Back* (Rego Auram 5), *Trackless Step* (Rego Terram 10), *The Earth Split Asunder* (Rego Terram 30). All three print a stat-line `D: Spec` or `D: Special` with no catalog entry to resolve to — `parameters.json` deliberately has no "Special" parameter (todo item 26's decision: it's shorthand for a real parameter, not a fifth catalog value). Each of these three spells' own design line names what it's shorthand *for*, via an adjustment clause already recognized by `designline.ADJUSTMENT_LABELS`: `"Special (based on Concentration)"` (both Wind at the Back and Trackless Step), `"Special based on Mom"` (The Earth Split Asunder). Base-effect resolution needs no new ledger work for any of the three — verified below.

**Files:**
- Modify: `scripts/spell_import/emit.py:599` (the `_parameter_name` function)
- Test: `scripts/spell_import/tests/test_emit.py`

**Interfaces:**
- Produces: `emit.SPECIAL_PARAMETER_BASIS: dict[str, str]` (module-level constant, read by Task 2 too — it reuses this same table for its own "Special (equivalent to Boundary)" Target).
- Consumes: `designline.ADJUSTMENT_LABELS` (existing), `designline.Token` (existing, `kind="adjustment"` carries `.note`).

**Base-effect verification (no code needed, recorded here so the implementer doesn't have to re-derive it):**
- *Wind at the Back*: Rego Auram, `(Base 2, +1 Touch, +2 Special (based on Concentration))`. `base_effects.json` has exactly **one** Rego Auram entry at base level 2 — `reau-2`, "Control a minor weather phenomenon" (matches: an existing breeze that follows you is a minor weather phenomenon). Single candidate, no ledger entry needed.
- *Trackless Step*: Rego Terram, `(Base 2, +1 Touch, +2 Special (based on Concentration), +1 Part)`. Three candidates at Rego Terram base 2 (`rete-2a`/`2b`/`2c`) — **already resolved** in `resolutions.json` under `lib-rete-trackless-step` → `rete-2b`. Nothing to do here; this entry has been sitting dormant since before the parsing blocker existed.
- *The Earth Split Asunder*: Rego Terram, `(Base 3, +2 Voice, +1 Special based on Mom, +1 Part, +2 size, +1 fancy effect)`. `base_effects.json` has exactly **one** Rego Terram entry at base level 3 — `rete-3`, "Control or move dirt in a very unnatural fashion" (matches: shaking the ground open is a very unnatural use of dirt). Single candidate, no ledger entry needed.

- [ ] **Step 1: Write the failing tests**

Add to `scripts/spell_import/tests/test_emit.py` (put this new class after `AdjustmentEmissionTest`, before `ElaborateEffectEmissionTest` — both already exist in the file):

```python
class SpecialParameterResolutionTest(unittest.TestCase):
    """A `D: Spec`/`T: Special` stat-line marker has no parameters.json entry
    of its own -- it's shorthand for whichever real parameter the spell's own
    adjustment clause names ("based on Concentration", "based on Mom",
    "equivalent to Boundary"). See todo item 26.
    """

    @classmethod
    def setUpClass(cls):
        cls.catalog = catalog_module.Catalog.load()

    def _block_with_stat(self, technique, form, level, duration_name="Sun", target_name="Ind"):
        return blocks.SpellBlock(
            name="Test Spell",
            technique=technique,
            form=form,
            printed_level=level,
            stat=statline.StatLine(
                range_name="Touch", duration_name=duration_name, target_name=target_name,
                is_ritual=False, requisite_arts=[], trailing="",
            ),
            prose="Test prose.",
            design_line=None,
            line_no=1,
        )

    def test_special_duration_based_on_concentration_resolves_to_concentration(self):
        design = designline.parse_design(
            "(Base 2, +1 Touch, +2 Special (based on Concentration))"
        )
        block = self._block_with_stat("Rego", "Auram", 5, duration_name="Spec")
        spell = emit.build_spell(block, "reau-2", self.catalog, design)
        self.assertEqual(spell["durationId"], "duration-concentration")

    def test_special_duration_based_on_mom_resolves_to_momentary(self):
        design = designline.parse_design(
            "(Base 3, +2 Voice, +1 Special based on Mom, +1 Part, +2 size, +1 fancy effect)"
        )
        block = self._block_with_stat("Rego", "Terram", 30, duration_name="Spec")
        spell = emit.build_spell(block, "rete-3", self.catalog, design)
        self.assertEqual(spell["durationId"], "duration-momentary")

    def test_a_special_marker_with_no_named_basis_still_raises(self):
        # No adjustment token at all in this design -- nothing names what the
        # Special marker is shorthand for. Must still block, not guess.
        design = designline.parse_design("(Base 2, +1 Touch)")
        block = self._block_with_stat("Rego", "Auram", 5, duration_name="Spec")
        with self.assertRaises(designline.UnknownToken):
            emit.build_spell(block, "reau-2", self.catalog, design)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_emit.SpecialParameterResolutionTest -v`
Expected: the first two FAIL with `designline.UnknownToken: Test Spell: unknown duration 'Spec'`; the third currently PASSES already (it's here to pin the negative case going forward, not to prove new behavior).

- [ ] **Step 3: Implement `SPECIAL_PARAMETER_BASIS` and widen `_parameter_name`**

In `scripts/spell_import/emit.py`, immediately above `def _parameter_name` (currently line 599):

```python
# A "Spec"/"Special" Range, Duration or Target has no parameters.json entry
# of its own -- todo item 26's decision was that this is shorthand for a
# real parameter, not a fifth catalog value, resolved by reading what the
# spell's own adjustment clause says it's "based on"/"equivalent to". A
# closed table, not a parser: each key is a designline.ADJUSTMENT_LABELS
# entry verified against the one spell that prints it. Watching Ward also
# prints a Special Duration ("Duration is non-standard") but names no basis
# for it at all -- deliberately absent here, see todo item 26's own note on
# why it stays blocked rather than getting a guessed entry.
SPECIAL_PARAMETER_BASIS: dict[str, str] = {
    "Special (based on Concentration)": "Concentration",
    "Special based on Mom": "Momentary",
    "Special (equivalent to Boundary)": "Boundary",
}

_SPECIAL_STAT_MARKERS = frozenset({"Spec", "Special"})
```

Then replace the existing `_parameter_name` function body:

```python
def _parameter_name(design: designline.Design, slot: str, block) -> str:
    """Resolve a slot from the stat line, expanded to its full catalog name."""
    raw = {
        "range": block.stat.range_name,
        "duration": block.stat.duration_name,
        "target": block.stat.target_name,
    }[slot]
    if raw in _SPECIAL_STAT_MARKERS:
        for token in design.tokens:
            if token.kind == "adjustment" and token.note in SPECIAL_PARAMETER_BASIS:
                return SPECIAL_PARAMETER_BASIS[token.note]
        raise designline.UnknownToken(
            f"{block.name}: {slot} is {raw!r} but no adjustment token names "
            "what it's based on"
        )
    if raw not in designline.PARAMETER_LABELS:
        raise designline.UnknownToken(f"{block.name}: unknown {slot} {raw!r}")
    return designline.PARAMETER_LABELS[raw]
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_emit.SpecialParameterResolutionTest -v`
Expected: `Ran 3 tests ... OK`

- [ ] **Step 5: Regenerate the asset and run the full Python suite**

Run: `python -m scripts.spell_import.extract_spells --write`
Expected output includes `imported : 318` (315 + 3), and `git diff --stat assets/data/spell_library.json` shows the 3 new entries. Then:

Run: `python -m unittest discover -s scripts/spell_import -t .`
Expected: all green (244 + 3 new = 247 tests).

- [ ] **Step 6: Verify the 3 spells by hand**

```bash
python -c "
import json
data = json.load(open('assets/data/spell_library.json', encoding='utf-8'))
for s in data:
    if s['name'] in ('Wind at the Back', 'Trackless Step', 'The Earth Split Asunder'):
        print(s['name'], s['printedLevel'], s['baseEffectId'], s['durationId'])
"
```
Expected:
```
Wind at the Back 5 reau-2 duration-concentration
Trackless Step 10 rete-2b duration-concentration
The Earth Split Asunder 30 rete-3 duration-momentary
```

- [ ] **Step 7: Update `.superpowers/todo.md` item 26**

Item 26's first bullet currently reads exactly:

```
- [ ] **A `Special` Duration has nothing to resolve to.** `D: Spec` / `D: Special`
      is not in `parameters.json`, so `emit._parameter_name` raises. Most likely
      answer: the parameter the adjustment is "based on", read off the adjustment's
      own note. Affects *Wind at the Back*, *Trackless Step*
      (`+2 Special (based on Concentration)`), *The Earth Split Asunder*
      (`+1 Special based on Mom`), and *Watching Ward* (`Duration is non-standard`,
      numberless; General-level, so item 25 no longer blocks it — this item is its
      sole blocker). *Trackless Step* has a ledger entry, `rete-2b`.
```

Replace it with:

```
- [x] **A `Special` Duration has nothing to resolve to — ✅ DONE 2026-08-15 for 3
      of 4.** `emit._parameter_name` now resolves `D: Spec`/`D: Special` via a
      closed table, `SPECIAL_PARAMETER_BASIS`, keyed on the spell's own "based on
      X" adjustment clause. *Wind at the Back*, *Trackless Step* and *The Earth
      Split Asunder* all import now. **`Watching Ward` does not and will not
      via this mechanism** — its own clause, `Duration is non-standard`, names no
      basis at all (no "based on X"), so there is nothing to resolve it to
      without guessing. It remains this item's sole open case, General-level
      (item 25 doesn't block it), blocked purely on this.
```

Do not touch the top "Where the import stands" summary block yet — that's Task 5, once all of this plan's tasks are in.

- [ ] **Step 8: Commit**

```bash
git add scripts/spell_import/emit.py scripts/spell_import/tests/test_emit.py assets/data/spell_library.json .superpowers/todo.md
git commit -m "fix: resolve Special Duration/Target to its named basis (item 26)

Wind at the Back, Trackless Step and The Earth Split Asunder all print a
D: Spec/Special stat-line marker with no parameters.json entry -- item 26's
decision was that this is shorthand for a real parameter, not a new catalog
value, resolved by reading the spell's own \"based on X\"/\"equivalent to X\"
adjustment clause. emit._parameter_name now does that via a closed table,
SPECIAL_PARAMETER_BASIS, keyed on the exact ADJUSTMENT_LABELS text.

All three spells have either a single base-effect candidate at their
computed level or an existing resolutions.json entry (Trackless Step ->
rete-2b, already present, previously dormant) -- no new ledger work needed.

Watching Ward also prints a Special Duration but names no basis for it at
all (\"Duration is non-standard\") -- deliberately left out of
SPECIAL_PARAMETER_BASIS and still blocked; guessing a basis its own text
doesn't support is exactly what item 39/32's discipline forbids.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: The Bountiful Feast

Unblocks *The Bountiful Feast* (Creo Herbam, 35). This spell's printed design line has a missing closing parenthesis — a rulebook transcription defect, not a `_split_parts` splitting-logic bug (**this corrects todo item 26/29's earlier guess that it needed a bracket-matching fix in `_split_parts`; having now read the actual rulebook text character-by-character, it does not**). The line is:

```
(Base 1, +1 Touch, +4 Year, +4 Special (equivalent to Boundary), +1 Size (for a total of +4 Size, including the +3 from the guideline, so that the area affected is up to about 6 miles across)
```

Count the parens: 3 opens (`(Base 1`, `(equivalent to Boundary)`, `(for a total...`), only 2 closes. The outer one never closes, so `_split_parts`'s depth tracking never returns to 0 after the second inner paren closes, and the trailing `+1 Size (...)` token is never split off. Fixed the same way *Ward against Heat and Flames*'s `"+1Touch"` was fixed — a narrowly-scoped `DESIGN_LINE_TYPOS` entry, not a change to `_split_parts` itself (which would risk mis-parsing some other, genuinely-nested case elsewhere in the corpus).

**Depends on:** Task 1 (reuses `emit.SPECIAL_PARAMETER_BASIS` for this spell's `T: Special` — "Special (equivalent to Boundary)" is already one of the 3 entries Task 1 adds).

**Files:**
- Modify: `scripts/spell_import/extract_spells.py:247` (`DESIGN_LINE_TYPOS`)
- Modify: `scripts/spell_import/resolutions.json` (new ledger entry)
- Test: `scripts/spell_import/tests/test_extract.py`

**Base-effect verification:** Creo Herbam base 1 has 5 candidates (`crhe-1a` "Ensure that a plant grows well ... includes a +3 Size enhancement", `1b` "Create a plant product", `1c` "Create a plant", `1d` "Prevent a plant from becoming sick", `1e` "Heal a Light Wound to a plant"). The design line's own text forces `crhe-1a`: its parenthetical explicitly says "including the +3 from the guideline" — the only one of the five whose description states a baked-in Size bonus at all. No other candidate mentions a Size enhancement, so this is forced by the design line's own arithmetic note, not by prose similarity.

- [ ] **Step 1: Write the failing test**

Add to `scripts/spell_import/tests/test_extract.py`, inside `HandDerivedTest` is the wrong home (that class is about the "no printed design line at all" spells) — add a new class instead, placed after `HandDerivedTest`:

```python
class BountifulFeastTypoTest(unittest.TestCase):
    """The Bountiful Feast's printed design line is missing its outer closing
    paren (a rulebook transcription defect, not a splitter bug -- see
    DESIGN_LINE_TYPOS). Confirms the fix, not just that parsing succeeds.
    """

    def test_the_bountiful_feast_imports_at_its_printed_level(self):
        report = extract_spells.run(write=False)
        spell = next(s for s in report.spells if s["name"] == "The Bountiful Feast")
        self.assertEqual(spell["printedLevel"], 35)
        self.assertEqual(spell["baseEffectId"], "crhe-1a")
        self.assertEqual(spell["targetId"], "target-boundary")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python -m unittest scripts.spell_import.tests.test_extract.BountifulFeastTypoTest -v`
Expected: FAIL — `StopIteration` (the spell isn't in `report.spells` yet, it's still blocked).

- [ ] **Step 3: Add the `DESIGN_LINE_TYPOS` entry**

In `scripts/spell_import/extract_spells.py`, add to the existing `DESIGN_LINE_TYPOS` dict (currently at line 247, one entry already present for *Ward against Heat and Flames*):

```python
DESIGN_LINE_TYPOS: dict[str, tuple[str, str]] = {
    "Ward against Heat and Flames": ("+1Touch", "+1 Touch"),
    # Missing the outer closing paren entirely -- 3 opens, 2 closes in the
    # printed line. A rulebook transcription defect (verified against the
    # reviewed Definitive Edition markdown directly), not a _split_parts
    # bug: the line is genuinely unbalanced, not oddly-but-validly nested.
    "The Bountiful Feast": (
        "so that the area affected is up to about 6 miles across)",
        "so that the area affected is up to about 6 miles across))",
    ),
}
```

- [ ] **Step 4: Add the `resolutions.json` ledger entry**

Append to `scripts/spell_import/resolutions.json` (before the final closing `}`, matching the file's existing style — see the last few entries for exact formatting):

```json
  "lib-crhe-bountiful-feast": {
    "baseEffectId": "crhe-1a",
    "candidates": [
      "crhe-1a",
      "crhe-1b",
      "crhe-1c",
      "crhe-1d",
      "crhe-1e"
    ],
    "rationale": "The design line's own parenthetical says the +1 Size token is 'for a total of +4 Size, including the +3 from the guideline' -- crhe-1a is the only one of the five candidates whose description states a baked-in Size enhancement at all ('includes a +3 Size enhancement'), so the design line's own arithmetic forces this pick, not just prose similarity. Not crhe-1b/1c (create a product/plant -- this spell doesn't create anything, it protects existing crops), 1d (prevent sickness -- narrower than the spell's own 'healthier, larger, and tastier') or 1e (heal a wound -- no wound involved)."
  }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `python -m unittest scripts.spell_import.tests.test_extract.BountifulFeastTypoTest -v`
Expected: `Ran 1 test ... OK`

- [ ] **Step 6: Regenerate the asset and run the full Python suite**

Run: `python -m scripts.spell_import.extract_spells --write`
Expected: `imported : 319` (one more than Task 1's 318).

Run: `python -m unittest discover -s scripts/spell_import -t .`
Expected: all green.

- [ ] **Step 7: Update `.superpowers/todo.md`**

Item 26's second bullet currently reads exactly:

```
- [ ] *The Bountiful Feast* (`+4 Special (equivalent to Boundary)`) — allow-listed,
      but the same design line has unbalanced brackets so the later `+1 Size (for a
      total of ...` token never closes. **A splitter fix — see item 29's
      `_split_parts` bullet, which should fix this and the `;` case in one pass.**
```

Replace it with:

```
- [x] *The Bountiful Feast* — ✅ DONE 2026-08-15. **Correction: this was never a
      `_split_parts` bug** — the printed line is genuinely missing its outer
      closing paren (a rulebook transcription defect, verified directly against
      the reviewed Definitive Edition markdown), not oddly-but-validly nested
      brackets. Fixed via a `DESIGN_LINE_TYPOS` entry, the same mechanism as
      *Ward against Heat and Flames*'s `"+1Touch"`, not a `_split_parts` change.
      Base effect `crhe-1a`, forced by the design line's own "+3 from the
      guideline" note (the only one of 5 candidates with a stated Size bonus).
```

Then find item 29's "Fix `designline._split_parts` for both malformed design lines in one pass" bullet (it still names *The Bountiful Feast* as the second, still-open malformed-brackets case) and correct it the same way: this spell's bug was never `_split_parts`'s to fix — point at item 26 for where it actually landed, and note only the semicolon case (*Ball of Abysmal Flame*, already done) genuinely needed a `_split_parts` change.

- [ ] **Step 8: Commit**

```bash
git add scripts/spell_import/extract_spells.py scripts/spell_import/resolutions.json scripts/spell_import/tests/test_extract.py assets/data/spell_library.json .superpowers/todo.md
git commit -m "fix: correct The Bountiful Feast's missing closing paren (item 26)

Not a _split_parts bug, despite item 26/29's earlier guess -- the printed
design line is genuinely missing its outer closing paren (3 opens, 2
closes), a rulebook transcription defect verified directly against the
reviewed Definitive Edition markdown. Fixed via DESIGN_LINE_TYPOS, the same
narrowly-scoped mechanism already used for Ward against Heat and Flames's
\"+1Touch\" typo, rather than changing _split_parts's bracket-depth logic
(which could silently misparse a different, genuinely-nested case
elsewhere).

Base effect crhe-1a forced by the design line's own arithmetic note (\"+3
from the guideline\" matches only crhe-1a's stated Size enhancement).
Target resolved via Task 1's SPECIAL_PARAMETER_BASIS (\"equivalent to
Boundary\" -> target-boundary).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Hermes' Portal (item 45)

Unblocks *Hermes' Portal* (Rego Terram, 75). This spell prints no real design line at all — just `(Mercurian Ritual)` — so unlike Tasks 1-2, there is no printed arithmetic to fix; a synthetic line is hand-derived from the spell's own prose and the `rete-4` guideline's own text, the same way *Enchantment of the Scrying Pool* already is. This closes the tokenizer gap flagged in todo item 45 (opened this session): `designline.MODIFIER_LABELS` doesn't recognize the `rego-transport-distance` ladder's labels, so even a correct synthetic line can't be tokenized without this change first.

**Base-effect verification:** Rego Terram base 4 has exactly **one** candidate — `rete-4`, "Transport a non-living object instantly up to 5 paces (add magnitudes for distance/Arcane Connection)". Matches the spell's own prose ("Creates a magical portal through which people, animals, and objects can travel almost instantaneously") and its `Req:`-free, non-living-object framing. No ledger entry needed.

**Magnitude arithmetic (verify this by hand before writing any code — it's the whole point of the task):** `rete-4` base level 4 = magnitude 4. The stat line is `R: Arc, D: Year, T: Ind, Ritual`. Range Arcane Connection = +4 magnitudes, Duration Year = +4 magnitudes. The guideline's own "add magnitudes for distance/Arcane Connection" note is what `rego-transport-distance` models — its top rung, "somewhere you have an Arcane Connection" (`modifiers.json` id `rego-distance-arcane`), costs +5 magnitudes. Plus 2 magnitudes of Size (`size-terram`, magnitude 2, option `size-terram-2`) to cover "people, animals, and objects" rather than a single small item. Total added magnitudes: 4 (Arc) + 4 (Year) + 5 (arcane connection modifier) + 2 (size) = 15. Total magnitude: 4 (base) + 15 = 19. Magnitude 19 → level 75 (magnitude-to-level table: 1-5 map 1:1, then +1 magnitude = +5 level from there — mag 6=10, 7=15, 8=20, 9=25, 10=30, 11=35, 12=40, 13=45, 14=50, 15=55, 16=60, 17=65, 18=70, 19=75). **Matches the printed level exactly — confirms this derivation, not a guess.**

**Files:**
- Modify: `scripts/spell_import/designline.py` (`MODIFIER_LABELS`, currently closes at line 133)
- Modify: `scripts/spell_import/extract_spells.py` (`HAND_DERIVED` at line 184-187, and the `design_text = block.design_line or HAND_DERIVED.get(block.name)` line at 370)
- Modify: `scripts/spell_import/tests/test_extract.py` (`HandDerivedTest.test_the_two_non_derivable_spells_stay_correctly_blocked`)
- Test: `scripts/spell_import/tests/test_designline.py`, `scripts/spell_import/tests/test_extract.py`

**Interfaces:**
- Consumes: `emit.py`'s existing `# Rego transport distance` block (already correct since item 43 — see `.superpowers/todo.md` item 43 — it already maps `"arcane connection"` to `rego-distance-arcane` at the right magnitude; this task only needs the *tokenizer* to produce that label as a `kind="modifier"` token in the first place).

- [ ] **Step 1: Write the failing tokenizer test**

Add to `scripts/spell_import/tests/test_designline.py`, in whichever existing class covers `MODIFIER_LABELS` additions (follow the file's own placement convention — look for where `"metal/gems"`/`"highly unnatural"` were added and put this alongside):

```python
def test_arcane_connection_is_a_modifier_token(self):
    design = designline.parse_design(
        "(Base 4, +4 Arc, +4 Year, +5 arcane connection, +2 size)"
    )
    modifier_tokens = [t for t in design.tokens if t.kind == "modifier"]
    self.assertIn(
        ("arcane connection", 5),
        [(t.label.lower(), t.magnitude) for t in modifier_tokens],
    )

def test_the_distance_ladder_labels_are_modifier_tokens(self):
    for label, magnitude in [
        ("5 paces", 0), ("50 paces", 1), ("500 paces", 2),
        ("1 league", 3), ("7 leagues", 4),
    ]:
        with self.subTest(label=label):
            design = designline.parse_design(f"(Base 4, +{magnitude} {label})")
            self.assertEqual(design.tokens[0].kind, "modifier")

def test_a_bare_distance_token_still_raises(self):
    # Deliberately NOT added to MODIFIER_LABELS -- it names no real option
    # (rego-transport-distance's own table has no bare "distance" entry),
    # so it should keep failing at the tokenizer, not silently succeed and
    # fail one layer deeper with a near-identical error.
    with self.assertRaises(designline.UnknownToken):
        designline.parse_design("(Base 4, +1 distance)")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_designline -v -k Modifier` (or run the whole file and locate these 3 by name)
Expected: the first two FAIL with `designline.UnknownToken`; the third already passes (pinning existing behavior, not new).

- [ ] **Step 3: Check the corpus for a conflicting use of these labels first**

Before adding anything, confirm none of these 6 strings appear elsewhere in Chapter 9 with a different meaning:

```bash
grep -n "arcane connection\|[0-9] paces\|[0-9] league" "c:/Development/personal/Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md" | grep -iE "^\s*\([0-9]|,\s*\+[0-9]"
```

This should show only real design-line tokens (lines starting `(Base ...` or containing `, +N ...`), not prose. If any hit is prose-only (e.g. inside a guideline's descriptive paragraph, not inside a `(Base ...)` line), it doesn't matter — `parse_design` only ever sees text inside a `(Base ...)` line, never guideline prose. Record what you found in the commit message either way.

- [ ] **Step 4: Add the 6 distance-ladder labels to `MODIFIER_LABELS`**

In `scripts/spell_import/designline.py`, add to the end of the existing `MODIFIER_LABELS` dict body (currently closes at line 133 with a bare `}`):

```python
    # Rego transport-distance ladder (modifiers.json id
    # "rego-transport-distance", scoped to rete-4/rehe-10b/reig-3c/rean-10b/
    # reaq-4b). Bare "distance" is deliberately NOT here -- it names no real
    # option (the modifier's own option table has no entry for it), so it
    # should keep failing at the tokenizer rather than succeed here and fail
    # one layer deeper in emit.py with a near-identical message. See todo
    # item 45.
    "5 paces", "50 paces", "500 paces", "1 league", "7 leagues",
    "arcane connection",
```

- [ ] **Step 5: Run the tokenizer tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_designline -v -k "arcane_connection or distance_ladder or bare_distance"`
Expected: all 3 pass.

- [ ] **Step 6: Write the failing extractor test for Hermes' Portal**

Modify `scripts/spell_import/tests/test_extract.py`'s `HandDerivedTest` class. Replace:

```python
    def test_the_two_non_derivable_spells_stay_correctly_blocked(self):
        report = extract_spells.run(write=False)
        blocked_names = {name for name, _ in report.blocked}
        for name in ["Whispering Winds", "Hermes' Portal"]:
            self.assertIn(name, blocked_names)
```

with:

```python
    def test_the_one_remaining_non_derivable_spell_stays_correctly_blocked(self):
        report = extract_spells.run(write=False)
        blocked_names = {name for name, _ in report.blocked}
        self.assertIn("Whispering Winds", blocked_names)

    def test_hermes_portal_is_now_derivable(self):
        # Item 45: the tokenizer gap that made this permanently blocked is
        # closed. rete-4's own guideline note ("add magnitudes for
        # distance/Arcane Connection") plus the rego-transport-distance
        # modifier's top rung is the derivation -- see HAND_DERIVED's
        # comment for the full magnitude arithmetic.
        report = extract_spells.run(write=False)
        spell = next(s for s in report.spells if s["name"] == "Hermes' Portal")
        self.assertEqual(spell["printedLevel"], 75)
        self.assertEqual(spell["baseEffectId"], "rete-4")
```

Also update the class docstring's `"Of the 3 spells with no printed design line, only 1 has a legitimate hand-derivation."` — it's now 2 of 3.

- [ ] **Step 7: Run to verify it fails**

Run: `python -m unittest scripts.spell_import.tests.test_extract.HandDerivedTest -v`
Expected: `test_hermes_portal_is_now_derivable` FAILS with `StopIteration` (still blocked — `HAND_DERIVED` doesn't have an entry yet, and even if it did, `design_text = block.design_line or HAND_DERIVED.get(...)` wouldn't use it since `block.design_line` is the truthy `"(Mercurian Ritual)"`).

- [ ] **Step 8: Add the `HAND_DERIVED` entry and reorder the fallback**

In `scripts/spell_import/extract_spells.py`, add to `HAND_DERIVED` (currently lines 184-187):

```python
HAND_DERIVED: dict[str, str] = {
    "Enchantment of the Scrying Pool": "(Base 5, +1 Touch, +4 Year)",
    "Ward against Faeries of the Mountain": "(Base effect)",
    # Prints only "(Mercurian Ritual)", no arithmetic at all. Derived from
    # rete-4's own guideline note ("add magnitudes for distance/Arcane
    # Connection") plus the spell's own stat line (R: Arc, D: Year, T: Ind)
    # and prose ("people, animals, and objects can travel" -> Size, not a
    # single small item). Magnitude check: 4 (base) + 4 (Arc) + 4 (Year) +
    # 5 (arcane connection, rego-transport-distance's top rung) + 2 (size)
    # = 19 magnitudes -> level 75. Matches the printed level exactly. See
    # todo item 45.
    "Hermes' Portal": "(Base 4, +4 Arc, +4 Year, +5 arcane connection, +2 size)",
}
```

Then change the consuming line (currently `design_text = block.design_line or HAND_DERIVED.get(block.name)`) to check `HAND_DERIVED` first:

```python
        # HAND_DERIVED checked first, not as a fallback: two of its entries
        # (Hermes' Portal) have a real but non-numeric printed line
        # ("(Mercurian Ritual)") that would otherwise win the `or` and never
        # let the derived text through. For every other spell -- i.e. not a
        # HAND_DERIVED key at all -- this is a no-op, `.get()` returns None
        # and the real printed line is used exactly as before.
        design_text = HAND_DERIVED.get(block.name) or block.design_line
```

- [ ] **Step 9: Run the extractor tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_extract.HandDerivedTest -v`
Expected: `Ran 2 tests ... OK`

- [ ] **Step 10: Regenerate the asset and run the full Python suite**

Run: `python -m scripts.spell_import.extract_spells --write`
Expected: `imported : 320` (one more than Task 2's 319).

Run: `python -m unittest discover -s scripts/spell_import -t .`
Expected: all green.

- [ ] **Step 11: Update `.superpowers/todo.md`**

Item 45's three checklist bullets currently read:

```
- [ ] Decide which labels to accept into `MODIFIER_LABELS` and whether a
      bare `"distance"` should raise or resolve
- [ ] Wire the accepted labels through `designline.parse_design` as
      `kind="modifier"` tokens
- [ ] Re-check *Hermes' Portal* against the widened tokenizer — confirm
      whether it now derives end-to-end or still needs item 27's other gap
```

Replace with (mark all three `[x]`, add the heading's own `— ✅ DONE 2026-08-15`):

```
- [x] **Decided:** the 6 concrete distance-ladder labels (5/50/500 paces, 1/7
      leagues, arcane connection), checked against the whole corpus first.
      Bare `"distance"` deliberately excluded — it names no real option in
      `rego-transport-distance`'s own table, so it keeps failing at the
      tokenizer rather than succeeding here and failing one layer deeper in
      `emit.py` with a near-identical message.
- [x] Wired via `designline.MODIFIER_LABELS`.
- [x] **Confirmed: sufficient on its own, no other gap.** The magnitude
      arithmetic (4 base + 4 Arc + 4 Year + 5 arcane-connection modifier + 2
      size = 19 magnitudes) reaches level 75 exactly. *Hermes' Portal* now
      imports as `rete-4`.
```

Then two cross-references elsewhere need the same update:
- Item 27's *Hermes' Portal* bullet: change "Three spells print no design line. Only one has a legitimate derivation" to "two" (Enchantment of the Scrying Pool and now Hermes' Portal), and update its own per-spell note to say the derivation is live, not just planned.
- Item 29's `rego-transport-distance` extension bullet (already marked "Superseded 2026-08-15 by items 43/45") — add that item 45 itself is now done, not just opened.

- [ ] **Step 12: Commit**

```bash
git add scripts/spell_import/designline.py scripts/spell_import/extract_spells.py scripts/spell_import/tests/test_designline.py scripts/spell_import/tests/test_extract.py assets/data/spell_library.json .superpowers/todo.md
git commit -m "fix: close the transport-distance tokenizer gap, derive Hermes' Portal (item 45)

designline.MODIFIER_LABELS gains the 6 concrete rego-transport-distance
labels (5/50/500 paces, 1/7 leagues, arcane connection) -- checked against
the whole corpus first, no conflicting use found. Bare \"distance\"
deliberately excluded: it names no real option, so it should keep failing
at the tokenizer rather than succeed here and fail one layer deeper in
emit.py with a near-identical message.

Hermes' Portal prints no real design line (\"(Mercurian Ritual)\" only) --
hand-derived from rete-4's own guideline note (\"add magnitudes for
distance/Arcane Connection\") plus its stat line and prose. Magnitude
arithmetic (4 base + 4 Arc + 4 Year + 5 arcane-connection modifier + 2 size
= 19 magnitudes) reaches level 75 exactly, confirming the derivation.
HAND_DERIVED is now checked before the real printed line, not as a
fallback to it -- this spell's printed \"(Mercurian Ritual)\" is real but
non-numeric text that would otherwise always win the old `or` ordering.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Conjuration of the Indubitable Cold — final decision (item 39)

No code change expected. This is the one Bucket-B spell with **no forced reading** — confirm that conclusion still holds, and close out item 39 with a final, explicit decision rather than leaving it open-ended.

**Files:**
- Modify: `.superpowers/todo.md` (item 39)
- Modify: `scripts/spell_import/extract_spells.py` (`KNOWN_UNRESOLVABLE`'s comment, if the wording needs a final pass — likely doesn't, verify first)

- [ ] **Step 1: Re-read the spell's printed text one more time**

`Ars Magica - Definitive Edition (Core Rules).md`, Perdo Ignem, *Conjuration of the Indubitable Cold* (search for the heading — it's under Perdo Ignem Spells, level 25): `(Base 4, +2 Voice, +1 Part, +2 size)`. Candidates at Perdo Ignem base 4: `peig-4a` ("Extinguish a fire, cooling the ashes to merely warm"), `peig-4b` ("Chill an object"), `peig-4c` ("Chill a person so that they lose a Fatigue level").

- [ ] **Step 2: Confirm no forced reading exists**

The spell's own text does all three simultaneously: "All nonliving things are chilled thoroughly" (matches `peig-4b` near-verbatim), "All living things ... lose one Fatigue level" (matches `peig-4c` near-verbatim), and a weaker, partial fire effect ("house fires become as small as campfires ... campfires and smaller fires go out" — this is the *level 3* guideline's "reduce the size of a fire without destroying it completely", not level 4's "extinguish", which rules out `peig-4a` on its own wording). Two candidates (`4b`/`4c`) are each matched close to verbatim by different clauses of the same spell, with no textual signal for which is primary. If a genuinely new discriminator turns up during this re-read (it shouldn't — this has already been checked twice this session), record it and pick a forced answer instead of what follows. Otherwise, continue.

- [ ] **Step 3: Update `.superpowers/todo.md` item 39**

Item 39 already correctly narrows this to "peig-4b vs peig-4c, both matched near-verbatim" from this session's earlier work. Add a final closing note: this was re-checked once more during Bucket-B planning (2026-08-15) and the same conclusion holds — genuinely undecidable from the text, staying in `KNOWN_UNRESOLVABLE` permanently unless a future rules source (errata, FAQ) settles it. Mark item 39's checklist item as closed with this outcome (a decision, not a deferral — "stays blocked" is the decision).

- [ ] **Step 4: Commit**

```bash
git add .superpowers/todo.md
git commit -m "docs: close item 39's final spell — Conjuration of the Indubitable Cold stays blocked

Re-checked once more during Bucket-B planning: peig-4b and peig-4c are each
matched near-verbatim by different clauses of the same spell, with no
textual signal for which is primary. Same conclusion as the two earlier
passes this session. This is the decision, not a deferral -- staying
blocked is correct until a future rules source settles it.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Final integration and whole-plan review

**Depends on:** Tasks 1-4, all committed.

- [ ] **Step 1: Full four-suite verification from a clean checkout state**

```bash
python -m unittest discover -s scripts/spell_import -t .
python -m scripts.spell_import.extract_spells --write
git status --short   # must be empty after --write: confirms committed assets are byte-identical to a fresh run
python -m unittest discover -s scripts/spell_import -t .   # run again after --write, per house convention
flutter test
flutter test integration_test/ -d windows
```
Expected: all four green, `git status --short` empty after regeneration. Record the final counts.

- [ ] **Step 2: Confirm the final blocked count**

```bash
python -m scripts.spell_import.extract_spells --write 2>&1 | head -5
```
Expected: `imported : 320`, `blocked : 16` (21 at plan start, minus 5 spells: Wind at the Back, Trackless Step, The Earth Split Asunder, The Bountiful Feast, Hermes' Portal).

- [ ] **Step 3: Update the top "Where the import stands" summary block in `.superpowers/todo.md`**

Update the count line, the "Verified against a live `--show-blocked` run" narrative paragraph (add this round to the list of fix rounds, naming all 5 unblocked spells), and the blocker-family table: item 26's row (6 → 1, only Watching Ward remains, corrected reason), item 27's row (2 → 1, only Whispering Winds remains, permanent), item 39's row stays 1 but the note changes from "3 of 4 resolved" to "3 of 4 resolved, the 4th is a final decision not a pending one". Table total: 21 → 16.

- [ ] **Step 4: Spot-check all 5 newly-imported spells together**

```bash
python -c "
import json
data = json.load(open('assets/data/spell_library.json', encoding='utf-8'))
names = ['Wind at the Back', 'Trackless Step', 'The Earth Split Asunder', 'The Bountiful Feast', \"Hermes' Portal\"]
for s in data:
    if s['name'] in names:
        print(s['name'], '|', s['printedLevel'], '|', s['baseEffectId'], '|', s['rangeId'], s['durationId'], s['targetId'])
"
```
Verify every printed level matches this plan's stated arithmetic and every id looks sane (no `None`, no empty string).

- [ ] **Step 5: Whole-plan review**

Read the final diff of all 4 prior commits together (`git log --oneline -4`, `git diff <task-1-commit>~1..HEAD`). Check specifically for:
- Any place a "forced reading" claim in a commit message doesn't actually hold up against the rulebook text quoted in this plan (re-read the quotes in Tasks 1-4 against the live diff).
- Any leftover TODO/placeholder text.
- That `SPECIAL_PARAMETER_BASIS`, `HAND_DERIVED`, `MODIFIER_LABELS`, and `DESIGN_LINE_TYPOS` each still read as closed, exact-text tables — no generalized matching crept in anywhere.
- That the todo.md's item 26/27/29/39/45 cross-references are mutually consistent (an item referencing another item's status should match what that item's own section now says).

Report findings; fix inline if anything is wrong, no need for a second pass.

- [ ] **Step 6: Commit the final todo.md sync**

```bash
git add .superpowers/todo.md
git commit -m "docs: sync todo.md's summary block against Bucket B's 5 fixes

311 -> 320 imported, 21 -> 16 blocked. Item 26 down to its one permanent
holdout (Watching Ward, no forced Duration basis); item 27 down to its one
permanent holdout (Whispering Winds); item 45 closed; item 39 closed with
a final decision, not a deferral.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
