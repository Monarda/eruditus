# Open Guideline Slots — Part B (Form + Specific Type) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the remaining two `OpenSlotKind` values — `form` and `specificType` — by annotating the 7 catalog entries that declare them and adding their UI controls, reusing Part A's mechanism (`OpenSlotKind`/`chosenSlots`, checks 6/7, `OpenSlotChosen`) exactly as shipped, with no code reshaping.

**Architecture:** Part A already built everything generic: the data model, both validation checks, the bloc event, and the UI-gating pattern. Part B is additive catalog coverage plus two more UI controls that plug into that same pattern. Unlike Part A's realm work, **no hand-verified resolution table is needed** — every real corpus template that references these 7 guidelines is genuinely case-2 (its own prose never commits to one Form or type; each explicitly describes a family of variants), so their `chosenSlots` correctly stays empty by the rule Part A's Decision 9 already established, and asset regeneration is expected to produce a byte-identical `spell_templates.json`.

**Tech Stack:** Dart/Flutter (`lib/`, `test/`), Python 3 (`scripts/spell_import/`, `scripts/spell_import/tests/`).

## Global Constraints

- No migration story needed (prototype stage, DB droppable — project convention, unchanged from Part A).
- `OpenSlotChosen(kind, value)` is reused as-is — no new bloc event. Only new UI call sites (`OpenSlotChosen('form', value)`, `OpenSlotChosen('specificType', value)`).
- `chosenSlots` stays `required` on `validateSpellAgainstCatalog` (Part A's final review reverted it from optional back to required — do not reintroduce a default).
- Checks 6 and 7 are already correctly split: check 6 skips templates, check 7 does not (Part A's final-review fix, `lib/models/spell.dart`). Nothing in this plan touches that split.
- `assets/data/base_effects.json` edits must be surgical single-line edits, preserving the file's existing one-line-per-entry format and each line's exact comma-spacing/Unicode characters. **Do not** load the whole file with `json.load` and write it back with `json.dump` — Part A's Task 5 did exactly that by accident and reformatted all 611 entries; it was caught and reverted before review. Read the target line's exact current text first, then edit only that line.
- `source.lock`'s pinned rulebook revision is unchanged — asset regeneration uses `--write` alone, never `--accept-source`.
- `openSlots` stays declared per-guideline, even for `muvi-G2` (shared by Form-restricted spells and the Form-agnostic `The Sorcerer's Fork`) — this is an accepted, human-approved rough edge (design spec Decision 12), not something to redesign around.
- `muvi-G1` is deliberately **not** annotated — its only corpus user (`Shroud Magic`) never mentions Form in its own prose.

---

## File Structure

| File | Responsibility |
|---|---|
| `assets/data/base_effects.json` | 7 entries gain `openSlots`: `pevi-G2`/`pevi-G7`/`revi-G5` → `["specificType"]`; `pevi-G10` → `["form", "specificType"]`; `pevi-G11`/`muvi-G2`/`muvi-G3` → `["form"]`. |
| `lib/presentation/screens/spell_creation_screen.dart` | Two new gated controls beside the existing realm dropdown: a Form dropdown (`ArsForms.all`) and a `specificType` free-text field. |
| `test/presentation/screens/spell_creation_screen_test.dart` | New fixtures + widget tests for both controls. |
| `test/data/published_spell_import_test.dart` | New end-to-end test proving a real corpus Form-slot template (`Wizard's Boost (Form)`) round-trips through the asset-load path, stays empty as a template, and requires (then accepts) a filled Form once instantiated into a concrete `Spell`. |
| `scripts/spell_import/tests/test_catalog.py` | New test confirming `Catalog.open_slots` reads the 7 new annotations correctly (the method itself needs no code change — Task 5 of Part A already shipped it generically). |

No Python emit/import code changes are needed — `catalog.py`'s `open_slots` lookup, and `emit.py`'s `if chosen_slots: ...` guard, already handle "guideline declares a slot, no table entry exists" correctly (that's exactly `Wind of Mundane Silence`'s existing case). Regeneration in Task 3 is verification, not new wiring.

---

### Task 1: Catalog annotation — the 7 Form/specificType entries

**Files:**
- Modify: `assets/data/base_effects.json`
- Test: `scripts/spell_import/tests/test_catalog.py`

**Interfaces:**
- Consumes: `Catalog.open_slots(effect_id)` (Part A, `scripts/spell_import/catalog.py` — already generic, no change needed here).
- Produces: 7 annotated catalog entries other tasks read via the same method.

- [ ] **Step 1: Write failing tests for the 7 annotations**

Add to `scripts/spell_import/tests/test_catalog.py`, in the same class as Part A's `open_slots` tests (search for `test_open_slots_returns_the_annotated_list`):

```python
    def test_pevi_g2_declares_specificType_open(self):
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("pevi-G2"), ["specificType"])

    def test_pevi_g7_declares_specificType_open(self):
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("pevi-G7"), ["specificType"])

    def test_pevi_g10_declares_form_and_specificType_open(self):
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("pevi-G10"), ["form", "specificType"])

    def test_pevi_g11_declares_form_open(self):
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("pevi-G11"), ["form"])

    def test_revi_g5_declares_specificType_open(self):
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("revi-G5"), ["specificType"])

    def test_muvi_g2_declares_form_open(self):
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("muvi-G2"), ["form"])

    def test_muvi_g3_declares_form_open(self):
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("muvi-G3"), ["form"])

    def test_muvi_g1_declares_nothing_open(self):
        # Deliberately not annotated -- its only corpus user (Shroud Magic)
        # never mentions Form in its own prose (design spec Decision 12's
        # context; muvi-G1 itself carries no rough edge, muvi-G2 does).
        catalog = catalog_module.Catalog.load()
        self.assertEqual(catalog.open_slots("muvi-G1"), [])
```

(These use the real, disk-loaded catalog via `Catalog.load()`, matching the convention Part A's `test_catalog.py` and `test_emit.py` already established — not a synthetic in-memory `Catalog`.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest scripts.spell_import.tests.test_catalog -v`
Expected: FAIL — none of the 7 ids carry `openSlots` yet (`test_muvi_g1_declares_nothing_open` passes trivially since it expects `[]`, which is already true; the other 7 fail).

- [ ] **Step 3: Annotate the 7 entries in `base_effects.json`**

For each id below, find its current line (read the file first — do not assume exact surrounding content), and add the `openSlots` key immediately before the entry's closing `}`, matching that line's existing comma-spacing convention exactly (Part A's annotated lines used `,"openSlots": [...]}` with no space after the comma, matching this file's established style — confirm against the actual line before editing, since a hand-typed guess risks the reformatting mistake this plan's Global Constraints warn against):

| id | value to add |
|---|---|
| `pevi-G2` | `"openSlots": ["specificType"]` |
| `pevi-G7` | `"openSlots": ["specificType"]` |
| `pevi-G10` | `"openSlots": ["form", "specificType"]` |
| `pevi-G11` | `"openSlots": ["form"]` |
| `revi-G5` | `"openSlots": ["specificType"]` |
| `muvi-G2` | `"openSlots": ["form"]` |
| `muvi-G3` | `"openSlots": ["form"]` |

Do **not** touch `muvi-G1` or any other entry.

- [ ] **Step 4: Verify every id was found and the JSON is still valid**

Run:
```bash
python -c "
import json
data = json.load(open('assets/data/base_effects.json', encoding='utf-8'))
by_id = {e['id']: e for e in data}
expected = {
    'pevi-G2': ['specificType'], 'pevi-G7': ['specificType'],
    'pevi-G10': ['form', 'specificType'], 'pevi-G11': ['form'],
    'revi-G5': ['specificType'], 'muvi-G2': ['form'], 'muvi-G3': ['form'],
}
wrong = {i: by_id[i].get('openSlots') for i, want in expected.items() if by_id[i].get('openSlots') != want}
assert not wrong, f'mismatched: {wrong}'
assert by_id['muvi-G1'].get('openSlots') is None, 'muvi-G1 should be untouched'
print('all 7 annotated correctly, muvi-G1 untouched')
"
```
Expected: prints `all 7 annotated correctly, muvi-G1 untouched`.

- [ ] **Step 5: Verify the diff is surgical (7 lines, not a reflow)**

Run: `git diff --stat assets/data/base_effects.json`
Expected: shows exactly 7 changed lines (`7 changed, 7 insertions(+), 7 deletions(-)` or similar — not hundreds). If it shows anything close to 611, stop, revert (`git checkout -- assets/data/base_effects.json`), and redo Step 3 as pure line-level text edits, not a JSON parse/dump round-trip.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python -m unittest scripts.spell_import.tests.test_catalog -v`
Expected: PASS

- [ ] **Step 7: Run the full Python suite**

Run: `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add assets/data/base_effects.json scripts/spell_import/tests/test_catalog.py
git commit -m "feat: annotate the 7 Form/specificType-slot catalog entries"
```

---

### Task 2: UI — Form dropdown and specificType text field

**Files:**
- Modify: `lib/presentation/screens/spell_creation_screen.dart`
- Test: `test/presentation/screens/spell_creation_screen_test.dart`

**Interfaces:**
- Consumes: `BaseEffect.openSlots`, `SpellDraft.chosenSlots`, `OpenSlotChosen` (all Part A). `ArsForms.all` (`lib/utils/constants.dart`, pre-existing).
- Produces: a `DropdownButtonFormField<String>` keyed `'chosen-form-field'`; a text field keyed `'chosen-specific-type-field'`.

This test file mocks the bloc (`MockSpellCreationBloc` via mocktail) — construct `SpellCreationState` directly and pump via the file's existing `pumpScreen(tester, state, {configState})` helper, matching the existing `'chosen realm field (open realm slot)'` group exactly (search for it in the test file before writing new tests, to confirm the pattern hasn't drifted).

- [ ] **Step 1: Write failing tests for both controls**

Add three new fixtures near the existing `generalRealmEffect` (a General Rego Vim ward at `revi-G1`), as siblings — do not mutate `generalRealmEffect`:

```dart
  final formSlotEffect = BaseEffect(
    id: 'muvi-G3', technique: 'Muto', form: 'Vim',
    description: 'Totally change spell', baseLevel: null,
    openSlots: const [OpenSlotKind.form],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );

  final specificTypeSlotEffect = BaseEffect(
    id: 'pevi-G2', technique: 'Perdo', form: 'Vim',
    description: 'Dispel effects of a specific type', baseLevel: null,
    openSlots: const [OpenSlotKind.specificType],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );

  final eitherSlotEffect = BaseEffect(
    id: 'pevi-G10', technique: 'Perdo', form: 'Vim',
    description: 'Dispel specific enchantment type', baseLevel: null,
    openSlots: const [OpenSlotKind.form, OpenSlotKind.specificType],
    provenance: Provenance(source: PublicationSource.published, citations: const [Citation(bookId: 'arm5-core')]),
    effectFormula: const GeneralEffectFormula(kind: GeneralEffectKind.mightThreshold),
  );
```

Add a new group, mirroring `'chosen realm field (open realm slot)'`'s shape exactly:

```dart
  group('chosen form field (open form slot)', () {
    testWidgets('is absent when the selected base effect declares no open slot', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect),
      );
      await pumpScreen(tester, state);

      expect(find.byKey(const Key('chosen-form-field')), findsNothing);
    });

    testWidgets('is present when the selected base effect declares an open form slot',
        (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Muto', form: 'Vim', baseEffect: formSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, formSlotEffect],
          parameters: const [],
        ),
      );

      expect(find.byKey(const Key('chosen-form-field')), findsOneWidget);
    });

    testWidgets('picking a Form dispatches OpenSlotChosen', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Muto', form: 'Vim', baseEffect: formSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, formSlotEffect],
          parameters: const [],
        ),
      );

      await tester.tap(find.byKey(const Key('chosen-form-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignem').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(const OpenSlotChosen('form', 'Ignem'))).called(1);
    });
  });

  group('chosen specific type field (open specificType slot)', () {
    testWidgets('is absent when the selected base effect declares no open slot', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Creo', form: 'Ignem', baseEffect: creoIgnemEffect),
      );
      await pumpScreen(tester, state);

      expect(find.byKey(const Key('chosen-specific-type-field')), findsNothing);
    });

    testWidgets('is present when the selected base effect declares an open specificType slot',
        (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Perdo', form: 'Vim', baseEffect: specificTypeSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, specificTypeSlotEffect],
          parameters: const [],
        ),
      );

      expect(find.byKey(const Key('chosen-specific-type-field')), findsOneWidget);
    });

    testWidgets('typing a value dispatches OpenSlotChosen', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Perdo', form: 'Vim', baseEffect: specificTypeSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, specificTypeSlotEffect],
          parameters: const [],
        ),
      );

      await tester.enterText(
        find.byKey(const Key('chosen-specific-type-field')), 'Hermetic Terram magic');

      verify(() => bloc.add(const OpenSlotChosen('specificType', 'Hermetic Terram magic')))
          .called(1);
    });
  });

  group('either/or open slot (form or specificType)', () {
    testWidgets('both controls render when the effect declares both kinds', (tester) async {
      final state = SpellCreationState(
        status: SpellCreationStatus.editing,
        draft: SpellDraft(technique: 'Perdo', form: 'Vim', baseEffect: eitherSlotEffect),
      );
      await pumpScreen(
        tester,
        state,
        configState: ConfigurationState(
          status: ConfigurationStatus.loaded,
          effects: [creoIgnemEffect, eitherSlotEffect],
          parameters: const [],
        ),
      );

      expect(find.byKey(const Key('chosen-form-field')), findsOneWidget);
      expect(find.byKey(const Key('chosen-specific-type-field')), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: FAIL — no widgets with keys `'chosen-form-field'`/`'chosen-specific-type-field'` exist yet.

- [ ] **Step 3: Add the Form dropdown and specificType field**

In `lib/presentation/screens/spell_creation_screen.dart`, immediately after the existing realm-dropdown block (the `if (draft.baseEffect?.openSlots.contains(OpenSlotKind.realm) ?? false) ...[...]` block), add two more independent gated blocks:

```dart
                if (draft.baseEffect?.openSlots.contains(OpenSlotKind.form) ?? false) ...[
                  const SizedBox(height: 8),
                  // Same ValueKey rationale as the realm dropdown above --
                  // forces a fresh initialValue read on external change
                  // (template instantiation) without needing a StatefulWidget.
                  DropdownButtonFormField<String>(
                    key: ValueKey('chosen-form-field-${draft.chosenSlots['form']}'),
                    decoration: const InputDecoration(labelText: 'Form'),
                    initialValue: draft.chosenSlots['form'],
                    items: ArsForms.all
                        .map((form) => DropdownMenuItem(value: form, child: Text(form)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) bloc.add(OpenSlotChosen('form', value));
                    },
                  ),
                ],
                if (draft.baseEffect?.openSlots.contains(OpenSlotKind.specificType) ?? false) ...[
                  const SizedBox(height: 8),
                  _SpecificTypeField(
                    key: const Key('chosen-specific-type-field'),
                    value: draft.chosenSlots['specificType'],
                    onChanged: (value) => bloc.add(OpenSlotChosen('specificType', value)),
                  ),
                ],
```

`specificType` is free text (design spec Decision 4), not a fixed set, so — unlike the realm/Form dropdowns — it needs a real `StatefulWidget` owning a `TextEditingController` that resyncs on external change, the same reason `_GuidelineLevelField` exists rather than a bare `TextFormField`. Add this class near `_GuidelineLevelField` (same file):

```dart
/// The free-text field for [OpenSlotKind.specificType] -- "a specific type
/// of enchantment" per the rulebook's own illustrative-not-exhaustive
/// examples (design spec Decision 4), so this is text input, not a dropdown
/// like realm/Form.
///
/// A real [StatefulWidget], not a bare [TextFormField], for the same reason
/// as [_GuidelineLevelField]: an uncontrolled field seeds itself from
/// `initialValue` exactly once and never resyncs on a later external change
/// (e.g. `TemplateInstantiated` setting a new `chosenSlots` while this
/// screen's widget state survives underneath `main.dart`'s `IndexedStack`).
class _SpecificTypeField extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _SpecificTypeField({super.key, required this.value, required this.onChanged});

  @override
  State<_SpecificTypeField> createState() => _SpecificTypeFieldState();
}

class _SpecificTypeFieldState extends State<_SpecificTypeField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(covariant _SpecificTypeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != (widget.value ?? '')) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: const InputDecoration(labelText: 'Specific type'),
      onChanged: widget.onChanged,
    );
  }
}
```

Note the key is passed via the widget constructor (`key: const Key('chosen-specific-type-field')` at the call site above) rather than a `ValueKey` on an inner field, since `_SpecificTypeField` is a real `StatefulWidget` that already resyncs its own controller in `didUpdateWidget` — it doesn't need the Element to be torn down and recreated the way the stateless dropdowns do.

`ArsForms` is already imported in this file (used elsewhere for the requisites art-picker union, per `lib/presentation/screens/spell_creation_screen.dart:341-343`) — verify before adding a duplicate import.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/spell_creation_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full Dart test suite, then integration tests**

Run: `flutter test`
Run: `flutter test integration_test/ -d windows`
Expected: both PASS

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/spell_creation_screen.dart test/presentation/screens/spell_creation_screen_test.dart
git commit -m "feat: add Form dropdown and specificType field to the spell creation screen"
```

---

### Task 3: Regenerate assets and verify, with a real-corpus round-trip test

**Files:**
- Modify: `assets/data/spell_library.json` (expected: no change)
- Modify: `assets/data/spell_templates.json` (expected: no change)
- Modify: `test/data/published_spell_import_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1 and 2.

- [ ] **Step 1: Run the importer's write flow**

Run: `python -m scripts.spell_import.extract_spells --write`

(If running from a nested worktree, set `ARS_RULEBOOK_ROOT` to the sibling rulebook checkout first, matching Part A's environment note — check the current shell for whether this is needed before assuming it is.)

- [ ] **Step 2: Verify the diff is truly empty**

Run: `git diff --stat assets/data/spell_library.json assets/data/spell_templates.json`

Expected: **no output at all** — zero changes to either file. Unlike Part A's realm work, none of the 6 corpus templates that reference the 7 newly-annotated guidelines (`Mirror of Opposition (form)`, `Wizard's Boost (Form)`, `Wizard's Reach (Form)`, `The Sorcerer's Fork`, `Unravelling the Fabric of (Form)` — all on `muvi-G2`/`muvi-G3`/`pevi-G2`) have prose committing to one value; every one is genuinely case-2, so `chosenSlots` correctly stays empty and `emit.py`'s `if chosen_slots: ...` guard omits the key entirely, exactly as it already does today. If the diff is non-empty, stop and investigate before proceeding — an unexpected change here means either a prose-scan assumption was wrong or a table was accidentally wired that this plan didn't call for.

- [ ] **Step 3: Verify the counts are unchanged**

Run: `python -m scripts.spell_import.extract_spells --show-blocked`

Expected: `imported : 294`, `templates: 23`, `blocked : 43`, `unresolved: 0` — identical to before this plan (Global Constraints: this plan changes no count, same reasoning as Part A's Decision 10/11).

- [ ] **Step 4: Write a failing end-to-end test for a real Form-slot template**

This proves both halves of the mechanism with real data: a template may stay incomplete (already covered by Part A's analogous realm test), and — new to this test — a caster who fills the slot in at instantiation produces a spell that validates clean, while one who doesn't gets rejected. Add to `test/data/published_spell_import_test.dart`, after the existing `"Circular Ward against Demons' chosenSlots survives..."` test (read that test first — mirror its structure exactly, including how it obtains `loader`/`effects`/`parameters`/`modifiers`):

```dart
  test(
      "Wizard's Boost (Form) has no committed Form (case 2), but a caster's "
      'choice at instantiation validates cleanly', () async {
    final templates = await loader.loadSpellTemplates();
    final template = templates.firstWhere((t) => t.name == "Wizard's Boost (Form)");

    // Case 2: the template itself never commits to one Form -- its own
    // prose says "one for each Hermetic Form" -- so chosenSlots stays empty,
    // same rule as Wind of Mundane Silence's realm case in Part A.
    expect(template.chosenSlots, isEmpty);

    final effects = {for (final e in await loader.loadBaseEffects()) e.id: e};
    final parameters = {for (final p in await loader.loadParameters()) p.id: p};
    final modifiers = await loader.loadModifiers();
    final baseEffect = effects[template.baseEffectId]!;

    Spell instantiate({required Map<String, String> chosenSlots}) {
      final draft = SpellDraft(
        technique: baseEffect.technique,
        form: baseEffect.form,
        baseEffect: baseEffect,
        range: parameters[template.rangeId],
        duration: parameters[template.durationId],
        target: parameters[template.targetId],
        selectedModifiers: template.selectedModifiers,
        requisites: template.requisites,
        adjustments: template.adjustments,
        summary: template.summary,
        description: template.description,
        chosenSlots: chosenSlots,
        chosenBaseLevel: 20,
      );
      return draft.toSpell(name: template.name, source: PublicationSource.userCreated);
    }

    // A caster who instantiates without picking a Form gets a real,
    // catchable problem -- the template's completeness rule (Decision 9)
    // does not extend to the concrete Spell it becomes.
    final unfilled = instantiate(chosenSlots: const {});
    final unfilledProblems = validateSpellAgainstCatalog(
      effect: baseEffect,
      chosenBaseLevel: unfilled.chosenBaseLevel,
      requisites: unfilled.requisites,
      selectedModifiers: unfilled.selectedModifiers,
      chosenSlots: unfilled.chosenSlots,
      modifiers: modifiers,
    );
    expect(unfilledProblems, contains('Choose a Form for this guideline'));

    // Filling it in satisfies check 6, same real catalog entry.
    final filled = instantiate(chosenSlots: const {'form': 'Ignem'});
    final filledProblems = validateSpellAgainstCatalog(
      effect: baseEffect,
      chosenBaseLevel: filled.chosenBaseLevel,
      requisites: filled.requisites,
      selectedModifiers: filled.selectedModifiers,
      chosenSlots: filled.chosenSlots,
      modifiers: modifiers,
    );
    expect(filledProblems, isEmpty, reason: filledProblems.join('; '));
  });
```

- [ ] **Step 5: Run the test to verify it fails first, for the right reason**

Run: `flutter test test/data/published_spell_import_test.dart`
Expected: FAIL before Task 1's catalog annotation exists (if run standalone against a pre-Task-1 checkout) — but since Task 1 is already merged by the time this step runs in the normal task order, run this instead: temporarily comment out Task 1's `openSlots` line for `muvi-G2` in `assets/data/base_effects.json`, rerun the test, confirm it fails with `unfilledProblems` empty and `filledProblems` failing on the stray-kind check (7) instead of passing, then restore the line. This proves the test is actually pinned to the real annotation, not vacuously true. (If this local-revert-and-restore step feels awkward to script, it's acceptable to instead reason through it by inspection — read `muvi-G2`'s current `openSlots` value and confirm the test's assertions genuinely depend on it being `["form"]` — and note in the task report which approach was taken.)

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/data/published_spell_import_test.dart`
Expected: PASS

- [ ] **Step 7: Run the full Dart test suite, integration suite, and Python suite**

Run: `flutter test`
Run: `flutter test integration_test/ -d windows`
Run: `python -m unittest discover -t . -s scripts/spell_import/tests -p "test_*.py"`
Expected: all PASS

- [ ] **Step 8: Run flutter analyze**

Run: `flutter analyze`
Expected: no issues found.

- [ ] **Step 9: Commit**

```bash
git add test/data/published_spell_import_test.dart
git commit -m "test: prove a real Form-slot template's chosenSlots stays open and validates once filled"
```

(No asset files to stage — Step 2 confirmed zero diff there.)

---

## Self-Review Notes

- **Spec coverage:** Catalog annotation for all 7 guidelines named in the spec's Scope table (Task 1), Form dropdown + specificType field (Task 2), asset regeneration verification + real-corpus round-trip test (Task 3) — every item in the spec's Part B scope row is covered. The `pevi-G10` either/or case is exercised by Task 2's widget test (both controls render) and by check 6/7's existing generic logic (Part A) — no real corpus entry uses `pevi-G10` today, so Task 3's round-trip test uses `muvi-G2`/`Wizard's Boost` instead, the strongest real case available.
- **Type consistency:** `chosenSlots` keys stay `'form'`/`'specificType'` (matching `OpenSlotKind.name`) throughout Tasks 2 and 3, consistent with Part A's `'realm'` key and `_openSlotDescription`'s existing switch (already handles all three kinds — Part A's final review confirmed check 6's message routes correctly for `form`/`specificType` too, e.g. "Choose a Form for this guideline").
- **No placeholders:** every step carries real, complete code, grounded directly against the current post-Part-A files (fixture patterns, `_GuidelineLevelField`'s exact resync logic, the existing end-to-end realm test's exact structure) rather than assumed from memory. The one step with a soft instruction (Task 3 Step 5's "reason through it by inspection" alternative) is deliberately flexible because scripting a temporary revert-and-restore mid-task-execution is unusually awkward to specify as a rigid command sequence — the goal (confirm the test isn't vacuous) is still concrete and checkable either way.
