import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language.dart';
import 'loading.dart' show plateChoices;
import 'units.dart';


DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// The Mondays of the current streak, newest first: weeks in a row (Monday to Sunday) with at least
/// [perWeek] trainings. A week that falls short only breaks the streak once it's over, so the current
/// week may still be below the goal.
List<DateTime> streakWeeks(Iterable<DateTime> dates, DateTime now, {int perWeek = 1}) {
  final counts = <DateTime, int>{};
  for (final d in dates) {
    counts.update(mondayOf(d), (n) => n + 1, ifAbsent: () => 1);
  }
  bool hit(DateTime week) => (counts[week] ?? 0) >= perWeek;
  var week = mondayOf(now);
  if (!hit(week)) week = DateTime(week.year, week.month, week.day - 7);
  final streak = <DateTime>[];
  while (hit(week)) {
    streak.add(week);
    week = DateTime(week.year, week.month, week.day - 7);
  }
  return streak;
}

/// The last [weeks] calendar weeks, oldest first: (Monday, trainings, cardio minutes).
List<(DateTime, int, int)> weeklySummary(List<Session> sessions, DateTime now, {int weeks = 10}) {
  final thisWeek = mondayOf(now);
  return [
    for (var i = weeks - 1; i >= 0; i--)
      () {
        final monday = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i);
        final inWeek = sessions.where((s) => mondayOf(s.date) == monday);
        final cardio = inWeek
            .expand((s) => s.exercises)
            .where((e) => e.cardio)
            .fold(0, (n, e) => n + (e.reps.first ?? 0));
        return (monday, inWeek.length, cardio);
      }(),
  ];
}

/// Estimated one-rep max (Epley) from all sets: the average reps at the working weight, skipped
/// sets counting 0. Missed reps lower it, so it shows how a training went, not just the plan.
double estimated1rm(ExerciseLog log) {
  if (log.cardio || log.timed || log.weight <= 0 || log.reps.isEmpty) return 0; // no 1RM with assistance
  final avg = log.reps.fold(0, (n, r) => n + (r ?? 0)) / log.reps.length;
  return avg == 0 ? 0 : log.weight * (1 + avg / 30);
}

/// Trainings of [history] (oldest first, by index) that went backwards: reps missed although the
/// weight wasn't new, i.e. a lower 1RM than last time at the same or a heavier weight, or a weight
/// managed before. Deloads and restarts after a break are lighter and succeed, so they don't count.
Set<int> setbacks(List<(DateTime, ExerciseLog)> history) => {
      for (var i = 1; i < history.length; i++)
        if (history[i].$2 case final l when !l.cardio && l.weight > 0 && !l.succeeded)
          if ((l.weight >= history[i - 1].$2.weight && estimated1rm(l) < estimated1rm(history[i - 1].$2) * .97) ||
              history.take(i).any((h) => h.$2.succeeded && h.$2.weight >= l.weight))
            i,
    };

enum Trend { up, flat, stuck }

/// What a training of an exercise achieved, for its trend: the 1RM; without one (bodyweight, holds) the
/// reps or seconds of all sets, times the weight if any.
double progressOf(ExerciseLog log) {
  final e1rm = estimated1rm(log);
  if (e1rm > 0 || log.cardio) return e1rm;
  return log.reps.fold(0, (n, r) => n + (r ?? 0)) * max(1.0, log.weight);
}

/// How an exercise is going, with the change in percent over the last [days] ([progressOf]: the 1RM,
/// or reps and seconds without one): up when it rose by more than 2 % (catching up after a deload
/// counts, misses or not), else stuck when at least two of the last three trainings missed reps, else flat.
/// Null with fewer than two trainings.
(Trend, double)? trendOf(List<(DateTime, ExerciseLog)> history, DateTime now, {int days = 28}) {
  if (history.length < 2) return null;
  final cutoff = now.subtract(Duration(days: days));
  final before = progressOf(history.lastWhere((h) => !h.$1.isAfter(cutoff), orElse: () => history.first).$2);
  final change = before == 0 ? 0.0 : (progressOf(history.last.$2) / before - 1) * 100;
  final misses = history.reversed.take(3).where((h) => !h.$2.succeeded).length;
  return (change > 2 ? Trend.up : misses >= 2 ? Trend.stuck : Trend.flat, change);
}

int weekStreak(Iterable<DateTime> dates, DateTime now, {int perWeek = 1}) =>
    streakWeeks(dates, now, perWeek: perWeek).length;

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// One exercise inside a workout plan, e.g. "Squat 3x5 @ 100 kg, +2.5 kg on success,
/// -5 kg after 3 failed sessions in a row".
class Exercise {
  String name;
  double weight;
  int sets;
  int reps;

  /// Added to the weight when every set hit [reps], if [up].
  double increment;
  bool up;

  /// Taken off after [failsToDeload] missed sessions in a row, if [down].
  double decrement;
  bool down;
  int failsToDeload;

  /// Missed sessions in a row so far; reset on success or deload.
  int fails;
  int restSeconds;

  /// Rest after a set that missed its target; null = [restSeconds].
  int? failRestSeconds;

  /// Weight per set when the sets differ (e.g. back-off sets); null = [weight] for all sets.
  /// All 0 = no weight (reps only).
  List<double>? setWeights;

  /// Reps per set when they differ (e.g. 10/8/6); null = [reps] for every set.
  List<int>? setReps;

  /// Rep range: each set aims for its reps up to [maxReps]; the weight only goes up once every
  /// set reaches [maxReps]. Null = fixed reps.
  int? maxReps;

  /// Cardio instead of strength: one "set", no weight. The goal is either a duration ([reps] minutes,
  /// [km] null) or a distance ([km], [reps] 0).
  bool cardio;
  double? km;

  /// Held or carried for a time instead of repeated (plank, farmer's walk): [reps] are seconds, with or
  /// without weight.
  bool timed;

  /// Auto mode instead of [up], [down], [increment] and [failsToDeload]: a share of the weight that adapts
  /// itself, steered by the reserve; reps bridge steps too coarse to load. See [applyResult], [AutoState],
  /// [Store.loadStepOf] and [Store.comebackOf].
  bool auto;

  /// The auto mode's memory; null in the fixed mode.
  AutoState? state;

  /// What the weight can be loaded in, in kg, set by the user (a machine that only takes 5 kg plates);
  /// null = learned, see [Store.loadStepOf]. Auto mode only.
  double? loadStep;

  Exercise({
    required this.name,
    this.weight = 20,
    this.sets = 3,
    this.reps = 8,
    this.increment = 2.5,
    this.up = true,
    this.decrement = 2.5,
    this.down = false,
    this.failsToDeload = 3,
    this.fails = 0,
    this.restSeconds = 120,
    this.failRestSeconds,
    this.setWeights,
    this.setReps,
    this.maxReps,
    this.cardio = false,
    this.km,
    this.timed = false,
    this.auto = false,
    this.state,
    this.loadStep,
  });

  /// A cardio exercise with a distance goal ([km]) or else a duration goal ([minutes]).
  Exercise.cardio({required this.name, required int minutes, this.km})
      : weight = 0,
        sets = 1,
        reps = km == null ? minutes : 0,
        increment = 2.5,
        up = false,
        decrement = 2.5,
        down = false,
        failsToDeload = 3,
        fails = 0,
        restSeconds = 0,
        cardio = true,
        timed = false,
        auto = false;

  /// Next session's weights from what was lifted: up on success, down after enough misses in a row.
  /// A set done lighter than planned holds the plan: the new weight was trained, just not every set
  /// (e.g. the last set dropped back), so neither an increase nor a miss towards a deload.
  /// In [auto] mode see [_auto]; it returns what it did (null in the fixed mode).
  Progression? applyResult(ExerciseLog log, {bool badDay = false, bool pain = false, double grid = 2.5}) {
    if (cardio) return null; // cardio stays as planned
    final planned = weights;
    final lighter = [
      for (final (i, r) in log.reps.indexed)
        if (r != null && i < planned.length && log.weights[i] < planned[i]) i,
    ].isNotEmpty;
    // Fewer sets than planned (taken off or swapped during the training): the plan holds, no miss.
    if (lighter) return auto ? Progression.lighter : null;
    if (log.reps.length < sets) return auto ? Progression.fewer : null;
    var delta = 0.0;
    Progression? done;
    final top = maxReps;
    final reached = top == null ? log.succeeded : log.reps.every((r) => r != null && r >= top);
    if (auto) {
      (delta, done) = _auto(log, reached, badDay: badDay, pain: pain, grid: grid);
    } else if (reached) {
      if (up) delta = increment;
      fails = 0;
    } else if (log.succeeded) {
      fails = 0; // within the range: same weight, go for more reps
    } else if (++fails >= failsToDeload && down) {
      delta = -decrement;
      fails = 0;
    }
    if (setWeights != null) {
      // Keep the per-set shape; take what was actually lifted when the set count still matches.
      final base = log.weights.length == sets ? log.weights : setWeights!;
      setWeights = [for (final w in base) _next(w, delta)];
      weight = setWeights!.reduce(max);
    } else {
      weight = _next(log.weight, delta);
    }
    return done;
  }

