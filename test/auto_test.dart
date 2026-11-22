import 'dart:convert';

import 'package:ferrolog/loading.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExerciseLog _log(double kg, List<int?> reps, {int target = 5, int? rir, int? maxReps, List<double>? weights}) =>
    ExerciseLog(name: 'Kniebeuge', weight: kg, targetReps: target, reps: reps, rir: rir, maxReps: maxReps, weights: weights);

Exercise _squat({double kg = 100}) => Exercise(name: 'Kniebeuge', weight: kg, sets: 3, reps: 5, auto: true);

void main() {
  setUp(() => unit.value = WeightUnit.kg);

  test('uses the last set reserve and the original target to choose weight or another rep', () {
    final light = _squat(kg: 10)..reps = 6;
    light.state = AutoState(bridgeFrom: 5);
    final log = _log(10, [6, 6, 6], target: 6, rir: 2);
    expect(light.applyResult(log, grid: .5), Progression.up);
    expect((light.weight, light.reps, light.state!.bridgeFrom), (10.5, 5, null));

    final coarse = _squat(kg: 10)..reps = 6;
    coarse.state = AutoState(bridgeFrom: 5);
    expect(coarse.applyResult(_log(10, [6, 6, 6], target: 6), grid: 2.5), Progression.reserveNeeded);
    expect(coarse.applyResult(_log(10, [6, 6, 6], target: 6, rir: 1), grid: 2.5), Progression.limit);
    expect(coarse.applyResult(log, grid: 2.5), Progression.bridge);
    expect((coarse.weight, coarse.reps, coarse.state!.bridgeFrom), (10, 7, 5));
    expect(progressionLabel(Progression.bridge, coarse), 'Wiederholungsbrücke: Ziel 7, ursprünglich 5 Wdh.');
    expect(coarse.applyResult(_log(10, [7, 7, 7], target: 7, rir: 2), grid: 2.5), Progression.bridge);
    expect(coarse.applyResult(_log(10, [8, 8, 8], target: 8, rir: 4), grid: 2.5), Progression.stepTooLarge);
    expect((coarse.weight, coarse.reps), (10, 8));
  });

  test('deload moves down by whole steps from the actual load', () {
    final e = _squat(kg: 101)..loadStep = 5;
    for (final p in [Progression.miss, Progression.miss, Progression.deload]) {
      expect(e.applyResult(_log(101, [5, 5, 3])), p);
    }
    expect(e.weight, 86);
    expect(deloadTo(92, 5), 82);
    expect(deloadTo(12.5, 10), 2.5);
    expect(deloadTo(10, 10), 10);
  });

  test('bad days excuse twice in a row; pain holds everything', () {
    final e = _squat();
    expect(e.applyResult(_log(100, [5, 4, 4]), grid: 2.5, badDay: true), Progression.badDay);
    expect(e.applyResult(_log(100, [5, 4, 4]), grid: 2.5, badDay: true), Progression.badDay);
    expect(e.fails, 0);
    expect(e.applyResult(_log(100, [5, 4, 4]), grid: 2.5, badDay: true), Progression.miss, reason: 'the third counts');
    expect(e.fails, 1);
    expect(e.applyResult(_log(100, [5, 5, 5], rir: 4), grid: 2.5, pain: true), Progression.pain);
    expect((e.weight, e.fails), (100.0, 1));
  });

  test('the bridge keeps different set targets and a second miss ends it', () {
    final e = Exercise(name: 'Curls', weight: 12, sets: 2, reps: 10, setReps: [10, 8], auto: true);
    ExerciseLog done(double kg, List<int> targets, List<int> reps) =>
        ExerciseLog(name: e.name, weight: kg, targetReps: targets.first, targets: targets, reps: reps, rir: 2);
    expect(e.applyResult(done(12, [10, 8], [10, 8]), grid: 2), Progression.bridge);
    expect(e.repsPerSet, [11, 9]);
    final miss = done(12, [11, 9], [11, 7]);
    expect(e.applyResult(miss, grid: 2), Progression.miss);
    expect(e.applyResult(miss, grid: 2), Progression.reset);
    expect(e.repsPerSet, [10, 8]);
  });

  test('a deliberate rep range stays in place, including at the top', () {
    final range = Exercise(name: 'Curls', weight: 12, sets: 3, reps: 8, maxReps: 12, auto: true);
    expect(range.applyResult(_log(12, [12, 11, 10], target: 8, maxReps: 12), grid: 2), Progression.range);
    expect(range.applyResult(_log(12, [12, 12, 12], target: 8, maxReps: 12, rir: 2), grid: 2), Progression.stepTooLarge);
    expect((range.weight, range.reps, range.maxReps), (12, 8, 12));
    expect(range.applyResult(_log(12, [12, 12, 12], target: 8, maxReps: 12, rir: 3), grid: .5), Progression.up);
    expect((range.weight, range.reps, range.maxReps), (12.5, 8, 12));
  });

  test('the fixed mode is untouched', () {
    final fixed = Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5);
    expect(fixed.applyResult(_log(100, [5, 5, 5], rir: 4)), isNull);
    expect(fixed.weight, 102.5);
    expect(fixed.state, isNull);
  });

  group('store', () {
    late Store store;
    late Workout w;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = Store(await SharedPreferences.getInstance());
      w = Workout(name: 'A', exercises: [
        Exercise(name: 'Kniebeuge', weight: 100, sets: 3, reps: 5, auto: true),
        Exercise(name: 'Bankdrücken', weight: 60, sets: 3, reps: 5),
        Exercise(name: 'Kurzhantel-Curls', weight: 12, sets: 3, reps: 10, auto: true),
      ]);
      await store.saveWorkout(w);
    });

    Future<Session> train(DateTime date, List<int> squat, {int? rir, List<String> tags = const []}) async {
      final s = store.startSession(w, date)..date = date;
      s.exercises[0]
        ..reps.setAll(0, squat)
        ..rir = rir;
      s.exercises[1].reps.setAll(0, [5, 5, 5]);
      s.exercises[2]
        ..reps.setAll(0, List.filled(3, s.exercises[2].targets.first))
        ..rir = 2;
      s.tags = [...tags];
      await store.finishSession(s, at: date.add(const Duration(hours: 1)));
      return s;
    }

    test('load steps: the exercise’s plates, learned from the weights used, else a start value', () {
      expect(store.loadStepOf(w.exercises[0]), (2.5, LoadSource.guess));
      w.exercises[0].barbellSetups = {WeightUnit.kg: BarbellSetup(20, [20, 10, 5, 2.5, 1.25])};
      expect(store.loadStepOf(w.exercises[0]), (2.5, LoadSource.plates));
      expect(store.loadStepOf(w.exercises[1]), (2.5, LoadSource.guess), reason: 'bench keeps its own setup');
      expect(store.loadStepOf(w.exercises[2]), (2.0, LoadSource.guess));
      expect(store.loadStepOf(Exercise(name: 'Latzug')), (2.5, LoadSource.guess));
      final raise = Exercise(name: 'Seitheben', weight: 10, increment: 1.25);
      expect(store.loadStepOf(raise), (2.5, LoadSource.guess));
      store.sessions = [
        for (final (i, kg) in [6.0, 8.0, 10.0].indexed)
          Session(workoutId: 'x', workoutName: 'X', date: DateTime(2026, 10, i + 1), exercises: [
            ExerciseLog(name: 'Seitheben', weight: kg, targetReps: 12, reps: [12]),
          ]),
      ];
      expect(store.loadStepOf(raise), (2.0, LoadSource.learned));
      raise.loadStep = 2.5;
      expect(store.loadStepOf(raise), (2.5, LoadSource.set), reason: 'set by hand wins');
      final press = Exercise(name: 'Kniebeuge', weight: 100, auto: true, loadStep: 5);
      expect(store.loadStepOf(press), (5.0, LoadSource.set), reason: 'over the plates too');
      expect(Exercise.fromJson(press.toJson()).loadStep, 5);
      expect(Exercise.fromJson((press..auto = false).toJson()).loadStep, 5, reason: 'fixed mode keeps the step too');
    });

    test('fixed mode accepts whole multiples of the configured step', () {
      final fixed = Exercise(name: 'Beinpresse', weight: 100, sets: 3, reps: 5, loadStep: 5);
      fixed.applyResult(_log(100, [5, 5, 5]));
      expect(fixed.weight, 100);
      fixed.increment = 10;
      fixed.applyResult(_log(100, [5, 5, 5]));
      expect(fixed.weight, 110);
      expect(ExerciseLog.fromJson(ExerciseLog.fromPlan(fixed).toJson()).loadStep, 5);
    });

    test('a training: auto takes one step, curls bridge, fixed progression still works', () async {
      final s = await train(DateTime(2026, 11, 2, 18), [5, 5, 5], rir: 3);
      expect(w.exercises[0].weight, 102.5, reason: 'one available step');
      expect(s.exercises[0].progression, Progression.up);
      expect((w.exercises[1].weight, s.exercises[1].progression), (62.5, null));
      expect((w.exercises[2].weight, w.exercises[2].reps), (12.0, 11));
      expect(s.exercises[2].progression, Progression.bridge);

      await store.deleteSession(s);
      expect((w.exercises[0].weight, w.exercises[2].reps), (100.0, 10), reason: 'deleting takes the bridge back too');
      expect(w.exercises[2].state, isNull);
    });

    test('back after a break: 5/10/20 % lighter, then standard progression', () async {
      await train(DateTime(2026, 10, 1, 18), [5, 5, 5], rir: 3);
      expect(w.exercises[0].weight, 102.5);
      for (final (now, pct) in [
        (DateTime(2026, 10, 14), null),
        (DateTime(2026, 10, 16), 5),
        (DateTime(2026, 10, 30), 10),
        (DateTime(2026, 11, 27), 20),
      ]) {
        expect(store.comebackOf(w.exercises[0], now), pct, reason: '$now');
      }
      expect(store.comebackOf(w.exercises[1], DateTime(2026, 11, 30)), isNull, reason: 'fixed mode');

      final s = await train(DateTime(2026, 10, 20, 18), [5, 5, 5], rir: 2);
      expect(s.exercises[0].backoff, 5);
      expect(s.exercises[0].weights, [95, 95, 95], reason: 'three 2.5 kg steps below 102.5');
      expect(s.exercises[1].weights, [62.5, 62.5, 62.5], reason: 'fixed mode starts as planned');
      expect(w.exercises[0].weight, 97.5);

      await store.deleteSession(s);
      expect(w.exercises[0].weight, 102.5);
    });

    test('tags entered on the recap: a bad day excuses, pain holds, the mood doesn\'t count', () async {
      final s = await train(DateTime(2026, 11, 2, 18), [5, 5, 3]);
      expect((w.exercises[0].fails, s.exercises[0].progression), (1, Progression.miss));
      s.tags = ['Stress'];
      await store.updateSession(s, replan: true);
      expect((w.exercises[0].fails, s.exercises[0].progression), (0, Progression.badDay));
      s
        ..tags = []
        ..mood = 1;
      await store.updateSession(s, replan: true);
      expect((w.exercises[0].fails, s.exercises[0].progression), (1, Progression.miss));
      s.tags = ['Schmerzen'];
      await store.updateSession(s, replan: true);
      expect((w.exercises[0].fails, s.exercises[0].progression), (0, Progression.pain));
    });

    test('stored and exported', () async {
      final s = await train(DateTime(2026, 10, 1, 18), [5, 5, 5], rir: 3);
      expect(Session.fromJson(jsonDecode(jsonEncode(s.toJson()))).exercises[0].progression, Progression.up);
      final back = Exercise.fromJson(jsonDecode(jsonEncode(w.exercises[2].toJson())));
      expect((back.auto, back.reps, back.state?.bridgeFrom), (true, 11, 10));
      expect(w.exercises[1].toJson().keys, isNot(anyElement(startsWith('auto'))));
      final reopened = Store(await SharedPreferences.getInstance());
      expect(reopened.sessions.first.planBefore?['Kurzhantel-Curls']?.auto?['reps'], 10);
      final later = store.startSession(w, DateTime(2026, 11, 1));
      expect(ExerciseLog.fromJson(later.exercises[0].toJson()).backoff, 10);
      expect(later.exercises[0].reshaped(w.exercises[0]).backoff, 10, reason: 'editing during the training keeps it');
      final format = jsonDecode(store.exportJson())['format'] as String;
      expect(format, allOf(contains('"auto": true'), contains('autoState'), contains('exercises[].backoff'),
          contains('exercises[].progression')));
    });
  });
}
