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
    expect((t.single.id, t.single.title), ('balance:pushPullFlat', 'Fokus Oberer Rücken'));
    expect((t.single.fix, t.single.action), (null, null), reason: 'a hint, the plan stays as it is');
    expect(t.single.why, 'Drücken 3 : Rudern 0 Sätze/Woche (0 %, Richtwert ab 100 %). '
        'Nichts im Plan trainiert das, zum Beispiel Kurzhantelrudern.');

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
    expect(tasks(chest, [chestOnly], now).single.title, 'Fokus Oberer Rücken', reason: 'chest without back: row');

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

  test('balance advice by cause: never more work', () {
    // Eight trainings over 15 days; [change] edits each one.
    List<Session> eight(Workout w, [void Function(Session s, int i)? change]) => [
          for (var i = 0; i < 8; i++) at(w, 1 + 2 * i),
        ]..indexed.forEach((x) => change?.call(x.$2, x.$1));

    // Pull-ups planned as often as the press, but left out at the end: move them up.
    final ohp = Workout(name: 'O', exercises: [
      Exercise(name: 'Schulterdrücken', weight: 50, sets: 3, reps: 5),
      Exercise(name: 'Bizepscurls', weight: 20, sets: 3, reps: 10),
      Exercise(name: 'Klimmzüge', weight: 0, sets: 3, reps: 5),
    ]);
    final skipped = tasks(eight(ohp, (s, i) {
      if (i.isEven) s.exercises.last.reps.fillRange(0, 3, null);
    }), [ohp], now).single;
    expect((skipped.title, skipped.fix, skipped.exercise, skipped.action), ('Fokus Latissimus', Fix.moveUp, 'Klimmzüge', 'Vorziehen'));
    expect(skipped.why, endsWith('Klimmzüge in 4 Wochen 4× ausgelassen oder abgebrochen. Vor die Zusatzübungen ziehen?'));

    // Planned uneven with an accessory ahead: one set less there.
    final push = Workout(name: 'P', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Dips', weight: 0, sets: 3, reps: 10),
      Exercise(name: 'Langhantelrudern', weight: 70, sets: 3, reps: 5),
    ]);
    final drop = tasks(eight(push), [push], now).single;
    expect((drop.title, drop.fix, drop.exercise, drop.action), ('Fokus Oberer Rücken', Fix.dropSet, 'Dips', '−1 Satz'));
    expect(drop.why, endsWith('Ein Satz weniger Dips in P gleicht aus.'));

    // Uneven, but only main lifts ahead: they stay, a hint only.
    final main = Workout(name: 'M', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 5, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 70, sets: 3, reps: 5),
    ]);
    final hint = tasks(eight(main), [main], now).single;
    expect((hint.fix, hint.why),
        (null, 'Drücken 10 : Rudern 6 Sätze/Woche (60 %, Richtwert ab 100 %). Grundübungen bleiben wie geplant, '
            'Langhantelrudern nicht auslassen und weiter steigern.'));

    // By strength: rows far behind the bench press, same sets. Raising them is the fix, not more sets.
    final weak = Workout(name: 'S', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 40, sets: 3, reps: 5),
    ]);
    final strength = tasks(eight(weak), [weak], now).single;
    expect((strength.id, strength.fix), ('balance:chestBack', null));
    expect(strength.why, endsWith('kg 1RM (50 %, Richtwert 75–120 %). Langhantelrudern weiter steigern, das holt auf.'));
  });

  testWidgets('task card: −1 Satz changes the plan, puts the advice away, undo brings both back', (tester) async {
    prefs = await SharedPreferences.getInstance();
    sync = GitHubSync(prefs);
    final push = Workout(name: 'P', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Dips', weight: 0, sets: 3, reps: 10),
      Exercise(name: 'Langhantelrudern', weight: 70, sets: 3, reps: 5),
    ]);
    await tester.runAsync(() async {
      for (final w in [...store.workouts]) {
        await store.deleteWorkout(w);
      }
      await store.saveWorkout(push);
    });
    store.sessions
      ..clear()
      ..addAll([for (var i = 0; i < 8; i++) at(push, 1 + 2 * i)].map((s) =>
          Session.fromJson({...s.toJson(), 'date': s.date.add(DateTime.now().difference(now)).toIso8601String()})));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TasksCard()))));
    expect(find.text('Fokus Oberer Rücken'), findsOneWidget);

    await tester.tap(find.text('−1 Satz'));
    await tester.pumpAndSettle();
    Exercise dips() => store.workouts.single.exercises.firstWhere((e) => e.name == 'Dips');
    expect(dips().sets, 2);
    expect(find.text('Fokus Oberer Rücken'), findsNothing, reason: 'done until the numbers can move');

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(dips().sets, 3);
    expect(find.text('Fokus Oberer Rücken'), findsOneWidget);

    await tester.tap(find.byTooltip('Später (2 Wochen ausblenden)'));
    await tester.pumpAndSettle();
    expect(find.text('Fokus Oberer Rücken'), findsNothing);
    expect(snoozedTasks.keys, contains('balance:pushPullFlat'));
  });
}
