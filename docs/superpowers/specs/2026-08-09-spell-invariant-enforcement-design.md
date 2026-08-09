# Spell Invariant Enforcement: one rule, every path

**Todo item:** 40 (opens section 0, the `spell.dart` foundation program; gives
items 35 and 37 an enforcement home before they add three more caster-supplied
slots)

**Status:** designed 2026-08-09

**Rulebook:** not a rules question. Every invariant here is already established;
this is about where the code enforces them.

---

## Problem

`Spell` has two construction paths — `Spell.fromMap` (assets, DB, backups) and
`SpellDraft.toSpell` (the creation screen). Exactly one rule is enforced on
both: the prose rule, via `validateSpellProse` (`spell.dart:24-36`), which the
`Spell` constructor calls and whose own doc comment says it is shared "so the
two paths cannot drift."

Three further invariants got no such treatment. They live only in
`SpellEngine.validateSpellDraft`, reachable only from the creation screen:

| Invariant | Enforced at | `fromMap` path |
|---|---|---|
| General guideline ⇒ `chosenBaseLevel` present, `>= 1` | `spell_engine.dart:67-73` | unchecked |
| No duplicate requisite art | `spell_engine.dart:93-96` | unchecked |
| No requisite equal to own Technique/Form | `spell_engine.dart:90-92` | unchecked |
| `selectionMode: single` ⇒ at most one option | `spell_engine.dart:99-105` | unchecked |

So the rules that make a spell unsaveable through the UI are silently optional
for a spell arriving from an asset, an importer, or a restored backup.

### Why it matters

**The failure is silent, and silent because two individually-correct decisions
compound.** `calculateBreakdown` throws `ArgumentError` on a General spell with
no chosen level (`spell_engine.dart:149-155`). `SpellLibraryBloc` catches per
spell and continues (`spell_library_bloc.dart:53-65`) — deliberately, so one bad
row cannot redden the whole tab. The result is a card rendered with no level and
no error anywhere: indistinguishable from a spell that has not been calculated
yet.

**No test can catch it.** `published_spell_import_test.dart` has assertions 1-4
(printed level, Ritual agreement, ledger completeness, id resolution). None
covers these. This is item 32's failure mode one layer down: the automated checks
pass *by construction*, and correctness rests on something they never look at.

**Two write paths are unguarded in practice, not just in theory.**
`_handleSpellSaveRequested` (`spell_creation_bloc.dart:394-395`) calls `toSpell`
then `saveSpell` with no `validateSpellDraft` call — only the UI gates it, since
Save renders after Calculate. And `BackupService.importFromJson` calls
`Spell.fromMap` directly (`backup_service.dart:67`).

### Severity: latent, not live

A scan of all 294 spells in `assets/data/spell_library.json` against
`base_effects.json` and `modifiers.json` on 2026-08-09 found **zero violations**
of any invariant. Nothing is broken today. This is foundation work.

Two consequences follow, and both shape the design:

- **The General invariant is currently unreachable from published data at all.**
  `spell_library.json` contains zero `chosenBaseLevel` keys, because item 25
  routed every General published spell to `spell_templates.json`, and
  `SpellTemplate` has no such field (asserted by `spell_template_test.dart:30`).
  Only a user-created spell or a restored backup can carry one — exactly the path
  with no asset test over it.
- **A stored spell can become invalid without anyone rewriting it.** Edit a
  custom modifier's `selectionMode` from `multi` to `single` in Settings and
  every stored spell holding two options on it now violates the rule. Write-time
  blocking cannot catch this, which is why the design needs a read-side half too.

### Why the obvious fix does not work

