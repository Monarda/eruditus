# Guideline Adoption Yields to a Conflicting Peer

Designed 2026-08-19. Closes todo item 74, opened from item 67's cross-field
branch and deferred there rather than patched on the spot, because it needed a
design decision about how adoption behaves — not an implementation detail.

## A note on line citations

Item 70 established that every core-rules citation written into this codebase
before 2026-08-18 is exactly 8 lines low, and item 70 is still open. **This
spec deliberately mirrors the code's existing numbers** (`12086`, not `12094`)
so it stays readable against the source it describes, and so item 70's bulk
correction can sweep it with everything else rather than leaving it as an
outlier. `2026-08-18-cross-field-parameter-constraints-design.md` made the
opposite choice for its own reasons; both point at the same sentences.

## The gap

`_seedParameters` (`lib/bloc/spell_creation/spell_creation_bloc.dart`) moves a
draft's Range/Duration/Target to the zero point its newly-adopted guideline is
priced against. A slot is re-seeded only when it is null or still holds the
*outgoing* guideline's reference value — so a deliberately chosen parameter
survives a guideline switch while an untouched one follows.

That rule is evaluated one slot at a time, and Range and Target are not
independent. Two rulebook constraints tie them together:

- **Check 10** (Core Rules 12086): a Personal Range can never take a container
  Target. The *forbidding* direction, carried by `Parameter.forbidsTargetTypes`.
- **Check 11** (HoH:MC 1006): each of the five Sensory Targets requires
  Personal Range. The *forcing* direction, carried by
  `Parameter.requiresRangeId`.

`RangeSelected` and `TargetSelected` both prune against each other in both
directions. `_seedParameters` is the third path that writes this pair, and it
does not participate.

## Three reachable shapes, not one

