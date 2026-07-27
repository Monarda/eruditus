import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/resolved_spell.dart';

class LibraryRepository {
  final AssetDataLoader assetLoader;
  final SpellRepository spellRepository;
  final SpellResolver resolver;
  // Optional so unit tests that hand-build a resolver from a fixed, in-memory
  // catalog (disconnected from any real ConfigurationRepository) keep working
  // unchanged. When provided (as it always is from `main.dart` and real
  // integration usage), every `getAllSpells` call refreshes [resolver]'s
  // catalog snapshot from current storage first — see [_refreshResolver].
  final ConfigurationRepository? configRepository;

  List<ResolvedSpell>? _cachedBuiltInSpells;

  LibraryRepository({
    required this.assetLoader,
    required this.spellRepository,
    required this.resolver,
    this.configRepository,
  });

  // The resolver built at app startup holds a snapshot of the catalog at that
  // moment. Custom effects/parameters can be added or deleted afterward (from
  // the Settings tab), and the deletion-invalidates-spells policy requires
  // that a spell referencing a deleted one shows up as unresolved on the very
  // next Library reload — not still resolving against a stale snapshot.
  // Refreshing here, right before every load, is the seam equivalent of how
  // `SpellCreationScreen` keeps `SpellEngine.allModifiers` current via
  // `AvailableModifiersSynced`; the difference is this repository has no
  // widget tree to listen from, so it refreshes itself against the source of
  // truth (`ConfigurationRepository`) instead of reacting to a bloc stream.
  Future<void> _refreshResolver() async {
    final configRepository = this.configRepository;
    if (configRepository == null) return;
    resolver.updateCatalogs(
      effects: await configRepository.getAllEffects(),
      parameters: await configRepository.getAllParameters(),
    );
  }

  Future<List<ResolvedSpell>> getBuiltInSpells() async {
    _cachedBuiltInSpells ??= resolver.resolveAll(await assetLoader.loadSpellLibrary());
    return _cachedBuiltInSpells!;
  }

  Future<List<ResolvedSpell>> getAllSpells() async {
    // Refresh before resolving anything: getBuiltInSpells caches its result
    // permanently on first call, so whatever catalog snapshot the resolver
    // holds at that moment fixes the resolution quality of every built-in
    // spell forever. Refreshing first ensures that first cache-populating
    // resolve already sees the current catalog rather than a stale one.
    await _refreshResolver();
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
