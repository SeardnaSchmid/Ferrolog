import 'dart:math';

import 'main.dart';
import 'model.dart';

/// Gaps longer than this (a phone call, a chat) say nothing about the exercise and are left out.
const _maxGap = Duration(minutes: 15), _maxFirst = Duration(minutes: 25);

/// How long [log] took in [s], from the timestamps of its sets: from the set logged before its first
/// one (any exercise, or the start of the training) to its last set. So setup, warm-ups and walking
/// to the station count to the exercise, the rest after its last set to the next one. [first] is that
/// first stretch, [gaps] the time between its sets (rest plus one set). Null without timestamps.
({Duration total, Duration first, List<Duration> gaps})? measured(Session s, ExerciseLog log) {
  final own = log.doneAt.nonNulls.toList()..sort();
  if (own.isEmpty) return null;
  var start = s.date;
  for (final e in s.exercises) {
    if (e == log) continue;
    for (final t in e.doneAt.nonNulls) {
      if (t.isBefore(own.first) && t.isAfter(start)) start = t;
    }
  }
  return (
    total: own.last.difference(start),
    first: own.first.difference(start),
    gaps: [for (var i = 1; i < own.length; i++) own[i].difference(own[i - 1])],
  );
}

/// Seconds per rep, from typical tempos: about 3 s for a controlled rep (1–2 s up, 2 s down), more for
/// heavy barbell reps (bracing and a breath between them), most for Olympic lifts (reset after each),
/// less for swings and burpees.
double _perRep(String name) {
  if (const {'Umsetzen', 'Reißen'}.contains(name)) return 8;
  if (const {'Kettlebell Swings', 'Burpees', 'Russian Twists'}.contains(name)) return 2;
  return isBarbell(name) ? 4.5 : 3;
}

/// Setup before the first set: barbell lifts ramp up from the empty bar in steps of about half again
/// (100 kg: 20, 30, 45, 70 → 4 warm-up sets), a minute each with loading the plates; else a minute
/// to get the station or dumbbells ready, half that with no weight.
int _setupSeconds(String name, double kg) {
  if (isBarbell(name)) return 60 + (kg > 20 ? (log(kg / 20) / log(1.5)).ceil() : 0) * 60;
  return kg > 0 ? 60 : 30;
}

/// The plan's shape of an exercise, as far as the estimate needs it.
typedef Shape = ({String name, int sets, int reps, double kg, int rest, bool cardio, int minutes, double? km, bool timed});

Shape shapeOf(Exercise e) => (
      name: e.name,
      sets: e.sets,
      reps: e.repsPerSet.fold(0, max),
      kg: e.weights.fold(0.0, max),
      rest: e.restSeconds,
      cardio: e.cardio,
      minutes: e.reps,
      km: e.km,
      timed: e.timed,
    );

/// The same for an exercise of a training, with the rest from its plan [p] (else its own, or the catalogue).
Shape shapeOfLog(ExerciseLog log, Exercise? p) => (
      name: log.name,
      sets: log.reps.length,
      reps: log.targets.fold(0, max),
      kg: log.weights.fold(0.0, max),
      rest: p?.restSeconds ?? log.restSeconds ?? exerciseCatalogue[log.name]?.$5 ?? 120,
      cardio: log.cardio,
      minutes: log.targetReps,
      km: log.targetKm,
      timed: log.timed,
    );

double median(List<double> v) {
  final s = [...v]..sort();
  return s.length.isOdd ? s[s.length ~/ 2] : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
}

/// Estimates from the training data: the user's own pace where there is enough of it, else typical
/// values scaled by how the user's measured exercises compare with them.
class Pace {
  final Map<String, List<Duration>> _first = {}, _gaps = {};
  final List<double> _paceKm = []; // cardio minutes per km

  /// The user's tempo against the typical values (1 = as estimated), from their measured exercises.
  double factor = 1;

  /// From [sessions], newest first; the latest 10 trainings of an exercise count.
  Pace(List<Session> sessions, {Exercise? Function(String name)? plan}) {
    final ratios = <double>[];
    final seen = <String, int>{};
    for (final s in sessions) {
      for (final log in s.exercises) {
        if (log.cardio) {
          if ((log.reps.first, log.km) case (final m?, final km?) when km > 0) _paceKm.add(m / km);
          continue;
        }
        final m = measured(s, log);
        if (m == null || (seen[log.name] = (seen[log.name] ?? 0) + 1) > 10) continue;
        if (m.first <= _maxFirst) _first.putIfAbsent(log.name, () => []).add(m.first);
        final gaps = [for (final g in m.gaps) if (g <= _maxGap) g];
        _gaps.putIfAbsent(log.name, () => []).addAll(gaps);
        if (ratios.length < 30 && m.first <= _maxFirst && gaps.length == m.gaps.length && m.total.inSeconds > 0) {
          final shape = shapeOfLog(log, plan?.call(log.name));
          final typical = _typical((
              name: shape.name, sets: log.setsDone, reps: shape.reps, kg: log.weight, rest: shape.rest,
              cardio: false, minutes: 0, km: null, timed: log.timed));
          ratios.add(m.total.inSeconds / typical.inSeconds);
        }
      }
    }
    if (ratios.length >= 5) factor = median(ratios).clamp(.7, 1.6);
  }

