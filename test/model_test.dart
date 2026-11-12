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

  test('an exercise skipped entirely is not a miss', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final pullUps = Exercise(name: 'Klimmzüge', weight: 0, sets: 3, reps: 5, down: true, failsToDeload: 1);
    final w = Workout(name: 'A', exercises: [pullUps, Exercise(name: 'Kniebeuge', weight: 100, sets: 1, reps: 5)]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    s.exercises[1].reps[0] = 5;
    await store.finishSession(s);
    expect((pullUps.weight, pullUps.fails), (0, 0));
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

    ExerciseLog pull(List<int?> reps) => ExerciseLog(name: 'Klimmzüge', weight: 0, targetReps: 5, reps: reps);
    final pullUps = [(now.subtract(const Duration(days: 30)), pull([5, 4, 3])), (now, pull([5, 5, 5]))];
    expect(trendOf(pullUps, now)?.$1, Trend.up, reason: 'bodyweight: more reps is progress');
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

  test('assistance: negative weight, up means less help, through 0 into added weight; no 1RM or volume', () {
    unit.value = WeightUnit.kg;
    final e = Exercise(name: 'Klimmzüge', weight: -20, sets: 3, reps: 5, up: true, down: true, failsToDeload: 1);
    ExerciseLog log(double kg, List<int?> reps) => ExerciseLog(name: 'Klimmzüge', weight: kg, reps: reps, targetReps: 5);
    e.applyResult(log(-20, [5, 5, 5]));
    expect(e.weight, -17.5, reason: 'done: a step less help');
    e.applyResult(log(-17.5, [5, 4, 3]));
    expect(e.weight, -20, reason: 'deload: more help');
    final near = Exercise(name: 'Klimmzüge', weight: -2.5, sets: 1, reps: 5, up: true);
    near.applyResult(log(-2.5, [5]));
    near.applyResult(log(0, [5]));
    expect(near.weight, 2.5, reason: 'past 0 into added weight');
    final light = Exercise(name: 'Dips', weight: 2.5, sets: 1, reps: 5, down: true, failsToDeload: 1, decrement: 5);
    light.applyResult(ExerciseLog(name: 'Dips', weight: 2.5, reps: [2], targetReps: 5));
    expect(light.weight, 0, reason: 'added weight never turns into assistance by itself');

    expect((estimated1rm(log(-10, [5, 5, 5])), log(-10, [5, 5, 5]).volume), (0, 0));
    expect((weightLabel(-10), weightNum(-12.5)), ('−10 kg', '−12,5'));
    expect((parseWeight('−10'), parseWeight('-7,5')), (-10, -7.5));
    final back = Exercise.fromJson(jsonDecode(jsonEncode(e.toJson())));
    expect(back.weight, -20);
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

  test('changed during the training: swapped and added exercises and other set counts leave the plan as it is', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final w = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5, increment: 2.5),
      Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5, increment: 2.5),
      Exercise(name: 'Rudern', weight: 50, sets: 3, reps: 5, increment: 2.5),
      Exercise(name: 'Dips', weight: 10, sets: 3, reps: 8, increment: 2.5, setWeights: [10, 10, 5]),
    ]);
    await store.saveWorkout(w);
    final s = Session.start(w);
    final [squat, bench, row, dips] = s.exercises;
    // Kniebeuge: four sets instead of three, all hit. Bankdrücken: two of three, all hit.
    s.exercises[0] = squat.withSets(reps: [5, 5, 5, 5], targets: [5, 5, 5, 5], weights: [100, 100, 100, 100], doneAt: List.filled(4, null));
    s.exercises[1] = bench.withSets(reps: [5, 5], targets: [5, 5], weights: [60, 60], doneAt: [null, null]);
    // Rudern swapped for Kabelrudern before the first set; Dips four sets with their own per-set weights.
    s.exercises[2] = ExerciseLog.fromPlan(Exercise(name: 'Kabelrudern', weight: 45, sets: 3, reps: 10, restSeconds: 90), replaces: 'Rudern')
      ..reps.setAll(0, [10, 10, 10]);
    s.exercises[3] = dips.withSets(reps: [8, 8, 8, 8], targets: [8, 8, 8, 8], weights: [10, 10, 5, 5], doneAt: List.filled(4, null));
    s.exercises.add(ExerciseLog.fromPlan(Exercise(name: 'Facepulls', weight: 15, sets: 2, reps: 12), added: true)..reps.setAll(0, [12, 12]));
    await store.finishSession(s);

    expect([for (final e in w.exercises) (e.name, e.sets, e.weight)],
        [('Kniebeuge', 3, 102.5), ('Bankdrücken', 3, 60.0), ('Rudern', 3, 50.0), ('Dips', 3, 12.5)],
        reason: 'more sets: normal progression; fewer: weight holds; swapped out: untouched; no new plan entries');
    expect(w.exercises[3].setWeights, [12.5, 12.5, 7.5], reason: 'the plan keeps its three per-set weights');
    expect(w.exercises[1].fails, 0, reason: 'fewer sets is no miss');

    final j = jsonDecode(jsonEncode(s.toJson()))['exercises'] as List;
    expect((j[0]['replaces'], j[0]['restSeconds']), (null, null), reason: 'planned: rest lives in the plan');
    expect((j[2]['replaces'], j[2]['restSeconds'], j[4]['added']), ('Rudern', 90, true));
    final back = Session.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect((back.exercises[2].replaces, back.exercises[2].restSeconds, back.exercises[4].added), ('Rudern', 90, true));
  });

  test('reshaped: open sets take the edit, logged ones stay where they are', () {
    final log = ExerciseLog(name: 'Rudern', weight: 50, targetReps: 8, reps: [8, null, 7, null],
        doneAt: [DateTime(2026, 11, 12, 18), null, DateTime(2026, 11, 12, 18, 4), null]);
    final more = log.reshaped(Exercise(name: 'Rudern', weight: 55, sets: 5, reps: 10, maxReps: 12));
    expect(more.reps, [8, null, 7, null, null]);
    expect(more.targets, [8, 10, 8, 10, 10]);
    expect(more.weights, [50, 55, 50, 55, 55]);
    expect(more.doneAt, [DateTime(2026, 11, 12, 18), null, DateTime(2026, 11, 12, 18, 4), null, null]);
    expect(more.maxReps, 12);
    final fewer = log.reshaped(Exercise(name: 'Rudern', weight: 50, sets: 1, reps: 8));
    expect(fewer.reps, [8, null, 7], reason: 'never below the last logged set');
    final ramp = log.reshaped(Exercise(name: 'Rudern', sets: 4, reps: 8, setWeights: [40, 45, 50, 55], setReps: [10, 8, 8, 6]));
    expect(ramp.weights, [50, 45, 50, 55]);
    expect(ramp.targets, [8, 8, 8, 6]);
    final run = ExerciseLog(name: 'Laufen', weight: 0, targetReps: 20, reps: [null], cardio: true);
    expect(run.reshaped(Exercise.cardio(name: 'Laufen', minutes: 0, km: 5)).targetKm, 5);
  });
}
