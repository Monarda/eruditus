import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/data/spell_resolver.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/spell.dart';

void main() {
  final effect = BaseEffect(
      id: 'creim-2', technique: 'Creo', form: 'Imaginem',
      description: 'Create an image that affects two senses', baseLevel: 2, source: 'published');
  final voice = Parameter(
      id: 'range-voice', name: 'Voice', category: 'Range', magnitude: 2, source: 'published');
  final momentary = Parameter(
      id: 'duration-momentary', name: 'Momentary', category: 'Duration', magnitude: 0, source: 'published');
  final individual = Parameter(
      id: 'target-individual', name: 'Individual', category: 'Target', magnitude: 0, source: 'published');

  final resolver = SpellResolver(
      effects: [effect], parameters: [voice, momentary, individual]);

  Spell record({String baseEffectId = 'creim-2', String rangeId = 'range-voice'}) => Spell(
        id: 'spell-1',
        name: 'Phantasm',
        baseEffectId: baseEffectId,
        rangeId: rangeId,
        durationId: 'duration-momentary',
        targetId: 'target-individual',
        requisites: const [],
        source: 'published',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('resolve joins a record to its catalog entries', () {
    final resolved = resolver.resolve(record());

    expect(resolved.isResolved, isTrue);
    expect(resolved.baseEffect?.description, 'Create an image that affects two senses');
    expect(resolved.range?.magnitude, 2);
    expect(resolved.technique, 'Creo');
  });

  test('an unknown base effect id resolves to null without throwing', () {
    final resolved = resolver.resolve(record(baseEffectId: 'deleted-custom-effect'));

    expect(resolved.isResolved, isFalse);
    expect(resolved.baseEffect, isNull);
    expect(resolved.unresolvedReferences, ['deleted-custom-effect']);
    // The other three still resolve — one bad id degrades one field.
    expect(resolved.range?.id, 'range-voice');
  });

  test('an unknown parameter id resolves to null without throwing', () {
    final resolved = resolver.resolve(record(rangeId: 'deleted-custom-parameter'));

    expect(resolved.isResolved, isFalse);
    expect(resolved.range, isNull);
    expect(resolved.baseEffect?.id, 'creim-2');
  });

  test('resolveAll resolves each record independently', () {
    final resolved = resolver.resolveAll([record(), record(baseEffectId: 'gone')]);

    expect(resolved.length, 2);
    expect(resolved[0].isResolved, isTrue);
    expect(resolved[1].isResolved, isFalse);
  });

  test('resolveAll on an empty catalog yields unresolved spells rather than throwing', () {
    final empty = SpellResolver(effects: const [], parameters: const []);

    final resolved = empty.resolveAll([record()]);

    expect(resolved.single.isResolved, isFalse);
    expect(resolved.single.unresolvedReferences.length, 4);
  });
}