  /// The auto mode after a training, as (weight change, what it did):
  /// - Done (every set at its reps, in a range at the top): up by [AutoState.pct] of the weight, rounded to
  ///   [grid] (what can be loaded); twice that with 3 or more reps in reserve, nothing at the limit, half a
  ///   step at the limit the second time in a row. Reps beyond the target in the last set count as reserve.
  ///   Back from a break, double steps up to the weight from before it.
  /// - A step that rounds to nothing (light weight, coarse steps) is bridged by reps: one more per set (two
  ///   with reserve), and once the sets hold [AutoState.bridgeTo] the weight goes up a [grid] and the reps
  ///   back. A range is its own bridge.
  /// - Missed: holds. The second miss in a row takes a bridge back, the third takes off about 10 % and
  ///   halves the share (down to [AutoState.minPct]); three done in a row with reserve double it again.
  /// - A bad day ([badDay]) excuses a miss, twice in a row at most; [pain] holds everything.
  (double, Progression) _auto(ExerciseLog log, bool reached, {required bool badDay, required bool pain, required double grid}) {
    final a = state ??= AutoState();
    final w = log.weight;
    if (pain) return (0, Progression.pain);
    if (!reached && log.succeeded) {
      fails = a.excused = 0;
      return (0, Progression.range); // within the range: more reps first
    }
    if (!reached) {
      a.limits = a.streak = 0;
      if (badDay && a.excused < 2) {
        a.excused++;
        return (0, Progression.badDay);
      }
      a.excused = 0;
      if (++fails >= autoFails) {
        fails = 0;
        _endBridge();
        a
          ..pct = max(AutoState.minPct, a.pct / 2)
          ..comebackTo = null;
        return (noWeight ? 0 : w > 0 ? deloadTo(w, grid) - w : -grid, Progression.deload);
      }
      if (fails == 2 && a.bridgeFrom != null) {
        _endBridge();
        return (0, Progression.reset);
      }
      return (0, Progression.miss);
    }

    fails = a.excused = 0;
    final aim = maxReps ?? log.targets.last;
    final extra = max(0, (log.reps.last ?? 0) - aim);
    final reserve = log.rir == null && extra == 0 ? null : (log.rir ?? 0) + extra;
    double factor;
    if (reserve == 0) {
      a.streak = 0;
      factor = ++a.limits >= 2 ? .5 : 0;
    } else {
      a.limits = 0;
      a.streak = reserve != null && reserve >= 2 ? a.streak + 1 : 0;
      factor = reserve != null && reserve >= 3 ? 2 : 1;
    }
    final pct = a.pct;
    if (a.streak >= 3) {
      a
        ..pct = min(AutoState.maxPct, a.pct * 2)
        ..streak = 0;
    }
    if (factor == 0 || noWeight) return (0, Progression.limit);
    final back = a.comebackTo != null;
    if (back) factor *= 2;
    final done = factor >= 2 && !back ? Progression.up2 : factor < 1 ? Progression.half : Progression.up;

    double up(double delta) {
      // Back from a break: no further than the weight from before it.
      if (a.comebackTo case final to? when w + delta >= to - 1e-6) {
        a.comebackTo = null;
        return max(0, to - w);
      }
      return delta;
    }

    if (w < 0) return (up(grid * max(1, factor.floor())), done); // assistance: a step less help
    final steps = (w * pct / 100 * factor / grid).round();
    if (steps >= 1) {
      _endBridge();
      return (up(steps * grid), done);
    }
    if (maxReps != null) return (up(grid), done); // the range was the bridge
    if (factor < 1) return (0, Progression.limit);
    // Too small to load: bridge by reps.
    final base = a.bridgeFrom ?? reps;
    final to = a.bridgeTo ?? base + (grid / max(w, grid) / .05).round().clamp(1, 3);
    if (reps >= to) {
      _endBridge();
      return (up(grid), done);
    }
    final add = min(factor >= 2 ? 2 : 1, to - reps);
    a
      ..bridgeFrom = base
      ..bridgeTo = to;
    reps += add;
    if (setReps case final r?) setReps = [for (final x in r) x + add];
    return (0, Progression.bridge);
  }

  /// Back to the reps from before a bridge.
  void _endBridge() {
    final a = state;
    if (a?.bridgeFrom case final base?) {
      final add = reps - base;
      reps = base;
      if (setReps case final r?) setReps = [for (final x in r) x - add];
    }
    a
      ?..bridgeFrom = null
      ..bridgeTo = null;
  }

  /// [w] moved by [delta]: added weight never drops below none, assistance (negative) moves freely, so
  /// "more weight" means less help: −20 → −17,5.
  static double _next(double w, double delta) => w < 0 ? w + delta : max(0.0, w + delta);

  /// The planned weight of each set.
  List<double> get weights => setWeights ?? List.filled(sets, weight);

  /// The planned reps of each set.
  List<int> get repsPerSet => setReps ?? List.filled(sets, reps);

  /// Reps only, no weight.
  bool get noWeight => !cardio && weights.every((w) => w == 0);

  Exercise copy() => Exercise.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'sets': sets,
        'reps': reps,
        'increment': increment,
        'up': up,
        'decrement': decrement,
        'down': down,
        'failsToDeload': failsToDeload,
        'fails': fails,
        'restSeconds': restSeconds,
        if (failRestSeconds != null) 'failRestSeconds': failRestSeconds,
        if (setWeights != null) 'setWeights': setWeights,
        if (setReps != null) 'setReps': setReps,
        if (maxReps != null) 'maxReps': maxReps,
        if (cardio) 'type': 'cardio',
        if (timed) 'type': 'timed',
        if (km != null) 'km': km,
        if (auto) 'auto': true,
        if (auto && state != null) 'autoState': state!.toJson(),
        if (auto && loadStep != null) 'loadStep': loadStep,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        name: j['name'],
        weight: (j['weight'] as num).toDouble(),
        sets: j['sets'],
        reps: j['reps'],
        // Older files had no flags: a step of 0 meant off.
        increment: switch ((j['increment'] as num).toDouble()) { 0 => 2.5, final v => v },
        up: j['up'] ?? (j['increment'] as num) > 0,
        decrement: switch ((j['decrement'] as num?)?.toDouble()) { null || 0 => 2.5, final v => v },
        down: j['down'] ?? ((j['decrement'] as num?) ?? 0) > 0,
        failsToDeload: j['failsToDeload'] ?? 3,
        fails: j['fails'] ?? 0,
        restSeconds: j['restSeconds'] ?? 120,
        failRestSeconds: j['failRestSeconds'],
        setWeights: j['setWeights'] == null ? null : [for (final w in j['setWeights']) (w as num).toDouble()],
        setReps: j['setReps'] == null ? null : List<int>.from(j['setReps']),
        maxReps: j['maxReps'],
        cardio: j['type'] == 'cardio',
        km: (j['km'] as num?)?.toDouble(),
        timed: j['type'] == 'timed',
        auto: j['auto'] == true,
        state: j['autoState'] == null ? null : AutoState.fromJson(j['autoState']),
        loadStep: (j['loadStep'] as num?)?.toDouble(),
      );
}

/// What the auto mode remembers of an exercise between trainings.
class AutoState {
  static const startPct = 2.5, minPct = .5, maxPct = 2.5;

  /// Share of the weight a step adds, in percent: halved by every deload, doubled again by [streak].
  double pct;

  /// Trainings done in a row with 2 or more reps in reserve; 3 raise [pct].
  int streak;

  /// Trainings done in a row at the limit (reserve 0); from the second on half a step.
  int limits;

  /// Misses in a row excused as a bad day; at most 2.
  int excused;

  /// A rep bridge: the reps before it, and the reps at which the weight goes up a step.
  int? bridgeFrom, bridgeTo;

  /// Back from a break: the weight from before it, reached again in double steps.
  double? comebackTo;

  AutoState({this.pct = startPct, this.streak = 0, this.limits = 0, this.excused = 0, this.bridgeFrom, this.bridgeTo, this.comebackTo});

  Map<String, dynamic> toJson() => {
        'pct': pct,
        if (streak > 0) 'streak': streak,
        if (limits > 0) 'limits': limits,
        if (excused > 0) 'excused': excused,
        'bridgeFrom': ?bridgeFrom,
        'bridgeTo': ?bridgeTo,
        'comebackTo': ?comebackTo,
      };

  factory AutoState.fromJson(Map<String, dynamic> j) => AutoState(
        pct: (j['pct'] as num?)?.toDouble() ?? startPct,
        streak: j['streak'] ?? 0,
        limits: j['limits'] ?? 0,
        excused: j['excused'] ?? 0,
        bridgeFrom: j['bridgeFrom'],
        bridgeTo: j['bridgeTo'],
        comebackTo: (j['comebackTo'] as num?)?.toDouble(),
      );
}

/// Misses in a row before the auto mode takes weight off.
const autoFails = 3;

/// About 10 % off [kg] ([share] to keep), down to a multiple of [grid] (what can be loaded), at least one [grid].
double deloadTo(double kg, double grid, {double share = .9}) =>
    max(0.0, min(kg - grid, (kg * share / grid + 1e-9).floor() * grid));

/// Where a load step comes from, see [Store.loadStepOf].
enum LoadSource { set, plates, learned, guess }

/// What the auto mode did with an exercise after a training, kept on its log for the recap and the export.
enum Progression { up, up2, half, limit, bridge, range, miss, reset, badDay, pain, deload, lighter, fewer }

/// For the recap, after next time's weight: "↑ 102,5 kg · viel Reserve". [e] is the plan after the training,
/// for a bridge's reps.
String progressionLabel(Progression p, [Exercise? e]) => switch (p) {
      Progression.up => tr.progUp,
      Progression.up2 => tr.progUp2,
      Progression.half => tr.progHalf,
      Progression.limit => tr.progLimit,
      Progression.bridge => switch (e?.state?.bridgeTo) {
          final to? => tr.progBridgeTo(e!.reps, to),
          null => tr.progBridge,
        },
      Progression.range => tr.progRange,
      Progression.miss => tr.progMiss,
      Progression.reset => tr.progReset,
      Progression.badDay => tr.progBadDay,
      Progression.pain => tr.progPain,
      Progression.deload => tr.progDeload(autoFails),
      Progression.lighter => tr.progLighter,
      Progression.fewer => tr.progFewer,
    };

/// Tags after a training that excuse a miss in the auto mode (twice in a row at most). The mood doesn't:
/// it comes after the training, and a miss makes it bad.
const badDayTags = {'Krank', 'Schlecht geschlafen', 'Wenig gegessen', 'Stress'};

/// The tag that holds the weight in the auto mode, whatever happened.
const painTag = 'Schmerzen';

bool isBadDay(Session s) => s.tags.any(badDayTags.contains);


/// Big barbell lifts (squat, bench, deadlift, press, row, …), not their dumbbell or machine variants: the
/// warm-up takes longer, the plates per side are shown and the auto mode steps by the plates.
bool isBarbell(String name) {
  final k = searchKey(name);
  const big = ['kniebeuge', 'squat', 'kreuzheb', 'deadlift', 'bankdrueck', 'benchpress', 'schulterdrueck',
      'overheadpress', 'langhantelrudern', 'barbellrow', 'rackpull', 'goodmorning', 'pushpress', 'umsetzen', 'reissen'];
  const not = ['kurzhantel', 'dumbbell', 'maschine', 'machine', 'goblet', 'split', 'bulgarian', 'einbeinig', 'single'];
  return big.any(k.contains) && !not.any(k.contains);
}

class Workout {
  final String id;
  String name;
  List<Exercise> exercises;

  Workout({String? id, required this.name, List<Exercise>? exercises})
      : id = id ?? newId(),
        exercises = exercises ?? [];

  Workout copy() => Workout.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'],
        name: j['name'],
        exercises: [for (final e in j['exercises']) Exercise.fromJson(e)],
      );
}

/// What actually happened for one exercise in a session.
/// `reps[i] == null` means set i was not done.
class ExerciseLog {
  final String name;

  /// Target reps per set, same length as [reps].
  final List<int> targets;
  final List<int?> reps;

  /// Top of the rep range, if the plan has one.
  final int? maxReps;

  /// Weight per set, same length as [reps].
  final List<double> weights;

