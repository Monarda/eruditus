import 'package:equatable/equatable.dart';
import 'package:eruditus/models/spell.dart';

enum SpellLibraryStatus { loading, loaded, error }

class SpellLibraryState extends Equatable {
  final SpellLibraryStatus status;
  final List<Spell> allSpells;
  final String query;
  final String filter;
  // Precomputed spell levels keyed by spell id (via SpellEngine.
  // calculateSpellLevel), so cards can display "name, level, source,
  // description" without recomputing/duplicating the level math.
  final Map<String, int> spellLevels;
  final String? errorMessage;

  const SpellLibraryState({
    required this.status,
    this.allSpells = const [],
    this.query = '',
    this.filter = 'All',
    this.spellLevels = const {},
    this.errorMessage,
  });

  factory SpellLibraryState.initial() => const SpellLibraryState(status: SpellLibraryStatus.loading);

  List<Spell> get visibleSpells {
    var result = allSpells;
    if (filter == 'Built-in') {
      result = result.where((s) => s.source == 'built-in').toList();
    } else if (filter == 'My Spells') {
      result = result.where((s) => s.source == 'user-created').toList();
    }
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      result = result.where((s) => (s.name ?? '').toLowerCase().contains(lowerQuery)).toList();
    }
    return result;
  }

  SpellLibraryState copyWith({
    SpellLibraryStatus? status,
    List<Spell>? allSpells,
    String? query,
    String? filter,
    Map<String, int>? spellLevels,
    String? errorMessage,
  }) {
    return SpellLibraryState(
      status: status ?? this.status,
      allSpells: allSpells ?? this.allSpells,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      spellLevels: spellLevels ?? this.spellLevels,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, allSpells, query, filter, spellLevels, errorMessage];
}