The checks cannot move into the `Spell` constructor. `Spell` deliberately holds
`baseEffectId`, not `BaseEffect` (`spell.dart:38-43`: "this record deliberately
holds no copy of any catalog data … so there is exactly one source of truth").
It therefore cannot see `isGeneral`, the effect's technique/form, or a modifier's
`selectionMode`. Three of the four invariants are **uncheckable at the model
boundary by construction**. That is the finding: it is not that sharing was
overlooked, it is that `validateSpellProse`'s pattern does not reach them.

---

## Decisions taken

Recorded here because each was a fork with a defensible other side.

| # | Decision | Rationale |
|---|---|---|
| 1 | **Invalid spells block**, rejected at the boundary rather than degraded | User's call, 2026-08-09. **Flagged revisitable** — blocking is the conservative start, not a settled principle; it may later converge with the degrade treatment `isResolved` gets |
| 2 | **No migration story** for already-stored invalid rows | Backwards compatibility is not a goal and the DB is droppable |
| 3 | **Rule in the model, enforcement in the repository** | Mirrors `validateSpellProse`: one rule, several call sites. The alternatives each fail one way — a model-only check cannot block, a repository-only check cannot be reused by the draft path |
| 4 | **Restore reorders, then skips invalid spells and reports them** | A backup should not lose good rows to one bad one. All-or-nothing was considered and rejected as harsher than the data warrants |
| 5 | **`saveSpell` refreshes the resolver before validating** | Mirrors `LibraryRepository._refreshResolver` |
| 6 | **A stray `chosenBaseLevel` on a non-General spell is invalid** | Silently-meaningless stored data is the class of bug this closes |
| 7 | **Requisites reshape is not batched with items 35/37** | Considered and rejected: the shared cost of a shape change is modest once migration is off the table, and coupling a small fix to 35/37's open design question is the worse trade |
| 8 | **Blocking and degrading are not converged** | They are different facts, not two treatments of one — see "Two ways a spell is unusable" below. The convergence question is filed with item 38, not left open here |
| 9 | **`AssetDataLoader` caches its asset parses, in part A** | The new refresh-before-validate would otherwise re-parse the 611-entry effect catalog on every save. Assets are immutable at runtime, so the cache needs no invalidation |

---

## Design

### The rule

One function, beside `validateSpellProse` in `spell.dart`:

```dart
/// The catalog-dependent invariants every spell must satisfy, stated once and
/// shared by every path that can produce or hold one — the same contract
/// [validateSpellProse] provides for prose.
List<String> validateSpellAgainstCatalog({
  required BaseEffect effect,
  required int? chosenBaseLevel,
  required List<Requisite> requisites,        // becomes a Map in part B
  required Map<String, List<String>> selectedModifiers,
  required List<Modifier> modifiers,
});
```

**It takes the pieces, not a `ResolvedSpell`.** Two reasons, both binding:
`resolved_spell.dart` imports `spell.dart`, so the dependency cannot run the
other way; and `SpellDraft` holds a bare `BaseEffect?`, never a `ResolvedSpell`,
so pieces are the only shape both the draft path and the record path can call.
That is the whole point of the exercise.

Five checks in part A:

1. `effect.isGeneral` ⇒ `chosenBaseLevel` present and `>= 1`
2. `!effect.isGeneral` ⇒ `chosenBaseLevel` absent
3. No requisite art equals `effect.technique` or `effect.form`
4. No duplicate requisite art
5. No `selectionMode: single` modifier carries more than one selected option

**Part B deletes check 4** and changes the `requisites` parameter to
`Map<String, RequisiteKind>`, which is what makes the duplicate unrepresentable.
Part A must therefore keep check 4 as a runtime check, and the signature above
is part A's; do not write it with the Map type before part B lands.

Reconciling against the problem table: of the four invariants named there, three
become checks 1, 3 and 4; the fourth becomes check 5. Check 2 is new — a
backstop rather than a fix for a live leak, since `spell_creation_bloc.dart:87`
already keeps `chosenBaseLevel` only across a General→General switch and `:49`
and `:64` clear it on Technique/Form change. It guards a *future* path that
misses the same clearing.

**Deliberately unchanged:** an unknown modifier id stays tolerated, contributing
0, as `calculateBreakdown` already documents. Tightening that is a separate
question from these invariants.

### The invariant that stops existing

`requisites` changes from `List<Requisite>` to `Map<String, RequisiteKind>` keyed
by art. Duplicate arts become **unrepresentable** — no check, no test, no
enforcement point, which is strictly better than validating for them.

Serialization goes from `[{"art": "Rego", "kind": "adding"}]` to
`{"Rego": "adding"}`. Dart maps and JSON objects both preserve insertion order,
so display order survives the change.

### Where the rule is called

| Path | What it does | On failure |
|---|---|---|
| `SpellEngine.validateSpellDraft` | calls the validator with the draft's pieces, replacing its inline checks | existing error list → creation screen |
| `SpellRepository.saveSpell` / `updateSpell` | refresh resolver, resolve, validate | throw `InvalidSpellException` |
| `SpellRepository.saveAll` *(new)* | refresh **once**, validate each, write the valid | return the rejected; do not throw |
| `ResolvedSpell.problems` *(new getter)* | calls the validator | Library renders an invalid card |
| assertion 7, `published_spell_import_test.dart` | validator across all published spells | test failure |

**There is no unchecked write method.** `saveAll` is not a bypass: same
validator, different failure mode, which is what decision 4 requires. Refreshing
once is what makes a restore affordable — nothing caches the 611-entry asset
parse (`AssetDataLoader.loadBaseEffects` re-reads the bundle on every call), so
refreshing per spell would re-parse it once per imported row.

### Two ways a spell is unusable, kept separate

`ResolvedSpell` already carries one notion of "not usable" — `isResolved` /
`unresolvedReferences`, formalised in `LibraryEntry` and consumed across 8 files
in `lib/`, including `SpellCard`'s existing not-usable rendering. `problems` is a
**second** notion, deliberately not merged with it, because the two are different
kinds of fact:

| | Can compute a level? | Meaning |
|---|---|---|
| Unresolved | **No** — `baseEffect`/`range`/`duration`/`target` are null, so `calculateBreakdown` cannot be called | a dependency vanished |
| Invalid (`problems`) | **Yes** — everything resolves | the combination breaks a rule; the number is computable but must not be trusted |

`spell_library_bloc.dart:44` (`if (!s.isResolved) continue;`) uses `isResolved`
precisely as a can-I-compute gate. Merging the two into one list destroys that
distinction unless `problems` carries a severity, which is more machinery than
this warrants.

`ResolvedSpell.problems` must therefore say so in its doc comment — that it is a
sibling of `isResolved`, and which of the two questions it answers — so the third
parallel notion on this class is deliberate rather than accidental. **Whether the
family should be collapsed into one concept is filed with item 38**, whose
`ResolvedSpell`/`ResolvedTemplate` duplication cleanup is where `LibraryEntry`'s
whole contract gets rationalised. Doing that once across three notions and two
types is cheaper than rationalising two now and three again later.

### The write boundary is what makes blocking possible

Decision 1 blocks invalid spells, and that is not in tension with degrading on
load. The axis is not invalid-vs-unresolved; it is **whether anything is being
written**:

- At a write boundary you can refuse, so blocking is available.
- On load nothing is being written. There is nothing to refuse, and the
  alternatives to degrading are hiding or deleting user data.

The same invariant can need both. Edit a custom modifier's `selectionMode` from
`multi` to `single` in Settings and every stored spell holding two options on it
becomes invalid, with no write anywhere. That case can only ever degrade — which
is why the read side is not optional.

### Three supporting changes

**`SpellResolver` starts carrying modifiers.** It holds `_effectsById` and
`_parametersById` today; modifiers live on `SpellEngine.allModifiers`, so
`ResolvedSpell` has no way to run check 4. Adding `modifiers` to the constructor
and to `updateCatalogs`, and giving `ResolvedSpell` the modifiers its
`selectedModifiers` keys resolve to, makes it self-sufficient and mirrors how it
already carries effect/range/duration/target. This touches every `SpellResolver`
construction site, including tests.

**`SpellRepository` gains a `ConfigurationRepository`,** so it can refresh before
validating. One shared `SpellResolver` instance already exists (`main.dart:44`,
injected into both `SpellRepository` and `LibraryRepository`), so the refresh
reaches the object the check reads — no new wiring, only a new dependency. There
is no cycle: `ConfigurationRepository` depends only on `assetLoader` and
`configDatasource`, neither of which points back, so this is a diamond rather
than a loop. It is also not a new pattern — `LibraryRepository` already holds
exactly this pair for exactly this purpose.

The mechanical cost is the constructor change: **19 `SpellRepository`
construction sites across 10 files**, 9 of them outside `lib/`.

**`AssetDataLoader` caches its three asset loads.** Without this, the refresh
above re-reads and re-parses the 611-entry `base_effects.json` from the bundle on
**every save**, because `ConfigurationRepository.getAllEffects` delegates
straight to `AssetDataLoader` and nothing memoises it.

Caching needs no invalidation: assets are immutable at runtime, which is exactly
why `LibraryRepository.getBuiltInSpells` already caches (`:48-51`). Custom
entries come from the DB and stay uncached, so freshness is preserved everywhere
it is actually achievable.

This is in part A rather than filed as an optimisation because it is what makes
the new dependency affordable. It also pays for itself in code this work does not
otherwise touch: `LibraryRepository._refreshResolver` currently re-parses those
611 entries on **every Library tab visit**, the same shape of waste item 38
records for `getTemplates()`.

### Restore

`importFromJson` writes custom effects and parameters **first**, then spells via
`saveAll`. `BackupImportResult` gains `rejectedSpells` — id plus reason — and
`backup_screen.dart:39-40`'s status message reports them alongside the counts.

This fixes an ordering bug that exists today independently of validation: spells
are written at `backup_service.dart:66-75`, custom effects and parameters at
`:77-91`, *after*. A spell built on a custom effect from the same backup is
currently written before the effect it depends on exists.

---

## Testing

- Unit tests per check, positive and negative
- `saveSpell` throws on an invalid record; `updateSpell` likewise
- `saveAll` writes the valid rows, reports the rejected, and does not throw
- A restore whose spell depends on a custom effect in the same backup imports
- Assertion 7 across `spell_library.json` **and** `spell_templates.json` —
  green on landing, given the zero violations measured 2026-08-09, and a
  regression guard thereafter

**One test is not optional.** Item 7 records that
`backup_service_test.dart`'s round-trip duplicates `spell_test.dart`'s
serialization test rather than calling through `BackupService`, so the service is
not exercised. This design changes `importFromJson`'s ordering and its failure
behaviour, and a real round-trip through the service is the only thing that
verifies either. Closing item 7's coverage hole is a consequence of doing this
work correctly, not scope added to it.

---

## Scope: two parts, planned separately

Only one part touches serialized data.

| | Touches | Delivers |
|---|---|---|
| **A. Validator + enforcement** | `spell.dart`, `spell_resolver.dart`, `resolved_spell.dart`, `spell_repository.dart`, `backup_service.dart`, `spell_engine.dart`, `asset_data_loader.dart`, `main.dart`, tests | all five checks enforced on every path |
| **B. Requisites reshape** | all of A's models, plus both assets, `emit.py` ×2, provenance adoption, every requisite-bearing test | converts one invariant from a runtime check into an impossibility |

**Part A is planned and implemented first.** It delivers every invariant; B only
changes *how* one of them is guaranteed. Splitting keeps the asset regeneration
in its own reviewable change.

### What part B drags with it

- `emit.py` builds `[{"art", "kind"}]` in two near-duplicate places —
  `build_spell` (`:92-104`) and `build_template` (`:163-181`), the duplication
  item 38 already flagged. Both become dict-building.
- The hand-rolled duplicate-art guard at `:98`/`:169` disappears — but must
  become `setdefault`, **not** plain assignment, or a later `free` requisite
  would silently overwrite an earlier `adding` one.
- Regenerate `spell_library.json` (294 spells) and `spell_templates.json` (23),
  then adopt through item 30's provenance machinery: `--accept-source`,
  `source.lock`, `import_report.md`.
- Every test constructing a `Spell`, `SpellDraft` or `SpellTemplate` literal
  with requisites.

---

## What this deliberately does not do

- **It does not unify `problems` with the `isResolved` degrade path.** Decision 8
  keeps them separate on their merits, not as a deferral; the collapse question
  is filed with item 38. Decision 1's revisitability is about something else —
  whether an invalid spell should be *refused* at a write boundary at all.
- **It does not add validation for items 35/37's slots.** It gives them a home;
  they supply their own checks when they land.
- **It adds no write-path enforcement for `SpellTemplate`.** Templates are
  read-only catalog data — users instantiate them, never author them — so there
  is no write boundary to block at. Checks 1 and 2 do not apply (a template has
  no `chosenBaseLevel` by design); checks 3, 4 and 5 do, and assertion 7 covers
  them by running over `spell_templates.json` as well as `spell_library.json`.