  /// Cardio: one "set", [reps] holds the minutes done and [targetReps] the planned minutes
  /// (0 with a distance goal, [targetKm]).
  final bool cardio;
  double? km;
  final double? targetKm;

  /// Held or carried: [reps] and [targets] are seconds.
  final bool timed;

  /// Cardio stopwatch: when it was started, while it runs.
  DateTime? startedAt;

  /// When each set was logged, same length as [reps]; null = not done, or logged before this was
  /// recorded. The base for how long an exercise takes, see timing.dart.
  final List<DateTime?> doneAt;

  /// Rest, rest after a missed set and weight step, copied from the exercise it was made from. The
  /// page prefers the plan; these count for an exercise that isn't in it (swapped in or added).
  final int? restSeconds, failRestSeconds;
  final double? increment;

  /// Changed during the training: the planned exercise this one stood in for, or added on top of
  /// the plan. Only for the export, the logic doesn't read them.
  final String? replaces;
  final bool added;

  /// Reps in reserve after the last set, as the user answered: 0 (at the limit) to 4 (four or more).
  /// Null when not asked or not answered. Read by the plateau finding, never by the 1RM.
  int? rir;

  /// Percent the auto mode took off at the start after a break, see [Store.comebackOf].
  final int? backoff;

  /// What the auto mode did after this training; null for a plan without it.
  Progression? progression;

  ExerciseLog({
    required this.name,
    required double weight,
    required int targetReps,
    required this.reps,
    List<int>? targets,
    this.maxReps,
    List<double>? weights,
    this.cardio = false,
    this.km,
    this.targetKm,
    this.timed = false,
    this.startedAt,
    List<DateTime?>? doneAt,
    this.restSeconds,
    this.failRestSeconds,
    this.increment,
    this.replaces,
    this.added = false,
    this.rir,
    this.backoff,
    this.progression,
  })  : weights = weights ?? List.filled(reps.length, weight),
        doneAt = doneAt ?? List.filled(reps.length, null),
        targets = targets ?? List.filled(reps.length, targetReps);

  /// A fresh log for training [e]: every set open.
  factory ExerciseLog.fromPlan(Exercise e, {String? replaces, bool added = false, int? backoff}) => ExerciseLog(
        name: e.name,
        weight: e.weight,
        weights: List.of(e.weights),
        targetReps: e.reps,
        targets: e.repsPerSet,
        maxReps: e.maxReps,
        reps: List.filled(e.sets, null, growable: true),
        cardio: e.cardio,
        targetKm: e.km,
        timed: e.timed,
        restSeconds: e.restSeconds,
        failRestSeconds: e.failRestSeconds,
        increment: e.increment,
        replaces: replaces,
        added: added,
        backoff: backoff,
      );

  /// This exercise reshaped to [e] as edited during the training: its sets, reps per set, rep range and
  /// weights. Logged sets stay as they were and where they were (so there are never fewer sets than the
  /// last logged one); the open ones take [e]'s. For cardio [e]'s goal. The plan isn't touched.
  ExerciseLog reshaped(Exercise e) {
    final done = [for (final (i, r) in reps.indexed) if (r != null) i];
    final n = max(e.cardio ? 1 : e.sets, done.isEmpty ? 0 : done.last + 1);
    T at<T>(List<T> l, int i) => l[min(i, l.length - 1)];
    bool kept(int i) => i < reps.length && reps[i] != null;
    return ExerciseLog(
      name: name,
      weight: e.weight,
      targetReps: at(e.repsPerSet, 0),
      reps: [for (var i = 0; i < n; i++) kept(i) ? reps[i] : null],
      targets: [for (var i = 0; i < n; i++) kept(i) ? targets[i] : at(e.repsPerSet, i)],
      weights: [for (var i = 0; i < n; i++) kept(i) ? weights[i] : at(e.weights, i)],
      doneAt: [for (var i = 0; i < n; i++) kept(i) ? doneAt[i] : null],
      maxReps: e.maxReps,
      cardio: cardio,
      km: km,
      targetKm: cardio ? e.km : targetKm,
      timed: timed,
      startedAt: startedAt,
      restSeconds: restSeconds,
      failRestSeconds: failRestSeconds,
      increment: increment,
      replaces: replaces,
      added: added,
      rir: n == done.length ? rir : null, // asked after the last set: open sets again, the answer goes
      backoff: backoff,
    );
  }

  /// The same exercise with other sets; the lists are final, so a set more or less is a new log.
  ExerciseLog withSets({
    required List<int?> reps,
    required List<int> targets,
    required List<double> weights,
    required List<DateTime?> doneAt,
  }) =>
      ExerciseLog(
        name: name,
        weight: weight,
        targetReps: targets.first,
        reps: reps,
        targets: targets,
        maxReps: maxReps,
        weights: weights,
        cardio: cardio,
        km: km,
        targetKm: targetKm,
        timed: timed,
        startedAt: startedAt,
        doneAt: doneAt,
        restSeconds: restSeconds,
        failRestSeconds: failRestSeconds,
        increment: increment,
        replaces: replaces,
        added: added,
        rir: reps.every((r) => r != null) ? rir : null, // asked after the last set
        backoff: backoff,
      );

  /// Target reps of the first set; for cardio the planned minutes.
  int get targetReps => targets.first;

  /// Working weight: the heaviest set. Progression and stats build on it.
  double get weight => weights.isEmpty ? 0 : weights.reduce(max); // negative: assistance

  bool get succeeded => cardio && targetKm != null
      ? reps.first != null && (km ?? 0) >= targetKm!
      : [for (final (i, r) in reps.indexed) r != null && r >= targets[i]].every((ok) => ok);
  int get setsDone => reps.where((r) => r != null).length;
  /// Weight × reps; nothing for holds, whose seconds aren't reps.
  double get volume => timed ? 0 : [for (final (i, r) in reps.indexed) (r ?? 0) * max(0.0, weights[i])].fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'weights': weights,
        'targetReps': targetReps,
        if (targets.any((t) => t != targetReps)) 'targets': targets,
        if (maxReps != null) 'maxReps': maxReps,
        'reps': reps,
        if (cardio) 'type': 'cardio',
        if (timed) 'type': 'timed',
        if (km != null) 'km': km,
        if (targetKm != null) 'targetKm': targetKm,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (doneAt.any((t) => t != null)) 'doneAt': [for (final t in doneAt) t?.toIso8601String()],
        if (replaces != null) 'replaces': replaces,
        if (added) 'added': true,
        'rir': ?rir,
        'backoff': ?backoff,
        'progression': ?progression?.name,
        // A planned exercise has these in the plan; one from outside it keeps them for the running training.
        if (replaces != null || added) ...{
          if (restSeconds != null) 'restSeconds': restSeconds,
          if (failRestSeconds != null) 'failRestSeconds': failRestSeconds,
          if (increment != null) 'increment': increment,
        },
      };

  // Older data has only "weight"; it then applies to every set.
  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        name: j['name'],
        weight: (j['weight'] as num).toDouble(),
        weights: j['weights'] == null ? null : [for (final w in j['weights']) (w as num).toDouble()],
        targetReps: j['targetReps'],
        targets: j['targets'] == null ? null : List<int>.from(j['targets']),
        maxReps: j['maxReps'],
        reps: List<int?>.from(j['reps']),
        cardio: j['type'] == 'cardio',
        km: (j['km'] as num?)?.toDouble(),
        targetKm: (j['targetKm'] as num?)?.toDouble(),
        timed: j['type'] == 'timed',
        startedAt: j['startedAt'] == null ? null : DateTime.parse(j['startedAt']),
        doneAt: j['doneAt'] == null ? null : [for (final t in j['doneAt']) t == null ? null : DateTime.parse(t)],
        restSeconds: j['restSeconds'],
        failRestSeconds: j['failRestSeconds'],
        increment: (j['increment'] as num?)?.toDouble(),
        replaces: j['replaces'],
        added: j['added'] == true,
        rir: j['rir'],
        backoff: j['backoff'],
        progression: Progression.values.asNameMap()[j['progression']],
      );
}

/// Circumstances to tap after a training, with their emoji: body, energy, food, surroundings.
/// Stored by label, so keep existing labels when changing the list.
const noteTags = {
  'Schlecht geschlafen': '😴',
  'Gut erholt': '🛌',
  'Muskelkater': '🦵',
  'Schmerzen': '🤕',
  'Krank': '🤒',
  'Stress': '😓',
  'Unmotiviert': '🥱',
  'Voller Energie': '⚡',
  'Wenig gegessen': '🍽️',
  'Alkohol': '🍺',
  'Koffein': '☕',
  'Wenig Zeit': '⏱️',
  'Studio voll': '👥',
  'Unterwegs': '🧳',
  'Technik-Fokus': '🎯',
};

/// A tag of [noteTags] in the app's language; they stay stored by their German label.
String tagLabel(String tag) => switch (tag) {
      'Schlecht geschlafen' => tr.tagSleptBadly,
      'Gut erholt' => tr.tagWellRested,
      'Muskelkater' => tr.tagSore,
      'Schmerzen' => tr.tagPain,
      'Krank' => tr.tagSick,
      'Stress' => tr.tagStress,
      'Unmotiviert' => tr.tagUnmotivated,
      'Voller Energie' => tr.tagEnergetic,
      'Wenig gegessen' => tr.tagAteLittle,
      'Alkohol' => tr.tagAlcohol,
      'Koffein' => tr.tagCaffeine,
      'Wenig Zeit' => tr.tagLittleTime,
      'Studio voll' => tr.tagGymBusy,
      'Unterwegs' => tr.tagTravelling,
      'Technik-Fokus' => tr.tagTechnique,
      _ => tag,
    };

/// What progression changes on a planned exercise, as it was before a training.
/// [auto] is the auto mode's part: reps, setReps and [AutoState], as JSON; null in the fixed mode.
typedef PlanState = ({double weight, List<double>? setWeights, int fails, Map<String, dynamic>? auto});

class Session {
  final String id;
  final String workoutId;
  final String workoutName;

  /// Start of the training; changes only when a past training is edited.
  DateTime date;
  final List<ExerciseLog> exercises;

  /// Last change while training (a set logged, a weight edited); decides when an abandoned
  /// training ends on its own, see [Store.autoFinish].
  DateTime? lastActivity;

  /// When it ended; null for trainings logged before this was recorded.
  DateTime? finishedAt;

  /// Entered on the recap after training: body weight in kg and a free note.
  double? bodyWeight;
  String? note;

  /// How the training felt: 1 schlecht, 2 okay, 3 gut.
  int? mood;

  /// Circumstances picked after it instead of typing, e.g. "Schlecht geschlafen"; see [noteTags].
  List<String> tags;

