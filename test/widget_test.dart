import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:eruditus/bloc/configuration/configuration_bloc.dart';
import 'package:eruditus/bloc/configuration/configuration_event.dart';
import 'package:eruditus/bloc/configuration/configuration_state.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_bloc.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_event.dart';
import 'package:eruditus/bloc/spell_creation/spell_creation_state.dart';
import 'package:eruditus/bloc/spell_library/spell_library_bloc.dart';
import 'package:eruditus/bloc/spell_library/spell_library_event.dart';
import 'package:eruditus/bloc/spell_library/spell_library_state.dart';
import 'package:eruditus/main.dart';

class MockSpellCreationBloc extends MockBloc<SpellCreationEvent, SpellCreationState>
    implements SpellCreationBloc {}

class MockSpellLibraryBloc extends MockBloc<SpellLibraryEvent, SpellLibraryState>
    implements SpellLibraryBloc {}

class MockConfigurationBloc extends MockBloc<ConfigurationEvent, ConfigurationState>
    implements ConfigurationBloc {}

class FakeSpellCreationEvent extends Fake implements SpellCreationEvent {}
class FakeSpellCreationState extends Fake implements SpellCreationState {}
class FakeSpellLibraryEvent extends Fake implements SpellLibraryEvent {}
class FakeSpellLibraryState extends Fake implements SpellLibraryState {}
class FakeConfigurationEvent extends Fake implements ConfigurationEvent {}
class FakeConfigurationState extends Fake implements ConfigurationState {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSpellCreationEvent());
    registerFallbackValue(FakeSpellCreationState());
    registerFallbackValue(FakeSpellLibraryEvent());
    registerFallbackValue(FakeSpellLibraryState());
    registerFallbackValue(FakeConfigurationEvent());
    registerFallbackValue(FakeConfigurationState());
  });

  testWidgets('EruditusApp launches showing the Create tab and bottom navigation', (tester) async {
    final spellCreationBloc = MockSpellCreationBloc();
    final spellLibraryBloc = MockSpellLibraryBloc();
    final configurationBloc = MockConfigurationBloc();

    whenListen(spellCreationBloc, const Stream<SpellCreationState>.empty(),
        initialState: SpellCreationState.initial());
    whenListen(spellLibraryBloc, const Stream<SpellLibraryState>.empty(),
        initialState: SpellLibraryState.initial());
    whenListen(configurationBloc, const Stream<ConfigurationState>.empty(),
        initialState: ConfigurationState.initial());

    await tester.pumpWidget(EruditusApp(
      spellCreationBloc: spellCreationBloc,
      spellLibraryBloc: spellLibraryBloc,
      configurationBloc: configurationBloc,
      allEffects: const [],
      allParameters: const [],
      allSpecialFactors: const [],
    ));

    expect(find.text('Create Spell'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
