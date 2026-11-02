import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home shows a saved workout without switching tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    await tester.pumpWidget(const MaterialApp(home: Home()));
    expect(find.text('Push A'), findsNothing);

    await store.saveWorkout(Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken')]));
    await tester.pump();

    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Bankdrücken'), findsOneWidget);
  });
}
