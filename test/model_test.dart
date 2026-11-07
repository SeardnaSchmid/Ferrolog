import 'dart:convert';

import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('progressive overload and JSON round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final w = Workout(
      name: 'A',
      exercises: [
        Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5, increment: 2.5),
        Exercise(name: 'Bankdrücken', weight: 60, sets: 2, reps: 5, increment: 2.5),
      ],
    );
    await store.saveWorkout(w);

    final s = Session.start(w);
    s.exercises[0].reps.setAll(0, [5, 5]); // success -> +2.5
    s.exercises[1].reps.setAll(0, [5, 3]); // missed reps -> stays
    await store.finishSession(s);

    expect(w.exercises[0].weight, 102.5);
    expect(w.exercises[1].weight, 60);
    expect(store.lastSessionOf(w), s);
    expect(store.historyOf('Kniebeuge').single.$2.volume, 1000);

    final reopened = await Store.open();
    expect(reopened.workouts.single.exercises.first.weight, 102.5);
    expect(reopened.sessions.single.exercises[1].reps, [5, 3]);
    expect(jsonDecode(reopened.exportJson())['sessions'], hasLength(1));
  });

  test('week streak', () {
    final now = DateTime(2026, 11, 4); // Wednesday
    expect(weekStreak([], now), 0);
    // This week, last week, two weeks ago, then a gap.
    expect(
      weekStreak([DateTime(2026, 11, 2), DateTime(2026, 10, 30), DateTime(2026, 10, 19), DateTime(2026, 10, 5)], now),
      3,
    );
    // Nothing yet this week: the streak still counts from last week.
    expect(weekStreak([DateTime(2026, 10, 26), DateTime(2026, 10, 25)], now), 2);
    // Last training two weeks ago: broken.
    expect(weekStreak([DateTime(2026, 10, 22)], now), 0);
    // Goal 2× per week: last week had 2, the week before only 1; this week (1 so far) doesn't count yet.
    final twice = [DateTime(2026, 11, 3), DateTime(2026, 10, 27), DateTime(2026, 10, 29), DateTime(2026, 10, 21)];
    expect(weekStreak(twice, now, perWeek: 2), 1);
    expect(weekStreak([...twice, DateTime(2026, 11, 4)], now, perWeek: 2), 2, reason: 'this week reached 2');
    expect(weekStreak(twice, now, perWeek: 1), 3);
  });

  test('per-set weights: old data, grouping, working weight', () {
    final old = ExerciseLog.fromJson({
      'name': 'Squat',
      'weight': 100,
      'targetReps': 5,
      'reps': [5, 5, 3],
    });
    expect(old.weights, [100, 100, 100]);
    final log = ExerciseLog(name: 'Bench', weight: 0, targetReps: 5, reps: [5, 5, 3], weights: [72.5, 72.5, 70]);
    expect(log.weight, 72.5);
    expect(log.volume, 5 * 72.5 * 2 + 3 * 70);
    expect(ExerciseLog.fromJson(log.toJson()).weights, [72.5, 72.5, 70]);
    expect(groupByWeight(log.weights).map((g) => '${g.$1}: ${g.$2}'), ['72.5: [0, 1]', '70.0: [2]']);
  });

  test('cardio: one set, goal is distance or duration, survives JSON, never auto-adjusted', () {
    final run = Exercise.cardio(name: 'Laufen', minutes: 30, km: 5);
    final w = Workout(
      name: 'Mix',
      exercises: [
        Exercise(name: 'Kniebeuge'),
        run,
      ],
    );
    final again = Workout.fromJson(jsonDecode(jsonEncode(w.toJson()))).exercises.last;
    expect((again.cardio, again.reps, again.km, again.sets), (true, 0, 5.0, 1), reason: 'distance goal');

    final log = Session.start(w).exercises.last;
    expect((log.cardio, log.targetReps, log.targetKm, log.reps.length, log.reps.first), (true, 0, 5.0, 1, null));
    log
      ..reps[0] = 25
      ..km = 4.2;
    final logAgain = ExerciseLog.fromJson(jsonDecode(jsonEncode(log.toJson())));
    expect((logAgain.cardio, logAgain.reps.single, logAgain.km, logAgain.succeeded), (true, 25, 4.2, false));
    logAgain.km = 5.1;
    expect(logAgain.succeeded, true, reason: 'distance reached, time does not matter');
    expect(logAgain.volume, 0);

    run.applyResult(log);
    expect((run.reps, run.km, run.weight), (0, 5.0, 0.0));
  });

  test('weekly summary', () {
    final now = DateTime(2026, 11, 4); // Wednesday
    Session at(DateTime d, {int? cardioMinutes}) => Session(
      workoutId: 'w',
      workoutName: 'A',
      date: d,
      exercises: [
        ExerciseLog(name: 'Kniebeuge', weight: 80, targetReps: 5, reps: [5]),
        if (cardioMinutes != null)
          ExerciseLog(name: 'Laufen', weight: 0, targetReps: 30, reps: [cardioMinutes], cardio: true),
      ],
    );
    final weeks = weeklySummary(
      [at(DateTime(2026, 11, 3), cardioMinutes: 25), at(DateTime(2026, 11, 2)), at(DateTime(2026, 10, 28))],
      now,
      weeks: 3,
    );
    expect(weeks.map((w) => (w.$1.day, w.$2, w.$3)), [(19, 0, 0), (26, 1, 0), (2, 2, 25)]);

  });

  test('1RM from all sets, setbacks, trend', () {
    ExerciseLog squat(double kg, List<int?> reps) => ExerciseLog(name: 'Kniebeuge', weight: kg, targetReps: 5, reps: reps);
    expect(estimated1rm(squat(90, [5, 5, 5])), 105);
    expect(estimated1rm(squat(90, [5, 5, 2])), 90 * (1 + 4 / 30), reason: 'missed reps lower it');
    expect(estimated1rm(squat(90, [null, null, null])), 0);

    final now = DateTime(2026, 11, 4);
    final history = [
      (DateTime(2026, 9, 1), squat(80, [5, 5, 5])),
      (DateTime(2026, 9, 3), squat(82.5, [5, 5, 4])), // new weight missed: normal, no setback
      (DateTime(2026, 9, 5), squat(82.5, [3, 3, 3])), // same weight, clearly worse: setback
      (DateTime(2026, 9, 20), squat(75, [5, 5, 5])), // deload after a break: no setback
      (DateTime(2026, 10, 1), squat(80, [5, 5, 4])), // missed a weight managed before: setback
      (DateTime(2026, 10, 20), squat(80, [5, 5, 5])),
      (DateTime(2026, 11, 3), squat(82.5, [5, 5, 5])),
    ];
    expect(setbacks(history), {2, 4});

    final (trend, change) = trendOf(history, now)!;
    expect(trend, Trend.up);
    expect(change, closeTo((96.25 / (80 * (1 + 14 / 3 / 30)) - 1) * 100, .01), reason: 'Oct 1 (last before the window) → now');
    expect(trendOf([(DateTime(2026, 10, 1), squat(80, [5, 5, 5])), (DateTime(2026, 11, 3), squat(80, [5, 5, 5]))], now)!.$1,
        Trend.flat);
    expect(trendOf(history.take(3).toList(), DateTime(2026, 9, 6))!.$1, Trend.stuck, reason: 'two of the last three missed');
    expect(trendOf([...history.take(2), (DateTime(2026, 9, 5), squat(85, [5, 5, 4]))], DateTime(2026, 9, 6))!.$1, Trend.up,
        reason: 'two misses, but the 1RM still rose');
    expect(trendOf([history.last], now), isNull);
  });

  test('switching increase/decrease off keeps the step; old files with 0 read as off', () {
    final e = Exercise(name: 'Kniebeuge', weight: 100, sets: 1, reps: 5, increment: 5, up: false);
    final back = Exercise.fromJson(jsonDecode(jsonEncode(e.toJson())));
    expect((back.up, back.increment, back.down), (false, 5.0, false));
    back.applyResult(ExerciseLog(name: 'Kniebeuge', weight: 100, reps: [5], targetReps: 5));
    expect(back.weight, 100, reason: 'off: no increase');

    final old = Exercise.fromJson({'name': 'X', 'weight': 50, 'sets': 3, 'reps': 5, 'increment': 0, 'decrement': 5});
    expect((old.up, old.increment, old.down, old.decrement), (false, 2.5, true, 5.0));
  });

  test('rep range: weight goes up only when every set reaches the top; custom reps per set', () {
    final e = Exercise(name: 'Rudern', weight: 50, sets: 2, reps: 5, maxReps: 8, failRestSeconds: 180);
    final again = Exercise.fromJson(jsonDecode(jsonEncode(e.toJson())));
    expect((again.maxReps, again.failRestSeconds), (8, 180));
    ExerciseLog log(List<int?> reps) =>
        Session.start(Workout(name: 'A', exercises: [again])).exercises.single..reps.setAll(0, reps);
    again.applyResult(log([8, 6]));
    expect((again.weight, again.fails), (50, 0), reason: 'in the range, not at the top');
    again.applyResult(log([8, 8]));
    expect(again.weight, 52.5);
    again.applyResult(log([4, 8]));
    expect(again.fails, 1, reason: 'below the bottom counts as a miss');

    final pyramid = Exercise(name: 'Bank', sets: 3, reps: 10, setReps: [10, 8, 6]);
    final l = Session.start(Workout(name: 'B', exercises: [pyramid])).exercises.single;
    expect(l.targets, [10, 8, 6]);
    l.reps.setAll(0, [10, 8, 6]);
    final back = ExerciseLog.fromJson(jsonDecode(jsonEncode(l.toJson())));
    expect(back.targets, [10, 8, 6]);
    expect(back.succeeded, true);
    expect(setsLabel(pyramid.repsPerSet, null), '10/8/6');
    expect(setsLabel([5, 5, 5], 8), '3×5–8');
  });

  test('period stats: per week from the first training, volume against the period before, records, duration', () {
    final now = DateTime(2026, 11, 3, 20);
    Session at(int daysAgo, double kg, {int minutes = 0}) {
      final d = now.subtract(Duration(days: daysAgo));
      return Session(
        workoutId: 'w',
        workoutName: 'A',
        date: d,
        finishedAt: minutes == 0 ? null : d.add(Duration(minutes: minutes)),
        exercises: [
          ExerciseLog(name: 'Kniebeuge', weight: kg, targetReps: 5, reps: [5, 5]),
        ],
      );
    }

    final sessions = [at(1, 100, minutes: 50), at(8, 90, minutes: 70), at(14, 80), at(120, 70), at(200, 60)];
    final p = periodStats(sessions, now, days: 90);
    expect(p.trainings, 3);
    expect(p.perWeek, closeTo(3 / 2, .01), reason: '3 trainings, first one 2 weeks ago');
    expect(p.volume, 2700);
    expect(p.volumeBefore, 700, reason: 'the 90 days before: only the training 120 days ago');
    expect((p.lifts, p.recordLifts), (1, 1), reason: '80, 90, 100 each beat everything before');
    expect(p.lastRecord, ('Kniebeuge', 100.0, now.subtract(const Duration(days: 1))));
    expect(p.avgDuration, const Duration(minutes: 60), reason: 'only trainings with an end time');
    final all = periodStats(sessions, now);
    expect((all.trainings, all.volumeBefore, all.recordLifts), (5, null, 1));
    expect(periodStats([at(1, 90), at(8, 100)], now, days: 90).lastRecord, isNull, reason: 'lighter than before');
  });

  test('a training left running ends at its last activity after 30 minutes', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final w = Workout(
      name: 'A',
      exercises: [Exercise(name: 'Kniebeuge', sets: 1, reps: 5)],
    );
    store.workouts.add(w);
    final s = Session.start(w);
    await store.saveActive(s);
    expect(await store.autoFinish(DateTime.now().add(const Duration(hours: 2))), false, reason: 'nothing logged yet');
    s.exercises.single.reps[0] = 5;
    await store.saveActive(s);
    final last = s.lastActivity!;
    expect(await store.autoFinish(last.add(const Duration(minutes: 20))), false);
    expect(await store.autoFinish(last.add(const Duration(minutes: 31))), true);
    expect((store.active, store.sessions.first.finishedAt), (null, last));

    SharedPreferences.setMockInitialValues({'session.autoFinish': false});
    final off = await Store.open();
    await off.saveActive(Session.start(w)..exercises.single.reps[0] = 5);
    expect(await off.autoFinish(DateTime.now().add(const Duration(hours: 5))), false, reason: 'switched off in the settings');
  });

  test('home facts: record, streak, gain, near miss, week, tonnage; nothing made up', () async {
    SharedPreferences.setMockInitialValues({});
    unit.value = WeightUnit.kg;
    final store = await Store.open();
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5),
      Exercise(name: 'Rudern', weight: 50, sets: 2, reps: 5),
    ]);
    await store.saveWorkout(a);
    final now = DateTime(2026, 11, 4); // Wednesday
    expect(homeFacts(store.sessions, store.workouts, now), isEmpty, reason: 'nothing trained yet');

    for (final day in [26, 28, 30, 2, 3]) {
      final s = Session.start(a);
      s.exercises[0].reps.setAll(0, [5, 5]);
      s.exercises[1].reps.setAll(0, day == 3 ? [5, 4] : [5, 5]); // last time 1 rep short
      await store.finishSession(s);
      store.sessions[0] = Session.fromJson({...s.toJson(), 'date': DateTime(2026, day > 20 ? 10 : 11, day).toIso8601String()});
    }
    final facts = {for (final (k, t) in homeFacts(store.sessions, store.workouts, now, perWeek: 2)) k: t};
    expect(facts[Fact.record], 'Kniebeuge: neues Höchstgewicht, 110 kg');
    expect(facts[Fact.streak], 'Kniebeuge: 5× in Folge alle Sätze geschafft');
    expect(facts[Fact.gain], 'Rudern: 50 → 60 kg seit 26.10.', reason: '+20 % beats +10 %');
    expect(facts[Fact.close], 'Rudern: nur 1 Wiederholung bis zur Steigerung');
    expect(facts[Fact.week], 'Woche geschafft ✓ · 2 Wochen in Folge');
    expect(facts.containsKey(Fact.pause), isFalse);
    expect(facts[Fact.tonnage], 'Insgesamt 7,9 t bewegt, noch 2,1 t bis 10 t');
    expect(facts.containsKey(Fact.today), isFalse, reason: 'last training was yesterday');
    expect(facts[Fact.next], 'Nächstes Mal schwerer: Kniebeuge 112,5 kg', reason: 'Rudern missed, stays');
    expect(facts.containsKey(Fact.fresh), isFalse, reason: 'trained since the first day');
    expect(facts.containsKey(Fact.journey), isFalse, reason: 'shorter than 120 days');
    final sameDay = homeFacts(store.sessions, store.workouts, DateTime(2026, 11, 3, 20));
    expect(sameDay.take(2).map((f) => f.$1), [Fact.record, Fact.today], reason: 'freshest first');
    expect(sameDay[1].$2, 'Heute 1,6 t bewegt (-1 % zum letzten Mal)');
  });

  test('home facts: an exercise skipped in every training does not crash', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final a = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5),
      Exercise(name: 'Rudern', weight: 50, sets: 2, reps: 5),
    ]);
    await store.saveWorkout(a);
    final s = Session.start(a);
    s.exercises[0].reps.setAll(0, [5, 5]); // Rudern skipped
    await store.finishSession(s);
    final facts = homeFacts(store.sessions, store.workouts, DateTime.now());
    expect(facts.map((f) => f.$2).join(), isNot(contains('Rudern')));
  });

  test('session recap: sets, volume vs last time, records; body weight, note and tags survive JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final w = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5),
      Exercise(name: 'Rudern', weight: 50, sets: 2, reps: 5),
    ]);
    await store.saveWorkout(w);

    Future<Session> train(DateTime date, List<int?> rows) async {
      final s = Session.start(w);
      final dated = Session(workoutId: s.workoutId, workoutName: s.workoutName, date: date, exercises: s.exercises);
      dated.exercises[0].reps.setAll(0, [5, 5]);
      dated.exercises[1].reps.setAll(0, rows);
      await store.finishSession(dated);
      return dated;
    }

    final first = await train(DateTime(2026, 11, 1), [5, 5]);
    var r = sessionRecap(first, store.sessions);
    expect((r.setsDone, r.sets, r.succeeded, r.volumeBefore), (4, 4, 2, null));
    expect(r.records, isEmpty, reason: 'a first training sets no record');

    final second = await train(DateTime(2026, 11, 3), [5, null]); // squat +2.5, a row set skipped
    r = sessionRecap(second, store.sessions);
    expect((r.setsDone, r.succeeded), (3, 1));
    expect(r.volume, 102.5 * 10 + 52.5 * 5);
    expect(r.volumeBefore, 100 * 10 + 50 * 10);
    expect(r.records, [('Kniebeuge', 102.5), ('Rudern', 52.5)]);

    second
      ..bodyWeight = 82.4
      ..note = 'Gut geschlafen'
      ..mood = 3
      ..tags = ['Alkohol', 'Stress'];
    await store.updateSession(second);
    final reopened = await Store.open();
    expect(reopened.sessions.first.bodyWeight, 82.4);
    expect(reopened.sessions.first.note, 'Gut geschlafen');
    expect(reopened.sessions.first.mood, 3);
    expect(reopened.sessions.first.tags, ['Alkohol', 'Stress']);
  });
}