  static Duration _medianOf(List<Duration> v) =>
      Duration(milliseconds: median([for (final d in v) d.inMilliseconds.toDouble()]).round());

  /// One set's work in seconds: reps × tempo, or the seconds themselves for holds and carries.
  static double _work(Shape e) => e.timed ? e.reps.toDouble() : e.reps * _perRep(e.name);

  /// Typical values only: setup + sets × work + the rests between them.
  static Duration _typical(Shape e) => Duration(
      seconds: (_setupSeconds(e.name, e.kg) + e.sets * _work(e) + max(0, e.sets - 1) * e.rest).round());

  /// Before the first set (setup plus the set) and from set to set (rest plus the set).
  (Duration, Duration) _parts(Shape e) {
    final first = _first[e.name], gaps = _gaps[e.name];
    return (
      first != null && first.length >= 3
          ? _medianOf(first)
          : Duration(seconds: ((_setupSeconds(e.name, e.kg) + _work(e)) * factor).round()),
      gaps != null && gaps.length >= 4
          ? _medianOf(gaps)
          : Duration(seconds: ((e.rest + _work(e)) * factor).round()),
    );
  }

  /// How long an exercise takes, setup included.
  Duration of(Shape e) {
    if (e.cardio) {
      final minutes = e.km == null ? e.minutes.toDouble() : e.km! * (_paceKm.isEmpty ? 6 : median(_paceKm));
      return Duration(seconds: (minutes * 60).round() + 60);
    }
    if (e.sets == 0) return Duration.zero;
    final (first, gap) = _parts(e);
    return first + gap * (e.sets - 1);
  }

  /// A whole workout.
  Duration ofWorkout(Workout w) => w.exercises.fold(Duration.zero, (sum, e) => sum + of(shapeOf(e)));

  /// What's left of [log] in a running training at [now]: its open sets, the next one counted from its
  /// last set (or, before the first, the full estimate).
  Duration left(ExerciseLog log, Shape e, DateTime now) {
    final open = log.reps.where((r) => r == null).length;
    if (open == 0) return Duration.zero;
    if (log.cardio) {
      if (log.startedAt case final t?) return _clamp(of(e) - const Duration(minutes: 1) - now.difference(t));
      return of(e);
    }
    final last = log.doneAt.nonNulls.fold<DateTime?>(null, (a, t) => a == null || t.isAfter(a) ? t : a);
    if (last == null) return of((name: e.name, sets: open, reps: e.reps, kg: e.kg, rest: e.rest, cardio: false, minutes: 0, km: null, timed: log.timed));
    final (_, gap) = _parts(e);
    return _clamp(gap - now.difference(last)) + gap * (open - 1);
  }

  static Duration _clamp(Duration d) => d.isNegative ? Duration.zero : d;
}

/// The estimates from the stored trainings, each exercise with its rest from the workouts.
Pace currentPace() =>
    Pace(store.sessions, plan: (name) => store.workouts.expand((w) => w.exercises).where((e) => e.name == name).firstOrNull);

/// The exercise [name] as planned in the workout of [s], if it's still there.
Exercise? planFor(Session s, String name) => store.workouts
    .where((w) => w.id == s.workoutId)
    .firstOrNull
    ?.exercises
    .where((e) => e.name == name)
    .firstOrNull;

/// What's left of the running training [s] at [now].
Duration sessionLeft(Session s, Pace pace, DateTime now) =>
    s.exercises.fold(Duration.zero, (sum, l) => sum + pace.left(l, shapeOfLog(l, planFor(s, l.name)), now));

/// "noch ≈ 25 Min · fertig gegen 19:40", or null when nothing is left.
String? leftLabel(Session s, Pace pace, DateTime now) {
  final left = sessionLeft(s, pace, now);
  return left <= Duration.zero ? null : 'noch ${aboutLabel(left)} · fertig gegen ${timeOfDay(now.add(left))}';
}

/// "≈ 8 Min", "≈ 1:05 h"; at least one minute.
String aboutLabel(Duration d) {
  final m = max(1, (d.inSeconds / 60).round());
  return m < 60 ? '≈ $m Min' : '≈ ${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')} h';
}

/// Time taken: "7 Min", "1:05 h"; at least one minute.
String takenLabel(Duration d) => aboutLabel(d).substring(2);

/// "19:40".
String timeOfDay(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

/// How long exercise [name] took in [s], for the recap and the history: "7 Min", with [perSet] also the
/// typical time from set to set ("7 Min · alle 2:40 Min ein Satz"). Null without timestamps.
String? timeTaken(Session s, String name, {bool perSet = false}) {
  final log = s.exercises.where((e) => e.name == name && !e.cardio).firstOrNull;
  final m = log == null ? null : measured(s, log);
  if (m == null) return null;
  if (!perSet || m.gaps.isEmpty) return takenLabel(m.total);
  final avg = m.gaps.fold(0, (sum, g) => sum + g.inSeconds) ~/ m.gaps.length;
  return '${takenLabel(m.total)} · alle ${avg ~/ 60}:${(avg % 60).toString().padLeft(2, '0')} Min ein Satz';
}
