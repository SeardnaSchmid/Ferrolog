import 'package:ferrolog/findings.dart';
import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/muscles.dart';
import 'package:ferrolog/units.dart';
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
    expect(f.evidence, 'Drücken 12 : Rudern 6 Sätze/Woche (50 %)');
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
}
