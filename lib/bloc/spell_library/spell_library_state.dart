import 'package:equatable/equatable.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/publication_source.dart';

enum SpellLibraryStatus { loading, loaded, error }

class SpellLibraryState extends Equatable {
  final SpellLibraryStatus status;
  final List<ResolvedSpell> allSpells;
  final String query;
  final String filter;
  // Precomputed spell levels keyed by spell id (via SpellEngine.
  // calculateSpellLevel), so cards can display "name, level, source,
  // description" without recomputing/duplicating the level math.
  final Map<String, int> spellLevels;
  // Ids of the spells that are Rituals. Precomputed alongside [spellLevels]
  // for the same reason: the card has no SpellEngine to derive it with.
  final Set<String> ritualSpellIds;
  final String? errorMessage;

  const SpellLibraryState({
    required this.status,
    this.allSpells = const [],
    this.query = '',
    this.filter = 'All',
    this.spellLevels = const {},
    this.ritualSpellIds = const {},
    this.errorMessage,
  });

  factory SpellLibraryState.initial() => const SpellLibraryState(status: SpellLibraryStatus.loading);

  List<ResolvedSpell> get visibleSpells {
    var result = allSpells;
    if (filter == 'Published') {
      result = result.where((s) => s.source == PublicationSource.published).toList();
    } else if (filter == 'My Spells') {
      result = result.where((s) => s.source == PublicationSource.userCreated).toList();
    }
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      result = result.where((s) => (s.name ?? '').toLowerCase().contains(lowerQuery)).toList();
    }
    return result;
  }

  SpellLibraryState copyWith({
    SpellLibraryStatus? status,
    List<ResolvedSpell>? allSpells,
    String? query,
    String? filter,
    Map<String, int>? spellLevels,
    Set<String>? ritualSpellIds,
    String? errorMessage,
  }) {
    return SpellLibraryState(
      status: status ?? this.status,
      allSpells: allSpells ?? this.allSpells,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      spellLevels: spellLevels ?? this.spellLevels,
      ritualSpellIds: ritualSpellIds ?? this.ritualSpellIds,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, allSpells, query, filter, spellLevels, ritualSpellIds, errorMessage];
}
