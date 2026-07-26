import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';

class AssetDataLoader {
  Future<List<BaseEffect>> loadBaseEffects() async {
    final jsonString = await rootBundle.loadString('assets/data/base_effects.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => BaseEffect.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Parameter>> loadParameters() async {
    final jsonString = await rootBundle.loadString('assets/data/parameters.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => Parameter.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Modifier>> loadModifiers() async {
    final jsonString = await rootBundle.loadString('assets/data/modifiers.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => Modifier.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Spell>> loadSpellLibrary() async {
    final jsonString = await rootBundle.loadString('assets/data/spell_library.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => Spell.fromMap(e as Map<String, dynamic>)).toList();
  }
}
