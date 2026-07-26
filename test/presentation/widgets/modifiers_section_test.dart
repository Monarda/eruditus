import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eruditus/models/modifier.dart';
import 'package:eruditus/presentation/widgets/modifiers_section.dart';

void main() {
  final material = Modifier(
    id: 'terram-material',
    name: 'Material difficulty',
    selectionMode: ModifierSelectionMode.single,
    scope: const ModifierScope(form: 'Terram'),
    options: [
      ModifierOption(id: 'mat-stone', label: 'Stone or glass', magnitude: 1),
      ModifierOption(id: 'mat-metal', label: 'Metal or gemstone', magnitude: 2),
    ],
    source: 'built-in',
  );
  final complexity = Modifier(
    id: 'crim-complexity',
    name: 'Complexity',
    selectionMode: ModifierSelectionMode.multi,
    scope: const ModifierScope(technique: 'Creo', form: 'Imaginem'),
    options: [ModifierOption(id: 'crim-intricate-design', label: 'Intricate Design', magnitude: 1)],
    source: 'built-in',
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<Modifier> modifiers,
    Map<String, List<String>> selected = const {},
    void Function(String, String)? onSelect,
    void Function(String, String)? onDeselect,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModifiersSection(
          modifiers: modifiers,
          selected: selected,
          onSelect: onSelect ?? (_, __) {},
          onDeselect: onDeselect ?? (_, __) {},
        ),
      ),
    ));
  }

  testWidgets('renders nothing when no modifier applies', (tester) async {
    await pump(tester, modifiers: const []);

    expect(find.byKey(const Key('modifiers-summary')), findsNothing);
  });

  testWidgets('collapsed summary shows the selected count and total magnitude', (tester) async {
    await pump(
      tester,
      modifiers: [material],
      selected: const {'terram-material': ['mat-metal']},
    );

    expect(find.byKey(const Key('modifiers-summary')), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    // Collapsed by default: the controls are not built yet.
    expect(find.byKey(const Key('modifier-dropdown-terram-material')), findsNothing);
  });

  testWidgets('collapsed summary shows +0 when nothing is selected', (tester) async {
    await pump(tester, modifiers: [material]);

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('+0'), findsOneWidget);
  });

  testWidgets('expanding reveals a dropdown for single mode', (tester) async {
    await pump(tester, modifiers: [material]);

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('modifier-dropdown-terram-material')), findsOneWidget);
  });

  testWidgets('expanding reveals checkboxes for multi mode', (tester) async {
    await pump(tester, modifiers: [complexity]);

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('modifier-checkbox-crim-intricate-design')), findsOneWidget);
  });

  testWidgets('choosing a dropdown option invokes onSelect', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      modifiers: [material],
      onSelect: (modifierId, optionId) => calls.add('$modifierId/$optionId'),
    );

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('modifier-dropdown-terram-material')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metal or gemstone (+2)').last);
    await tester.pumpAndSettle();

    expect(calls, ['terram-material/mat-metal']);
  });

  testWidgets('unticking a checkbox invokes onDeselect', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      modifiers: [complexity],
      selected: const {'crim-complexity': ['crim-intricate-design']},
      onDeselect: (modifierId, optionId) => calls.add('$modifierId/$optionId'),
    );

    await tester.tap(find.byKey(const Key('modifiers-expand-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('modifier-checkbox-crim-intricate-design')));
    await tester.pumpAndSettle();

    expect(calls, ['crim-complexity/crim-intricate-design']);
  });
}
