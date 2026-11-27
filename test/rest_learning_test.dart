import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/rest_learning.dart';
import 'package:ferrolog/timing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Exercise bench({int rest = 120}) =>
    Exercise(name: 'Bankdrücken', weight: 80, sets: 5, reps: 5, restSeconds: rest, learnRest: true);

/// A training on day [day] of November: sets of [reps] with [rests] before the second set on (the taps
/// lie apart by the rest plus 4.5 s a rep).
Session sets(int day, List<int> rests, List<int> reps,
    {double kg = 80, int target = 5, int? trialSet, int? trialSeconds, int? rir, Progression? progression}) {
  final t0 = DateTime(2026, 11, day, 18);
  final times = [t0];
  for (var i = 1; i < reps.length; i++) {
    times.add(times.last.add(Duration(seconds: rests[i - 1]) + Duration(milliseconds: reps[i] * 4500)));
  }
  final log = ExerciseLog(
    name: 'Bankdrücken',
    weight: kg,
    targetReps: target,
    reps: reps,
    doneAt: times,
    trialSet: trialSet,
    trialSeconds: trialSeconds,
    progression: progression,
  )..rir = rir;
  return Session(workoutId: 'w', workoutName: 'A', date: t0, exercises: [log]);
}

/// Three minutes before sets 2 to 4, then the last set with [last] reps after [rest] seconds.
Session training(int day, int rest, int last, {double kg = 80, int? trialSeconds, Progression? progression}) =>
    sets(day, [180, 180, 180, rest], [5, 5, 5, 5, last],
        kg: kg, trialSet: trialSeconds == null ? null : 4, trialSeconds: trialSeconds, progression: progression);

/// Adds [n] sets of [name] (Dips share the chest with the bench press, squats don't) 3 min apart, before
/// the bench press or [after] it; without timestamps unless [timed].
Session plus(Session s, String name, int n, {bool after = false, bool timed = true}) {
  final bench = s.exercises.first;
  final t = after ? bench.doneAt.last!.add(const Duration(minutes: 3)) : bench.doneAt.first!.subtract(Duration(minutes: 3 * n));
  s.exercises.add(ExerciseLog(
    name: name,
    weight: 0,
    targetReps: 10,
    reps: List.filled(n, 10),
    doneAt: [for (var i = 0; i < n; i++) timed ? t.add(Duration(minutes: 3 * i)) : null],
  ));
  return s;
}