  /// The rest between sets while training: when it started (shifted forward by pauses), its length
  /// in seconds and, while paused, since when. Stored with the running training so leaving the page
  /// or the app being killed doesn't lose it; cleared on finish, so never in the history.
  DateTime? restStartedAt, restPausedAt;
  int? restSeconds;

  /// The plan of each exercise just before this training's progression, by name, so editing or deleting
  /// the training can undo and redo it. Only on the newest training of a workout (an older one's plan has
  /// moved on since); null on trainings from before this was recorded. Stored, not exported.
  Map<String, PlanState>? planBefore;

  Session({
    String? id,
    required this.workoutId,
    required this.workoutName,
    DateTime? date,
    required this.exercises,
    this.lastActivity,
    this.finishedAt,
    this.bodyWeight,
    this.note,
    this.mood,
    List<String>? tags,
    this.restStartedAt,
    this.restSeconds,
    this.restPausedAt,
    this.planBefore,
  })  : id = id ?? newId(),
        tags = tags ?? [],
        date = date ?? DateTime.now();

  int get setsDone => exercises.fold(0, (n, e) => n + e.setsDone);

  Duration? get duration => finishedAt?.difference(date);

  /// Seconds of rest left at [now]; negative once it's over, null without a rest.
  int? restLeft(DateTime now) => restStartedAt == null
      ? null
      : (restSeconds ?? 0) - (restPausedAt ?? now).difference(restStartedAt!).inSeconds;

  /// Moves the training in time; set times move along, so their gaps stay.
  void shift(Duration d) {
    DateTime? by(DateTime? t) => t?.add(d);
    date = date.add(d);
    finishedAt = by(finishedAt);
    lastActivity = by(lastActivity);
    for (final e in exercises) {
      e.startedAt = by(e.startedAt);
      for (var i = 0; i < e.doneAt.length; i++) {
        e.doneAt[i] = by(e.doneAt[i]);
      }
    }
  }

  Session copy() => Session.fromJson(toJson());

  factory Session.start(Workout w) => Session(
        workoutId: w.id,
        workoutName: w.name,
        exercises: [for (final e in w.exercises) ExerciseLog.fromPlan(e)],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workoutId': workoutId,
        'workoutName': workoutName,
        'date': date.toIso8601String(),
        if (lastActivity != null) 'lastActivity': lastActivity!.toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
        if (bodyWeight != null) 'bodyWeight': bodyWeight,
        if (note != null) 'note': note,
        if (mood != null) 'mood': mood,
        if (tags.isNotEmpty) 'tags': tags,
        if (restStartedAt != null) 'restStartedAt': restStartedAt!.toIso8601String(),
        if (restSeconds != null) 'restSeconds': restSeconds,
        if (restPausedAt != null) 'restPausedAt': restPausedAt!.toIso8601String(),
        if (planBefore case final p?)
          'planBefore': {
            for (final MapEntry(:key, :value) in p.entries)
              key: {'weight': value.weight, 'setWeights': ?value.setWeights, 'fails': value.fails, 'auto': ?value.auto},
          },
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'],
        workoutId: j['workoutId'],
        workoutName: j['workoutName'],
        date: DateTime.parse(j['date']),
        lastActivity: j['lastActivity'] == null ? null : DateTime.parse(j['lastActivity']),
        finishedAt: j['finishedAt'] == null ? null : DateTime.parse(j['finishedAt']),
        bodyWeight: (j['bodyWeight'] as num?)?.toDouble(),
        note: j['note'],
        mood: j['mood'],
        tags: j['tags'] == null ? null : List<String>.from(j['tags']),
        restStartedAt: j['restStartedAt'] == null ? null : DateTime.parse(j['restStartedAt']),
        restSeconds: j['restSeconds'],
        restPausedAt: j['restPausedAt'] == null ? null : DateTime.parse(j['restPausedAt']),
        planBefore: switch (j['planBefore']) {
          final Map<String, dynamic> p => {
              for (final MapEntry(:key, :value) in p.entries)
                key: (
                  weight: (value['weight'] as num).toDouble(),
                  setWeights: value['setWeights'] == null ? null : [for (final w in value['setWeights']) (w as num).toDouble()],
                  fails: value['fails'] as int? ?? 0,
                  auto: value['auto'],
                ),
            },
          _ => null,
        },
        exercises: [for (final e in j['exercises']) ExerciseLog.fromJson(e)],
      );
}

/// Version of the stored JSON (and of the export) this app writes and reads.
const dataVersion = 1;

/// The one entry point for reading FerroLog JSON that didn't come from this install's own save: checks
/// it's ours and brings an older version up to [dataVersion], step by step as versions are added.
/// Throws a [FormatException] with a message for the user, before anything is changed.
Map<String, dynamic> migrate(Object? j) {
  if (j is! Map<String, dynamic> || j['app'] != 'ferrolog') {
    throw FormatException(tr.fileNotFerrolog);
  }
  final version = j['version'];
  if (version is! int || version < 1) throw FormatException(tr.fileNoVersion);
  if (version > dataVersion) {
    throw FormatException(tr.fileTooNew(version, dataVersion));
  }
  // Steps go here: if (j['version'] == 1) j = _v1to2(j); ...
  if (j['workouts'] is! List || j['sessions'] is! List) throw FormatException(tr.fileNoData);
  return j;
}

/// The plan entry [log] trains in [w]: the n-th entry of its name for the n-th log of that name in
/// [logs], so a name that is in the plan twice (only in older data) gives each entry its own result.
Exercise? planEntryOf(Workout? w, List<ExerciseLog> logs, ExerciseLog log) {
  final n = logs.takeWhile((l) => !identical(l, log)).where((l) => l.name == log.name).length;
  return w?.exercises.where((e) => e.name == log.name).elementAtOrNull(n);
}

/// All app data, persisted as one JSON blob. The same JSON is what gets exported for AI analysis.
// ponytail: whole-blob save on every change, move to a DB if history grows past a few MB.
class Store extends ChangeNotifier {
  static const _key = 'ferrolog';
  final SharedPreferences _prefs;
  List<Workout> workouts = [];
  List<Session> sessions = []; // newest first

  /// Muscle groups the user picked for an exercise, by name: {"primary": [...], "secondary": [...]}.
  /// Read through musclesOf in muscles.dart.
  Map<String, dynamic> muscles = {};

  /// The session currently being trained, persisted so it survives the app being killed.
  Session? active;

  Store._empty(this._prefs);

