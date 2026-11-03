import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('calendar counts the month and filters by tapped day', (tester) async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    final now = DateTime.now();
    final w = Workout(name: 'Push A', exercises: [Exercise(name: 'Bankdrücken')]);
    // Two trainings this month on different days (day 1 is always in the month, today too).
    for (final d in {DateTime(now.year, now.month, 1, 9), now}) {
      await store.finishSession(Session(workoutId: w.id, workoutName: 'Push A', date: d, exercises: [
        ExerciseLog(name: 'Bankdrücken', weight: 60, targetReps: 5, reps: [5, 5, 5]),
      ]));
    }
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HistoryList())));

    expect(find.text('Push A'), findsNWidgets(2));
    expect(find.textContaining('2 Trainings im'), findsOneWidget);

    if (now.day != 1) {
      await tester.tap(find.text('1').first);
      await tester.pump();
      expect(find.text('Push A'), findsOneWidget);
    }
  });
}
