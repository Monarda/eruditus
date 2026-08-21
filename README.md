# Eruditus

A spell-design calculator for **Ars Magica** (Definitive Edition), built in Flutter.

A spell's level is computed from a base-effect guideline plus its Range, Duration and
Target, any modifiers it selects, and any storyguide adjustments — the arithmetic the
rulebook prints as `(Base 4, +1 Touch, +1 Conc, +3 size)`. Eruditus holds the
published guideline catalogs, computes that level, and lets you design your own
spells against the same rules.

## Layout

| Path | What lives there |
|---|---|
| `lib/models/` | The domain types — `Spell`, `BaseEffect`, `Parameter`, `Modifier` |
| `lib/engine/` | `SpellEngine`, which turns a draft into a `LevelBreakdown` |
| `lib/data/` | `datasources/` and `repositories/` that load the JSON catalogs, `app_database.dart`, and `spell_resolver.dart` |
| `lib/bloc/`, `lib/presentation/` | State management and the Flutter UI |
| `assets/data/` | The catalogs: base effects, parameters, modifiers, books, and the published spell library, templates and exceptions |
| `scripts/spell_import/` | The Python extractor that builds the spell library from the rulebook, and `resolutions.json`, its hand-written decision ledger |
| `test/`, `integration_test/` | Dart unit/widget tests, and end-to-end tests |

## Licence

Eruditus is licensed in two halves: rulebook-derived content is CC BY-SA 4.0
wherever it appears in this repository, and everything else is MIT. The table
below names the paths that are wholly one or the other, so the boundary stays
checkable — it is illustrative, not an exhaustive enumeration of every file
that carries rulebook text.

| Path | Licence |
|---|---|
| Everything else — e.g. `lib/`, `test/`, `integration_test/`, `tool/`, `scripts/` (Python) | MIT — see `LICENSE` |
| `assets/data/*.json` | CC BY-SA 4.0 — see `LICENSES/CC-BY-SA-4.0.txt` |
| `scripts/spell_import/resolutions.json` | CC BY-SA 4.0 — it quotes design lines |
| `scripts/spell_import/hand_authored_templates.json` | CC BY-SA 4.0 — carries verbatim published spell text |
| `scripts/spell_import/container_modes.json` | CC BY-SA 4.0 — rationales quote rulebook constructions |
| `docs/` | follows the text it quotes |

The catalogs are Adapted Material derived from the Ars Magica Open License
material, © 1993–2024 Trident, Inc. d/b/a Atlas Games®, and carry CC BY-SA 4.0
accordingly. Full attribution, modification notice and disclaimers are in
[NOTICE.md](NOTICE.md). Eruditus is an unofficial, fan-made tool and is not
endorsed by Atlas Games.

## Running

```bash
flutter pub get
flutter run
```

## Tests

Three suites, answering deliberately different questions. Run all three before
merging.

```bash
# Dart — the model, the engine, and the computed level of every published spell
flutter test

# Python — the extractor: parsing the rulebook, resolving guidelines, emitting assets
python -m unittest discover -s scripts/spell_import/tests -t .

# Integration — the app end to end
flutter test integration_test -d windows
```

The Dart half is not optional cover for the Python half: a regression that drops a
spell's selected modifiers passes every Python test, and only the Dart-side
printed-level assertion catches it.

If `flutter test` reports a permissions error on `sqlite3.dll`, the cause is a stale
`flutter_tester` process holding the file. Kill it and re-run.

## The rulebook

The rulebook is **not** vendored here. The extractor reads it from a sibling checkout
of the Ars Magica Open License repository:

```
<parent>/Ars-Magica-Open-License/reviewed/Ars Magica - Definitive Edition (Core Rules).md
```

`reviewed/` is authoritative; `wip/` is only a fallback for books not yet reviewed.
`scripts/spell_import/source.lock` records the exact rulebook revision, and CI clones
that revision so upstream edits can never redden an unrelated PR. A separate weekly
workflow checks the *unpinned* rulebook on purpose — a failure there means upstream
improved and the lock should be bumped.

To rebuild the spell library from the rulebook:

```bash
python -m scripts.spell_import.extract_spells          # report only
python -m scripts.spell_import.extract_spells --write  # rewrite the assets
```

`--write` only succeeds while the rulebook still matches `source.lock`; once upstream
moves, it raises `SourceMoved` and needs `--accept-source` added to knowingly adopt
the new rulebook (this rewrites `source.lock` and the change report too).

## Provenance

The guideline and spell data in `assets/data/` is derived from Ars Magica material
published under the Ars Magica Open License. See the licence in the rulebook
repository for terms.

## Where to look next

- `.superpowers/todo.md` — the item index: numbers, kind and status, mapping
  each item to its home file under `.superpowers/themes/`. Standing
  constraints live in `.superpowers/DECISIONS.md`, closed item bodies in
  `.superpowers/ARCHIVE.md`, and live counts and suite results in
  `.superpowers/STATUS.md`.
- `docs/superpowers/specs/` — the design record. Every non-trivial decision in this
  repo has a spec, and the specs explain *why* far better than the code does.
