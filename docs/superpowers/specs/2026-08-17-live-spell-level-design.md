# The Level Should Compute Live, Not Behind a Button — Design

**Date:** 2026-08-17
**Status:** Approved for planning
**Closes:** todo item 59; todo item 58's first bullet (`ContainerModeSelected`
and `SummaryChanged` hide the level breakdown)

## Goal

The spell level is a pure function of the draft. It should be on screen at all
times while the caster designs, and it should never be hidden by the act of
editing.

Today it exists only after pressing **Calculate & View Suggestions**
(`spell_creation_screen.dart:310-314`), and every subsequent edit emits
`status: editing`, which hides the card again — `showResultsBlock` gates it on
`status == calculated` (`:81-83`, `:307-308`). So the number a caster is
designing towards is absent exactly while they are designing.

## What the Button Was Actually Gating

One press gates three unrelated things at once:

| Gated today | Cost | Belongs behind a button? |
|---|---|---|
| The level breakdown card | one `calculateBreakdown` over ~10 contributions | **No** — pure function of the draft |
| The Similar Spells list | `findSimilarSpells` + one `calculateBreakdown` per candidate (`spell_creation_bloc.dart:553-591`) | **Yes** — the genuinely expensive half |
| The Save / Discard row | none | **No** |

Splitting them is the whole design. The button keeps only the middle row and is
relabelled **"Find Similar Spells"**. The level card becomes a pinned banner.
Save and Discard render at all times.

Discard is the sharper half of that last row. It renders only inside
`showResultsBlock` (`:315`, `:348-356`), so **before the first Calculate there is
no way to abandon a draft at all**. Item 61 closed the one case that made this
acute (a stuck modifier selection); the escape hatch itself is still missing for
every other mistake.

## Decision 1: A Total Function in the Engine

`calculateBreakdown` throws two ways, and a mid-edit draft hits both constantly:

- a General guideline with no `chosenBaseLevel` yet (`spell_engine.dart:140-146`)
- negative magnitudes driving the level below 1

Today `validateSpellDraft` converts the second into a message
(`spell_engine.dart:107-123`) and the button is the only caller, so nothing has
to survive a half-built draft. A live path does. Rather than scatter `try`/
`catch` at the call site, the engine gains one entry point that cannot throw:

```dart
/// Either a breakdown, or the single reason there isn't one. Exactly one of
/// the two fields is non-null.
class LevelPreview {
  final LevelBreakdown? breakdown;
  final String? unavailableReason;
}

LevelPreview SpellEngine.previewLevel(SpellDraft draft)
```

Reasons, first match wins:

| Condition | Reason |
|---|---|
| `baseEffect == null` | "Choose a base effect to see a level." |
| General guideline, `chosenBaseLevel == null` | "Type a level for this General guideline." |
| any of `range`/`duration`/`target` null | "Choose a Range, Duration and Target." |
| `calculateBreakdown` throws `ArgumentError` | "Magnitudes reduce this spell below level 1." |

Two notes on the placement. The wording lives in the engine because
`validateSpellDraft` already returns user-facing message strings from there —
this follows the established pattern rather than inventing a second home for
rules prose. And a null Technique or Form needs no reason of its own: the base
effect dropdown does not render without them (`spell_creation_screen.dart:115`),
so row 1 covers that state.

**`previewLevel` is not validation.** It answers *"is there a number"*, not
*"is this spell legal"*. Catalog checks stay in `validateSpellDraft`, behind
button presses. That separation is what lets the level go live while validation
errors do not — they render as bare red text
(`spell_creation_screen.dart:303-306`), and firing them on every keystroke would
flag a half-built draft as broken.

## Decision 2: One Emit Funnel in the Bloc

The bloc already routes every event through a single `_onEvent`
(`spell_creation_bloc.dart:44-47`), but each of ~20 branches calls `emit`
itself. Wrap that:

```dart
void _emit(Emitter<SpellCreationState> emit, SpellCreationState next) {
  final preview = spellEngine.previewLevel(next.draft);
  emit(next.copyWith(
    breakdown: preview.breakdown,
    levelUnavailableReason: preview.unavailableReason,
  ));
}
```

Every `emit(...)` becomes `_emit(emit, ...)`. The guarantee is structural: **no
handler can emit a state whose breakdown disagrees with its own draft.**

This is why item 58's first bullet closes here rather than being patched. That
bullet is one defect seen through two events (`ContainerModeSelected`,
`SummaryChanged`) — a level card that no edit can hide cannot be hidden by those
two either, and every future handler inherits the same property for free.

### State changes

- **`breakdown` changes meaning.** It is now always the current draft's, never a
  snapshot carried forward across edits. Its `copyWith` needs the `_unset`
  sentinel treatment already documented on `generalEffectSentence`
  (`spell_creation_state.dart:82-91`): a draft going incomplete must clear it
  back to null, which a plain `?? this.breakdown` cannot express.
- **`levelUnavailableReason: String?`** added, same sentinel, same reason.
- **`calculatedLevel` deleted.** It duplicated `breakdown.level` and no
  production code ever read it — it is written once
  (`spell_creation_bloc.dart:596`) and otherwise appears only in tests.

### Three places the funnel cannot reach

- **The constructor.** `super(...)` runs before `this` exists, so the initial
  state is built by a `static _initialState(SpellEngine engine)` — the same
  workaround `_emptySeeded` already uses (`spell_creation_bloc.dart:506-507`).
  Its draft has no base effect, so the app opens on reason 1.
