import 'dart:convert';

import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/invalid_spell_exception.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/publication_source.dart';
import 'package:eruditus/models/spell.dart';

class BackupImportResult {
  final int spellsImported;
  final int effectsImported;
  final int parametersImported;

  /// Spells the import refused, each carrying its own reasons. A backup should
  /// not lose good rows to one bad one, so these are skipped and reported
  /// rather than aborting the import.
  final List<InvalidSpellException> rejectedSpells;

  BackupImportResult({
    required this.spellsImported,
    required this.effectsImported,
    required this.parametersImported,
    this.rejectedSpells = const [],
  });

  int get spellsRejected => rejectedSpells.length;
}

class BackupService {
  static const String _supportedVersion = '4.0';

  final SpellRepository spellRepository;
  final ConfigurationRepository configRepository;

  BackupService({required this.spellRepository, required this.configRepository});

  Future<String> exportToJson() async {
    final userSpells = await spellRepository.getAllUserSpells();
    final customEffects = (await configRepository.getAllEffects())
        .where((e) => e.provenance.source == PublicationSource.userCreated)
        .toList();
    final customParameters = (await configRepository.getAllParameters())
        .where((p) => p.provenance.source == PublicationSource.userCreated)
        .toList();

    final backup = {
      'version': _supportedVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'spells': userSpells.map((s) => s.record.toMap()).toList(),
      'customEffects': customEffects.map((e) => e.toMap()).toList(),
      'customParameters': customParameters.map((p) => p.toMap()).toList(),
    };

    return jsonEncode(backup);
  }

  Future<BackupImportResult> importFromJson(String jsonString) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonString) as Map<String, dynamic>;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Backup file is not valid JSON: $e');
    }

    final version = data['version'];
    if (version != _supportedVersion) {
      throw FormatException('Unsupported backup version: $version (expected $_supportedVersion)');
    }

    // Custom effects and parameters first: a spell in this backup may be built
    // on one of them, and validating that spell against a catalog that does not
    // yet contain its own effect would refuse it wrongly.
    var effectsImported = 0;
    for (final effectMap in (data['customEffects'] as List? ?? const [])) {
      final effect = BaseEffect.fromMap(effectMap as Map<String, dynamic>);
      await configRepository.deleteCustomEffect(effect.id);
      await configRepository.addCustomEffect(effect);
      effectsImported++;
    }

    var parametersImported = 0;
    for (final parameterMap in (data['customParameters'] as List? ?? const [])) {
      final parameter = Parameter.fromMap(parameterMap as Map<String, dynamic>);
      await configRepository.deleteCustomParameter(parameter.id);
      await configRepository.addCustomParameter(parameter);
      parametersImported++;
    }

    final spells = [
      for (final spellMap in (data['spells'] as List? ?? const []))
        Spell.fromMap(spellMap as Map<String, dynamic>),
    ];
    final rejected = await spellRepository.saveAll(spells);

    return BackupImportResult(
      spellsImported: spells.length - rejected.length,
      effectsImported: effectsImported,
      parametersImported: parametersImported,
      rejectedSpells: rejected,
    );
  }
}
