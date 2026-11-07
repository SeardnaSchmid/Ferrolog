import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/sync.dart';
import 'package:ferrolog/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('tasks: balance and untrained muscles with a fix for the workout up next, week, data', () async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5),
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
    ]);
    final b = Workout(name: 'B', exercises: [
      Exercise(name: 'Schulterdrücken', weight: 50, sets: 3, reps: 5),
      Exercise(name: 'Kreuzheben', weight: 120, sets: 1, reps: 5),
      Exercise(name: 'Meditation', weight: 0, sets: 1, reps: 10),
    ]);
    final now = DateTime(2026, 11, 8, 12); // Sunday
    Session at(Workout w, int daysAgo) => Session(
          workoutId: w.id,
          workoutName: w.name,
          date: now.subtract(Duration(days: daysAgo)),
          exercises: [
            for (final e in w.exercises) ExerciseLog(name: e.name, weight: e.weight, targetReps: e.reps, reps: List.filled(e.sets, e.reps)),
          ],
        );
    final sessions = [at(a, 0), at(b, 9), at(a, 11)]; // B is up next
    final t = {for (final x in tasks(sessions, [a, b], now, perWeek: 3)) x.id: x};

    final rows = t['balance:pushPullFlat']!;
    expect((rows.title, rows.workout, rows.exercise, rows.addSet), ('Oberer Rücken stärken', b, 'Kurzhantelrudern', false));
    expect(rows.why, startsWith('Kurzhantelrudern in B aufnehmen. '));
    expect(rows.why, contains('Rudern bei 0 %'));
    expect(t['balance:pushPullOverhead']!.exercise, 'Latzug');
    expect(t.containsKey('untrained:lats'), isFalse, reason: 'Latzug is already suggested');
    expect(t['untrained:calves']!.exercise, 'Wadenheben');
    expect(t['untrained:biceps']!.exercise, 'Bizepscurls');
    expect(t.containsKey('untrained:abdominals'), isFalse, reason: 'shoulder presses help the abs');
    expect(t['week:2026-11-2']!.title, 'Noch 2 Trainings diese Woche');
    expect(t['bodyweight']!.why, contains('Noch nie'));
    expect(t['muscles:Meditation']!.workout, b);
    expect(t.containsKey('sync'), isFalse, reason: 'fewer than 5 trainings');

    // With rows in a plan, one more set of them instead of a new exercise.
    a.exercises.add(Exercise(name: 'Langhantelrudern', weight: 40, sets: 3, reps: 5));
    final withRows = [at(a, 0), at(b, 9), at(a, 11)];
    final fix = tasks(withRows, [a, b], now).firstWhere((x) => x.id == 'balance:chestBack');
    expect((fix.workout, fix.exercise, fix.addSet), (a, 'Langhantelrudern', true));
    expect(fix.action, '+1 Satz');
  });

  testWidgets('task card: +1 Satz changes the plan and can be undone, × puts the task off', (tester) async {
    // The store from the test above; prefs and sync for the card.
    prefs = await SharedPreferences.getInstance();
    sync = GitHubSync(prefs);
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 40, sets: 3, reps: 5),
    ]);
    await tester.runAsync(() async {
      await store.saveWorkout(a);
      final s = Session.start(a);
      s.exercises[0].reps.setAll(0, [5, 5, 5]);
      s.exercises[1].reps.setAll(0, [5, 5, 5]);
      await store.finishSession(s);
    });
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TasksCard()))));
    expect(find.text('Oberer Rücken stärken'), findsOneWidget, reason: 'rows at 50 % of the bench press');

    await tester.tap(find.text('+1 Satz'));
    await tester.pumpAndSettle();
    expect(store.workouts.single.exercises[1].sets, 4);
    expect(find.text('Langhantelrudern in A: jetzt 4 Sätze'), findsOneWidget);
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(store.workouts.single.exercises[1].sets, 3);

    await tester.tap(find.byTooltip('Später (2 Wochen ausblenden)').first);
    await tester.pumpAndSettle();
    expect(find.text('Oberer Rücken stärken'), findsNothing);
    expect(snoozedTasks.keys, contains('balance:chestBack'));
  });
}
