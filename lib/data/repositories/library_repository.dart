import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/models/spell.dart';

class LibraryRepository {
  final AssetDataLoader assetLoader;
  final SpellRepository spellRepository;

  List<Spell>? _cachedBuiltInSpells;

  LibraryRepository({required this.assetLoader, required this.spellRepository});

  Future<List<Spell>> getBuiltInSpells() async {
    _cachedBuiltInSpells ??= await assetLoader.loadSpellLibrary();
    return _cachedBuiltInSpells!;
  }

  Future<List<Spell>> getAllSpells() async {
    final builtIn = await getBuiltInSpells();
    final user = await spellRepository.getAllUserSpells();
    return [...builtIn, ...user];
  }

  Future<List<Spell>> searchSpells(String query) async {
    final all = await getAllSpells();
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all.where((s) => (s.name ?? '').toLowerCase().contains(lowerQuery)).toList();
  }

  Future<List<Spell>> filterBySource(String source) async {
    final all = await getAllSpells();
    return all.where((s) => s.source == source).toList();
  }
}
