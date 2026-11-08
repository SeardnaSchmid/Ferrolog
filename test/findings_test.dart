import 'package:ferrolog/findings.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/muscles.dart';
import 'package:ferrolog/stats.dart';
import 'package:ferrolog/sync.dart';
import 'package:ferrolog/training_card.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String dump(Iterable<Finding> fs) => [for (final f in fs) '${f.type.name}: ${f.title} | ${f.evidence}'].join('\n');

final now = DateTime(2026, 11, 4, 12); // Wednesday: the weekly goal isn't tight yet

/// A training of [w] [daysAgo] days before [now], every set as planned.
Session at(Workout w, int daysAgo) => Session(
      workoutId: w.id,
      workoutName: w.name,
      date: now.subtract(Duration(days: daysAgo)),
      exercises: [
        for (final e in w.exercises)
          ExerciseLog(name: e.name, weight: e.weight, targetReps: e.reps, maxReps: e.maxReps, reps: List.filled(e.sets, e.reps)),
      ],
    );

/// Eight trainings of [w] over 15 days, newest first; [change] edits each one (0 = newest).
List<Session> eight(Workout w, [void Function(Session s, int i)? change]) {
  final list = [for (var i = 0; i < 8; i++) at(w, 1 + 2 * i)];
  for (final (i, s) in list.indexed) {
    change?.call(s, i);
  }
  return list;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    unit.value = WeightUnit.kg;
    store = await Store.open();
    prefs = await SharedPreferences.getInstance();
    sync = GitHubSync(prefs);
  });

  test('nothing trained: nothing found', () {
    expect(findings([], [Workout(name: 'A')], now), isEmpty);
  });

  test('skipped beats balance: the cause stands for the gap, with a button to move it up', () {
    final b = Workout(name: 'B', exercises: [
      Exercise(name: 'Schulterdrücken', weight: 50, sets: 3, reps: 5),
      Exercise(name: 'Bizepscurls', weight: 20, sets: 3, reps: 10),
      Exercise(name: 'Klimmzüge', weight: 0, sets: 3, reps: 5),
    ]);
    final s = eight(b, (s, i) {
      if (i.isEven) s.exercises.last.reps.fillRange(0, 3, null);
    });
    final all = findings(s, [b], now);
    expect(all.where((f) => f.kind == FindingKind.action), hasLength(1), reason: 'one piece of advice at a time');
    final f = all.first;
    expect((f.type, f.title, f.evidence), (FindingType.skipped, 'Klimmzüge 4× ausgelassen', 'In 4 Wochen, jedes Mal als letzte Übung'));
    expect((f.fix, f.workout, f.exercise), (Fix.moveUp, b, 'Klimmzüge'));
    expect(f.why, contains('Deshalb: Latissimus kommt zu kurz'));
    expect((f.source.view, f.source.pair), (StatsView.balance, Pair.pushPullOverhead), reason: 'the gap it causes');

    // Put off: the gap it explains stays quiet too.
    final snoozed = findings(s, [b], now, snoozed: {f.id: now.add(const Duration(days: 9))});
    expect(snoozed.where((f) => f.kind == FindingKind.action), isEmpty, reason: dump(snoozed));
    // The pause after the last advice.
    expect(findings(s, [b], now, lastAdvice: now.subtract(const Duration(days: 3))), isEmpty);
  });

  test('skipped without a gap points to the exercise; once is no pattern', () {
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5),
      Exercise(name: 'Bizepscurls', weight: 20, sets: 3, reps: 10),
      Exercise(name: 'Wadenheben', weight: 40, sets: 3, reps: 12),
    ]);
    final twice = findings(eight(a, (s, i) {
      if (i < 2) s.exercises[1].reps.fillRange(0, 3, null);
    }), [a], now);
    final f = twice.first;
    expect((f.title, f.evidence, f.source.view, f.source.exercise), ('Bizepscurls 2× ausgelassen', 'In 4 Wochen', StatsView.exercise, 'Bizepscurls'));
    expect(f.source.dates, hasLength(2));
    expect(f.fix, isNull, reason: 'already before the other accessories');
    final once = findings(eight(a, (s, i) {
      if (i == 0) s.exercises[1].reps.fillRange(0, 3, null);
    }), [a], now);
    expect(once.where((f) => f.type == FindingType.skipped), isEmpty, reason: dump(once));
  });

  test('balance by cause: one set less of an accessory ahead, never more work; strength: raise it', () {
    final push = Workout(name: 'P', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Dips', weight: 0, sets: 3, reps: 10),
      Exercise(name: 'Langhantelrudern', weight: 70, sets: 3, reps: 5),
    ]);
    final f = findings(eight(push), [push], now).single;
    expect((f.type, f.title, f.fix, f.exercise), (FindingType.balance, 'Oberer Rücken kommt zu kurz', Fix.dropSet, 'Dips'));
    expect(f.evidence, '50 % · Brust 22,4 : Oberer Rücken 11,2 Sätze/Woche', reason: 'per week as on the statistics: since the first training, 15 days ago');
    expect(f.advice, 'Ein Satz weniger Dips in P gleicht aus, ohne mehr Arbeit.');

    final weak = Workout(name: 'S', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 40, sets: 3, reps: 5),
    ]);
    final s = findings(eight(weak), [weak], now).single;
    expect((s.source.pair, s.fix), (Pair.chestBack, null));
    expect(s.advice, startsWith('Langhantelrudern weiter steigern'));
  });

  test('plateau: three trainings at one weight without more reps, explained, no button', () {
    final b = Workout(name: 'B', exercises: [
      Exercise(name: 'Schulterdrücken', weight: 42.5, sets: 5, reps: 5, down: false),
    ]);
    final s = [
      at(b, 1)..exercises.single.weights[4] = 40,
      at(b, 3)..exercises.single.reps.setAll(0, [5, 5, 4, 4, 3]),
      at(b, 5)..exercises.single.reps.setAll(0, [5, 5, 5, 4, 4]),
    ];
    final pl = findings(s, [b], now).where((f) => f.kind == FindingKind.action);
    expect(pl.length, 1, reason: dump(pl));
    final f = pl.first;
    expect((f.type, f.title, f.evidence, f.fix), (FindingType.plateau, 'Schulterdrücken steht bei 42,5 kg', '3 Trainings ohne Steigerung', null));
    expect(f.why, '30.10.: 5 · 5 · 5 · 4 · 4\n1.11.: 5 · 5 · 4 · 4 · 3\n3.11.: 5 · 5 · 5 · 5 · 5 @ 40\n'
        'Zuletzt einen Satz leichter gemacht, das hält das Gewicht.\nAutomatischer Deload ist aus.');
    expect((f.source.view, f.source.dates.length), (StatsView.exercise, 3));

    // A range climbing in reps is progress, not a plateau.
    final curls = Workout(name: 'C', exercises: [Exercise(name: 'Bizepscurls', weight: 20, sets: 3, reps: 8, maxReps: 12)]);
    final climbing = [
      for (final (i, r) in [10, 9, 8].indexed) at(curls, 1 + 2 * i)..exercises.single.reps.fillRange(0, 3, r),
    ];
    expect(findings(climbing, [curls], now).where((f) => f.kind == FindingKind.action), isEmpty);
  });

  test('weekly goal comes first; positives of the last training fill the lines below', () {
    final a = Workout(name: 'A', exercises: [Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5)]);
    final sunday = DateTime(2026, 11, 8, 12);
    // Nine trainings before, the tenth on Friday with a record.
    final s = [
      Session(workoutId: a.id, workoutName: 'A', date: DateTime(2026, 11, 6, 18), exercises: [
        ExerciseLog(name: 'Kniebeuge', weight: 110, targetReps: 5, reps: [5, 5, 5]),
      ]),
      for (var i = 0; i < 9; i++) at(a, 6 + 3 * i),
    ];
    // Advice paused (only squats would flag the hamstrings): weekly goal and positives don't pause.
    final all = findings(s, [a], sunday, perWeek: 2, lastAdvice: sunday.subtract(const Duration(days: 2)));
    expect([for (final f in all) f.type], [FindingType.weekGoal, FindingType.record, FindingType.milestone], reason: dump(all));
    expect((all[0].title, all[0].evidence), ('Noch 1 Training diese Woche', '1 von 2 geschafft, heute ist der letzte Tag'));
    expect((all[1].title, all[1].source.exercise), ('Rekord: Kniebeuge 110 kg', 'Kniebeuge'));
    expect(all[2].title, '10. Training geschafft');

    final (top, rows) = homeSelection(all);
    expect(top?.type, FindingType.weekGoal);
    expect([for (final f in rows) f.type], [FindingType.record, FindingType.milestone]);
    final (none, onlyGood) = homeSelection(all.skip(1).toList());
    expect((none, onlyGood.length), (null, 2), reason: 'no action: positives only, no top');
  });

  test('progress over 90 days where the last training moved it; a record month broken by it', () {
    final a = Workout(name: 'A', exercises: [Exercise(name: 'Rudern', weight: 60, sets: 3, reps: 5)]);
    Session row(DateTime d, double kg) => Session(workoutId: a.id, workoutName: 'A', date: d, exercises: [
          ExerciseLog(name: 'Rudern', weight: kg, targetReps: 5, reps: [5, 5, 5]),
        ]);
    final s = [
      row(DateTime(2026, 11, 3), 60),
      row(DateTime(2026, 11, 2), 60),
      row(DateTime(2026, 11, 1), 57.5),
      row(DateTime(2026, 10, 5), 55),
      row(DateTime(2026, 10, 1), 50),
    ];
    final all = findings(s, [a], now, perWeek: 1);
    expect([for (final f in all) f.title], ['Fortschritt: Rudern 50 → 60 kg', 'Rekordmonat: 3 Trainings']);
    expect(all.first.evidence, 'Seit 1.10.');
  });

  test('weekly goal: only when tight and still doable one a day, not right after training, not in the first week', () {
    final a = Workout(name: 'A', exercises: [Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5)]);
    final saturday = DateTime(2026, 11, 7, 12), sunday = DateTime(2026, 11, 8, 12);
    List<Finding> week(List<int> daysAgo, DateTime when, int perWeek) => [
          for (final f in findings([for (final d in daysAgo) at(a, d)], [a], when, perWeek: perWeek))
            if (f.type == FindingType.weekGoal) f,
        ];
    final due = week([6, 8], sunday, 1).single;
    expect((due.title, due.evidence), ('Noch 1 Training diese Woche', '0 von 1 geschafft, heute ist der letzte Tag'));
    expect((due.source.view, due.fix), (StatsView.weeks, null));
    expect(week([6, 8], sunday, 3), isEmpty, reason: 'three on the last day: not doable');
    expect(week([-4, 6, 8], sunday, 2), isEmpty, reason: 'trained today: no second one');
    expect(week([-3, 6, 8], saturday, 2).single.evidence, '1 von 2 geschafft, morgen ist der letzte Tag');
    expect(week([-2], sunday, 2), isEmpty, reason: 'first week of training');
  });

  test('an exercise skipped in every training breaks nothing', () {
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5),
      Exercise(name: 'Rudern', weight: 50, sets: 2, reps: 5),
    ]);
    final s = eight(a, (s, i) => s.exercises[1].reps.fillRange(0, 2, null));
    expect(findings(s, [a], now).map((f) => f.title), contains('Rudern 8× ausgelassen'));
  });

  testWidgets('card → sheet → fix changes the plan and puts the finding away; undo brings both back', (tester) async {
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
    // Eight trainings up to yesterday, whatever day the test runs.
    final shift = DateTime.now().difference(now);
    store.sessions
      ..clear()
      ..addAll([for (final s in eight(push)) Session.fromJson({...s.toJson(), 'date': s.date.add(shift).toIso8601String()})]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListenableBuilder(listenable: Listenable.merge([store, findingsVersion]), builder: (_, _) => TrainingCard())),
    ));
    expect(find.text('Oberer Rücken kommt zu kurz'), findsOneWidget);

    await tester.tap(find.text('Oberer Rücken kommt zu kurz'));
    await tester.pumpAndSettle();
    expect(find.text('BALANCE · LETZTE 30 TAGE'), findsOneWidget);
    expect(find.text('Ein Satz weniger Dips in P gleicht aus, ohne mehr Arbeit.'), findsOneWidget);
    await tester.tap(find.text('1 Satz weniger Dips'));
    await tester.pumpAndSettle();
    Exercise dips() => store.workouts.single.exercises.firstWhere((e) => e.name == 'Dips');
    expect(dips().sets, 2);
    expect(find.text('Oberer Rücken kommt zu kurz'), findsNothing, reason: 'done until the numbers can move');

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(dips().sets, 3);
    expect(find.text('Oberer Rücken kommt zu kurz'), findsOneWidget);

    // Put off from the sheet.
    await tester.tap(find.text('Oberer Rücken kommt zu kurz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();
    expect(find.text('Oberer Rücken kommt zu kurz'), findsNothing);
    expect(snoozedFindings.keys, contains('balance:pushPullFlat'));
  });

  testWidgets('into the statistics: the balance card outlined with its pair; the exercise names the trainings left out', (tester) async {
    final push = Workout(name: 'P', exercises: [
      Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 5),
      Exercise(name: 'Langhantelrudern', weight: 70, sets: 3, reps: 5),
    ]);
    final shift = DateTime.now().difference(now);
    final s = [
      for (final x in eight(push, (s, i) {
        if (i < 2) s.exercises[1].reps.fillRange(0, 3, null);
      }))
        Session.fromJson({...x.toJson(), 'date': x.date.add(shift).toIso8601String()}),
    ];
    store.sessions
      ..clear()
      ..addAll(s);
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    statsFocus.value = statsAt(StatsView.balance, pair: Pair.pushPullFlat);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatsPage())));
    await tester.pumpAndSettle();
    expect(statsFocus.value, isNull, reason: 'used once');
    final card = tester.widget<Card>(find.ancestor(of: find.text('Balance'), matching: find.byType(Card)).first);
    expect((card.shape as RoundedRectangleBorder).side.width, 2, reason: 'outlined');
    final top = tester.getRect(find.text('Balance')).top;
    expect(top, inInclusiveRange(0, 200), reason: 'scrolled to the top of the screen');
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<Card>(find.ancestor(of: find.text('Balance'), matching: find.byType(Card)).first).shape, isNull,
        reason: 'only for a moment');

    final skipped = [s[0].date, s[1].date];
    await tester.pumpWidget(MaterialApp(home: ExerciseStats('Langhantelrudern', marked: skipped)));
    await tester.pump();
    expect(find.textContaining('Ausgelassen am ${skipped[1].day}.${skipped[1].month}., ${skipped[0].day}.'), findsOneWidget);
  });
}
