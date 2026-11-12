import 'dart:convert';

import 'package:ferrolog/model.dart';
import 'package:ferrolog/units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExerciseLog _log(double kg, List<int?> reps, {int target = 5, int? rir, int? maxReps, List<double>? weights}) =>
    ExerciseLog(name: 'Kniebeuge', weight: kg, targetReps: target, reps: reps, rir: rir, maxReps: maxReps, weights: weights);

Exercise _squat({double kg = 100}) => Exercise(name: 'Kniebeuge', weight: kg, sets: 3, reps: 5, auto: true);

void main() {
  setUp(() => unit.value = WeightUnit.kg);

  test('done: 2,5 % of the weight on the load step, steered by the reserve', () {
    for (final (rir, reps, kg, p) in [
      (null, [5, 5, 5], 102.5, Progression.up),
      (1, [5, 5, 5], 102.5, Progression.up),
      (2, [5, 5, 5], 102.5, Progression.up),
      (3, [5, 5, 5], 105.0, Progression.up2),
      (4, [5, 5, 5], 105.0, Progression.up2),
      (1, [5, 5, 7], 105.0, Progression.up2), // two reps beyond the target count as reserve
      (null, [5, 5, 8], 105.0, Progression.up2),
      (0, [5, 5, 5], 100.0, Progression.limit),
    ]) {
      final e = _squat()..fails = 1;
      expect(e.applyResult(_log(100, reps, rir: rir), grid: 2.5), p, reason: 'rir $rir, $reps');
      expect((e.weight, e.fails), (kg, 0), reason: 'rir $rir, $reps');
    }
    final limit = _squat();
    expect(limit.applyResult(_log(100, [5, 5, 5], rir: 0), grid: 2.5), Progression.limit);
    expect(limit.applyResult(_log(100, [5, 5, 5], rir: 0), grid: 2.5), Progression.half, reason: 'twice at the limit');
    expect(limit.weight, 102.5);
    expect(_squat(kg: 200).applyResult(_log(200, [5, 5, 5]), grid: 1), Progression.up);
    final heavy = _squat(kg: 200)..applyResult(_log(200, [5, 5, 5]), grid: 1);
    expect(heavy.weight, 205);
    final assisted = _squat(kg: -20)..applyResult(_log(-20, [5, 5, 5]), grid: 2.5);
    expect(assisted.weight, -17.5, reason: 'assistance: a step less help');
  });

  test('the share adapts: halved by a deload, doubled back by easy trainings', () {
    final e = _squat();
    for (final p in [Progression.miss, Progression.miss, Progression.deload]) {
      expect(e.applyResult(_log(100, [5, 5, 3]), grid: 2.5), p);
    }
    expect((e.weight, e.state!.pct), (90.0, 1.25));
    expect(e.applyResult(_log(90, [5, 5, 5], rir: 1), grid: 2.5), Progression.bridge,
        reason: '1,25 % of 90 kg is 1,1 kg, less than half a load step: one rep more first');
    expect((e.weight, e.reps), (90.0, 6));
    expect(e.applyResult(_log(90, [6, 6, 6], target: 6, rir: 1), grid: 2.5), Progression.up);
    expect((e.weight, e.reps), (92.5, 5));
    for (var i = 0; i < 3; i++) {
      e.applyResult(_log(92.5, [5, 5, 3]), grid: 2.5);
    }
    expect((e.weight, e.state!.pct), (82.5, .625));
    for (var i = 0; i < 6; i++) {
      e.applyResult(_log(e.weight, [5, 5, 5], rir: 2), grid: 2.5);
    }
    expect(e.state!.pct, 2.5, reason: 'doubled after each 3 in a row with reserve, capped');
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

  test('a step too small to load is bridged by reps; a second miss ends the bridge', () {
    final e = Exercise(name: 'Kurzhantel-Curls', weight: 12, sets: 3, reps: 10, auto: true);
    ExerciseLog done(int reps, {int? rir}) =>
        ExerciseLog(name: e.name, weight: 12, targetReps: reps, reps: [reps, reps, reps], rir: rir);
    expect(e.applyResult(done(10), grid: 2), Progression.bridge);
    expect((e.reps, e.state!.bridgeFrom, e.state!.bridgeTo), (11, 10, 13), reason: '2 kg on 12 kg: three reps');
    expect(progressionLabel(Progression.bridge, e), 'nächstes Mal 11 Wdh., bei 13 mehr Gewicht');
    expect(e.applyResult(done(11, rir: 3), grid: 2), Progression.bridge);
    expect(e.reps, 13, reason: 'two reps with reserve');
    expect(e.applyResult(done(13), grid: 2), Progression.up);
    expect((e.weight, e.reps, e.state!.bridgeFrom), (14.0, 10, null));

    final m = Exercise(name: 'Kurzhantel-Curls', weight: 12, sets: 2, reps: 10, setReps: [10, 8], auto: true);
    m.applyResult(ExerciseLog(name: m.name, weight: 12, targetReps: 10, targets: [10, 8], reps: [10, 8]), grid: 2);
    expect(m.reps, 11);
    expect(m.setReps, [11, 9]);
    final miss = ExerciseLog(name: m.name, weight: 12, targetReps: 11, targets: [11, 9], reps: [11, 7]);
    expect(m.applyResult(miss, grid: 2), Progression.miss);
    expect(m.reps, 11, reason: 'the first miss keeps the bridge');
    expect(m.applyResult(miss, grid: 2), Progression.reset);
    expect((m.reps, m.state!.bridgeTo), (10, null));
    expect(m.setReps, [10, 8]);

    final range = Exercise(name: 'Kurzhantel-Curls', weight: 12, sets: 3, reps: 8, maxReps: 12, auto: true);
    expect(range.applyResult(_log(12, [12, 11, 10], target: 8, maxReps: 12), grid: 2), Progression.range);
    expect(range.applyResult(_log(12, [12, 12, 12], target: 8, maxReps: 12), grid: 2), Progression.up);
    expect((range.weight, range.reps), (14.0, 8), reason: 'a range is its own bridge');
  });

  test('back from a break: double steps up to the weight from before, not beyond', () {
    final e = _squat(kg: 90)..state = AutoState(comebackTo: 100);
    expect(e.applyResult(_log(90, [5, 5, 5], rir: 1), grid: 2.5), Progression.up);
    expect(e.weight, 95);
    e.applyResult(_log(95, [5, 5, 5], rir: 4), grid: 2.5);
    expect((e.weight, e.state!.comebackTo), (100.0, null));
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
      s.exercises[2].reps.setAll(0, List.filled(3, s.exercises[2].targets.first));
      s.tags = [...tags];
      await store.finishSession(s, at: date.add(const Duration(hours: 1)));
      return s;
    }

    test('load steps: the plates, learned from the weights used, else a start value', () async {
      expect(store.loadStepOf(w.exercises[0]), (1.0, LoadSource.plates), reason: 'smallest default plate 0,5 kg');
      await (await SharedPreferences.getInstance()).setStringList('barbell.plates.kg', ['20', '10', '5', '2.5', '1.25']);
      expect(store.loadStepOf(w.exercises[0]), (2.5, LoadSource.plates));
      expect(store.loadStepOf(w.exercises[2]), (2.0, LoadSource.guess));
      expect(store.loadStepOf(Exercise(name: 'Latzug')), (2.5, LoadSource.guess));
      final raise = Exercise(name: 'Seitheben', weight: 10, increment: 1.25);
      expect(store.loadStepOf(raise), (1.25, LoadSource.guess));
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
      expect(Exercise.fromJson((press..auto = false).toJson()).loadStep, isNull, reason: 'auto mode only');
    });

    test('a leg press set to 5 kg steps: rounds to 5, bridges below', () async {
      final legs = Exercise(name: 'Beinpresse', weight: 150, sets: 3, reps: 10, auto: true, loadStep: 5);
      final grid = store.loadStepOf(legs).$1;
      ExerciseLog done(double kg) => ExerciseLog(name: 'Beinpresse', weight: kg, targetReps: 10, reps: [10, 10, 10]);
      expect(legs.applyResult(done(150), grid: grid), Progression.up);
      expect(legs.weight, 155, reason: '2,5 % of 150 = 3,75 kg rounds to one 5-kg step');
      legs.state!.pct = 1.25;
      expect(legs.applyResult(done(155), grid: grid), Progression.bridge, reason: '1,9 kg is less than half a step');
    });

    test('a training: auto steps by the plates, a bridge for the curls, fixed stays fixed', () async {
      final s = await train(DateTime(2026, 11, 2, 18), [5, 5, 5], rir: 3);
      expect(w.exercises[0].weight, 105, reason: '5 % of 100 on 1 kg steps');
      expect(s.exercises[0].progression, Progression.up2);
      expect((w.exercises[1].weight, s.exercises[1].progression), (62.5, null));
      expect((w.exercises[2].weight, w.exercises[2].reps), (12.0, 11));
      expect(s.exercises[2].progression, Progression.bridge);

      await store.deleteSession(s);
      expect((w.exercises[0].weight, w.exercises[2].reps), (100.0, 10), reason: 'deleting takes the bridge back too');
      expect(w.exercises[2].state, isNull);
    });

    test('back after a break: 5/10/20 % lighter, then double steps back', () async {
      await train(DateTime(2026, 10, 1, 18), [5, 5, 5]);
      expect(w.exercises[0].weight, 103, reason: '2,5 kg rounds to 3 one-kg steps');
      for (final (now, pct) in [
        (DateTime(2026, 10, 14), null),
        (DateTime(2026, 10, 16), 5),
        (DateTime(2026, 10, 30), 10),
        (DateTime(2026, 11, 27), 20),
      ]) {
        expect(store.comebackOf(w.exercises[0], now), pct, reason: '$now');
      }
      expect(store.comebackOf(w.exercises[1], DateTime(2026, 11, 30)), isNull, reason: 'fixed mode');

      final s = await train(DateTime(2026, 10, 20, 18), [5, 5, 5]);
      expect(s.exercises[0].backoff, 5);
      expect(s.exercises[0].weights, [97, 97, 97], reason: '103 × 0,95 = 97,85, down to whole kg');
      expect(s.exercises[1].weights, [62.5, 62.5, 62.5], reason: 'fixed mode starts as planned');
      expect((w.exercises[0].weight, w.exercises[0].state!.comebackTo), (102.0, 103.0), reason: 'double step: +5');

      await store.deleteSession(s);
      expect((w.exercises[0].weight, w.exercises[0].state?.comebackTo), (103.0, null));
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
      final s = await train(DateTime(2026, 10, 1, 18), [5, 5, 5]);
      expect(Session.fromJson(jsonDecode(jsonEncode(s.toJson()))).exercises[0].progression, Progression.up);
      final back = Exercise.fromJson(jsonDecode(jsonEncode(w.exercises[2].toJson())));
      expect((back.auto, back.state?.bridgeFrom, back.state?.bridgeTo, back.state?.pct), (true, 10, 13, 2.5));
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