  Store(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = jsonDecode(raw);
      _load(j['version'] == dataVersion ? j : migrate(j)); // an update may find data of an older version
    }
    final a = _prefs.getString('$_key.active');
    if (a != null) active = Session.fromJson(jsonDecode(a));
  }

  Future<void> saveActive(Session? s) async {
    s?.lastActivity = DateTime.now();
    active = s;
    notifyListeners();
    s == null ? await _prefs.remove('$_key.active') : await _prefs.setString('$_key.active', jsonEncode(s.toJson()));
  }

  static Future<Store> open() async => Store(await SharedPreferences.getInstance());

  void _load(Map<String, dynamic> j) {
    workouts = [for (final w in j['workouts']) Workout.fromJson(w)];
    sessions = [for (final s in j['sessions']) Session.fromJson(s)];
    muscles = Map.of(j['muscles'] ?? const {});
  }

  /// Takes the data of a file from elsewhere (the GitHub copy): only plans, trainings and muscles, never
  /// the export-only blocks or the running training. [merge] keeps what's only here: trainings join by id
  /// (ours win, they're the same training), plans by id (theirs win, their weights carry the progression of
  /// the newer trainings), muscles by name (theirs win). Without [merge] the three are replaced.
  /// Nothing changes if the file is refused. [beforeSave] runs once the file is accepted, before the save
  /// triggers [onSaved]: sync takes the file as its own there, so the push after it isn't a conflict.
  Future<void> importJson(Object? json, {required bool merge, Future<void> Function()? beforeSave}) async {
    final j = migrate(json);
    final Store other;
    try {
      other = Store._empty(_prefs).._load(j);
    } catch (e) {
      throw FormatException(tr.fileBroken(e));
    }
    if (merge) {
      final ids = {for (final s in sessions) s.id};
      sessions = [...sessions, ...other.sessions.where((s) => !ids.contains(s.id))]..sort((a, b) => b.date.compareTo(a.date));
      final theirs = {for (final w in other.workouts) w.id};
      workouts = [...other.workouts, ...workouts.where((w) => !theirs.contains(w.id))];
      muscles = {...muscles, ...other.muscles};
    } else {
      workouts = other.workouts;
      sessions = other.sessions;
      muscles = other.muscles;
    }
    await beforeSave?.call();
    await _save();
  }

  /// True if this device has trainings and [json] (a FerroLog file) holds no training or plan that isn't
  /// here too, so overwriting it loses nothing. Unreadable counts as false.
  bool covers(String json) {
    try {
      final j = migrate(jsonDecode(json));
      bool all(String key, Iterable<String> mine) => {for (final x in j[key]) x['id']}.difference(mine.toSet()).isEmpty;
      return sessions.isNotEmpty && all('sessions', sessions.map((s) => s.id)) && all('workouts', workouts.map((w) => w.id));
    } catch (_) {
      return false;
    }
  }

  /// Saves [muscles] after a change.
  Future<void> saveMuscles() => _save();

  Map<String, dynamic> toJson() => {
        'app': 'ferrolog',
        'version': dataVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'units': 'kg',
        'format': 'workouts = plans; exercise.weight is the weight for the NEXT session (setWeights, if '
            'present, per set; all 0 = no weight) and rises by "increment" when all sets hit "reps" (setReps, if present, '
            'per set; with "maxReps" a rep range whose top every set must reach) and "up" is true (progressive overload); '
            'after "failsToDeload" missed sessions in a row it drops by "decrement" if "down" is true; a set done lighter than '
            'planned holds the weight (no increase, no miss), an exercise skipped entirely changes nothing. "auto": true = auto mode '
            'instead of increment/up/down/failsToDeload, with its memory in "autoState": on success the weight rises by '
            'autoState.pct percent (starts at ${AutoState.startPct}, halved by each deload down to ${AutoState.minPct}, doubled back '
            'after 3 successes in a row with 2+ reps in reserve), rounded to the exercise\'s load step (barbell: the user\'s '
            'plates; else learned from the weights used; "loadStep" in kg when the user set it); twice that with 3+ reps in reserve (rir plus reps beyond the '
            'target in the last set), nothing at the limit, half a step the second time in a row at the limit; a step too '
            'small to load is bridged by reps (bridgeFrom = reps before, bridgeTo = reps at which the weight goes up a load '
            'step); a miss holds, the 2nd in a row ends a bridge, $autoFails in a row take off about 10 %; tags '
            '${badDayTags.map((t) => '"$t"').join(', ')} excuse a miss (2 in a row at most), "$painTag" holds everything; '
            'after 14 days without the exercise a training starts 5 % lighter, 28 days 10 %, 56 days 20 % '
            '(exercises[].backoff), then double steps back up to autoState.comebackTo; exercises[].progression = what the '
            'auto mode did (up, up2, half, limit, bridge, range, miss, reset, badDay, pain, deload, lighter, fewer). '
            'sessions = completed trainings, '
            'newest first; exercises[].reps holds reps done per set, null = set skipped (targets = target per set when '
            'they differ); "failRestSeconds" = rest after a missed set; exercises[].replaces = the planned exercise this '
            'one was swapped in for during the training, exercises[].added = added on top of the plan (both change '
            'nothing in the plan; sets added or taken off during a training neither: fewer sets than planned hold the weight, '
            'no increase, no miss); finishedAt = end of the training; bodyWeight (kg), note, mood (1 bad, 2 okay, 3 good) and tags (circumstances like "Schlecht geschlafen", "Alkohol") as entered after it; exercises[].weights '
            'the weight per set, exercises[].weight the heaviest of them. type "cardio": one set whose reps are '
            'minutes (targetReps = planned minutes, 0 when the goal is targetKm), km/targetKm = distance in km, no weight. '
            'type "timed" (held or carried, e.g. plank, farmer\'s walk): reps and targets are seconds, weight optional. '
            'exercises[].doneAt = when each set was logged (null = not done or not recorded); date = start of the training. '
            'exercises[].rir = reps in reserve after the last set as the user answered (0 = at the limit, 4 = four or more; '
            'only asked if switched on, missing = not answered). '
            'muscles = muscle groups the user set for an exercise (primary; secondary count half); other exercises '
            'use a built-in list.',
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        if (muscles.isNotEmpty) 'muscles': muscles,
      };

  /// Added to the export only (not to what's stored): statistics and the like, computed fresh each time.
  /// A failure there must not stop the export or sync of the data itself.
  Map<String, dynamic> Function()? exportExtras;

  /// The extras come right after the header, before the raw data: an AI reads the instructions in them
  /// first instead of finding them after hundreds of sessions.
  String exportJson() {
    final data = toJson();
    for (final s in data['sessions']) {
      s.remove('planBefore'); // undo state of the app, not training data
    }
    final j = {for (final k in const ['app', 'version', 'exportedAt', 'units']) k: data.remove(k)};
    if (exportExtras case final extras?) {
      try {
        j.addAll(extras());
      } catch (e) {
        j['derivedError'] = '$e';
      }
    }
    return const JsonEncoder.withIndent('  ').convert({...j, ...data});
  }

  /// Called after every saved change (used for GitHub sync, which then builds the export).
  void Function()? onSaved;

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(toJson()));
    onSaved?.call();
  }

  Future<void> saveWorkout(Workout w) {
    final i = workouts.indexWhere((x) => x.id == w.id);
    i < 0 ? workouts.add(w) : workouts[i] = w;
    return _save();
  }

  /// Replaces all plans at once (a plan from the AI, or undoing one); the trainings stay.
  Future<void> replacePlans(List<Workout> plans, {required Map<String, dynamic> muscles}) {
    workouts = plans;
    this.muscles = muscles;
    return _save();
  }

  Future<void> deleteWorkout(Workout w) {
    workouts.removeWhere((x) => x.id == w.id);
    return _save();
  }

  /// No activity for this long and the training counts as over.
  static const idleLimit = Duration(minutes: 30);

  /// Ends the running training if nothing happened for [idleLimit], dated at its last activity, so
  /// a forgotten "Beenden" doesn't stretch it over hours. Trainings without a logged set stay open.
  /// Can be switched off in the settings.
  Future<bool> autoFinish([DateTime? now]) async {
    if (!(_prefs.getBool('session.autoFinish') ?? true)) return false;
    final s = active;
    final last = s?.lastActivity ?? s?.date;
    if (s == null || last == null || s.setsDone == 0) return false;
    if ((now ?? DateTime.now()).difference(last) < idleLimit) return false;
    await finishSession(s, at: last);
    return true;
  }

  /// Stores the session and adjusts next time's weights: every exercise where all sets hit the
  /// target gets `increment` added; after `failsToDeload` misses in a row it drops by `decrement`.
  /// Exercises skipped entirely stay as they are. The plan before is kept on the session, see [Session.planBefore].
  Future<void> finishSession(Session s, {DateTime? at}) {
    s.finishedAt = at ?? DateTime.now();
    s.restStartedAt = s.restPausedAt = s.restSeconds = null; // only for the running training
    active = null;
    _prefs.remove('$_key.active');
    final w = _workoutOf(s);
    if (w != null) {
      lastSessionOf(w)?.planBefore = null;
      s.planBefore = {
        for (final e in w.exercises)
          if (s.exercises.any((log) => log.name == e.name))
            e.name: (
              weight: e.weight,
              setWeights: e.setWeights == null ? null : List.of(e.setWeights!),
              fails: e.fails,
              auto: e.auto ? {'reps': e.reps, 'setReps': ?e.setReps, 'state': ?e.state?.toJson()} : null,
            ),
      };
      _progress(w, s);
    }
    sessions.insert(0, s);
    return _save();
  }

  Workout? _workoutOf(Session s) => workouts.where((x) => x.id == s.workoutId).firstOrNull;

  void _progress(Workout w, Session s) {
    final bad = isBadDay(s), pain = s.tags.contains(painTag);
    for (final log in s.exercises) {
      final e = planEntryOf(w, s.exercises, log);
      log.progression = null;
      // Skipped entirely (no time, no bar): not a miss, the plan stays.
      if (e == null || log.setsDone == 0) continue;
      if (log.backoff case final pct? when e.auto) {
        // Back after a break: the lighter start becomes the plan, the old weight the way back.
        final ws = comebackWeights(e, pct);
        (e.state ??= AutoState()).comebackTo = max(e.state!.comebackTo ?? 0, e.weight);
        if (e.setWeights != null) e.setWeights = ws;
        e.weight = ws.reduce(max);
      }
      log.progression = e.applyResult(log, badDay: bad, pain: pain, grid: loadStepOf(e).$1);
    }
  }

  /// The smallest step [e]'s weight can change by, in kg, and where it comes from: as set for the exercise
  /// ([Exercise.loadStep]); for a barbell lift both
  /// sides' smallest plate the user has; else learned from the weights used (the coarsest step all of them
  /// fit, once there are 3 different ones); else a start value by kind: dumbbells 2 kg, machines and cables
  /// 2,5 kg (5 lb each), anything else the plan's increment.
  (double, LoadSource) loadStepOf(Exercise e) {
    final lb = unit.value == WeightUnit.lb;
    if (e.loadStep case final step? when step > 0) return (step, LoadSource.set);
    if (isBarbell(e.name)) {
      final plates = [
        for (final p in _prefs.getStringList('barbell.plates.${unit.value.name}') ?? const <String>[]) double.parse(p),
      ];
      return (toKg(2 * (plates.isEmpty ? plateChoices[unit.value]! : plates).reduce(min)), LoadSource.plates);
    }
    final used = {
      for (final (_, l) in historyOf(e.name)) for (final w in l.weights) if (w > 0) shown(w),
      for (final w in e.weights) if (w > 0) shown(w),
    };
    if (used.length >= 3) {
      for (final g in lb ? const [10.0, 5.0, 2.5, 1.0] : const [5.0, 2.5, 2.0, 1.25, 1.0, .5]) {
        if (used.every((w) => ((w / g) - (w / g).round()).abs() < 1e-3)) return (toKg(g), LoadSource.learned);
      }
    }
    final k = searchKey(e.name);
    if (const ['kurzhantel', 'dumbbell'].any(k.contains)) return (toKg(lb ? 5 : 2), LoadSource.guess);
    if (const ['maschine', 'machine', 'kabel', 'cable', 'zug', 'presse', 'press'].any(k.contains)) {
      return (toKg(lb ? 5 : 2.5), LoadSource.guess);
    }
    return (e.increment, LoadSource.guess);
  }

  /// Percent an auto exercise starts lighter after a break: 5 from 14 days without it, 10 from 4 weeks,
  /// 20 from 8 weeks. Null when trained lately, never trained, or not in auto mode.
  int? comebackOf(Exercise e, [DateTime? now]) {
    if (!e.auto || e.cardio || e.weight <= 0) return null;
    final last = sessions.where((s) => s.exercises.any((l) => l.name == e.name && l.setsDone > 0)).firstOrNull;
    if (last == null) return null;
    final days = (now ?? DateTime.now()).difference(last.date).inDays;
    return days >= 56 ? 20 : days >= 28 ? 10 : days >= 14 ? 5 : null;
  }

  /// [e]'s planned weights [pct] percent lighter, down to what can be loaded.
  List<double> comebackWeights(Exercise e, int pct) {
    final grid = loadStepOf(e).$1;
    return [for (final w in e.weights) w <= 0 ? w : deloadTo(w, grid, share: 1 - pct / 100)];
  }

  /// A fresh training of [w]; auto exercises back after a break start lighter ([comebackOf]). Not saved.
  Session startSession(Workout w, [DateTime? now]) {
    final s = Session.start(w);
    for (final (i, e) in w.exercises.indexed) {
      if (comebackOf(e, now) case final pct?) {
        final log = s.exercises[i] = ExerciseLog.fromPlan(e, backoff: pct);
        log.weights.setAll(0, comebackWeights(e, pct));
      }
    }
    return s;
  }

  /// True if editing or deleting [s] moves the plan: it's the newest training of its workout and knows
  /// the plan before it.
  bool movesPlan(Session s) => switch (_workoutOf(s)) {
        final w? => s.planBefore != null && lastSessionOf(w)?.id == s.id,
        null => false,
      };

  /// Puts the plan back to before [s] (see [movesPlan]). An exercise whose per-set weights were changed
  /// in the plan since (another count, or uniform now) stays as it is. Doesn't save.
  void revertProgression(Session s) {
    final w = _workoutOf(s);
    if (w == null || !movesPlan(s)) return;
    for (final MapEntry(key: name, value: before) in s.planBefore!.entries) {
      final e = w.exercises.where((x) => x.name == name).firstOrNull;
      if (e == null || before.setWeights?.length != e.setWeights?.length) continue;
      e
        ..weight = before.weight
        ..setWeights = before.setWeights == null ? null : List.of(before.setWeights!)
        ..fails = before.fails;
      // The auto mode's reps and memory, unless the mode or the sets were changed in the plan since.
      if (before.auto case final a? when e.auto && (a['setReps'] as List?)?.length == e.setReps?.length) {
        e
          ..reps = a['reps']
          ..setReps = a['setReps'] == null ? null : List<int>.from(a['setReps'])
          ..state = a['state'] == null ? null : AutoState.fromJson(a['state']);
      }
    }
  }

  /// The plan as if [s] had been finished as it is now: back to before it, then its progression again.
  /// Doesn't save.
  void reapplyProgression(Session s) {
    if (!movesPlan(s)) return;
    revertProgression(s);
    _progress(_workoutOf(s)!, s);
  }

  /// Saves changes made in place to a stored session (body weight, note). With [replan] (the mood or
  /// tags changed) the auto mode looks at the training again: a bad day doesn't count a miss.
  Future<void> updateSession(Session s, {bool replan = false}) {
    if (replan && (_workoutOf(s)?.exercises.any((e) => e.auto) ?? false)) reapplyProgression(s);
    return _save();
  }

  /// Takes an edited copy of a stored training (same id): the history re-sorted by date and, for the
  /// newest training of its workout, the plan recomputed. A training moved behind another of its workout
  /// leaves the plan as it is and no longer moves it.
  Future<void> replaceSession(Session edited) {
    final i = sessions.indexWhere((x) => x.id == edited.id);
    if (i < 0) return Future.value();
    final moves = movesPlan(sessions[i]);
    sessions[i] = edited;
    sessions.sort((a, b) => b.date.compareTo(a.date));
    if (moves && movesPlan(edited)) {
      reapplyProgression(edited);
    } else {
      // Only the newest training of a workout keeps the plan before it.
      for (final s in sessions.where((x) => x.workoutId == edited.workoutId).skip(moves ? 0 : 1)) {
        s.planBefore = null;
      }
    }
    return _save();
  }

  /// Removes a training; the newest of its workout takes its progression back with it.
  Future<void> deleteSession(Session s) {
    revertProgression(s);
    sessions.removeWhere((x) => x.id == s.id);
    return _save();
  }

  /// Names that can't merge into each other: both in one workout, which would then hold one twice.
  bool shareAWorkout(String a, String b) =>
      workouts.any((w) => w.exercises.any((e) => e.name == a) && w.exercises.any((e) => e.name == b));

  /// Renames an exercise everywhere in one save: plans, trainings (also where it was swapped out), the
  /// running training, its muscles and the findings put off for it. If [to] has a history already, the two
  /// become one, ordered by date as before; that's how a split history is repaired.
  Future<void> renameExercise(String from, String to) async {
    if (from == to) return;
    if (shareAWorkout(from, to)) throw StateError('„$from“ und „$to“ stehen im selben Workout.');
    for (final w in workouts) {
      for (final e in w.exercises) {
        if (e.name == from) e.name = to;
      }
    }
    void renameIn(Session s) {
      for (var i = 0; i < s.exercises.length; i++) {
        final log = s.exercises[i];
        if (log.name != from && log.replaces != from) continue;
        // The name is final: rebuilt through JSON. Swapped in for itself is no swap.
        final j = log.toJson();
        if (log.name == from) j['name'] = to;
        if (log.replaces == from) j['replaces'] = to;
        if (j['replaces'] == j['name']) j.remove('replaces');
        s.exercises[i] = ExerciseLog.fromJson(j);
      }
      if (s.planBefore?.remove(from) case final before?) s.planBefore![to] = before;
    }

    sessions.forEach(renameIn);
    if (active case final a?) {
      renameIn(a);
      await saveActive(a);
    }
    final fromKey = searchKey(from), toKey = searchKey(to);
    final own = muscles.keys.where((k) => searchKey(k) == fromKey).toList();
    for (final k in own) {
      final m = muscles.remove(k);
      if (!muscles.keys.any((x) => searchKey(x) == toKey)) muscles[to] = m;
    }
    // Finding ids are "kind:exercise[:date]", see findings.dart; stored by training_card.dart.
    if (_prefs.getString('tasks.snoozed') case final raw?) {
      final snoozed = jsonDecode(raw) as Map<String, dynamic>;
      await _prefs.setString('tasks.snoozed', jsonEncode({
        for (final MapEntry(:key, :value) in snoozed.entries)
          switch (key.split(':')) {
            [final kind, final name, ...final rest] when name == from => [kind, to, ...rest].join(':'),
            _ => key,
          }: value,
      }));
    }
    await _save();
  }

  Session? lastSessionOf(Workout w) => sessions.where((s) => s.workoutId == w.id).firstOrNull;

  /// Every logged set of an exercise, oldest first: (date, log).
  List<(DateTime, ExerciseLog)> historyOf(String exercise) => [
        for (final s in sessions.reversed)
          for (final e in s.exercises)
            if (e.name == exercise && e.setsDone > 0) (s.date, e),
      ];

  List<String> get loggedExercises => {for (final s in sessions) for (final e in s.exercises) e.name}.toList()..sort();
}

