import 'dart:math';

import 'package:intl/intl.dart' show DateFormat;

import 'language.dart';
import 'main.dart';
import 'model.dart';

/// Gaps longer than this (a phone call, a chat) say nothing about the exercise and are left out.
const _maxGap = Duration(minutes: 15), _maxFirst = Duration(minutes: 25);

/// How long [log] took in [s], from the timestamps of its sets: from the set logged before its first
/// one (any exercise, or the start of the training) to its last set. So setup and walking
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
  final c = catalogueName(name);
  if (const {'Umsetzen', 'Reißen'}.contains(c)) return 8;
  if (const {'Kettlebell Swings', 'Burpees', 'Russian Twists'}.contains(c)) return 2;
  return isBarbell(name) ? 4.5 : 3;
}

/// Time to set up the station before the first set.
int _setupSeconds(double kg) => kg > 0 ? 60 : 30;

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
      rest: p?.restSeconds ?? log.restSeconds ?? exerciseCatalogue[catalogueName(log.name)]?.$5 ?? 120,
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
      seconds: (_setupSeconds(e.kg) + e.sets * _work(e) + max(0, e.sets - 1) * e.rest).round());

  /// Before the first set (setup plus the set) and from set to set (rest plus the set).
  (Duration, Duration) _parts(Shape e) {
    final first = _first[e.name], gaps = _gaps[e.name];
    return (
      first != null && first.length >= 3
          ? _medianOf(first)
          : Duration(seconds: ((_setupSeconds(e.kg) + _work(e)) * factor).round()),
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
  return left <= Duration.zero ? null : '${tr.leftAbout(aboutLabel(left))} · ${tr.doneAround(timeOfDay(now.add(left)))}';
}

/// "≈ 8 Min", "≈ 1:05 h"; at least one minute.
String aboutLabel(Duration d) {
  final m = max(1, (d.inSeconds / 60).round());
  return m < 60 ? tr.aboutMinutes(m) : '≈ ${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')} h';
}

/// Time taken: "7 Min", "1:05 h"; at least one minute.
String takenLabel(Duration d) => aboutLabel(d).substring(2);

/// "19:40" / "7:40 PM".
String timeOfDay(DateTime t) => DateFormat.jm(appLocale.languageCode).format(t);

/// How long exercise [name] took in [s], for the recap and the history: "7 Min", with [perSet] also the
/// typical time from set to set ("7 Min · alle 2:40 Min ein Satz"). Null without timestamps.
String? timeTaken(Session s, String name, {bool perSet = false}) {
  final log = s.exercises.where((e) => e.name == name && !e.cardio).firstOrNull;
  final m = log == null ? null : measured(s, log);
  if (m == null) return null;
  if (!perSet || m.gaps.isEmpty) return takenLabel(m.total);
  final avg = m.gaps.fold(0, (sum, g) => sum + g.inSeconds) ~/ m.gaps.length;
  return tr.everySet(takenLabel(m.total), '${avg ~/ 60}:${(avg % 60).toString().padLeft(2, '0')}');
}

/// Which rest the timer gave before a set: the normal one (or one learned for that set), the one
/// after a missed set, or a rest test.
enum RestKind { normal, afterMiss, trial }

/// One rest and the set after it, for learning rests (docs/puls.md, "Lernende Pausen"). The rest is
/// an estimate: from one logged tap to the next, minus the next set's work. Belongs to the set after it.
typedef RestObservation = ({
  DateTime date,
  String name,
  int set, // index of the set after the rest, ≥ 1
  int target,
  int reps,
  double kg,
  Duration rest,
  RestKind kind,
  int planned, // the rest the timer gave, seconds
  bool priorMet, // every earlier set of the exercise reached its target
  int? rir, // only on the last set, where it was asked
  bool regular, // not swapped in or added, no comeback, pain, bad day, lighter or skipped sets
});

/// The rests between the sets of [log] in [s]. [plan] is the exercise as planned, for its rests; else
/// what came with the log. Left out, so never guessed: the first set, a set after a skipped one, a
/// missing or out-of-order timestamp, another exercise logged in between, a negative estimate and a
/// gap longer than [_maxGap]. The reps of those sets still count for the progression.
List<RestObservation> restObservations(Session s, ExerciseLog log, {Exercise? plan}) {
  if (log.cardio) return const [];
  final rest = plan?.restSeconds ?? log.restSeconds ?? 120;
  final fail = plan != null ? plan.failRestSeconds : log.failRestSeconds;
  final others = [
    for (final e in s.exercises)
      if (e != log) ...[...e.doneAt.nonNulls, ?e.startedAt],
  ];
  final last = log.reps.length - 1;
  final regular = log.replaces == null &&
      !log.added &&
      log.backoff == null &&
      !s.tags.contains(painTag) &&
      !isBadDay(s) &&
      log.progression != Progression.lighter &&
      log.progression != Progression.fewer;
  final out = <RestObservation>[];
  for (var i = 1; i <= last; i++) {
    final (before, after) = (log.doneAt[i - 1], log.doneAt[i]);
    final (prev, reps) = (log.reps[i - 1], log.reps[i]);
    if (before == null || after == null || prev == null || reps == null || !after.isAfter(before)) continue;
    if (others.any((t) => t.isAfter(before) && t.isBefore(after))) continue;
    final work = log.timed ? reps.toDouble() : reps * _perRep(log.name);
    final estimated = after.difference(before) - Duration(milliseconds: (work * 1000).round());
    if (estimated.isNegative || estimated > _maxGap) continue;
    final missed = prev < log.targets[i - 1];
    final trial = !(missed && fail != null) && log.trialSet == i ? log.trialSeconds : null;
    out.add((
      date: s.date,
      name: log.name,
      set: i,
      target: log.targets[i],
      reps: reps,
      kg: log.weights[i],
      rest: estimated,
      kind: missed && fail != null ? RestKind.afterMiss : trial != null ? RestKind.trial : RestKind.normal,
      planned: missed && fail != null ? fail : trial ?? (plan != null && plan.learnRest ? plan.setRests[i] : null) ?? rest,
      priorMet: [for (var j = 0; j < i; j++) (log.reps[j] ?? -1) >= log.targets[j]].every((ok) => ok),
      rir: i == last ? log.rir : null,
      regular: regular,
    ));
  }
  return out;
}

/// "rund 2 Min", "rund 2½ Min": an estimated rest to the nearest half minute, never to the second.
String restAboutLabel(Duration d) {
  final halves = max(1, (d.inSeconds / 30).round());
  final whole = halves ~/ 2;
  return tr.restAbout(halves.isOdd ? (whole == 0 ? '½' : '$whole½') : '$whole');
}
