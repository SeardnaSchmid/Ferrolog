import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/sync.dart';
import 'package:ferrolog/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final a = Workout(name: 'A', exercises: [
  Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5),
  Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
  Exercise(name: 'Kreuzheben', weight: 120, sets: 1, reps: 5),
]);
final b = Workout(name: 'B', exercises: [
  Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5),
  Exercise(name: 'Schulterdrücken', weight: 50, sets: 3, reps: 5),
  Exercise(name: 'Kreuzheben', weight: 120, sets: 1, reps: 5),
]);
final now = DateTime(2026, 11, 4, 12); // Wednesday: the weekly goal isn't tight yet

Session at(Workout w, int daysAgo, {double? bodyWeight, List<String> extra = const []}) => Session(
      workoutId: w.id,
      workoutName: w.name,
      date: now.subtract(Duration(days: daysAgo)),
      bodyWeight: bodyWeight,
      exercises: [
        for (final e in w.exercises) ExerciseLog(name: e.name, weight: e.weight, targetReps: e.reps, reps: List.filled(e.sets, e.reps)),
        for (final name in extra) ExerciseLog(name: name, weight: 40, targetReps: 15, reps: [15, 15, 15]),
      ],
    );

/// Starting Strength, alternating A and B every other day, newest first.
List<Session> starting(int trainings, {List<String> extra = const []}) =>
    [for (var i = 0; i < trainings; i++) at(i.isEven ? a : b, 1 + 2 * i, extra: extra)];

void main() {
  test('tasks: no advice before a baseline, then one antagonist gap at a time with a pause, situational rest', () async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();

    expect(tasks(starting(3), [a, b], now), isEmpty, reason: 'first week: no flood of "train X"');

    final s = starting(8); // 15 days, no pulling at all
    final t = tasks(s, [a, b], now);
    expect(t, hasLength(1), reason: 'one piece of advice, never a list');
    expect((t.single.id, t.single.title), ('balance:pushPullFlat', 'Oberer Rücken stärken'));
    expect((t.single.workout, t.single.exercise, t.single.addSet), (b, 'Kurzhantelrudern', false), reason: 'B is up next');
    expect(t.single.why, startsWith('Kurzhantelrudern in B aufnehmen. '));

    expect(tasks(s, [a, b], now, lastAdvice: now.subtract(const Duration(days: 3))), isEmpty, reason: 'pause after advice');
    final next = tasks(s, [a, b], now,
        lastAdvice: now.subtract(const Duration(days: 8)), snoozed: {'balance:pushPullFlat': now.add(const Duration(days: 6))});
    expect(next.single.id, 'balance:pushPullOverhead', reason: 'the next one after the pause');

    // Only opposing muscles count: legs, calves, abs left out entirely are the program's choice.
    final both = {for (final x in ['balance:pushPullFlat', 'balance:pushPullOverhead']) x: now.add(const Duration(days: 9))};
    final dropped = [...starting(8), for (var i = 0; i < 6; i++) at(a, 30 + 3 * i, extra: ['Wadenheben'])];
    expect(tasks(dropped, [a, b], now, snoozed: both), isEmpty, reason: 'calves dropped: no antagonist, no advice');
    final chestOnly = Workout(name: 'Brust', exercises: [Exercise(name: 'Bankdrücken', weight: 80, sets: 5, reps: 5)]);
    final chest = [for (var i = 0; i < 8; i++) at(chestOnly, 1 + 2 * i)];
    expect(tasks(chest, [chestOnly], now).single.title, 'Oberer Rücken stärken', reason: 'chest without back: row');

    // Situational: own exercise without muscles; body weight only if tracked and gone stale.
    final own = Workout(name: 'C', exercises: [Exercise(name: 'Meditation', weight: 0, sets: 1, reps: 10)]);
    expect(tasks(starting(2), [a, own], now).map((x) => x.id), ['muscles:Meditation']);
    expect(tasks([at(a, 1), at(b, 40, bodyWeight: 80)], [a, b], now).single.why, 'Zuletzt vor 40 Tagen.');
    expect(tasks([at(a, 1, bodyWeight: 80)], [a, b], now), isEmpty);

    // Weekly goal: only when tight and still doable one a day, not right after training, not in the first week.
    final saturday = DateTime(2026, 11, 7, 12), sunday = DateTime(2026, 11, 8, 12);
    final lastWeek = [at(a, 6), at(b, 8)];
    final due = tasks(lastWeek, [a, b], sunday, perWeek: 1).single;
    expect((due.title, due.why), ('Noch 1 Training diese Woche', 'Für dein Wochenziel von 1, heute ist der letzte Tag.'));
    expect(tasks(lastWeek, [a, b], sunday, perWeek: 3), isEmpty, reason: 'three on the last day: not doable');
    expect(tasks([at(a, -4), ...lastWeek], [a, b], sunday, perWeek: 2), isEmpty, reason: 'trained today: no second one');
    expect(tasks([at(a, -3), ...lastWeek], [a, b], saturday, perWeek: 2).single.why,
        'Für dein Wochenziel von 2, morgen ist der letzte Tag.');
    expect(tasks([at(a, -2)], [a, b], sunday, perWeek: 2), isEmpty, reason: 'first week of training');
  });

  testWidgets('task card: Hinzufügen changes the plan, puts the advice away, undo brings both back', (tester) async {
    prefs = await SharedPreferences.getInstance();
    sync = GitHubSync(prefs);
    await tester.runAsync(() async {
      await store.saveWorkout(a);
      await store.saveWorkout(b);
    });
    store.sessions
      ..clear()
      ..addAll([for (var i = 0; i < 8; i++) at(i.isEven ? a : b, 1 + 2 * i)].map((s) =>
          Session.fromJson({...s.toJson(), 'date': s.date.add(DateTime.now().difference(now)).toIso8601String()})));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TasksCard()))));
    expect(find.text('Oberer Rücken stärken'), findsOneWidget);

    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(store.workouts.firstWhere((w) => w.id == b.id).exercises.last.name, 'Kurzhantelrudern');
    expect(find.text('Oberer Rücken stärken'), findsNothing, reason: 'done until the numbers can move');
    expect(find.text('Latissimus stärken'), findsNothing, reason: 'the next advice waits a week');

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(store.workouts.firstWhere((w) => w.id == b.id).exercises.map((e) => e.name), isNot(contains('Kurzhantelrudern')));
    expect(find.text('Oberer Rücken stärken'), findsOneWidget);

    await tester.tap(find.byTooltip('Später (2 Wochen ausblenden)'));
    await tester.pumpAndSettle();
    expect(find.text('Oberer Rücken stärken'), findsNothing);
    expect(snoozedTasks.keys, contains('balance:pushPullFlat'));
  });
}