/// Catalogue for the "add exercise" helper: name -> defaults (sets, reps, weight kg, increment kg, rest s).
/// Rests kept short on purpose: 1:30 for heavy compound lifts, 1 min for everything else.
/// Bodyweight exercises start at 0 kg extra; for [timedExercises] the reps are seconds.
const exerciseCatalogue = <String, (int, int, double, double, int)>{
  'Kniebeuge': (3, 5, 60.0, 2.5, 90),
  'Kreuzheben': (1, 5, 80.0, 5.0, 90),
  'Rumänisches Kreuzheben': (3, 8, 50.0, 2.5, 90),
  'Bankdrücken': (3, 5, 50.0, 2.5, 90),
  'Schrägbankdrücken': (3, 8, 40.0, 2.5, 90),
  'Kurzhantel-Bankdrücken': (3, 10, 20.0, 2.0, 60),
  'Schulterdrücken': (3, 5, 30.0, 1.25, 90),
  'Kurzhantel-Schulterdrücken': (3, 10, 14.0, 2.0, 60),
  'Langhantelrudern': (3, 8, 40.0, 2.5, 60),
  'Kurzhantelrudern': (3, 10, 20.0, 2.0, 60),
  'Kabelrudern': (3, 10, 40.0, 5.0, 60),
  'Klimmzüge': (3, 8, 0.0, 1.25, 60),
  'Latzug': (3, 10, 40.0, 5.0, 60),
  'Dips': (3, 10, 0.0, 1.25, 60),
  'Beinpresse': (3, 10, 100.0, 10.0, 90),
  'Ausfallschritte': (3, 10, 20.0, 2.0, 60),
  'Bulgarian Split Squat': (3, 10, 16.0, 2.0, 60),
  'Beinstrecker': (3, 12, 30.0, 5.0, 60),
  'Beinbeuger': (3, 12, 30.0, 5.0, 60),
  'Nordic Curls': (3, 5, 0.0, 1.25, 90),
  'Hip Thrust': (3, 10, 60.0, 5.0, 90),
  'Wadenheben': (3, 15, 40.0, 5.0, 60),
  'Bizepscurls': (3, 10, 20.0, 1.0, 60),
  'Hammercurls': (3, 10, 12.0, 1.0, 60),
  'Trizepsdrücken am Kabel': (3, 12, 20.0, 2.5, 60),
  'French Press': (3, 10, 20.0, 1.25, 60),
  'Seitheben': (3, 15, 8.0, 1.0, 60),
  'Face Pulls': (3, 15, 15.0, 2.5, 60),
  'Butterfly': (3, 12, 30.0, 5.0, 60),
  'Crunches': (3, 15, 0.0, 1.25, 60),
  'Enges Bankdrücken': (3, 8, 40.0, 2.5, 90),
  'Negativbankdrücken': (3, 8, 50.0, 2.5, 90),
  'Kurzhantel-Schrägbankdrücken': (3, 10, 18.0, 2.0, 60),
  'Kurzhantel-Fliegende': (3, 12, 10.0, 1.0, 60),
  'Kabelzug-Crossover': (3, 12, 15.0, 2.5, 60),
  'Brustpresse': (3, 10, 40.0, 5.0, 60),
  'Liegestütze': (3, 15, 0.0, 1.25, 60),
  'Überzüge': (3, 12, 16.0, 2.0, 60),
  'Arnold Press': (3, 10, 12.0, 2.0, 60),
  'Push Press': (3, 5, 40.0, 2.5, 90),
  'Maschinen-Schulterdrücken': (3, 10, 30.0, 5.0, 60),
  'Frontheben': (3, 12, 8.0, 1.0, 60),
  'Reverse Butterfly': (3, 15, 20.0, 2.5, 60),
  'Aufrechtes Rudern': (3, 10, 25.0, 2.5, 60),
  'Shrugs': (3, 12, 60.0, 5.0, 60),
  'T-Bar-Rudern': (3, 8, 40.0, 2.5, 60),
  'Maschinenrudern': (3, 10, 40.0, 5.0, 60),
  'Umgekehrtes Rudern': (3, 10, 0.0, 1.25, 60),
  'Klimmzüge im Untergriff': (3, 8, 0.0, 1.25, 60),
  'Latzug eng': (3, 10, 40.0, 5.0, 60),
  'Überzüge am Kabel': (3, 12, 20.0, 2.5, 60),
  'Rückenstrecker': (3, 12, 0.0, 2.5, 60),
  'Good Mornings': (3, 8, 30.0, 2.5, 60),
  'Rack Pulls': (3, 5, 100.0, 5.0, 90),
  'Frontkniebeuge': (3, 5, 40.0, 2.5, 90),
  'Goblet Squat': (3, 10, 16.0, 2.0, 60),
  'Hackenschmidt-Kniebeuge': (3, 10, 40.0, 5.0, 90),
  'Sumo-Kreuzheben': (1, 5, 80.0, 5.0, 90),
  'Trap-Bar-Kreuzheben': (1, 5, 80.0, 5.0, 90),
  'Kreuzheben mit gestreckten Beinen': (3, 8, 50.0, 2.5, 90),
  'Einbeiniges Kreuzheben': (3, 10, 12.0, 2.0, 60),
  'Step-ups': (3, 10, 12.0, 2.0, 60),
  'Ausfallschritte gehend': (3, 12, 12.0, 2.0, 60),
  'Adduktorenmaschine': (3, 12, 40.0, 5.0, 60),
  'Abduktorenmaschine': (3, 12, 40.0, 5.0, 60),
  'Wadenheben sitzend': (3, 15, 30.0, 5.0, 60),
  'SZ-Curls': (3, 10, 20.0, 1.25, 60),
  'Langhantelcurls': (3, 10, 25.0, 1.25, 60),
  'Konzentrationscurls': (3, 12, 10.0, 1.0, 60),
  'Scottcurls': (3, 10, 20.0, 1.25, 60),
  'Kabelcurls': (3, 12, 15.0, 2.5, 60),
  'Trizeps-Überkopfdrücken': (3, 12, 15.0, 1.25, 60),
  'Trizeps-Kickbacks': (3, 12, 6.0, 1.0, 60),
  'Bankdips': (3, 12, 0.0, 1.25, 60),
  'Handgelenkcurls': (3, 15, 10.0, 1.0, 60),
  'Plank': (3, 30, 0.0, 1.25, 60),
  'Seitstütz': (3, 30, 0.0, 1.25, 60),
  'Beinheben hängend': (3, 10, 0.0, 1.25, 60),
  'Beinheben liegend': (3, 15, 0.0, 1.25, 60),
  'Sit-ups': (3, 15, 0.0, 1.25, 60),
  'Russian Twists': (3, 20, 5.0, 1.0, 60),
  'Kabel-Crunches': (3, 12, 30.0, 2.5, 60),
  'Ab Wheel': (3, 10, 0.0, 1.25, 60),
  'Pallof Press': (3, 12, 10.0, 2.5, 60),
  'Dead Bug': (3, 10, 0.0, 1.25, 60),
  'Farmers Walk': (3, 30, 24.0, 2.0, 60),
  'Suitcase Carry': (3, 30, 20.0, 2.0, 60),
  'Kettlebell Swings': (3, 15, 16.0, 4.0, 60),
  'Turkish Get-up': (3, 3, 12.0, 4.0, 60),
  'Thruster': (3, 8, 30.0, 2.5, 90),
  'Burpees': (3, 10, 0.0, 1.25, 60),
  'Umsetzen': (3, 3, 40.0, 2.5, 90),
  'Reißen': (3, 3, 30.0, 2.5, 90),
};

