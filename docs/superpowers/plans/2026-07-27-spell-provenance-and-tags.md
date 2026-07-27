# Spell Provenance and Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the data models for future spell-corpus parsing and library browsing — spells gain tags, a summary/description split, and a source enum carrying book citations.

**Architecture:** Three additive model pieces (`Book`, `Citation`, `SpellSource`) land first and independently. A mechanical vocabulary rename (`built-in` → `published`) lands second across 668 asset values. The `Spell` record then flips to the new shape in one pass, because Dart cannot compile a model whose consumers are only half-updated. Citations deliberately stay out of `ResolvedSpell.isResolved`.

**Tech Stack:** Flutter, Dart 3 (enhanced enums), sqflite / sqflite_common_ffi, flutter_bloc, equatable, mocktail, bloc_test.

**Spec:** `docs/superpowers/specs/2026-07-27-spell-provenance-and-tags-design.md`

## Global Constraints

- **Backward compatibility is not a goal**, neither for the API nor for stored data. No compatibility shims, no field read under two names. Stored spells from before this change are destroyed by the migration, not translated.
- **`SpellSource` serializes to exactly `"published"` and `"user-created"`.** These are the same two values the catalog models use and the same values stored in the `spells.source` column. An unrecognised string is a `FormatException`, never a silent default.
- **Citations never affect `ResolvedSpell.isResolved`.** That property means "every input needed to calculate this spell's level is present" — base effect plus three parameters. A dangling `bookId` must never make a spell unavailable, and must never throw.
- **There is no `BookResolver` and no change to `SpellResolver`.** Nothing displays citations until the future browsing UI exists. Correctness is guarded by an asset test instead.
- **Invariant 1 is conditional and interim.** A *published* spell needs a non-empty `summary` or `description`; a *user-created* spell may have neither, because the creation screen collects only a name. Do not add a placeholder summary, and do not add a UI field — both were explicitly rejected. Tracked as todo item 13.
- **`selectedModifiers` keeps its current shape** — `Map<String, List<String>>`. Do not restructure it.
- **The books catalog is seeded with the core rulebook only.** Do not add the other 43 books; nothing cites them yet.
- **No spell parsing, no library browsing UI, no tag UI.** Tags are stored and read by nothing.
- **The suite is 215 unit tests / 0 failures and 4/4 integration tests before this work starts, and must be green at every task boundary.** Mid-task the tree may not compile — that is expected inside Task 3 — but no commit may leave a red suite.
- **`flutter test` does not run `integration_test/`.** That needs `flutter test integration_test/<file> -d windows`.
- **Do not run `flutter analyze` and `flutter test` concurrently** — they contend over `build/`.
- **`python3` is a broken Windows Store alias in this environment; use `python`.**
- **Flutter is not on the default PATH.** Prepend `export PATH="/c/Users/idf53/Development/SDKs/flutter/flutter/bin:$PATH"`.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/models/book.dart` | A rulebook: id, title, abbreviation, edition. |
| `lib/models/citation.dart` | One publication of a spell: `bookId` + optional `page`. |
| `lib/models/spell_source.dart` | The `SpellSource` enum and its wire encoding. Its own file so widgets, blocs and repositories can import it without pulling in `spell.dart`. |
| `assets/data/books.json` | The books catalog. One entry. |
| `test/models/book_test.dart` | `Book` round-trips. |
| `test/models/citation_test.dart` | `Citation` round-trips, including a null page. |
| `test/models/spell_source_test.dart` | Wire encoding both ways, and the unknown-value failure. |
| `test/data/database/app_database_migration_test.dart` | v3 → v4 preserves custom catalogs, drops spells. |

**Modified:** `lib/models/spell.dart`, `lib/models/resolved_spell.dart`, `lib/data/datasources/asset_data_loader.dart`, `lib/data/datasources/local_spell_datasource.dart`, `lib/data/database/app_database.dart`, `lib/bloc/spell_library/spell_library_state.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart`, `lib/data/repositories/library_repository.dart`, `lib/presentation/widgets/spell_card.dart`, `lib/presentation/screens/spell_library_screen.dart`, and the four asset JSON files.

`assets/data/` is globbed as a directory in `pubspec.yaml` (line 71-72), so `books.json` needs **no** pubspec change.

## A note on task sizing

Task 3 is deliberately monolithic. `Spell.source` changes type from `String` to
`SpellSource`, and Dart will not compile a model whose consumers are only
half-updated — there is no staging trick that avoids this, and `@Skip` does not
defer compile errors. Work through the analyzer and commit once, at the end,
green. Tasks 1, 2 and 4 are each independently green and independently
reviewable.

---

### Task 1: `Book`, `Citation` and the books catalog

Purely additive. Nothing existing references these types, so the tree compiles
and the suite stays green at every step.

**Files:**
- Create: `lib/models/book.dart`, `lib/models/citation.dart`, `assets/data/books.json`, `test/models/book_test.dart`, `test/models/citation_test.dart`
- Modify: `lib/data/datasources/asset_data_loader.dart`
- Test: `test/data/datasources/asset_data_loader_test.dart`

**Interfaces:**
- Consumes: `requireField<T>(Map<String, dynamic>, String key, String className)` from `lib/utils/map_serialization.dart`.
- Produces:
  - `Book({required String id, required String title, required String abbreviation, required String edition})` with `toMap()` / `Book.fromMap()`.
  - `Citation({required String bookId, int? page})` with `toMap()` / `Citation.fromMap()` and value equality.
  - `AssetDataLoader.loadBooks() → Future<List<Book>>`.

- [ ] **Step 1: Write the failing `Citation` test**

Create `test/models/citation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/citation.dart';

