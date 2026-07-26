import 'dart:convert';

import 'package:eruditus/data/repositories/configuration_repository.dart';
import 'package:eruditus/data/repositories/spell_repository.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';

class BackupImportResult {
  final int spellsImported;
  final int effectsImported;
  final int parametersImported;

  BackupImportResult({
    required this.spellsImported,
    required this.effectsImported,
    required this.parametersImported,
  });
}

class BackupService {
  static const String _supportedVersion = '1.0';

  final SpellRepository spellRepository;
  final ConfigurationRepository configRepository;

  BackupService({required this.spellRepository, required this.configRepository});

  Future<String> exportToJson() async {
    final userSpells = await spellRepository.getAllUserSpells();
    final customEffects =
        (await configRepository.getAllEffects()).where((e) => e.source == 'user-created').toList();
    final customParameters =
        (await configRepository.getAllParameters()).where((p) => p.source == 'user-created').toList();

    final backup = {
      'version': _supportedVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'spells': userSpells.map((s) => s.toMap()).toList(),
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

    var spellsImported = 0;
    for (final spellMap in (data['spells'] as List? ?? const [])) {
      final spell = Spell.fromMap(spellMap as Map<String, dynamic>);
      final existing = await spellRepository.getSpellById(spell.id);
      if (existing != null) {
        await spellRepository.updateSpell(spell);
      } else {
        await spellRepository.saveSpell(spell);
      }
      spellsImported++;
    }

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

    return BackupImportResult(
      spellsImported: spellsImported,
      effectsImported: effectsImported,
      parametersImported: parametersImported,
    );
  }
}
