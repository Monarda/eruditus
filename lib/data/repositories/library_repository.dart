import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/resolved_spell.dart';

class LibraryRepository {
  final AssetDataLoader assetLoader;
  final SpellRepository spellRepository;
  final SpellResolver resolver;

  List<ResolvedSpell>? _cachedBuiltInSpells;

  LibraryRepository({
    required this.assetLoader,
    required this.spellRepository,
    required this.resolver,
  });

  Future<List<ResolvedSpell>> getBuiltInSpells() async {
    _cachedBuiltInSpells ??= resolver.resolveAll(await assetLoader.loadSpellLibrary());
    return _cachedBuiltInSpells!;
  }

  Future<List<ResolvedSpell>> getAllSpells() async {
    final builtIn = await getBuiltInSpells();
    final user = await spellRepository.getAllUserSpells();
    return [...builtIn, ...user];
  }

  Future<List<ResolvedSpell>> searchSpells(String query) async {
    final all = await getAllSpells();
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all.where((s) => (s.name ?? '').toLowerCase().contains(lowerQuery)).toList();
  }

  Future<List<ResolvedSpell>> filterBySource(String source) async {
    final all = await getAllSpells();
    return all.where((s) => s.source == source).toList();
  }
}