- **`_handleSpellCalculated`** drops its own `calculateBreakdown` call and reads
  `state.breakdown!.level` as `findSimilarSpells`' reference level. Non-null is
  guaranteed once `validateSpellDraft` returns empty, since that method re-runs
  the same computation over the same draft; a comment says so rather than the
  code computing the breakdown twice.
- **`_handleSpellSaveRequested`** gains a `validateSpellDraft` guard at the top:
  on errors, emit them and return without saving. With Save no longer sitting
  behind Calculate, this is the only thing between an invalid draft and the
  repository.

## Decision 3: A Pinned, Collapsible Banner

`Scaffold.body` becomes `Column[ LevelBanner, Expanded(ListView) ]`. The banner
sits under the app bar, outside the scroll, and *above* the ListView so the
on-screen keyboard never collides with it.

Pinning rather than leaving the card in the scroll is the point: the form runs
from Technique down through Summary, so an inline card is off-screen precisely
when the caster is editing the fields at the top. Collapsible rather than a
compact bar plus an inline card, because the full breakdown runs up to a dozen
rows — pinning it expanded would swallow the form, and a bar plus a card would
show the same number in two places at once.

**`LevelBreakdownCard` is repurposed into `LevelBanner`**
(`lib/presentation/widgets/level_banner.dart`). Same job, one call site, and the
rename stops "Card" describing something that is no longer in the scroll. Now a
`StatefulWidget` holding `_expanded` (collapsed by default), taking
`LevelBreakdown?` and `String? unavailableReason`:

- **Header, always.** "Spell level" and the number, or `—`. The chevron appears
  only when there is a breakdown to expand.
- **Reason line** under the header whenever `unavailableReason != null`, visible
  while collapsed — it *is* the placeholder that keeps an incomplete draft from
  showing an absence.
- **Expanded**, the existing contribution rows and ritual-minimum note
  unchanged, inside a `ConstrainedBox` capped at 40% of body height with its own
  scroll, so a spell with many contributions cannot swallow the form.

Keys: `breakdown-total` and `ritual-minimum-note` keep their current meaning.
The root becomes `level-banner`, plus `level-unavailable-reason` and
`level-banner-toggle`.

## Decision 4: What Changes in the ListView

- `showResultsBlock` shrinks to `showSuggestions` (`status == calculated ||
  saving || error`) and gates only the Similar Spells heading, the list, and the
  save-error text. An edit after a press still clears them, which stays correct:
  suggestions computed against a superseded level should not linger.
- The button is relabelled **"Find Similar Spells"**. `_handleSpellCalculated`
  keeps its validate-then-compute shape, so it remains one of the two triggers
  that surface validation errors.
- **The Save / Discard row moves out of the gate** and renders always. Save is
  disabled when `isSaving || state.breakdown == null` — no level means nothing
  saveable, and the banner already says why. That is the affordance; Decision
  2's bloc guard is the actual gate.
- `RitualSection` takes `state.breakdown?.ritualStatus` unconditionally
  (`spell_creation_screen.dart:284-286`). Its current comment justifies the gate
  by staleness — with a live breakdown that reason is gone, so the comment is
  rewritten rather than left contradicting the code.
- The red `validationErrors` text stays exactly where and what it is. Only the
  two button presses populate it.

## Testing

**New:**

- *Engine* — one case per `previewLevel` reason, plus the happy path. The two
  that matter most are the throws that made this item necessary: a General
  guideline with no chosen level, and magnitudes below level 1. Both must return
  a reason, never propagate.
- *Bloc* — a draft-changing event attaches a breakdown; `ContainerModeSelected`
  and `SummaryChanged` each keep it (named explicitly as item 58's regression);
  an edit that makes the draft uncomputable clears the breakdown *and* sets a
  reason; `SpellDiscarded` lands on reason 1; the initial state carries reason 1;
  `SpellSaveRequested` on an invalid draft emits errors and saves nothing.
- *Widget* — banner present on the first frame reading `—` and "Choose a base
  effect"; **Discard reachable before any button press**; Save disabled with no
  level; the toggle expands and collapses; suggestions still absent until the
  button is pressed.

**Churn in three existing files, mostly mechanical:**

- Every `calculatedLevel:` in a setup state is deleted; the assertions on it
  become `breakdown.level`.
- Screen tests that set `status: calculated` purely to make the card appear now
  just supply a `breakdown`.
- Tests asserting the card is *absent* before Calculate invert to asserting the
  placeholder. Those are the assertions that encode the bug.
- `level_breakdown_card_test.dart` → `level_banner_test.dart`.

Verification is `flutter test`. A "permissions" failure on `sqlite3.dll` means
stale `flutter_tester` processes to kill, not a real error.

## Out of Scope

- Item 58's other five bullets.
- Item 56's rules hints (the help-mouseover work).
- Making validation errors live. Item 59 rules this out directly, and Decision 1
  keeps `previewLevel` and `validateSpellDraft` separate to preserve it.

## Files

- `lib/engine/spell_engine.dart` — `previewLevel`
- `lib/engine/level_breakdown.dart` — `LevelPreview`
- `lib/bloc/spell_creation/spell_creation_bloc.dart` — `_emit` funnel,
  `_initialState`, save guard
- `lib/bloc/spell_creation/spell_creation_state.dart` — `levelUnavailableReason`,
  sentinel on `breakdown`, drop `calculatedLevel`
- `lib/presentation/widgets/level_banner.dart` — from `level_breakdown_card.dart`
- `lib/presentation/screens/spell_creation_screen.dart` — `Column` body,
  `showSuggestions`, ungated Save/Discard, live `RitualSection`
