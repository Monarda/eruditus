import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/resolved_exception.dart';
import 'package:eruditus/models/resolved_spell.dart';
import 'package:eruditus/models/resolved_template.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/spell_template.dart';

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

  // Templates are read-only catalog assets (see SpellTemplate's doc
  // comment): unlike effects/parameters/modifiers, nothing in the Settings
  // tab can add or delete one mid-session, so caching the raw records here
  // is safe -- and avoids re-reading the asset file on every
  // [_refreshResolver] call.
  List<SpellTemplate>? _cachedTemplates;

  LibraryRepository({
    required this.assetLoader,
    required this.spellRepository,
    required this.resolver,
    this.configRepository,
  });

  Future<List<SpellTemplate>> _loadTemplates() async {
    _cachedTemplates ??= await assetLoader.loadSpellTemplates();
    return _cachedTemplates!;
  }

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
    // Templates come from assetLoader, not configRepository, so this half
    // always runs regardless of whether one was supplied -- needed so
    // ResolvedSpell.sourcedSummary/sourcedDescription can tell a
    // template-seeded spell's still-unedited prose from an authored one
    // (see SpellResolver.resolve's `sourceTemplate` and todo item 79.3
    // finding F1).
    resolver.updateTemplates(await _loadTemplates());

    final configRepository = this.configRepository;
    if (configRepository == null) return;
    resolver.updateCatalogs(
      effects: await configRepository.getAllEffects(),
      parameters: await configRepository.getAllParameters(),
      modifiers: await configRepository.getAllModifiers(),
    );
  }

  Future<List<ResolvedSpell>> getBuiltInSpells() async {
    _cachedBuiltInSpells ??= resolver.resolveAll(await assetLoader.loadSpellLibrary());
    return _cachedBuiltInSpells!;
  }

  // No cache here, unlike getBuiltInSpells: _cachedBuiltInSpells caches a
  // *resolution*, computed once because built-in spells don't change during a
  // run. Caching a template resolution the same way would reintroduce the
  // exact staleness _refreshResolver exists to prevent — a template built on
  // a custom effect added (or deleted) mid-session would keep resolving
  // against whatever catalog snapshot happened to exist on the first call.
  Future<List<ResolvedTemplate>> getTemplates() async {
    await _refreshResolver();
    return resolver.resolveAllTemplates(await _loadTemplates());
  }

  Future<List<ResolvedException>> getExceptions() async {
    final exceptions = await assetLoader.loadSpellExceptions();
    return exceptions.map((record) => ResolvedException(record: record)).toList();
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

  Future<List<ResolvedSpell>> filterBySource(PublicationSource source) async {
    final all = await getAllSpells();
    return all.where((s) => s.source == source).toList();
  }
}
