import 'package:ferrolog/edit.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('exercise dialog suggests and fills defaults', (tester) async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    Exercise? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog(context: context, builder: (_) => const ExerciseDialog(null)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'knie');
    await tester.pump();
    await tester.tap(find.text('Kniebeuge'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Kniebeuge');
    expect((result?.sets, result?.reps), (3, 5));
  });
}