void main() {
  test('round-trips with a page', () {
    const citation = Citation(bookId: 'arm5-core', page: 142);
    expect(Citation.fromMap(citation.toMap()), citation);
  });

  test('round-trips without a page, and omits the key entirely', () {
    const citation = Citation(bookId: 'arm5-core');
    expect(citation.toMap().containsKey('page'), isFalse,
        reason: 'an absent page should be absent, not an explicit null');
    expect(Citation.fromMap(citation.toMap()), citation);
  });

  test('two citations of the same book and page are equal', () {
    expect(const Citation(bookId: 'arm5-core', page: 142),
        const Citation(bookId: 'arm5-core', page: 142));
  });

  test('the same book on different pages is not equal', () {
    expect(const Citation(bookId: 'arm5-core', page: 142),
        isNot(const Citation(bookId: 'arm5-core', page: 143)));
  });

  test('fromMap throws a descriptive FormatException when bookId is missing', () {
    expect(() => Citation.fromMap(const {'page': 12}),
        throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/models/citation_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'eruditus/models/citation.dart'`.

- [ ] **Step 3: Write `Citation`**

Create `lib/models/citation.dart`:

```dart
import 'package:eruditus/utils/map_serialization.dart';

/// One place a spell was published: a book, and optionally the page.
///
/// [page] is nullable because page numbers are not available yet — they arrive
/// with the spell-parsing work. A citation naming only its book is complete and
/// valid until then.
class Citation {
  final String bookId;
  final int? page;

  const Citation({required this.bookId, this.page});

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        if (page != null) 'page': page,
      };

  factory Citation.fromMap(Map<String, dynamic> map) => Citation(
        bookId: requireField<String>(map, 'bookId', 'Citation'),
        page: map['page'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Citation && other.bookId == bookId && other.page == page);

  @override
  int get hashCode => Object.hash(bookId, page);

  @override
  String toString() => 'Citation($bookId${page == null ? '' : ' p.$page'})';
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/models/citation_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write the failing `Book` test**

Create `test/models/book_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/book.dart';

void main() {
  test('round-trips through toMap/fromMap', () {
    final book = Book(
      id: 'arm5-core',
      title: 'Ars Magica Fifth Edition',
      abbreviation: 'ArM5',
      edition: '5e',
    );
    final restored = Book.fromMap(book.toMap());

    expect(restored.id, book.id);
    expect(restored.title, book.title);
    expect(restored.abbreviation, book.abbreviation);
    expect(restored.edition, book.edition);
  });

  test('fromMap throws a descriptive FormatException when title is missing', () {
    expect(
      () => Book.fromMap(const {'id': 'x', 'abbreviation': 'X', 'edition': '5e'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('books are equal by id', () {
    final a = Book(id: 'arm5-core', title: 'A', abbreviation: 'A', edition: '5e');
    final b = Book(id: 'arm5-core', title: 'B', abbreviation: 'B', edition: '4e');
    expect(a, b);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/models/book_test.dart`
Expected: FAIL — package `eruditus/models/book.dart` cannot be resolved.

- [ ] **Step 7: Write `Book`**

Create `lib/models/book.dart`:

```dart
import 'package:eruditus/utils/map_serialization.dart';

/// A rulebook that spells can be published in.
///
/// The catalog is curated rather than scraped: the sibling
/// `Ars-Magica-Open-License` repo holds 56 files, but those include two OCR
/// passes of the same supplement, one book under two titles, and a file marked
/// "DO NOT USE". Files are not works.
class Book {
  final String id;
  final String title;
  final String abbreviation;
  final String edition;

  Book({
    required this.id,
    required this.title,
    required this.abbreviation,
    required this.edition,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'abbreviation': abbreviation,
        'edition': edition,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: requireField<String>(map, 'id', 'Book'),
        title: requireField<String>(map, 'title', 'Book'),
        abbreviation: requireField<String>(map, 'abbreviation', 'Book'),
        edition: requireField<String>(map, 'edition', 'Book'),
      );

  // Value equality by id, matching BaseEffect and Parameter — reloaded catalogs
  // produce fresh, non-identical instances that must still compare equal.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Book && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test test/models/book_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 9: Create the books catalog**

Create `assets/data/books.json`. Seeded with the core rulebook only — every one
of the 30 existing spells is an ArM5 core spell, and nothing else is cited yet.
The asset test in Task 3 makes a missing book fail loudly, so the future parsing
work will be told exactly which rows to add.

```json
[
  {
    "id": "arm5-core",
    "title": "Ars Magica Fifth Edition",
    "abbreviation": "ArM5",
    "edition": "5e"
  }
]
```

- [ ] **Step 10: Write the failing loader test**

Append to `test/data/datasources/asset_data_loader_test.dart`, and add
`import 'package:eruditus/models/book.dart';` to its imports:

```dart
  test('loadBooks loads the seeded books catalog', () async {
    final books = await loader.loadBooks();

    expect(books, isNotEmpty);
    final core = books.firstWhere((b) => b.id == 'arm5-core');
    expect(core.title, 'Ars Magica Fifth Edition');
    expect(core.abbreviation, 'ArM5');
    expect(core.edition, '5e');
  });

  test('every book id is unique', () async {
    final books = await loader.loadBooks();
    final ids = books.map((b) => b.id).toList();

    expect(ids.length, ids.toSet().length,
        reason: 'duplicate book ids would make citations ambiguous');
  });
```

- [ ] **Step 11: Run it to verify it fails**

Run: `flutter test test/data/datasources/asset_data_loader_test.dart`
Expected: FAIL — `The method 'loadBooks' isn't defined for the class 'AssetDataLoader'`.

- [ ] **Step 12: Add `loadBooks`**

In `lib/data/datasources/asset_data_loader.dart`, add the import
`import 'package:eruditus/models/book.dart';` and this method, following the
shape of the four loaders already there:

```dart
  Future<List<Book>> loadBooks() async {
    final jsonString = await rootBundle.loadString('assets/data/books.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => Book.fromMap(e as Map<String, dynamic>)).toList();
  }
```

- [ ] **Step 13: Run the full suite**

Run: `flutter test`
Expected: `All tests passed!` — 215 previous plus 10 new = 225.

- [ ] **Step 14: Commit**

```bash
git add lib/models/book.dart lib/models/citation.dart assets/data/books.json \
        lib/data/datasources/asset_data_loader.dart \
        test/models/book_test.dart test/models/citation_test.dart \
        test/data/datasources/asset_data_loader_test.dart
git commit -m "feat: add Book and Citation models and the books catalog"
```

---

### Task 2: Rename `built-in` to `published`

Mechanical and string-level. `BaseEffect`, `Parameter` and `Modifier` keep a
plain `String source`; only its value changes. `Spell.source` is still a
`String` at this point — it becomes an enum in Task 3.

**No database migration is needed.** Every custom row in the database is
`user-created`, which is unchanged, and built-in catalog data lives only in
assets.

**Files:**
- Modify: `assets/data/base_effects.json`, `assets/data/parameters.json`, `assets/data/modifiers.json`, `assets/data/spell_library.json`, `lib/bloc/spell_library/spell_library_state.dart:30-31`, `lib/presentation/widgets/spell_card.dart:54`, `lib/presentation/screens/spell_library_screen.dart:51`
- Test: every file under `test/` and `integration_test/` that asserts the literal `'built-in'`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: the string `'published'` wherever `'built-in'` previously appeared. Task 3 relies on this already being done.

- [ ] **Step 1: Rewrite the asset values**

Run this from the repo root. It uses a regex rather than a JSON round-trip
deliberately: re-serializing `base_effects.json` (604 entries) would reformat
the whole file and bury the real change in a diff of thousands of lines.

```bash
python - <<'PY'
import re, pathlib
total = 0
for name in ['base_effects', 'parameters', 'modifiers', 'spell_library']:
    p = pathlib.Path(f'assets/data/{name}.json')
    text = p.read_text(encoding='utf-8')
    new, n = re.subn(r'("source"\s*:\s*)"built-in"', r'\1"published"', text)
    p.write_text(new, encoding='utf-8')
    print(f'{name}.json: {n}')
    total += n
print('total:', total)
PY
```

Expected output:

```
base_effects.json: 604
parameters.json: 17
modifiers.json: 17
spell_library.json: 30
total: 668
```

- [ ] **Step 2: Verify no `built-in` survives in the assets**

Run: `grep -rc '"built-in"' assets/data/ || echo "none remaining"`
Expected: `none remaining` (grep exits non-zero when it matches nothing).

- [ ] **Step 3: Run the suite to see what the rename broke**

Run: `flutter test`
Expected: FAIL. Assertions comparing against `'built-in'` now see `'published'`.
This is the working list for Steps 4-6.

- [ ] **Step 4: Update the library filter**

In `lib/bloc/spell_library/spell_library_state.dart`, replace the `visibleSpells`
source comparisons (lines 30-33). The filter *label* changes too — a chip
reading "Built-in" that selects spells badged "Published" would be incoherent:

```dart
  List<ResolvedSpell> get visibleSpells {
    var result = allSpells;
    if (filter == 'Published') {
      result = result.where((s) => s.source == 'published').toList();
    } else if (filter == 'My Spells') {
      result = result.where((s) => s.source == 'user-created').toList();
    }
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      result = result.where((s) => (s.name ?? '').toLowerCase().contains(lowerQuery)).toList();
    }
    return result;
  }
```

- [ ] **Step 5: Update the filter chip labels**

In `lib/presentation/screens/spell_library_screen.dart` line 51, change the
label list:

```dart
                  children: ['All', 'Published', 'My Spells'].map((filter) {
```

- [ ] **Step 6: Update the card badge**

In `lib/presentation/widgets/spell_card.dart` line 54:

```dart
        trailing: Chip(label: Text(spell.source == 'published' ? 'Published' : 'My Spell')),
```

- [ ] **Step 7: Update the test assertions**

Replace the literal `'built-in'` with `'published'` throughout `test/` and
`integration_test/`, and the UI label `'Built-in'` with `'Published'` where a
test taps or finds the filter chip. Run this, then read the diff before
trusting it:

```bash
python - <<'PY'
import pathlib
n = 0
for p in list(pathlib.Path('test').rglob('*.dart')) + list(pathlib.Path('integration_test').rglob('*.dart')):
    text = p.read_text(encoding='utf-8')
    new = text.replace("'built-in'", "'published'").replace("'Built-in'", "'Published'")
    if new != text:
        p.write_text(new, encoding='utf-8')
        print(p)
        n += 1
print('files changed:', n)
PY
```

Then check nothing was missed, including double-quoted spellings:

```bash
grep -rn "built-in\|Built-in" test/ integration_test/ || echo "none remaining"
```

Expected: `none remaining`. If anything is listed, fix it by hand.

- [ ] **Step 8: Run the unit suite**

Run: `flutter test`
Expected: `All tests passed!` — 225 tests.

- [ ] **Step 9: Run the integration suite**

This task changes the library screen's widget tree, so `flutter test` alone does
not verify it.

Run: `flutter test integration_test/spell_creation_flow_test.dart -d windows`
Expected: `All tests passed!` — 4 tests.

- [ ] **Step 10: Commit**

```bash
git add assets lib test integration_test
git commit -m "refactor: rename the built-in source value to published"
```

---

### Task 3: Flip `Spell` to the new shape

**This task does not compile between Steps 1 and 12.** That is expected and
unavoidable — see "A note on task sizing". Work through the analyzer and commit
only at Step 15, green.

**Files:**
- Create: `lib/models/spell_source.dart`, `test/models/spell_source_test.dart`
- Modify: `lib/models/spell.dart`, `lib/models/resolved_spell.dart`, `lib/data/datasources/local_spell_datasource.dart:42`, `lib/data/database/app_database.dart:6`, `lib/bloc/spell_library/spell_library_state.dart`, `lib/bloc/spell_creation/spell_creation_bloc.dart:191`, `lib/data/repositories/library_repository.dart:70-73`, `lib/presentation/widgets/spell_card.dart`, `assets/data/spell_library.json`
- Test: `test/models/spell_test.dart`, `test/data/datasources/asset_data_loader_test.dart`, and every fixture that constructs a `Spell`

**Interfaces:**
- Consumes: `Citation` and `Book` from Task 1; the `'published'` value from Task 2.
- Produces:
  - `enum SpellSource { userCreated, published }` with `String get wireValue` and `static SpellSource fromWire(String)`.
  - `Spell({required String id, String? name, required String baseEffectId, required String rangeId, required String durationId, required String targetId, Map<String, List<String>> selectedModifiers = const {}, required List<Requisite> requisites, String? summary, String? description, required SpellSource source, List<Citation> citations = const [], List<String> tags = const [], required DateTime createdAt, required DateTime updatedAt})`.
  - `List<String> validateSpellFields({required SpellSource source, required String? summary, required String? description, required List<Citation> citations})` — returns human-readable problems, empty when valid.
  - `SpellDraft.toSpell({required String name, required SpellSource source})`.
  - `ResolvedSpell` gains `String? get summary`, `List<Citation> get citations`, `List<String> get tags`; its `source` getter now returns `SpellSource`.
  - `LibraryRepository.filterBySource(SpellSource source)`.

- [ ] **Step 1: Write the failing `SpellSource` test**

Create `test/models/spell_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/spell_source.dart';

void main() {
  test('wire values are exactly the two strings used in storage and assets', () {
    expect(SpellSource.published.wireValue, 'published');
    expect(SpellSource.userCreated.wireValue, 'user-created');
  });

  test('fromWire round-trips every value', () {
    for (final source in SpellSource.values) {
      expect(SpellSource.fromWire(source.wireValue), source);
    }
  });

  test('an unrecognised value throws rather than defaulting silently', () {
    expect(() => SpellSource.fromWire('built-in'),
        throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 2: Write `SpellSource`**

Create `lib/models/spell_source.dart`:

```dart
/// Where a spell came from.
///
/// This lives in its own file so widgets, blocs and repositories can import it
/// without pulling in the whole `spell.dart` model graph.
///
/// The wire values match the plain `source` string that [BaseEffect],
/// [Parameter] and [Modifier] still use, so one word means one thing across the
/// codebase. Those catalogs carry no citations — only spells record where they
/// were published.
enum SpellSource {
  userCreated('user-created'),
  published('published');

  const SpellSource(this.wireValue);

  final String wireValue;

  static SpellSource fromWire(String value) => switch (value) {
        'user-created' => SpellSource.userCreated,
        'published' => SpellSource.published,
        _ => throw FormatException('Unknown SpellSource: "$value"'),
      };
}
```

- [ ] **Step 3: Rewrite `Spell`**

In `lib/models/spell.dart`, add the imports:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/spell_source.dart';
```

Then replace the `Spell` class entirely:

```dart
/// The rules every spell record must satisfy, stated once and shared by
/// [Spell.fromMap] and [SpellDraft.toSpell] so the two paths cannot drift.
///
/// Returns a list of human-readable problems; empty means valid.
///
/// The summary-or-description rule applies to published spells only. This is
/// interim: user-created spells should carry prose too, but the creation screen
/// collects nothing but a name, so an unconditional rule would reject every
/// user-created spell on save. Tighten this when that UI lands — todo item 13.
List<String> validateSpellFields({
  required SpellSource source,
  required String? summary,
  required String? description,
  required List<Citation> citations,
}) {
  final problems = <String>[];
  final hasProse = (summary != null && summary.isNotEmpty) ||
      (description != null && description.isNotEmpty);

  if (source == SpellSource.published) {
    if (!hasProse) {
      problems.add('a published spell needs a summary or a description');
    }
    if (citations.isEmpty) {
      problems.add('a published spell needs at least one citation');
    }
  } else if (citations.isNotEmpty) {
    problems.add('a user-created spell cannot have citations');
  }

  return problems;
}

/// A saved spell, stored as references into the effect/parameter catalogs.
///
/// This record deliberately holds no copy of any catalog data — no base level,
/// magnitude, technique or form. Those are looked up through [SpellResolver] on
/// read, so there is exactly one source of truth.
///
/// [summary] is a short paraphrase; [description] is verbatim text from the
/// rulebook. Both are optional individually, and a published spell needs at
/// least one of them.
class Spell {
  final String id;
  final String? name;
  final String baseEffectId;
  final String rangeId;
  final String durationId;
  final String targetId;
  final Map<String, List<String>> selectedModifiers;
  final List<Requisite> requisites;
  final String? summary;
  final String? description;
  final SpellSource source;
  final List<Citation> citations;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Spell({
    required this.id,
    this.name,
    required this.baseEffectId,
    required this.rangeId,
    required this.durationId,
    required this.targetId,
    this.selectedModifiers = const {},
    required this.requisites,
    this.summary,
    this.description,
    required this.source,
    this.citations = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'baseEffectId': baseEffectId,
        'rangeId': rangeId,
        'durationId': durationId,
        'targetId': targetId,
        'selectedModifiers': selectedModifiers,
        'requisites': requisites.map((r) => r.toMap()).toList(),
        'summary': summary,
        'description': description,
        'source': source.wireValue,
        'citations': citations.map((c) => c.toMap()).toList(),
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Spell.fromMap(Map<String, dynamic> map) {
    final source = SpellSource.fromWire(requireField<String>(map, 'source', 'Spell'));
    final summary = map['summary'] as String?;
    final description = map['description'] as String?;
    final citations = (map['citations'] as List?)
            ?.map((c) => Citation.fromMap(c as Map<String, dynamic>))
            .toList() ??
        const <Citation>[];

    final problems = validateSpellFields(
      source: source,
      summary: summary,
      description: description,
      citations: citations,
    );
    if (problems.isNotEmpty) {
      throw FormatException('Spell.fromMap: ${problems.join('; ')}');
    }

    return Spell(
      id: requireField<String>(map, 'id', 'Spell'),
      name: map['name'] as String?,
      baseEffectId: requireField<String>(map, 'baseEffectId', 'Spell'),
      rangeId: requireField<String>(map, 'rangeId', 'Spell'),
      durationId: requireField<String>(map, 'durationId', 'Spell'),
      targetId: requireField<String>(map, 'targetId', 'Spell'),
      selectedModifiers: (map['selectedModifiers'] as Map?)?.map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List)),
          ) ??
          const {},
      requisites: (map['requisites'] as List?)
              ?.map((r) => Requisite.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
      summary: summary,
      description: description,
      source: source,
      citations: citations,
      tags: (map['tags'] as List?)?.map((t) => t as String).toList() ?? const [],
      createdAt: DateTime.parse(requireField<String>(map, 'createdAt', 'Spell')),
      updatedAt: DateTime.parse(requireField<String>(map, 'updatedAt', 'Spell')),
    );
  }
}
```

- [ ] **Step 4: Update `SpellDraft`**

In the same file, add a `summary` field and change `toSpell`'s signature. The
draft carries `summary` and `description` even though nothing writes them today,
so the deferred UI work adds only an input widget and an event — never another
model change.

Add the field beside `description`:

```dart
  String? summary;
  String? description;
```

Add `this.summary,` to the constructor parameter list, immediately before
`this.description,`. Then replace `toSpell`:

```dart
  Spell toSpell({required String name, required SpellSource source}) {
    final missingFields = <String>[
      if (baseEffect == null) 'baseEffect',
      if (range == null) 'range',
      if (duration == null) 'duration',
      if (target == null) 'target',
    ];
    if (missingFields.isNotEmpty) {
      throw StateError(
        'Cannot convert SpellDraft to Spell: ${missingFields.join(', ')} '
        '${missingFields.length == 1 ? 'is' : 'are'} not set',
      );
    }

    final problems = validateSpellFields(
      source: source,
      summary: summary,
      description: description,
      citations: const [],
    );
    if (problems.isNotEmpty) {
      throw StateError('Cannot convert SpellDraft to Spell: ${problems.join('; ')}');
    }

    return Spell(
      id: id,
      name: name,
      baseEffectId: baseEffect!.id,
      rangeId: range!.id,
      durationId: duration!.id,
      targetId: target!.id,
      selectedModifiers: selectedModifiers,
      requisites: requisites,
      summary: summary,
      description: description,
      source: source,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
```

Finally add `summary` to `copyWith` — a `String? summary,` parameter, and
`summary: summary ?? this.summary,` in the returned `SpellDraft`, both placed
immediately before the existing `description` handling.

- [ ] **Step 5: Update `ResolvedSpell`**

In `lib/models/resolved_spell.dart`, add the imports:

```dart
import 'package:eruditus/models/citation.dart';
import 'package:eruditus/models/spell_source.dart';
```

Replace the delegating getter block (lines 44-51). Note `isResolved` and
`unresolvedReferences` are **unchanged** — citations play no part in them:

```dart
  String get id => record.id;
  String? get name => record.name;
  String? get summary => record.summary;
  String? get description => record.description;
  SpellSource get source => record.source;
  List<Citation> get citations => record.citations;
  List<String> get tags => record.tags;
  DateTime get createdAt => record.createdAt;
  DateTime get updatedAt => record.updatedAt;
  Map<String, List<String>> get selectedModifiers => record.selectedModifiers;
  List<Requisite> get requisites => record.requisites;
```

- [ ] **Step 6: Update the datasource row mapping**

In `lib/data/datasources/local_spell_datasource.dart` line 42, the `source`
column must hold the wire string, not the enum:

```dart
        'source': spell.source.wireValue,
```

- [ ] **Step 7: Bump the schema version**

In `lib/data/database/app_database.dart` line 6:

```dart
  static const int _databaseVersion = 4;
```

Change nothing else in this file. The `onUpgrade` narrowing already drops only
`spells` and the dead `custom_factors`, preserving the user's custom effects,
parameters and modifiers — which is exactly right here, since `spells` is the
only table whose shape changes.

- [ ] **Step 8: Update the library filter and repository**

In `lib/bloc/spell_library/spell_library_state.dart`, add
`import 'package:eruditus/models/spell_source.dart';` and change the two
comparisons to use the enum:

```dart
    if (filter == 'Published') {
      result = result.where((s) => s.source == SpellSource.published).toList();
    } else if (filter == 'My Spells') {
      result = result.where((s) => s.source == SpellSource.userCreated).toList();
    }
```

In `lib/data/repositories/library_repository.dart`, add the same import and
change `filterBySource` (lines 70-73):

```dart
  Future<List<ResolvedSpell>> filterBySource(SpellSource source) async {
    final all = await getAllSpells();
    return all.where((s) => s.source == source).toList();
  }
```

- [ ] **Step 9: Update the creation bloc**

In `lib/bloc/spell_creation/spell_creation_bloc.dart` line 191, add
`import 'package:eruditus/models/spell_source.dart';` and pass the enum:

```dart
      final spell = state.draft.toSpell(name: event.name, source: SpellSource.userCreated);
```

- [ ] **Step 10: Update `SpellCard`**

In `lib/presentation/widgets/spell_card.dart`, add
`import 'package:eruditus/models/spell_source.dart';`. The blurb must now prefer
the summary, since that is where the built-in spells' prose lives after
migration. Replace lines 34-35:

```dart
    // Prefer the paraphrase; fall back to the verbatim rulebook text. A
    // published spell always has at least one of them; a user-created spell may
    // have neither, in which case the blurb is simply omitted.
    final blurb = spell.summary ?? spell.description;
    final hasBlurb = blurb != null && blurb.isNotEmpty;
```

Replace the `if (hasDescription)` line inside the subtitle `Column`:

```dart
            if (hasBlurb)
              Text(blurb, maxLines: 2, overflow: TextOverflow.ellipsis),
```

And replace the badge on line 54:

```dart
        trailing: Chip(
            label: Text(
                spell.source == SpellSource.published ? 'Published' : 'My Spell')),
```

- [ ] **Step 11: Migrate the built-in spell library**

Every one of the 30 spells is an ArM5 core spell whose existing `description` is
a hand-written paraphrase ending "Level N.", not verbatim rulebook text — so it
becomes the `summary`, and `description` is left absent until the parsing work
supplies real book text.

```bash
python - <<'PY'
import json, pathlib
p = pathlib.Path('assets/data/spell_library.json')
spells = json.loads(p.read_text(encoding='utf-8'))
for s in spells:
    s['summary'] = s.pop('description')
    s['citations'] = [{'bookId': 'arm5-core'}]
    assert s['source'] == 'published', f"{s['id']} is {s['source']}, expected published"
p.write_text(json.dumps(spells, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print('migrated', len(spells), 'spells')
PY
```

Expected output: `migrated 30 spells`. If the assertion fires, Task 2 Step 1 did
not run — fix that first rather than loosening this script.

- [ ] **Step 12: Update the asset loader test**

In `test/data/datasources/asset_data_loader_test.dart`, the level-verification
test parses "Level N." out of the spell's prose. That text now lives in
`summary`. Change the regex source inside `levelStatedInDescription`:

```dart
      final match = RegExp(r'Level (\d+)\.').firstMatch(spell.summary ?? '');
      expect(match, isNotNull,
          reason: '${spell.name}: summary does not contain a "Level N." phrase '
              '(summary was: "${spell.summary}")');
```

Then add the citation guard — the reason there is no `BookResolver`. Add
`import 'package:eruditus/models/spell_source.dart';` and this test:

```dart
  test("every spell's cited book ids exist in the books catalog", () async {
    final spells = await loader.loadSpellLibrary();
    final books = await loader.loadBooks();
    final bookIds = books.map((b) => b.id).toSet();

    for (final spell in spells) {
      expect(spell.source, SpellSource.published,
          reason: '${spell.name}: every library spell should be published');
      expect(spell.citations, isNotEmpty,
          reason: '${spell.name}: a published spell needs at least one citation');
      for (final citation in spell.citations) {
        expect(bookIds.contains(citation.bookId), isTrue,
            reason: '${spell.name}: cited book ${citation.bookId} is not in '
                'books.json — add the book, do not relax this check');
      }
    }
  });
```

- [ ] **Step 13: Add the invariant tests**

Append to `test/models/spell_test.dart`, adding the imports
`package:eruditus/models/citation.dart` and
`package:eruditus/models/spell_source.dart`:

```dart
  group('spell field invariants', () {
    Map<String, dynamic> baseMap() => {
          'id': 'x',
          'name': 'X',
          'baseEffectId': 'e1',
          'rangeId': 'p1',
          'durationId': 'p2',
          'targetId': 'p3',
          'requisites': <dynamic>[],
          'source': 'published',
          'summary': 'A summary.',
          'citations': [
            {'bookId': 'arm5-core'}
          ],
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-01T00:00:00.000',
        };

    test('a published spell with only a summary is valid', () {
      expect(Spell.fromMap(baseMap()).summary, 'A summary.');
    });

    test('a published spell with only a description is valid', () {
      final map = baseMap()
        ..remove('summary')
        ..['description'] = 'Verbatim rulebook text.';
      expect(Spell.fromMap(map).description, 'Verbatim rulebook text.');
    });

    test('a published spell with neither summary nor description is rejected', () {
      final map = baseMap()..remove('summary');
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });

    test('a published spell with no citations is rejected', () {
      final map = baseMap()..['citations'] = <dynamic>[];
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });

    test('a user-created spell with neither summary nor description is valid', () {
      // Interim: the creation screen collects only a name. See todo item 13.
      final map = baseMap()
        ..remove('summary')
        ..['source'] = 'user-created'
        ..['citations'] = <dynamic>[];
      expect(Spell.fromMap(map).source, SpellSource.userCreated);
    });

    test('a user-created spell carrying citations is rejected', () {
      final map = baseMap()..['source'] = 'user-created';
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });

    test('an unknown source value is rejected rather than defaulted', () {
      final map = baseMap()..['source'] = 'built-in';
      expect(() => Spell.fromMap(map), throwsA(isA<FormatException>()));
    });

    test('a spell published twice round-trips with both citations', () {
      final map = baseMap()
        ..['citations'] = [
          {'bookId': 'arm5-core', 'page': 142},
          {'bookId': 'arm5-core'},
        ];
      final restored = Spell.fromMap(Spell.fromMap(map).toMap());

      expect(restored.citations, [
        const Citation(bookId: 'arm5-core', page: 142),
        const Citation(bookId: 'arm5-core'),
      ]);
    });

    test('tags round-trip and default to empty', () {
      expect(Spell.fromMap(baseMap()).tags, isEmpty);

      final tagged = baseMap()..['tags'] = ['architecture', 'defensive'];
      expect(Spell.fromMap(tagged).tags, ['architecture', 'defensive']);
    });
  });
```

- [ ] **Step 14: Fix every remaining fixture and run the suite**

Run `flutter analyze` and work through the errors. Exactly 14 files construct a
`Spell` and will need attention:

```
integration_test/spell_creation_flow_test.dart
test/bloc/spell_creation_bloc_test.dart
test/bloc/spell_library_bloc_test.dart
test/data/datasources/local_spell_datasource_test.dart
test/data/repositories/library_repository_test.dart
test/data/repositories/spell_repository_test.dart
test/data/services/backup_service_test.dart
test/data/spell_resolver_test.dart
test/engine/spell_engine_test.dart
test/models/resolved_spell_test.dart
test/models/spell_test.dart
test/presentation/screens/spell_creation_screen_test.dart
test/presentation/screens/spell_library_screen_test.dart
test/presentation/widgets/spell_card_test.dart
```

In each, three changes:

1. `source:` takes `SpellSource.published` or `SpellSource.userCreated` instead
   of a string, and the file needs
   `import 'package:eruditus/models/spell_source.dart';`.
2. Any fixture using `SpellSource.published` also needs a `citations:` entry and
   a non-empty `summary:` or `description:`, or `Spell.fromMap`/the constructor
   path will reject it. The quickest fix for most fixtures is to make them
   `SpellSource.userCreated` with no citations — only use `published` where the
   test is actually about published spells.
3. Assertions reading `.description` on a built-in fixture should read
   `.summary`, since that is where the prose moved.

`test/presentation/widgets/spell_card_test.dart` also asserts on the badge text
and the blurb; both changed in Step 10.

Then run the unit suite, and the integration suite separately — this task
changes the widget tree, the schema and the repositories:

```bash
flutter test
flutter test integration_test/spell_creation_flow_test.dart -d windows
```

Expected: `All tests passed!` from both — 238 unit tests (225 after Task 1, plus
3 `SpellSource` tests, 9 invariant tests and 1 citation asset test) and 4
integration tests. Do not commit until both are green.

- [ ] **Step 15: Commit**

```bash
git add lib test integration_test assets
git commit -m "feat: split spell prose, add tags, and record publication sources"
```

---

### Task 4: Cover the v4 migration

The `onUpgrade` narrowing was fixed once already without a regression test. This
adds one, now that a second version bump exercises it for real.

**Files:**
- Create: `test/data/database/app_database_migration_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.open({String? path})` and the v4 schema from Task 3.

- [ ] **Step 1: Write the failing test**

Create `test/data/database/app_database_migration_test.dart`. It opens a v3
database by hand, writes one row into each table, then reopens through
`AppDatabase.open` to trigger the upgrade:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eruditus/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('upgrading to v4 drops spells but preserves the custom catalogs', () async {
    // A v3 database, built by hand: spells still carries the pre-v4 shape, and
    // each custom catalog holds one row that must survive the upgrade.
    final path = inMemoryDatabasePath;
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE spells (
              id TEXT PRIMARY KEY, name TEXT, source TEXT NOT NULL,
              data TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE custom_effects (
              id TEXT PRIMARY KEY, technique TEXT NOT NULL, form TEXT NOT NULL,
              data TEXT NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE custom_parameters (
              id TEXT PRIMARY KEY, category TEXT NOT NULL, data TEXT NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE custom_modifiers (id TEXT PRIMARY KEY, data TEXT NOT NULL)
          ''');
        },
      ),
    );
    await old.insert('spells', {
      'id': 'old-spell', 'name': 'Old', 'source': 'built-in',
      'data': '{}', 'created_at': 'x', 'updated_at': 'x',
    });
    await old.insert('custom_effects', {
      'id': 'keep-effect', 'technique': 'Creo', 'form': 'Ignem', 'data': '{}',
    });
    await old.insert('custom_parameters', {
      'id': 'keep-parameter', 'category': 'Range', 'data': '{}',
    });
    await old.insert('custom_modifiers', {'id': 'keep-modifier', 'data': '{}'});
    await old.close();

    final upgraded = await AppDatabase.open(path: path);

    // The user's authored catalog survives — only the spells table changed shape.
    expect(await upgraded.db.query('custom_effects'), hasLength(1));
    expect(await upgraded.db.query('custom_parameters'), hasLength(1));
    expect(await upgraded.db.query('custom_modifiers'), hasLength(1));

    // Stored spells are destroyed rather than translated, by design.
    expect(await upgraded.db.query('spells'), isEmpty);

    await upgraded.close();
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/data/database/app_database_migration_test.dart`
Expected: PASS. The behaviour already exists; this test pins it down.

If it fails on the custom-catalog assertions, `onUpgrade` is dropping more than
it should — fix `app_database.dart` so it drops only `spells` and
`custom_factors`, rather than weakening the test.

- [ ] **Step 3: Run the full suite**

Run: `flutter test`
Expected: `All tests passed!` — 239 tests.

- [ ] **Step 4: Commit**

```bash
git add test/data/database/app_database_migration_test.dart
git commit -m "test: pin the v4 migration's blast radius"
```

---

## Notes for the executor

- **Every commit must leave `flutter test` green.** Task 3 will not compile between its Steps 1 and 12; that is expected, and it commits once at Step 15.
- **`flutter test` never runs `integration_test/`.** Re-run it explicitly after Tasks 2 and 3, both of which touch the widget tree.
- **Do not run `flutter analyze` and `flutter test` concurrently** — they contend over `build/` and produce a spurious `sqlite3.dll` lock error.
- **If a `flutter test` run fails with a `sqlite3.dll` lock**, an orphaned `flutter_tester.exe` is holding it. Kill it and re-run.
- **`python3` is a broken Windows Store alias here; use `python`.**
- **Do not add a placeholder summary for user-created spells,** and do not add a summary input to the creation screen. Both were considered and explicitly rejected; the conditional invariant is deliberate and tracked as todo item 13.
- **Do not relax the citation asset test to accommodate a missing book.** If it reports an unknown `bookId`, add the book to `books.json`.
- **Do not thread books through `SpellResolver`.** A missing book must never make a spell unavailable.
