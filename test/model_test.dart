import 'dart:convert';

import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('progressive overload and JSON round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final w = Workout(name: 'A', exercises: [
      Exercise(name: 'Kniebeuge', weight: 100, sets: 2, reps: 5, increment: 2.5),
      Exercise(name: 'Bankdrücken', weight: 60, sets: 2, reps: 5, increment: 2.5),
    ]);
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
    expect(weekStreak([DateTime(2026, 11, 2), DateTime(2026, 10, 30), DateTime(2026, 10, 19), DateTime(2026, 10, 5)], now), 3);
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
    final old = ExerciseLog.fromJson({'name': 'Squat', 'weight': 100, 'targetReps': 5, 'reps': [5, 5, 3]});
    expect(old.weights, [100, 100, 100]);
    final log = ExerciseLog(name: 'Bench', weight: 0, targetReps: 5, reps: [5, 5, 3], weights: [72.5, 72.5, 70]);
    expect(log.weight, 72.5);
    expect(log.volume, 5 * 72.5 * 2 + 3 * 70);
    expect(ExerciseLog.fromJson(log.toJson()).weights, [72.5, 72.5, 70]);
    expect(groupByWeight(log.weights, log.reps).map((g) => '${g.$1}: ${g.$2}'), ['72.5: [5, 5]', '70.0: [3]']);
  });

  test('cardio: one set of minutes, survives JSON, never auto-adjusted', () {
    final run = Exercise.cardio(name: 'Laufen', minutes: 30, km: 5);
    final w = Workout(name: 'Mix', exercises: [Exercise(name: 'Kniebeuge'), run]);
    final again = Workout.fromJson(jsonDecode(jsonEncode(w.toJson()))).exercises.last;
    expect((again.cardio, again.reps, again.km, again.sets), (true, 30, 5.0, 1));

    final log = Session.start(w).exercises.last;
    expect((log.cardio, log.targetReps, log.targetKm, log.reps.length, log.reps.first), (true, 30, 5.0, 1, null));
    log
      ..reps[0] = 25
      ..km = 4.2;
    final logAgain = ExerciseLog.fromJson(jsonDecode(jsonEncode(log.toJson())));
    expect((logAgain.cardio, logAgain.reps.single, logAgain.km, logAgain.succeeded), (true, 25, 4.2, false));
    expect(logAgain.volume, 0);

    run.applyResult(log);
    expect((run.reps, run.km, run.weight), (30, 5.0, 0.0));
  });

  test('weekly summary and 30-day weight change', () {
    final now = DateTime(2026, 11, 4); // Wednesday
    Session at(DateTime d, {int? cardioMinutes}) => Session(workoutId: 'w', workoutName: 'A', date: d, exercises: [
          ExerciseLog(name: 'Kniebeuge', weight: 80, targetReps: 5, reps: [5]),
          if (cardioMinutes != null)
            ExerciseLog(name: 'Laufen', weight: 0, targetReps: 30, reps: [cardioMinutes], cardio: true),
        ]);
    final weeks = weeklySummary(
        [at(DateTime(2026, 11, 3), cardioMinutes: 25), at(DateTime(2026, 11, 2)), at(DateTime(2026, 10, 28))], now,
        weeks: 3);
    expect(weeks.map((w) => (w.$1.day, w.$2, w.$3)), [(19, 0, 0), (26, 1, 0), (2, 2, 25)]);

    ExerciseLog squat(double kg) => ExerciseLog(name: 'Kniebeuge', weight: kg, targetReps: 5, reps: [5]);
    final history = [
      (DateTime(2026, 9, 20), squat(75)),
      (DateTime(2026, 10, 1), squat(77.5)),
      (DateTime(2026, 10, 20), squat(80)),
      (DateTime(2026, 11, 3), squat(82.5)),
    ];
    expect(weightChange(history, now)?.$1, 5, reason: '77,5 on Oct 1 (last before the window) → 82,5');
    expect(weightChange([history.last], now), isNull);
  });
}
