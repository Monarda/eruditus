import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/book.dart';
import 'package:eruditus/models/exception_spell.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/spell_template.dart';

/// Loads the shipped JSON catalogs.
///
/// Every parse is memoised. Assets are immutable at runtime, so this needs no
/// invalidation story — the same reason `LibraryRepository.getBuiltInSpells`
/// already caches. Custom entries live in the database and are deliberately
/// **not** cached here; `ConfigurationRepository` reads those fresh on every
/// call, so the built-in half being memoised does not stale anything.
///
/// Without this, `ConfigurationRepository.getAllEffects` re-read and re-parsed
/// all 611 entries of `base_effects.json` from the bundle on every call — once
/// per save via `SpellRepository._refreshResolver`, and once per Library tab
/// visit via `LibraryRepository._refreshResolver`.
///
/// The Future is cached rather than its result, so two concurrent callers share
/// one parse instead of racing into two.
class AssetDataLoader {
  Future<List<BaseEffect>>? _baseEffects;
  Future<List<Parameter>>? _parameters;
  Future<List<Modifier>>? _modifiers;
  Future<List<Spell>>? _spellLibrary;
  Future<List<SpellTemplate>>? _spellTemplates;
  Future<List<ExceptionSpell>>? _spellExceptions;
  Future<List<Book>>? _books;

  Future<List<BaseEffect>> loadBaseEffects() =>
      _baseEffects ??= _load('assets/data/base_effects.json', BaseEffect.fromMap);

  Future<List<Parameter>> loadParameters() =>
      _parameters ??= _load('assets/data/parameters.json', Parameter.fromMap);

  Future<List<Modifier>> loadModifiers() =>
      _modifiers ??= _load('assets/data/modifiers.json', Modifier.fromMap);

  Future<List<Spell>> loadSpellLibrary() =>
      _spellLibrary ??= _load('assets/data/spell_library.json', Spell.fromMap);

  Future<List<SpellTemplate>> loadSpellTemplates() =>
      _spellTemplates ??=
          _load('assets/data/spell_templates.json', SpellTemplate.fromMap);

  Future<List<ExceptionSpell>> loadSpellExceptions() =>
      _spellExceptions ??=
          _load('assets/data/spell_exceptions.json', ExceptionSpell.fromMap);

  Future<List<Book>> loadBooks() =>
      _books ??= _load('assets/data/books.json', Book.fromMap);

  /// Reads one JSON array asset and maps it through [fromMap].
  ///
  /// Returns an unmodifiable list: the result is shared between every caller,
  /// so one caller mutating it would corrupt the others' view.
  Future<List<T>> _load<T>(
    String path,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    final jsonString = await rootBundle.loadString(path);
    final list = jsonDecode(jsonString) as List<dynamic>;
    return List.unmodifiable(
      list.map((e) => fromMap(e as Map<String, dynamic>)),
    );
  }
}