/// Heavy barbell lifts: after a missed set they get a longer rest (2 min) than their usual 1:30.
const heavyLifts = {'Kniebeuge', 'Frontkniebeuge', 'Bankdrücken', 'Schulterdrücken', 'Kreuzheben', 'Sumo-Kreuzheben',
    'Trap-Bar-Kreuzheben'};

/// The top of a range as suggested for a new accessory: three reps more, or half as long again for
/// a hold (30 s → 30–45 s). The [heavyLifts] keep fixed reps.
int rangeTop(int reps, {bool seconds = false}) => seconds ? max(reps + 5, (reps * 1.5 / 5).round() * 5) : reps + 3;

/// Held or carried for a time: their reps are seconds.
const timedExercises = {'Plank', 'Seitstütz', 'Farmers Walk', 'Suitcase Carry'};

/// Cardio catalogue: name -> default minutes and distance in km (null = no distance).
/// Cardio defaults: (minutes, km); with km the goal is the distance.
const cardioCatalogue = <String, (int, double?)>{
  'Laufen': (30, 5.0),
  'Laufband': (20, null),
  'Radfahren': (45, null),
  'Ergometer-Rudern': (10, 2.0),
  'Crosstrainer': (20, null),
  'Seilspringen': (10, null),
  'Treppensteiger': (15, null),
};

/// Other names a catalogue exercise is found by: English and common spellings.
const exerciseAliases = <String, List<String>>{
  'Kniebeuge': ['Squat', 'Back Squat', 'Low Bar Squat'],
  'Kreuzheben': ['Deadlift', 'Conventional Deadlift'],
  'Rumänisches Kreuzheben': ['Romanian Deadlift', 'RDL'],
  'Bankdrücken': ['Bench Press', 'Bench'],
  'Schrägbankdrücken': ['Incline Bench Press', 'Incline Bench'],
  'Kurzhantel-Bankdrücken': ['Dumbbell Bench Press', 'DB Bench'],
  'Schulterdrücken': ['Overhead Press', 'OHP', 'Military Press', 'Press'],
  'Kurzhantel-Schulterdrücken': ['Dumbbell Shoulder Press', 'DB Press'],
  'Langhantelrudern': ['Barbell Row', 'Bent Over Row', 'Pendlay Row'],
  'Kurzhantelrudern': ['Dumbbell Row', 'DB Row'],
  'Kabelrudern': ['Cable Row', 'Seated Row'],
  'Klimmzüge': ['Pull-ups', 'Pullups', 'Pull Up'],
  'Latzug': ['Lat Pulldown', 'Pulldown'],
  'Dips': ['Dips'],
  'Beinpresse': ['Leg Press'],
  'Ausfallschritte': ['Lunges'],
  'Bulgarian Split Squat': ['Bulgarische Kniebeuge', 'Split Squat'],
  'Beinstrecker': ['Leg Extension'],
  'Beinbeuger': ['Leg Curl'],
  'Nordic Curls': ['Nordic Hamstring Curl', 'Nordics'],
  'Crunches': ['Crunch'],
  'Enges Bankdrücken': ['Close Grip Bench Press', 'Close-Grip Bench'],
  'Negativbankdrücken': ['Decline Bench Press', 'Decline Bench'],
  'Kurzhantel-Schrägbankdrücken': ['Incline Dumbbell Press', 'Incline DB Press'],
  'Kurzhantel-Fliegende': ['Dumbbell Fly', 'Dumbbell Flyes'],
  'Kabelzug-Crossover': ['Cable Crossover', 'Cable Fly'],
  'Brustpresse': ['Chest Press', 'Machine Chest Press'],
  'Liegestütze': ['Push-ups', 'Pushups', 'Push Up'],
  'Überzüge': ['Pullover', 'Dumbbell Pullover'],
  'Arnold Press': ['Arnold-Drücken'],
  'Maschinen-Schulterdrücken': ['Machine Shoulder Press'],
  'Frontheben': ['Front Raise'],
  'Reverse Butterfly': ['Reverse Fly', 'Rear Delt Fly', 'Vorgebeugtes Seitheben'],
  'Aufrechtes Rudern': ['Upright Row'],
  'Shrugs': ['Schulterheben', 'Shrug'],
  'T-Bar-Rudern': ['T-Bar Row'],
  'Maschinenrudern': ['Machine Row'],
  'Umgekehrtes Rudern': ['Inverted Row', 'Australian Pull-up'],
  'Klimmzüge im Untergriff': ['Chin-ups', 'Chinups', 'Chin Up'],
  'Latzug eng': ['Close Grip Lat Pulldown', 'V-Bar Pulldown'],
  'Überzüge am Kabel': ['Straight Arm Pulldown', 'Cable Pullover'],
  'Rückenstrecker': ['Hyperextensions', 'Hyperextension', 'Back Extension'],
  'Good Mornings': ['Good Morning'],
  'Rack Pulls': ['Rack Pull'],
  'Frontkniebeuge': ['Front Squat'],
  'Goblet Squat': ['Kelchkniebeuge'],
  'Hackenschmidt-Kniebeuge': ['Hack Squat'],
  'Sumo-Kreuzheben': ['Sumo Deadlift'],
  'Trap-Bar-Kreuzheben': ['Trap Bar Deadlift', 'Hex Bar Deadlift'],
  'Kreuzheben mit gestreckten Beinen': ['Stiff Leg Deadlift', 'Stiff-Legged Deadlift'],
  'Einbeiniges Kreuzheben': ['Single Leg Romanian Deadlift', 'Single-Leg RDL'],
  'Step-ups': ['Aufsteiger', 'Step Up'],
  'Ausfallschritte gehend': ['Walking Lunges'],
  'Adduktorenmaschine': ['Hip Adduction', 'Adductor Machine'],
  'Abduktorenmaschine': ['Hip Abduction', 'Abductor Machine'],
  'Wadenheben sitzend': ['Seated Calf Raise'],
  'SZ-Curls': ['EZ Bar Curl'],
  'Langhantelcurls': ['Barbell Curl'],
  'Konzentrationscurls': ['Concentration Curl'],
  'Scottcurls': ['Preacher Curl'],
  'Kabelcurls': ['Cable Curl'],
  'Trizeps-Überkopfdrücken': ['Overhead Triceps Extension', 'Overhead Tricep Extension'],
  'Trizeps-Kickbacks': ['Triceps Kickback', 'Kickbacks'],
  'Bankdips': ['Bench Dips'],
  'Handgelenkcurls': ['Wrist Curl'],
  'Plank': ['Unterarmstütz', 'Planke'],
  'Seitstütz': ['Side Plank'],
  'Beinheben hängend': ['Hanging Leg Raise', 'Hängendes Beinheben'],
  'Beinheben liegend': ['Lying Leg Raise', 'Leg Raises'],
  'Sit-ups': ['Situps'],
  'Russian Twists': ['Russian Twist'],
  'Kabel-Crunches': ['Cable Crunch'],
  'Ab Wheel': ['Bauchroller', 'Ab Rollout'],
  'Dead Bug': ['Dead Bugs'],
  'Farmers Walk': ["Farmer's Walk", 'Farmers Carry', "Farmer's Carry", 'Bauernlauf'],
  'Suitcase Carry': ['Koffertragen'],
  'Kettlebell Swings': ['Kettlebell Swing', 'KB Swing'],
  'Turkish Get-up': ['Türkisches Aufstehen', 'TGU'],
  'Thruster': ['Thrusters'],
  'Burpees': ['Burpee'],
  'Umsetzen': ['Power Clean', 'Clean'],
  'Reißen': ['Snatch', 'Power Snatch'],
  'Hip Thrust': ['Hüftstoßen', 'Glute Bridge'],
  'Wadenheben': ['Calf Raise'],
  'Bizepscurls': ['Biceps Curl', 'Bicep Curl', 'Curls'],
  'Hammercurls': ['Hammer Curl'],
  'Trizepsdrücken am Kabel': ['Triceps Pushdown', 'Tricep Pushdown'],
  'French Press': ['Skull Crusher', 'Lying Triceps Extension'],
  'Seitheben': ['Lateral Raise', 'Side Raise'],
  'Face Pulls': ['Face Pull'],
  'Butterfly': ['Chest Fly', 'Pec Deck', 'Fly'],
  'Laufen': ['Running', 'Run', 'Joggen', 'Jogging'],
  'Laufband': ['Treadmill'],
  'Radfahren': ['Cycling', 'Bike', 'Fahrrad', 'Ergometer', 'Spinning'],
  'Ergometer-Rudern': ['Rowing', 'Rower', 'Rudergerät', 'Erg'],
  'Crosstrainer': ['Elliptical', 'Cross Trainer'],
  'Seilspringen': ['Jump Rope', 'Skipping', 'Springseil'],
  'Treppensteiger': ['Stair Climber', 'Stairmaster', 'Stepper'],
};

