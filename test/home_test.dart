import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home shows a saved workout without switching tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = await Store.open();
    await tester.pumpWidget(const MaterialApp(home: Home()));
    expect(find.text('Push A'), findsNothing);

    await store.saveWorkout(Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken')]));
    await tester.pump();

    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Bankdrücken'), findsOneWidget);
  });

  testWidgets('Dein Training: a record after the training, a quiet line without findings, off in the settings', (tester) async {
    unit.value = WeightUnit.kg; // the test locale is en-US, which would default to lb
    await tester.pumpWidget(const MaterialApp(home: Home()));
    await tester.runAsync(() async {
      for (final (i, kg) in [80.0, 85.0].indexed) {
        await store.finishSession(Session(workoutId: 'x', workoutName: 'Push A', date: DateTime.now().subtract(Duration(days: 1 - i)),
            exercises: [ExerciseLog(name: 'Bankdrücken', weight: kg, targetReps: 5, reps: [5, 5, 5])]));
      }
    });
    await tester.pump();
    expect(find.text('Dein Training'), findsOneWidget);
    expect(find.text('Rekord: Bankdrücken 85 kg'), findsOneWidget);

    await prefs.setBool('home.insights', false);
    await store.saveWorkout(store.workouts.first.copy()); // any change redraws the home screen
    await tester.pump();
    expect(find.text('Rekord: Bankdrücken 85 kg'), findsNothing, reason: 'successes switched off');
    expect(find.text('Alles im Lot', findRichText: true), findsNothing);
    expect(find.textContaining('Alles im Lot', findRichText: true), findsOneWidget);

    await prefs.setBool('home.tasks', false);
    await store.saveWorkout(store.workouts.first.copy());
    await tester.pump();
    expect(find.textContaining('Alles im Lot', findRichText: true), findsNothing, reason: 'both off: no card');
    await prefs.remove('home.insights');
    await prefs.remove('home.tasks');
  });

  testWidgets('the running training shows what is left on the home screen', (tester) async {
    final w = Workout(name: 'Push B', exercises: [Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5)]);
    await store.saveWorkout(w);
    await store.saveActive(Session.start(w));
    await tester.pumpWidget(const MaterialApp(home: Home()));
    await tester.pump();
    expect(find.textContaining('noch ≈'), findsOneWidget);
    await store.saveActive(null);
  });
}