/// Newest first, like the store.
List<Session> history(List<Session> s) => s..sort((a, b) => b.date.compareTo(a.date));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
  });

  // Before the last set after about 2 min 1 of 4, after about 2½ min 3 of 4: test 2:30.
  List<Session> pattern({double kg = 80}) => history([
        for (final (day, rest, reps) in [(1, 120, 4), (3, 120, 4), (5, 150, 5), (7, 120, 5), (9, 150, 5), (11, 120, 4), (13, 150, 4), (15, 150, 5)])
          training(day, rest, reps, kg: kg),
      ]);

  test('suggests a longer rest before a set that fails after shorter rests', () {
    final g = restSuggestion(pattern(), bench())!;
    expect((g.change, g.set, g.seconds, g.current), (RestChange.longer, 4, 150, 120));
    expect((g.before, g.beforeMet, g.beforeN, g.met, g.n), (120, 1, 4, 3, 4));
    expect(restNeedsVariety(pattern(), bench()), isNull);
  });

  test('no suggestion without different rests, enough days or a better longer rest', () {
    final same = history([for (final (d, r) in [(1, 4), (3, 5), (5, 4), (7, 4), (9, 5), (11, 5)]) training(d, 120, r)]);
    expect(restSuggestion(same, bench()), isNull, reason: 'six trainings at one rest compare nothing');
    expect(restNeedsVariety(same, bench()), 4);
    expect(restNeedsVariety(history([for (final d in [1, 3, 5]) training(d, 120, 5)]), bench()), isNull,
        reason: 'all reached: nothing to look into');

    final twoDays = history([training(1, 120, 4), training(3, 120, 4), training(5, 120, 5), training(7, 150, 5), training(9, 150, 5)]);
    expect(restSuggestion(twoDays, bench()), isNull, reason: 'only two trainings at the longer rest');
    final notBetter = history([
      for (final (d, r) in [(1, 4), (3, 4), (5, 5)]) training(d, 120, r),
      for (final (d, r) in [(7, 4), (9, 4), (11, 5)]) training(d, 150, r),
    ]);
    expect(restSuggestion(notBetter, bench()), isNull);
    expect(restSuggestion(pattern(), bench(rest: 150)), isNull, reason: 'nothing longer to test, nothing shorter made it');
    expect(restSuggestion(pattern(), bench()..learnRest = false), isNull, reason: 'fixed rests');
  });

  test('a rest close to the border waits when it would turn the result', () {
    List<Session> with3(int rest) => history([
          training(1, 120, 5),
          training(3, 120, 4),
          training(5, rest, 4),
          for (final d in [7, 9, 11]) training(d, 150, 5),
        ]);
    expect(restSuggestion(with3(120), bench())?.seconds, 150);
    expect(restSuggestion(with3(134), bench()), isNull, reason: '2:14 could be 2½ min, then only two trainings at 2 min');
  });

  test('suggests a shorter rest the history went on after and still made everything', () {
    // 3:00 planned; before set 2 sometimes only about 2 min, and the whole 5×5 made.
    final h = history([
      for (final d in [1, 3, 5]) sets(d, [120, 180, 180, 180], [5, 5, 5, 5, 5]),
      for (final d in [7, 9]) sets(d, [180, 180, 180, 180], [5, 5, 5, 5, 5]),
    ]);
    final g = restSuggestion(h, bench(rest: 180))!;
    expect((g.change, g.set, g.seconds, g.current, g.n), (RestChange.shorter, 1, 120, 180, 3));

    final missed = history([sets(11, [120, 180, 180, 180], [5, 5, 5, 5, 3]), ...h]);
    expect(restSuggestion(missed, bench(rest: 180)), isNull, reason: 'one training after the short rest missed the last set');
    final atLimit = history([for (final d in [1, 3, 5]) sets(d, [120, 180, 180, 180], [5, 5, 5, 5, 5], rir: 0)]);
    expect(restSuggestion(atLimit, bench(rest: 180)), isNull, reason: 'made, but without reserve');
  });

  test('always the same rest and made with reserve: one step shorter before the longest rest', () {
    final stable = history([for (final d in [1, 3, 5, 7]) sets(d, [180, 180, 180, 180], [5, 5, 5, 5, 5], rir: 2)]);
    final g = restSuggestion(stable, bench(rest: 180))!;
    expect((g.change, g.set, g.seconds, g.current), (RestChange.tryShorter, 1, 150, 180));
    final e = bench(rest: 180)..setRests[3] = 240;
    final longer = history([for (final d in [1, 3, 5, 7]) sets(d, [180, 180, 240, 180], [5, 5, 5, 5, 5], rir: 3)]);
    expect(restSuggestion(longer, e)?.set, 3, reason: 'the longest rest first');

    expect(restSuggestion(history(stable.take(3).toList()), bench(rest: 180)), isNull, reason: 'three trainings');
    final close = history([for (final d in [1, 3, 5, 7]) sets(d, [180, 180, 180, 180], [5, 5, 5, 5, 5], rir: 1)]);
    expect(restSuggestion(close, bench(rest: 180)), isNull, reason: 'a reserve of 1 is too close');
    expect(restSuggestion(stable, bench(rest: 120)), isNull, reason: '2:00 is the floor for heavy sets');
    expect(restSuggestion(stable, bench(rest: 180)..weight = 82.5), isNull, reason: 'the weight went up: proven rests first');
  });

  test('only comparable trainings: same load, regular, no deload', () {
    expect(restSuggestion(pattern(kg: 77.5), bench()), isNull);
    final deload = history([training(17, 150, 3, progression: Progression.deload), ...pattern()]);
    expect(restSuggestion(deload, bench()), isNull, reason: 'a deload comes first');
    final painful = pattern();
    for (final s in painful) {
      s.tags = ['Schmerzen'];
    }
    expect(restSuggestion(painful, bench()), isNull);
  });

  test('turned down: back only with newer trainings', () {
    final e = bench()..restDeclined = DateTime(2026, 11, 15, 18);
    expect(restSuggestion(pattern(), e), isNull);
    expect(restSuggestion(history([training(17, 120, 4), ...pattern()]), e)?.seconds, 150);
  });

  test('a test is pending until a training ran it, and drops when the plan changes', () {
    final e = bench()..restTrial = (set: 4, seconds: 150, kg: 80, target: 5, since: DateTime(2026, 11, 15, 20));
    expect(pendingTrial(pattern(), e)?.seconds, 150);
    expect(restSuggestion(pattern(), e), isNull, reason: 'one test at a time');
    expect(pendingTrial(pattern(), bench()..restTrial = e.restTrial..weight = 82.5), isNull, reason: 'load changed');
    expect(pendingTrial(pattern(), bench()..restTrial = e.restTrial..learnRest = false), isNull, reason: 'fixed rests');

    final ran = history([training(17, 150, 5, trialSeconds: 150), ...pattern()]);
    expect(pendingTrial(ran, e), isNull);
    final obs = restObservations(ran.first, ran.first.exercises.single, plan: e).last;
    expect((obs.kind, obs.planned), (RestKind.trial, 150));
    expect(restToAdopt(ran, e), isNull, reason: 'one success is a first data point');
    expect(restSuggestion(ran, e)?.seconds, 150, reason: 'offered again');
  });

  test('a test counts the whole exercise, reps of a range too', () {
    final failedLater = history([sets(17, [150, 180, 180, 180], [5, 5, 5, 5, 4], trialSet: 1, trialSeconds: 150)]);
    expect(trialResults(failedLater, bench(rest: 180), 1, 150).single.$2, TrialOutcome.failed,
        reason: 'set 2 made it, but set 5 missed');
    final range = Exercise(name: 'Bankdrücken', weight: 80, sets: 3, reps: 8, maxReps: 12, restSeconds: 90, learnRest: true);
    final usual = [for (final d in [1, 3, 5]) sets(d, [90, 90], [12, 11, 10], target: 8)];
    final fewer = sets(7, [60, 90], [12, 9, 8], target: 8, trialSet: 1, trialSeconds: 60);
    final kept = sets(9, [60, 90], [12, 11, 10], target: 8, trialSet: 1, trialSeconds: 60);
    final results = trialResults(history([kept, fewer, ...usual]), range, 1, 60);
    expect([for (final (_, ok) in results) ok], [TrialOutcome.worked, TrialOutcome.failed], reason: '12/9/8 lost reps although every set reached 8');
  });

  test('adopted after two tests that worked, unless turned down or adopted', () {
    final ran = history([training(17, 150, 5, trialSeconds: 150), training(19, 150, 5, trialSeconds: 150), ...pattern()]);
    expect(restToAdopt(ran, bench()), (set: 4, seconds: 150, worked: 2));
    expect(restSuggestion(ran, bench()), isNull, reason: 'adopting comes first');
    expect(restToAdopt(ran, bench()..setRests[4] = 150), isNull);
    expect(restToAdopt(ran, bench()..restDeclined = DateTime(2026, 11, 19, 18)), isNull);
    final failed = history([training(17, 150, 4, trialSeconds: 150), training(19, 150, 5, trialSeconds: 150)]);
    expect(restToAdopt(failed, bench()), isNull);

    final adopted = bench()..setRests[2] = 240;
    adoptRest(adopted, 4, 150);
    adoptRest(adopted, 2, 120);
    expect(adopted.setRests, {4: 150}, reason: "the exercise's own rest needs no entry");

    final e = Exercise.fromJson((bench()
          ..setRests[4] = 150
          ..restPulse = false
          ..restTrial = (set: 4, seconds: 150, kg: 80, target: 5, since: DateTime(2026, 11, 3))
          ..restDeclined = DateTime(2026, 11, 2))
        .toJson());
    expect(e.setRests, {4: 150});
    expect((e.learnRest, e.restPulse), (true, false));
    expect((e.restTrial?.seconds, e.restDeclined), (150, DateTime(2026, 11, 2)));
    final old = Exercise.fromJson(Exercise(name: 'Kniebeuge').toJson());
    expect((old.learnRest, old.restPulse), (false, true), reason: 'fixed, the pulse extends as before');
    final log = ExerciseLog.fromJson(ran.first.exercises.single.toJson());
    expect((log.trialSet, log.trialSeconds), (4, 150));
  });

  test('the store starts the pending test, not on a comeback', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store(await SharedPreferences.getInstance());
    final e = bench()..restTrial = (set: 4, seconds: 150, kg: 80, target: 5, since: DateTime(2026, 11, 1));
    final w = Workout(name: 'A', exercises: [e]);
    await store.saveWorkout(w);
    final s = store.startSession(w, DateTime(2026, 11, 2));
    expect((s.exercises.single.trialSet, s.exercises.single.trialSeconds), (4, 150));
  });

  test('preload from the timestamps: what came before, sharing a primary muscle', () {
    PreloadInfo of(Session s) => preloadOf(s, s.exercises.first);
    Session day() => sets(1, [180, 180, 180, 180], [5, 5, 5, 5, 5]);
    expect(of(day()).stage, Preload.none);
    expect(of(plus(day(), 'Dips', 3)), (stage: Preload.loaded, by: 'Dips', sets: 3));
    expect(of(plus(day(), 'Dips', 1)).stage, Preload.none, reason: 'one set is below the threshold');
    expect(of(plus(day(), 'Kniebeuge', 3)).stage, Preload.none, reason: 'no shared primary muscle');
    expect(of(plus(day(), 'Dips', 3, after: true)).stage, Preload.none, reason: 'reordered: dips after');
    expect(of(plus(day(), 'Dips', 2, timed: false)).stage, Preload.unknown, reason: 'could have been before');
    expect(of(plus(day(), 'Atemübung', 2)).stage, Preload.unknown, reason: 'muscles unknown');
    expect(of(plus(day(), 'Atemübung', 1)).stage, Preload.none, reason: 'one set of it cannot make two');

    // Nested: Dips between the second and third set raise the preload within the exercise.
    Session nested(String name) {
      final s = day();
      final t = s.exercises.first.doneAt[1]!;
      s.exercises.add(ExerciseLog(name: name, weight: 0, targetReps: 10, reps: [10, 10], doneAt: [
        t.add(const Duration(seconds: 30)),
        t.add(const Duration(seconds: 60)),
      ]));
      return s;
    }

    expect(of(nested('Dips')).stage, Preload.unknown);
    expect(of(nested('Kniebeuge')).stage, Preload.none, reason: 'squats in between change nothing');
    final later = nested('Kniebeuge');
    expect(restObservations(later, later.exercises.first).map((o) => o.set), [1, 3, 4],
        reason: 'the rest with squats in between drops, the later ones still count');
  });

  test('a longer rest only within one preload: mixed with the rest, no case', () {
    // Without preload 2:30 every time and made, after dips 2:00 and missed: the dips explain it.
    final mixed = history([
      for (final d in [1, 3, 5]) training(d, 150, 5),
      for (final d in [7, 9, 11]) plus(training(d, 120, 4), 'Dips', 3),
    ]);
    expect(restSuggestion(mixed, bench()), isNull);
    final plain = history([for (final d in [1, 3, 5]) training(d, 150, 5), for (final d in [7, 9, 11]) training(d, 120, 4)]);
    expect(restSuggestion(plain, bench())?.seconds, 150, reason: 'the same rests without dips make a case');

    final both = history([...pattern(), for (final d in [17, 19, 21]) plus(training(d, 150, 5), 'Dips', 3)]);
    final g = restSuggestion(both, bench())!;
    expect((g.seconds, g.stage, g.by), (150, Preload.none, null), reason: 'shown with the preload it holds for');
    final against = history([
      ...pattern(),
      for (final d in [17, 19, 21]) plus(training(d, 120, 5), 'Dips', 3),
      for (final d in [23, 25, 27]) plus(training(d, 150, 4), 'Dips', 3),
    ]);
    expect(restSuggestion(against, bench()), isNull, reason: 'after dips it went the other way round');
    final unknown = history([for (final s in pattern()) plus(s, 'Dips', 2, timed: false)]);
    expect(restSuggestion(unknown, bench()), isNull, reason: 'unknown preload backs nothing');
  });

  test('shorter needs every preload the exercise regularly has', () {
    final h = history([
      for (final d in [1, 3, 5]) sets(d, [120, 180, 180, 180], [5, 5, 5, 5, 5]),
      for (final d in [7, 9, 11]) plus(sets(d, [180, 180, 180, 180], [5, 5, 5, 5, 5], rir: 1), 'Dips', 3),
    ]);
    expect(regularPreloads(comparableUnits(h, bench(rest: 180))), {Preload.none, Preload.loaded});
    expect(restSuggestion(h, bench(rest: 180)), isNull, reason: '2:00 only ever without dips before');
    final also = history([plus(sets(13, [120, 180, 180, 180], [5, 5, 5, 5, 5]), 'Dips', 3), ...h]);
    expect(restSuggestion(also, bench(rest: 180))?.change, RestChange.shorter);
  });

  test('a test without a comparison with the same preload shows, but does not count', () {
    final test = plus(training(17, 150, 5, trialSeconds: 150), 'Dips', 3);
    final h = history([test, ...pattern()]);
    final (outcome, p) = trialOutcomeOf(h, test.exercises.first, bench())!;
    expect((outcome, p.stage, p.by, p.sets), (TrialOutcome.noComparison, Preload.loaded, 'Dips', 3));
    final two = history([plus(training(19, 150, 5, trialSeconds: 150), 'Dips', 3), test, ...pattern()]);
    expect(restToAdopt(two, bench()), isNull, reason: 'two tests made, nothing to compare them with');
    expect(trialResults(two, bench(), 4, 150).map((r) => r.$2), everyElement(TrialOutcome.noComparison));
    final unclear = plus(training(17, 150, 5, trialSeconds: 150), 'Dips', 2, timed: false);
    expect(trialOutcomeOf(history([unclear, ...pattern()]), unclear.exercises.first, bench())?.$1, TrialOutcome.noComparison);
  });

  test('tests at another load count neither as runs nor for adopting', () {
    final light = history([
      training(17, 150, 5, kg: 77.5, trialSeconds: 150),
      training(19, 150, 5, kg: 77.5, trialSeconds: 150),
      ...pattern(kg: 77.5),
    ]);
    expect(restToAdopt(light, bench()), isNull, reason: 'the plan is at 80 kg now');
    expect(trialResults(light, bench(), 4, 150), isEmpty);
    expect(trialOutcomeOf(light, light.first.exercises.single, bench())?.$1, TrialOutcome.worked,
        reason: 'the recap judges it at its own load');
  });

  test('a shorter rest is adopted only after it worked with each regular preload', () {
    Session run(int d, {bool dips = false, int? trial}) {
      final s = sets(d, [trial ?? 180, 180, 180, 180], [5, 5, 5, 5, 5], trialSet: trial == null ? null : 1, trialSeconds: trial);
      return dips ? plus(s, 'Dips', 3) : s;
    }

    final usual = [for (final d in [1, 3, 5]) run(d), for (final d in [7, 9, 11]) run(d, dips: true)];
    final fresh = history([run(13, trial: 150), run(15, trial: 150), ...usual]);
    expect(restToAdopt(fresh, bench(rest: 180)), isNull, reason: 'worked twice, but never after dips');
    final covered = history([run(17, dips: true, trial: 150), ...fresh]);
    expect(restToAdopt(covered, bench(rest: 180)), (set: 1, seconds: 150, worked: 3));
  });

  test('on its own: plans the suggested test, adopts after two that worked, and undoes either', () {
    final now = DateTime(2026, 11, 20, 18);
    final e = bench();
    final planned = autoRestStep(pattern(), e, now)!;
    expect((planned.test?.set, planned.test?.seconds, planned.adopted), (4, 150, null));
    expect(pendingTrial(pattern(), e)?.seconds, 150, reason: 'no button: the test is planned');
    expect(autoRestStep(pattern(), e, now), isNull, reason: 'one test at a time');
    undoRestStep(e, planned, DateTime(2026, 11, 15, 18));
    expect(e.restTrial, isNull);
    expect(restSuggestion(pattern(), e), isNull, reason: 'undone: not again before newer trainings');

    final ran = history([training(17, 150, 5, trialSeconds: 150), training(19, 150, 5, trialSeconds: 150), ...pattern()]);
    final f = bench()..setRests[4] = 120;
    final adopted = autoRestStep(ran, f, now)!;
    expect((adopted.adopted, adopted.before), ((set: 4, seconds: 150, worked: 2), 120));
    expect(f.setRests[4], 150);
    undoRestStep(f, adopted, DateTime(2026, 11, 19, 18));
    expect(f.setRests[4], 120);
    expect(restToAdopt(ran, f), isNull, reason: 'undone: not adopted again');
  });
}