/// English names of the catalogue exercises; the rest (Plank, Face Pulls, …) are the same in both.
/// The catalogue stays keyed by the German name: that's what older data holds.
const exerciseNamesEn = <String, String>{
  'Kniebeuge': 'Squat',
  'Kreuzheben': 'Deadlift',
  'Rumänisches Kreuzheben': 'Romanian Deadlift',
  'Bankdrücken': 'Bench Press',
  'Schrägbankdrücken': 'Incline Bench Press',
  'Kurzhantel-Bankdrücken': 'Dumbbell Bench Press',
  'Schulterdrücken': 'Overhead Press',
  'Kurzhantel-Schulterdrücken': 'Dumbbell Shoulder Press',
  'Langhantelrudern': 'Barbell Row',
  'Kurzhantelrudern': 'Dumbbell Row',
  'Kabelrudern': 'Cable Row',
  'Klimmzüge': 'Pull-ups',
  'Latzug': 'Lat Pulldown',
  'Beinpresse': 'Leg Press',
  'Ausfallschritte': 'Lunges',
  'Beinstrecker': 'Leg Extension',
  'Beinbeuger': 'Leg Curl',
  'Wadenheben': 'Calf Raise',
  'Bizepscurls': 'Biceps Curl',
  'Hammercurls': 'Hammer Curl',
  'Trizepsdrücken am Kabel': 'Triceps Pushdown',
  'French Press': 'Skull Crusher',
  'Seitheben': 'Lateral Raise',
  'Butterfly': 'Chest Fly',
  'Enges Bankdrücken': 'Close-Grip Bench Press',
  'Negativbankdrücken': 'Decline Bench Press',
  'Kurzhantel-Schrägbankdrücken': 'Incline Dumbbell Press',
  'Kurzhantel-Fliegende': 'Dumbbell Fly',
  'Kabelzug-Crossover': 'Cable Crossover',
  'Brustpresse': 'Chest Press',
  'Liegestütze': 'Push-ups',
  'Überzüge': 'Pullover',
  'Maschinen-Schulterdrücken': 'Machine Shoulder Press',
  'Frontheben': 'Front Raise',
  'Reverse Butterfly': 'Reverse Fly',
  'Aufrechtes Rudern': 'Upright Row',
  'T-Bar-Rudern': 'T-Bar Row',
  'Maschinenrudern': 'Machine Row',
  'Umgekehrtes Rudern': 'Inverted Row',
  'Klimmzüge im Untergriff': 'Chin-ups',
  'Latzug eng': 'Close-Grip Lat Pulldown',
  'Überzüge am Kabel': 'Straight-Arm Pulldown',
  'Rückenstrecker': 'Back Extension',
  'Frontkniebeuge': 'Front Squat',
  'Hackenschmidt-Kniebeuge': 'Hack Squat',
  'Sumo-Kreuzheben': 'Sumo Deadlift',
  'Trap-Bar-Kreuzheben': 'Trap Bar Deadlift',
  'Kreuzheben mit gestreckten Beinen': 'Stiff-Leg Deadlift',
  'Einbeiniges Kreuzheben': 'Single-Leg Romanian Deadlift',
  'Ausfallschritte gehend': 'Walking Lunges',
  'Adduktorenmaschine': 'Hip Adduction',
  'Abduktorenmaschine': 'Hip Abduction',
  'Wadenheben sitzend': 'Seated Calf Raise',
  'SZ-Curls': 'EZ-Bar Curl',
  'Langhantelcurls': 'Barbell Curl',
  'Konzentrationscurls': 'Concentration Curl',
  'Scottcurls': 'Preacher Curl',
  'Kabelcurls': 'Cable Curl',
  'Trizeps-Überkopfdrücken': 'Overhead Triceps Extension',
  'Trizeps-Kickbacks': 'Triceps Kickback',
  'Bankdips': 'Bench Dips',
  'Handgelenkcurls': 'Wrist Curl',
  'Seitstütz': 'Side Plank',
  'Beinheben hängend': 'Hanging Leg Raise',
  'Beinheben liegend': 'Lying Leg Raise',
  'Kabel-Crunches': 'Cable Crunch',
  'Umsetzen': 'Power Clean',
  'Reißen': 'Snatch',
  'Laufen': 'Running',
  'Laufband': 'Treadmill',
  'Radfahren': 'Cycling',
  'Ergometer-Rudern': 'Rowing',
  'Crosstrainer': 'Elliptical',
  'Seilspringen': 'Jump Rope',
  'Treppensteiger': 'Stair Climber',
};

/// A catalogue exercise ([exerciseCatalogue], [cardioCatalogue]) under its name in the app's language,
/// for templates and suggestions. Other names come back as they are.
String exerciseLabel(String name) => appLocale.languageCode == 'de' ? name : exerciseNamesEn[name] ?? name;

final _catalogueNames = <String, String>{
  for (final name in [...exerciseCatalogue.keys, ...cardioCatalogue.keys])
    for (final n in [name, ?exerciseNamesEn[name], ...?exerciseAliases[name]]) searchKey(n): name,
};

/// The catalogue's (German) name of [name], whatever language or spelling it's in: "Bench Press" →
/// "Bankdrücken". Own exercises come back as they are.
String catalogueName(String name) => _catalogueNames[searchKey(name)] ?? name;

/// Lower case, umlauts spelled out, only letters and digits: "Bench-Press" and "bench press"
/// both become "benchpress", "Bankdrücken" and "bankdruecken" both "bankdruecken".
String searchKey(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp('[^a-z0-9]'), '');

/// Known names matching [query] in German or English, best matches first.
List<String> searchExercises(String query, Iterable<String> names) {
  final q = searchKey(query);
  if (q.isEmpty) return [];
  int score(String name) {
    final c = catalogueName(name);
    final keys = [name, c, ?exerciseNamesEn[c], ...?exerciseAliases[c]].map(searchKey);
    if (keys.any((k) => k.startsWith(q))) return 0;
    if (keys.any((k) => k.contains(q))) return 1;
    return 2;
  }

  return (names.where((n) => score(n) < 2).toList()..sort((a, b) => score(a).compareTo(score(b)))).toList();
}

/// Planned sets and reps: "3×5", "3×5–8", "10/8/6"; with [seconds] "3×30 s".
/// The answer to "Wie viele gingen noch?": "am Limit", "noch 2 übrig", "noch 4+ übrig".
String rirLabel(int rir) => rir == 0 ? tr.rirLimit : tr.rirLeft(rir >= 4 ? '4+' : '$rir');

String setsLabel(List<int> reps, int? maxReps, {bool seconds = false}) {
  final range = maxReps == null ? '' : '–$maxReps';
  final unit = seconds ? ' s' : '';
  return reps.toSet().length == 1 ? '${reps.length}×${reps.first}$range$unit' : '${reps.join('/')}$range$unit';
}

/// Key figures for the trainings of the last [days] days (null = all): trainings, trainings per week,
/// weeks covered, total volume and that of the period before (null for all, or nothing then), average
/// duration and records: of the [lifts] trained with weight in the period, how many got heavier than
/// ever before ([recordLifts], not counting their first training), and the latest such record. Weeks count
/// from the first training if that's later, so a new user isn't averaged down.
PeriodStats periodStats(List<Session> sessions, DateTime now, {int? days}) {
  final from = days == null ? null : now.subtract(Duration(days: days));
  final inPeriod = [for (final s in sessions) if (from == null || s.date.isAfter(from)) s];
  final first = inPeriod.map((s) => s.date).fold<DateTime?>(null, (a, d) => a == null || d.isBefore(a) ? d : a);
  final weeks = first == null ? 1.0 : max(1.0, now.difference(first).inHours / (24 * 7));
  final durations = inPeriod.map((s) => s.duration).nonNulls.where((d) => d > Duration.zero).toList();
  double volumeOf(Iterable<Session> ss) => ss.fold(0.0, (v, s) => v + s.exercises.fold(0.0, (v, e) => v + e.volume));
  final before = from == null
      ? const <Session>[]
      : [for (final s in sessions) if (!s.date.isAfter(from) && s.date.isAfter(from.subtract(Duration(days: days!)))) s];
  final best = <String, double>{};
  final lifts = <String>{}, recordLifts = <String>{};
  (String, double, DateTime)? lastRecord;
  for (final s in sessions.reversed) {
    final inside = from == null || s.date.isAfter(from);
    for (final e in s.exercises) {
      if (e.cardio || e.weight <= 0 || e.setsDone == 0) continue;
      if (inside) lifts.add(e.name);
      final b = best[e.name];
      if (b != null && e.weight > b && inside) {
        recordLifts.add(e.name);
        lastRecord = (e.name, e.weight, s.date);
      }
      if (b == null || e.weight > b) best[e.name] = e.weight;
    }
  }
  return (
    trainings: inPeriod.length,
    perWeek: inPeriod.length / weeks,
    weeks: weeks,
    volume: volumeOf(inPeriod),
    volumeBefore: before.isEmpty ? null : volumeOf(before),
    avgDuration: durations.isEmpty
        ? null
        : Duration(seconds: durations.fold(0, (n, d) => n + d.inSeconds) ~/ durations.length),
    lifts: lifts.length,
    recordLifts: recordLifts.length,
    lastRecord: lastRecord,
  );
}

typedef PeriodStats = ({
  int trainings,
  double perWeek,
  double weeks,
  double volume,
  double? volumeBefore,
  Duration? avgDuration,
  int lifts,
  int recordLifts,
  (String, double, DateTime)? lastRecord,
});

/// Numbers for the recap after a training. [sessions] newest first, may contain [s]; only those
/// before it count as history.
/// - [volumeBefore]: volume of the previous training of the same workout,
/// - [succeeded]: exercises where every set hit its target,
/// - [records]: exercises lifted heavier than ever before (not on their first training).
({int setsDone, int sets, double volume, double? volumeBefore, int succeeded, List<(String, double)> records}) sessionRecap(
    Session s, List<Session> sessions) {
  final before = sessions.where((x) => x.date.isBefore(s.date)).toList();
  double volumeOf(Session x) => x.exercises.fold(0.0, (v, e) => v + e.volume);
  final previous = before.where((x) => x.workoutId == s.workoutId).firstOrNull;
  return (
    setsDone: s.setsDone,
    sets: s.exercises.fold(0, (n, e) => n + e.reps.length),
    volume: volumeOf(s),
    volumeBefore: previous == null ? null : volumeOf(previous),
    succeeded: s.exercises.where((e) => e.succeeded).length,
    records: [
      for (final l in s.exercises)
        if (!l.cardio && l.setsDone > 0 && l.weight > 0)
          if ([for (final x in before) for (final e in x.exercises) if (e.name == l.name && e.setsDone > 0) e.weight]
              case final w when w.isNotEmpty && l.weight > w.reduce(max))
            (l.name, l.weight),
    ],
  );
}
