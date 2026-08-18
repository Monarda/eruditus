# Every `SpellCreationState` Field Has an Owner

**Todo item 62.** Opened 2026-08-17 from item 59's whole-branch final review;
designed 2026-08-18.

## The problem

`SpellCreationBloc._emit` advertises itself, in its own doc comment, as "the
place a moved draft's stale halves are settled" — and every emit in the bloc
does go through it. Two fields do not follow that claim, and the gap is
invisible to the next person adding a handler:

- **`generalEffectSentence`** is recomputed at five hand-maintained handler
  call sites (`TechniqueSelected`, `FormSelected`, `BaseEffectSelected`,
  `ChosenBaseLevelChanged`, `TemplateInstantiated`), each passing
  `generalEffectSentence: _generalEffectSentenceFor(draft)`. Correct today —
  every handler that can move either input does call it. The exposure is the
  sixth one.
- **`savedSpell`** has no rule of any kind. `copyWith` carries it forward as
  `savedSpell ?? this.savedSpell`, so once a save writes one it survives every
  later edit, calculate and failed save. Harmless today because its single
  reader — the snack bar in `spell_creation_screen.dart:53-56` — sits in a
  listener gated on `status == saved`. Latent: any future read not gated on
  that status gets whatever was last saved this session.

Neither is a live bug. This is about the rules the fields follow, so that the
funnel's doc comment is true rather than nearly true.

## The rule this establishes

After this change every field on `SpellCreationState` falls into exactly one of
three classes, and `_emit`'s doc comment names all three:

| Class | Fields | Rule |
|---|---|---|
| Funnel-computed from the draft | `breakdown`, `levelUnavailableReason`, **`generalEffectSentence`** | Recomputed on every emit; no handler passes them |
| Funnel-invalidated | `validationErrors` (on `draftChanged`); `suggestions`, `suggestionLevels`, `ritualSuggestionIds` (on `breakdownChanged`) | Cleared by predicate; only a handler populates |
| One-shot payload | `errorMessage`, **`savedSpell`** | Not carried forward by `copyWith`; `_emit` re-passes `next.<field>` |

No field is left hand-maintained across handlers. That is the whole content of
item 62.

## Change 1 — `generalEffectSentence` moves into the funnel

Add to `_emit`'s `next.copyWith(...)`:

    generalEffectSentence: _generalEffectSentenceFor(next.draft),

and delete the five handler arguments at `spell_creation_bloc.dart:232, 255,
295, 302, 518`. `_generalEffectSentenceFor` is unchanged — it already takes a
draft and returns the sentence or null.

The argument is the one that moved the level into `_emit` in the first place.
`SpellEngine.deriveGeneralEffect` reads `baseEffect.effectFormula` and
`chosenBaseLevel` and nothing else — no catalog lookup — so the sentence is a
pure function of the draft, exactly the shape `previewLevel` has, computed by
an engine call exactly as cheap.

`SpellCreationState.copyWith` keeps its `_unset` sentinel for this field: the
funnel must be able to write `null` and have it mean "cleared", not "omitted".
Its comment changes, because the sentence it opens with — "only the four
handlers that can change baseEffect or chosenBaseLevel ever recompute it" —
stops being true. The new reason is the same one `breakdown` gives two fields
above it.

**This is behaviour-preserving.** All 25 handlers were checked:

- `SpellDiscarded` and the save-success emit build from
  `SpellCreationState.initial()` over a draft with no `baseEffect`, so the
  funnel computes `null` — exactly what they emit today.
- `TemplateInstantiated` also builds from `initial()`, but its draft always has a
  `baseEffect`: `ResolvedTemplate.isResolved` requires one and the handler
  early-returns without it. It was one of the five explicit call sites, so the
  funnel recomputes the identical sentence from the identical draft.
- The save-failure emit re-emits `state` with a draft differing only in
  `summary`, which moves neither input.
- `AvailableModifiersSynced` and `AvailableParametersSynced` cannot move the
  sentence, because `deriveGeneralEffect` consults no catalog. There is no
  catalog-sync hole here of the kind that made `suggestions` key off
  `breakdownChanged`.

So the value is structural, not a fix. Recording that plainly matters more than
claiming a bug: the change earns its place by making the sixth handler
impossible to get wrong, and it should be reviewed on that basis.

## Change 2 — `savedSpell` becomes a one-shot payload

In `SpellCreationState.copyWith`:

    -  savedSpell: savedSpell ?? this.savedSpell,
    +  savedSpell: savedSpell,

with a comment pointing at `errorMessage` immediately below it as the same
rule, and in `_emit`, beside the existing `errorMessage` pass-through:

    savedSpell: next.savedSpell,

`errorMessage` is the precedent and the parallel is exact: both are payloads
for the status that carries them, meaningful in the emit that writes them and
stale in every emit after. `_emit` must re-pass both for the same reason the
existing comment already gives — the funnel's `copyWith` would otherwise
swallow what the handler had just set.

**This one is a behaviour change**, the only one in the item: after a save, the
next edit nulls the field instead of carrying the spell forward. Nothing reads
it in that window today, which is why the change is safe now and worth making
now.

The single writer stays the save-success emit, which builds from `initial()`
and passes `savedSpell: spell`; the funnel preserves it, and the snack bar
reads it from the state that carries `status == saved`.

## Tests

Two new bloc tests, each stating the rule rather than the mechanics:

1. **`savedSpell` does not outlive the save it described.** Save a valid draft,
   then send `RangeSelected`; expect `savedSpell` null. This is the behaviour
   change, and the test that would have caught an ungated read.
2. **`generalEffectSentence` survives an edit that does not move it.** Select a
   General guideline and a chosen level, then send `RangeSelected`; expect the
   same sentence. Guards the funnel recomputing correctly for the events that
   previously relied on `copyWith` carrying the value forward.

Existing coverage stays green unchanged and is not rewritten:
`spell_creation_bloc_test.dart:1884-1912` and `:2155-2167` pin the five moved
call sites, and `spell_creation_bloc_test.dart:2606` and
`spell_creation_screen_test.dart:692-711` construct `savedSpell` states
directly, which both options preserve.

## Out of scope

- Dropping `savedSpell` from the state in favour of a one-shot side channel.
  The field is the established shape for this, matching `errorMessage`.
- Any change to the funnel's two invalidation predicates. Item 59 settled
  those and this design does not reopen them.

## Files

- `lib/bloc/spell_creation/spell_creation_bloc.dart`
- `lib/bloc/spell_creation/spell_creation_state.dart`
- `test/bloc/spell_creation_bloc_test.dart`
- `.superpowers/todo.md` (close item 62)

## See also

- Item 59, `## Completed ✅` — the funnel this completes.
- Item 58 — closed via 59; the same doc comment is the thing both items lean on.
