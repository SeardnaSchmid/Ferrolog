import 'package:ferrolog/model.dart';
import 'package:ferrolog/timing.dart';
import 'package:flutter_test/flutter_test.dart';

final start = DateTime(2026, 11, 2, 18);
DateTime at(int minutes, [int seconds = 0]) => start.add(Duration(minutes: minutes, seconds: seconds));

/// A training of bench press (3 sets) then rows (3 sets), with the minutes each set was logged.
Session training(DateTime day, List<int> bench, List<int> rows) {
  final d = day.difference(start);
  ExerciseLog log(String name, List<int> minutes) => ExerciseLog(
        name: name,
        weight: 60,
        targetReps: 5,
        reps: [for (final _ in minutes) 5],
        doneAt: [for (final m in minutes) at(m).add(d)],
      );
  return Session(workoutId: 'w', workoutName: 'A', date: day, exercises: [log('Bankdrücken', bench), log('Kurzhantelrudern', rows)]);
}

Shape shape(String name, int sets, int reps, double kg, int rest) =>
    (name: name, sets: sets, reps: reps, kg: kg, rest: rest, cardio: false, minutes: 0, km: null, timed: name == 'Plank');

void main() {
  test('measured: from the set before (or the start) to the exercise last set', () {
    final s = training(start, [5, 8, 11], [14, 16, 18]);
    final bench = measured(s, s.exercises[0])!, rows = measured(s, s.exercises[1])!;
    expect((bench.total, bench.first), (const Duration(minutes: 11), const Duration(minutes: 5)));
    expect(bench.gaps, [const Duration(minutes: 3), const Duration(minutes: 3)]);
    expect((rows.total, rows.first), (const Duration(minutes: 7), const Duration(minutes: 3)),
        reason: 'starts at the last bench set');
    expect(timeTaken(s, 'Bankdrücken', perSet: true), '11 Min · alle 3:00 Min ein Satz');

    final json = Session.fromJson(s.toJson());
    expect(json.exercises[0].doneAt, s.exercises[0].doneAt);
    expect(ExerciseLog.fromJson({'name': 'X', 'weight': 0, 'targetReps': 5, 'reps': [5]}).doneAt, [null],
        reason: 'older data has no timestamps');
  });

  test('typical values: warm-ups for heavy barbell lifts, seconds for holds', () {
    final pace = Pace([]);
    // 60 s + 5 warm-ups (20 → 120 kg in steps of half again) + 5 × 4.5 s.
    expect(pace.of(shape('Kreuzheben', 1, 5, 120, 240)).inSeconds, 383);
    // 30 s setup + 3 × 30 s hold + 2 × 60 s rest.
    expect(pace.of(shape('Plank', 3, 30, 0, 60)), const Duration(minutes: 4));
    // 60 s setup + 3 × 10 × 3 s + 2 × 90 s.
    expect(pace.of(shape('Kurzhantelrudern', 3, 10, 20, 90)).inSeconds, 330);
    expect(aboutLabel(const Duration(seconds: 383)), '≈ 6 Min');
    expect(aboutLabel(const Duration(minutes: 65)), '≈ 1:05 h');
  });

  test('own pace: medians of the last trainings replace the typical values', () {
    final sessions = [
      for (var i = 0; i < 3; i++) training(start.subtract(Duration(days: 2 * i)), [6, 10, 14], [16, 18, 20]),
    ];
    final pace = Pace(sessions);
    // 6 min to the first set, then 4 min from set to set.
    expect(pace.of(shape('Bankdrücken', 3, 5, 60, 180)), const Duration(minutes: 14));
    expect(pace.of(shape('Bankdrücken', 5, 5, 60, 180)), const Duration(minutes: 22));

    // Running: the next set counts from the last one done.
    final log = ExerciseLog(name: 'Bankdrücken', weight: 60, targetReps: 5, reps: [5, null, null], doneAt: [at(6), null, null]);
    expect(pace.left(log, shape('Bankdrücken', 3, 5, 60, 180), at(7)), const Duration(minutes: 7));
    expect(pace.left(log, shape('Bankdrücken', 3, 5, 60, 180), at(20)), const Duration(minutes: 4), reason: 'overdue: one gap left');
  });

  test('own tempo scales the typical values of exercises not measured yet', () {
    // Five trainings where rows took twice the typical time.
    final typical = Pace([]).of(shape('Kurzhantelrudern', 3, 5, 60, 120));
    final slow = [
      for (var i = 0; i < 5; i++)
        Session(workoutId: 'w', workoutName: 'A', date: start.subtract(Duration(days: i)), exercises: [
          ExerciseLog(name: 'Kurzhantelrudern', weight: 60, targetReps: 5, reps: [5, 5, 5], doneAt: [
            for (var j = 1; j <= 3; j++) start.subtract(Duration(days: i)).add(typical * (2 * j / 3)),
          ]),
        ]),
    ];
    expect(Pace(slow).factor, closeTo(1.6, .01), reason: 'capped');
  });

  test('timed exercises: seconds, no volume or 1RM, kept in the data', () {
    final log = ExerciseLog(name: 'Farmers Walk', weight: 24, targetReps: 30, reps: [30, 25], timed: true);
    expect((log.volume, estimated1rm(log)), (0.0, 0.0));
    final back = ExerciseLog.fromJson(log.toJson());
    expect((back.timed, back.weight), (true, 24.0));
    final e = Exercise.fromJson(Exercise(name: 'Plank', weight: 0, sets: 3, reps: 30, timed: true).toJson());
    expect((e.timed, setsLabel(e.repsPerSet, null, seconds: true)), (true, '3×30 s'));
    expect(Session.start(Workout(name: 'W', exercises: [e])).exercises.single.timed, isTrue);
  });
}

