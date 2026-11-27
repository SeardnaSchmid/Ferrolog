import 'package:ferrolog/main.dart';
import 'package:ferrolog/model.dart';
import 'package:ferrolog/pulse_compare.dart';
import 'package:ferrolog/rest_learning.dart' show Preload;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final t0 = DateTime(2026, 11, 20, 18);

/// [name] with sets of 5 reps tapped at [taps] seconds after the start (null = no timestamp).
ExerciseLog lift(String name, List<int?> taps, {double kg = 100}) => ExerciseLog(
      name: name,
      weight: kg,
      targetReps: 5,
      reps: List.filled(taps.length, 5),
      doneAt: [for (final t in taps) t == null ? null : t0.add(Duration(seconds: t))],
    );

/// A curve every 5 s from [from] to [to], [base] bpm except the [peaks] (second → bpm).
List<(int, int)> curve(int from, int to, {int base = 100, Map<int, int> peaks = const {}}) =>
    [for (var t = from; t <= to; t += 5) (t, peaks[t] ?? base)];

Session session(List<ExerciseLog> logs, List<(int, int)> pulse) =>
    Session(workoutId: 'w', workoutName: 'A', date: t0, exercises: logs, pulse: pulse);

/// A training of 3×8 at [kg] [day] days into November with a fully measured [peak].
PulseEntry entry(int day, double kg, int? peak, {int sets = 3, int covered = -1, Progression? progression}) {
  final log = ExerciseLog(name: 'Rumänisches Kreuzheben', weight: kg, targetReps: 8, reps: List.filled(sets, 8), doneAt: List.filled(sets, null))
    ..progression = progression;
  return (
    date: DateTime(2026, 11, day, 18),
    log: log,
    pulse: peak == null ? null : (peak: peak, covered: covered < 0 ? sets : covered, sets: sets),
    preload: Preload.none,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
  });

  test('each exercise gets the peak of its own sets, not the session peak or the way between', () {
    final dl = lift('Kreuzheben', [60, 240, 420]), bench = lift('Bankdrücken', [700, 880, 1060]);
    final s = session([dl, bench], curve(0, 1200, peaks: {245: 163, 550: 175, 880: 146}));
    final p = exercisePulses(s);
    expect(p[dl], (peak: 163, covered: 3, sets: 3), reason: 'a peak 5 s after the tap still counts');
    expect(p[bench], (peak: 146, covered: 3, sets: 3), reason: '175 bpm on the way between counts to neither');
  });

  test('a delayed peak between two close sets of different exercises goes to at most one', () {
    final dl = lift('Kreuzheben', [100]), bench = lift('Bankdrücken', [110]);
    final p = exercisePulses(session([dl, bench], curve(0, 200, peaks: {95: 170})));
    expect([p[dl]!.peak, p[bench]!.peak].where((b) => b == 170).length, lessThanOrEqualTo(1));
  });

  test('without timestamps nothing is assigned, not by plan order', () {
    final dl = lift('Kreuzheben', [null, null]);
    expect(exercisePulses(session([dl], curve(0, 600, base: 150)))[dl], (peak: null, covered: 0, sets: 2));
    expect(exercisePulses(session([dl], const [])), isEmpty, reason: 'no sensor, no value');
  });

  test('partly measured: the coverage, the peak of the measured sets; one isolated sample is not enough', () {
    final dl = lift('Kreuzheben', [60, 240, 420, 600]);
    final p = exercisePulses(session([dl], [...curve(0, 300, peaks: {240: 154}), (420, 180)]));
    expect(p[dl], (peak: 154, covered: 2, sets: 4));
    expect(p[dl]!.complete, isFalse);
  });

  test('same work, lower peak than 158, 160 and 162: the first comparison', () {
    final n = pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 151)])!;
    expect((n.kind, n.bpm, n.median, n.refs), (PulseNoteKind.lower, 151, 160, 3));
    final high = pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 168)])!;
    expect(high.kind, PulseNoteKind.higher);
    expect(pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 161)])!.kind, PulseNoteKind.similar);
    expect(pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 156)]), isNull,
        reason: 'below the range but only 4 bpm from the median: no pulse sentence');
  });

  test('more load at a similar peak: the second text', () {
    final n = pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 85, 158)])!;
    expect((n.kind, n.fromKg, n.refs), (PulseNoteKind.heavierSimilar, 80, 3));
    expect(pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 85, 150)]), isNull,
        reason: 'more load only says "similar"');
  });

  test('no comparison: other sets, one earlier training, partly measured or a deload', () {
    expect(pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 151, sets: 4)]), isNull);
    expect(pulseNote([entry(9, 80, 162), entry(13, 80, 151)]), isNull);
    expect(pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 151, covered: 2)]), isNull,
        reason: 'the partly measured one is no target; the newest full one has only two before it');
    expect(pulseNote([entry(1, 80, 158), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 151, progression: Progression.deload)]),
        isNull);
    expect(pulseNote([entry(1, 80, 158), entry(3, 80, null), entry(5, 80, 160), entry(9, 80, 162), entry(13, 80, 151)])!.refs, 3,
        reason: 'a training without a sensor in between is skipped');
  });

  test('per set: each set its own peak, unmeasured sets null', () {
    final dl = lift('Kreuzheben', [60, 240, 420, 600]);
    final p = setPulses(session([dl], [...curve(0, 300, peaks: {60: 140, 240: 154}), (420, 180)]));
    expect(p[dl], [140, 154, null, null]);
  });

  test('per set: an arrow only against three earlier trainings with the same work', () {
    PulseEntry same(int day, {double kg = 80}) => entry(day, kg, 150);
    final refs = [for (final d in [1, 5, 9]) same(d)];
    final peaks = [[140, 150, 160], [142, 151, 161], [144, 152, 159]];
    expect(setPulseDirs([...refs, same(13)], [...peaks, [131, 151, 170]]), [-1, 0, 1]);
    expect(setPulseDirs([...refs.skip(1), same(13)], [...peaks.skip(1), [131, 151, 170]]), [0, 0, 0],
        reason: 'two earlier trainings are not enough');
    expect(setPulseDirs([...refs, same(13, kg: 82.5)], [...peaks, [131, 151, 170]]), [0, 0, 0],
        reason: 'more load is other work');
    expect(setPulseDirs([...refs, same(13)], [...peaks, [null, 151, 170]]), [0, 0, 1]);
  });
}