Item 74 recorded one. The catalog admits three. Today `parameters.json` has 4
container Targets (`circle`, `room`, `structure`, `boundary`) and 5 Sensory
Targets (all `requiresRangeId: range-personal`); `base_effects.json` has 612
rows of which 13 carry a non-default reference triple — 12 wards at
Touch/Ring/**Circle** and one at Personal/Momentary/Vision.

| | Path | Illegal result |
|---|---|---|
| **A** | Deliberate `target-room`, untouched Range, adopt a standard-reference guideline → Range seeds to Personal | Personal + container → **check 10** |
| **B** | Deliberate `range-personal` (which clears the Target), adopt a ward guideline → Target seeds to Circle | Personal + Circle → **check 10** |
| **C** | Deliberate `target-sound` (which forces Range to Personal), adopt a ward guideline → Range seeds to Touch | Touch + Sensory → **check 11** |

**Shape A is already a passing test** — `test/bloc/spell_creation_bloc_test.dart`,
the case named *"the adopt is per-slot: an untouched Range and Duration follow
the new guideline while a chosen Target stays"*, asserts
`range == 'range-personal'` alongside `target == 'target-room'`.

**Shape C is the one no existing test would have caught.** `TargetSelected`
writes `range-personal` itself when the Target demands it — and
`range-personal` is also the standard reference value, so the seed's value
comparison cannot tell that bloc-written Range apart from an untouched slot. A
Range the app set on the user's behalf, to satisfy a rule, gets re-seeded out
from under the Target that required it.

Nothing escapes unnoticed today: `validateSpellAgainstCatalog` still runs on
the draft regardless of how it was assembled, so a save is refused. The gap is
that the bloc does not *prevent* the state.

## The rule

> **A seed that would contradict its peer is not written.** `_seedParameters`
> seeds as it does today; if the resulting Range/Target pair violates check 10
> or check 11, both slots keep their pre-adoption values. Duration is
> unaffected — it carries no cross-field constraint.

This adds **no exception** to "a parameter chosen deliberately survives a
guideline switch." It narrows the other half — "an untouched slot follows the
new guideline" — to *"…unless following it would contradict the peer."*

It is also not a new kind of behaviour in this helper. `_seedParameters`
already has a "the seed is not writable here, leave the slot alone" branch,
taken for three reasons: an id that does not resolve, a wrong-category
candidate, and one out of scope for the draft's Technique or Form. Cross-field
conflict is the fourth reason under the same existing rule.

### Alternatives rejected

**Guideline wins; the deliberate choice is cleared.** Seed the reference triple
whole, then null the conflicting peer as `RangeSelected` does. The level would
always start at the guideline's zero point, but it overturns the documented
survival rule and makes a chosen Target vanish with nothing said. Worst in
shape C, where adopting a ward would silently destroy a chosen Sensory Target.

**Refuse the seed and null the slot.** Most visible, and forces an explicit
re-pick — but it discards a legal working value (shape A's Touch/Room needs no
repair at all) and in shape C leaves a draft whose Target requires a Range that
is now empty.

## Why reverting both slots is correct

Reverting *both* slots is provably identical to "revert whichever slot the seed
moved," because a slot the seed did not move already holds its pre-adoption
value. So the reconcile needs no branch table.

The pre-adoption pair is always a legal landing place, by induction:

- **Base case.** The bloc's initial state is already a seeded draft, not an
  empty one — `_initialState` calls `_emptySeeded`, so the first state holds
  Personal / Momentary / Individual. That triple is check-10/11 clean by
  construction: `range-personal` forbids only `container`, and
  `target-individual` is an `object` Target naming no required Range.
- **Step.** Every path that emits a Range/Target pair leaves a clean one:
  `RangeSelected` and `TargetSelected` already prune both ways, and
  `_seedParameters` will once this lands.
- **The one other entry point is already guarded.** `TemplateInstantiated`
  writes a pair without seeding (templates are deliberately never seeded —
  their parameters are published catalog data), but assertion 7 in
  `test/data/published_spell_import_test.dart` runs
  `validateSpellAgainstCatalog` over every published spell *and* template, and
  checks 10/11 are not wrapped in `if (!isTemplate)`.

The only remaining way "revert both" could land somewhere illegal is a base
effect whose own reference triple is self-contradictory. That is a data
invariant, guarded by a test (below) rather than by bloc logic — the bloc
silently repairing bad catalog data would hide the bug.

## Implementation

### `_seedParameters` reconcile

```dart
var range  = seed(draft.range,  previousReference.rangeId,  next.rangeId,  'Range');
var target = seed(draft.target, previousReference.targetId, next.targetId, 'Target');

if (_rangeTargetConflict(range, target)) {
  range  = draft.range;
  target = draft.target;
}

final keepsMode = _isContainer(target);
```

`SpellDraft.copyWith` distinguishes "omitted" from "null" with an `_unset`
sentinel, so passing a slot's current value — null or not — is a genuine no-op.
The revert costs nothing and cannot accidentally clear a slot.

**`keepsMode` must move below the reconcile.** It has to read the Target that
actually lands, not the seed candidate. The existing ordering constraint
recorded in `DECISIONS.md` — every caller of the modifier pruning seeds after
it, so a Target pruned to null always reaches a mode clear one call later — is
unaffected.

### The predicate

A private static beside `_isContainer`, which is already exactly this shape of
helper: one shared property that both the seed and a handler need.

```dart
static bool _rangeTargetConflict(Parameter? range, Parameter? target) {
  if (range == null || target == null) return false;
  final kind = target.targetType;
  if (kind != null && range.forbidsTargetTypes.contains(kind)) return true;
  final required = target.requiresRangeId;
  return required != null && range.id != required;
}
```

It mirrors checks 10 and 11 exactly, **including their null tolerance**: an
absent slot conflicts with nothing, because a missing parameter is
`ResolvedSpell.isResolved`'s problem, not this function's.

**It stays in the bloc.** `RangeSelected` and `TargetSelected` keep their own
inline logic: they do not merely *detect* conflicts, they *resolve* them
asymmetrically — `TargetSelected` forces the required Range and lets that win
over the forbidding direction, `RangeSelected` clears the Target. Only the
predicate half is common, and folding the resolution halves together would
lose that asymmetry. `validateSpellAgainstCatalog`'s checks 10/11 also stay
separate: they build human-readable messages and have no parameter catalog to
resolve against.

## Testing

| | Test | Why |
|---|---|---|
| 1 | **Rewrite** the shape-A case at `spell_creation_bloc_test.dart` | Its assertion currently *pins the illegal state*. Becomes `range-touch` / `target-room`; the name gains the qualifier that the adopt is per-slot **and** yields to a conflicting peer. |
| 2 | **Add** shape B — `BaseEffectSelected(ward)`, `RangeSelected(personal)` (which clears Circle, and reads as deliberate only because the outgoing reference was Touch), `BaseEffectSelected(ward2)` | Target seed suppressed; Range stays Personal, Target stays null. |
| 3 | **Add** shape C — `TargetSelected(sound)` (which forces Range to Personal), `BaseEffectSelected(ward)` | Range seed suppressed; Personal / sound survives. The regression no value comparison can see. |
| 4 | **Add** assertion 8 to `test/data/published_spell_import_test.dart`, beside assertion 7 | No `base_effects.json` reference triple is self-contradictory under checks 10/11 — the one remaining way "revert both" could land illegally. Lives with assertion 7 because that is where corpus-wide catalog invariants already are. All 612 rows pass today. |
| 5 | **Confirm** Duration still seeds in every conflict case | The reconcile touches Range and Target only; a suppressed pair must not strand the Duration at the outgoing guideline's value. Asserted inline in tests 1-3. |

## Non-goals

- **No user-visible explanation** that the seed was suppressed. The resulting
  state is legal and the level is visible. *"Why didn't my Range follow the
  guideline"* is a rules-hint question and belongs to item 56.
- **No change to checks 10/11 or `validateSpellAgainstCatalog`.** The validator
  was never the gap — it already refuses the save. This closes the bloc's
  failure to prevent the state.
- **No shared cross-field constraint engine.**
  `2026-08-18-cross-field-parameter-constraints-design.md` already argued
  against one from the 52-book survey; nothing here revisits that.

## On close

- **Amend** the `DECISIONS.md` entry under **Bloc and state** whose last
  sentence currently reads *"(Item 74 records the one path this does not yet
  reconcile with the Range/Target checks.)"* — replace it with the rule above.
- **Archive** item 74's body and mark it closed, via the `closing-an-item`
  skill.
