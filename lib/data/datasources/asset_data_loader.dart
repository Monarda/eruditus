import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';
import 'package:eruditus/models/special_factor.dart';

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

  Future<List<SpecialFactor>> loadSpecialFactors() async {
    final jsonString = await rootBundle.loadString('assets/data/special_factors.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => SpecialFactor.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Spell>> loadSpellLibrary() async {
    final jsonString = await rootBundle.loadString('assets/data/spell_library.json');
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((e) => Spell.fromMap(e as Map<String, dynamic>)).toList();
  }
}
