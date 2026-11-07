import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
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

  testWidgets('insights and tasks can be switched off in the settings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Home()));
    await tester.runAsync(() => store.finishSession(Session(workoutId: 'x', workoutName: 'Push A', date: DateTime.now(),
        exercises: [ExerciseLog(name: 'Bankdrücken', weight: 80, targetReps: 5, reps: [5, 5, 5])])));
    await tester.pump();
    expect(find.byType(InsightCard), findsOneWidget);

    await prefs.setBool('home.insights', false);
    await prefs.setBool('home.tasks', false);
    await store.saveWorkout(store.workouts.first.copy()); // any change redraws the home screen
    await tester.pump();
    expect(find.byType(InsightCard), findsNothing);
    expect(find.text('Aufgaben'), findsNothing);
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

