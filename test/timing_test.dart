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

  test('typical values: setup and execution for barbell lifts and holds', () {
    final pace = Pace([]);
    // 60 s setup + 5 × 4.5 s.
    expect(pace.of(shape('Kreuzheben', 1, 5, 120, 240)).inSeconds, 83);
    // 30 s setup + 3 × 30 s hold + 2 × 60 s rest.
    expect(pace.of(shape('Plank', 3, 30, 0, 60)), const Duration(minutes: 4));
    // 60 s setup + 3 × 10 × 3 s + 2 × 90 s.
    expect(pace.of(shape('Kurzhantelrudern', 3, 10, 20, 90)).inSeconds, 330);
    expect(aboutLabel(const Duration(seconds: 83)), '≈ 1 Min');
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
  group('restObservations', () {
    ExerciseLog bench(List<int?> reps, List<DateTime?> times, {int? rir, int? failRest}) => ExerciseLog(
        name: 'Bankdrücken', weight: 80, targetReps: 5, reps: reps, doneAt: times, rir: rir,
        restSeconds: 150, failRestSeconds: failRest);
    Session one(ExerciseLog log, [List<ExerciseLog> more = const [], List<String> tags = const []]) =>
        Session(workoutId: 'w', workoutName: 'A', date: start, exercises: [log, ...more], tags: tags);

    test('the rest belongs to the set after it; the work of that set is taken off', () {
      final log = bench([5, 5, 5, 5, 4], [at(1), at(4), at(7), at(10), at(13)], rir: 0);
      final obs = restObservations(one(log), log);
      expect(obs.map((o) => o.set), [1, 2, 3, 4], reason: 'none before the first set');
      expect(obs.first.rest, const Duration(minutes: 2, seconds: 37, milliseconds: 500), reason: '5 × 4.5 s barbell reps');
      expect(obs.last.rest, const Duration(minutes: 2, seconds: 42), reason: 'counted with the reps done');
      expect((obs.last.reps, obs.last.target, obs.last.kg, obs.last.rir), (4, 5, 80.0, 0));
      expect(obs.take(3).map((o) => o.rir), [null, null, null], reason: 'the reserve was asked after the last set');
      expect(obs.every((o) => o.kind == RestKind.normal && o.planned == 150 && o.priorMet && o.regular), isTrue);
    });

    test('after a miss the fail rest counts, and later sets know an earlier one fell short', () {
      final log = bench([5, 4, 5], [at(1), at(4), at(9)], failRest: 300);
      final obs = restObservations(one(log), log);
      expect((obs[0].kind, obs[0].planned, obs[0].priorMet), (RestKind.normal, 150, true));
      expect((obs[1].kind, obs[1].planned, obs[1].priorMet), (RestKind.afterMiss, 300, false));
      final noFail = bench([5, 4, 5], [at(1), at(4), at(9)]);
      expect(restObservations(one(noFail), noFail)[1].kind, RestKind.normal, reason: 'no fail rest set');
    });

    test('left out instead of guessed', () {
      final skipped = bench([5, 5, null, 5, 5], [at(1), at(4), null, at(10), at(13)]);
      expect(restObservations(one(skipped), skipped).map((o) => o.set), [1, 4], reason: 'no rest across a skipped set');
      final untimed = bench([5, 5, 5], [null, at(4), at(7)]);
      expect(restObservations(one(untimed), untimed).map((o) => o.set), [2]);
      final odd = bench([5, 5, 5], [at(1), at(1, 10), at(30)]);
      expect(restObservations(one(odd), odd), isEmpty, reason: 'negative and longer than 15 min');
      final backwards = bench([5, 5], [at(4), at(1)]);
      expect(restObservations(one(backwards), backwards), isEmpty);

      final log = bench([5, 5, 5], [at(1), at(6), at(9)]);
      final curls = ExerciseLog(name: 'Curls', weight: 12, targetReps: 10, reps: [10], doneAt: [at(3)]);
      expect(restObservations(one(log, [curls]), log).map((o) => o.set), [2], reason: 'curls in between');
      final cardio = ExerciseLog(name: 'Laufen', weight: 0, targetReps: 20, reps: [null], cardio: true);
      expect(restObservations(one(cardio), cardio), isEmpty);
    });

    test('swaps, comebacks, pain and bad days are not regular', () {
      final log = bench([5, 5], [at(1), at(4)]);
      expect(restObservations(one(log, const [], ['Schmerzen']), log).single.regular, isFalse);
      expect(restObservations(one(log, const [], ['Stress']), log).single.regular, isFalse);
      expect(restObservations(one(log, const [], ['Studio voll']), log).single.regular, isTrue);
      final swapped = ExerciseLog(name: 'Bankdrücken', weight: 80, targetReps: 5, reps: [5, 5], doneAt: [at(1), at(4)],
          replaces: 'Schrägbankdrücken');
      expect(restObservations(one(swapped), swapped).single.regular, isFalse);
      final comeback = ExerciseLog(name: 'Bankdrücken', weight: 70, targetReps: 5, reps: [5, 5], doneAt: [at(1), at(4)],
          backoff: 10);
      expect(restObservations(one(comeback), comeback).single.regular, isFalse);
    });

    test('shown to the half minute', () {
      expect([20, 100, 120, 150, 170, 200].map((s) => restAboutLabel(Duration(seconds: s))),
          ['rund ½ Min', 'rund 1½ Min', 'rund 2 Min', 'rund 2½ Min', 'rund 3 Min', 'rund 3½ Min']);
    });
  });
}

