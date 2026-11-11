import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
        timed = false;

  /// Next session's weights from what was lifted: up on success, down after enough misses in a row.
  /// A set done lighter than planned holds the plan: the new weight was trained, just not every set
  /// (e.g. the last set dropped back), so neither an increase nor a miss towards a deload.
  void applyResult(ExerciseLog log) {
    if (cardio) return; // cardio stays as planned
    final planned = weights;
    final lighter = [
      for (final (i, r) in log.reps.indexed)
        if (r != null && i < planned.length && log.weights[i] < planned[i]) i,
    ].isNotEmpty;
    if (lighter) return;
    var delta = 0.0;
    final top = maxReps;
    if (top == null ? log.succeeded : log.reps.every((r) => r != null && r >= top)) {
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
      );
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
  })  : weights = weights ?? List.filled(reps.length, weight),
        doneAt = doneAt ?? List.filled(reps.length, null),
        targets = targets ?? List.filled(reps.length, targetReps);

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

class Session {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime date;
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
  })  : id = id ?? newId(),
        tags = tags ?? [],
        date = date ?? DateTime.now();

  int get setsDone => exercises.fold(0, (n, e) => n + e.setsDone);

  Duration? get duration => finishedAt?.difference(date);

  /// Seconds of rest left at [now]; negative once it's over, null without a rest.
  int? restLeft(DateTime now) => restStartedAt == null
      ? null
      : (restSeconds ?? 0) - (restPausedAt ?? now).difference(restStartedAt!).inSeconds;

  factory Session.start(Workout w) => Session(
        workoutId: w.id,
        workoutName: w.name,
        exercises: [
          for (final e in w.exercises)
            ExerciseLog(
              name: e.name,
              weight: e.weight,
              weights: List.of(e.weights),
              targetReps: e.reps,
              targets: e.repsPerSet,
              maxReps: e.maxReps,
              reps: List.filled(e.sets, null),
              cardio: e.cardio,
              targetKm: e.km,
              timed: e.timed,
            ),
        ],
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
        exercises: [for (final e in j['exercises']) ExerciseLog.fromJson(e)],
      );
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

  Store(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) _load(jsonDecode(raw));
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

  /// Saves [muscles] after a change.
  Future<void> saveMuscles() => _save();

  Map<String, dynamic> toJson() => {
        'app': 'ferrolog',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'units': 'kg',
        'format': 'workouts = plans; exercise.weight is the weight for the NEXT session (setWeights, if '
            'present, per set; all 0 = no weight) and rises by "increment" when all sets hit "reps" (setReps, if present, '
            'per set; with "maxReps" a rep range whose top every set must reach) and "up" is true (progressive overload); '
            'after "failsToDeload" missed sessions in a row it drops by "decrement" if "down" is true; a set done lighter than '
            'planned holds the weight (no increase, no miss), an exercise skipped entirely changes nothing. sessions = completed trainings, '
            'newest first; exercises[].reps holds reps done per set, null = set skipped (targets = target per set when '
            'they differ); "failRestSeconds" = rest after a missed set; finishedAt = end of the training; bodyWeight (kg), note, mood (1 bad, 2 okay, 3 good) and tags (circumstances like "Schlecht geschlafen", "Alkohol") as entered after it; exercises[].weights '
            'the weight per set, exercises[].weight the heaviest of them. type "cardio": one set whose reps are '
            'minutes (targetReps = planned minutes, 0 when the goal is targetKm), km/targetKm = distance in km, no weight. '
            'type "timed" (held or carried, e.g. plank, farmer\'s walk): reps and targets are seconds, weight optional. '
            'exercises[].doneAt = when each set was logged (null = not done or not recorded); date = start of the training. '
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

  /// Stores the session and adjusts next time's weights: every exercise where all sets hit the
  /// target gets `increment` added; after `failsToDeload` misses in a row it drops by `decrement`.
  /// Exercises skipped entirely stay as they are.
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

  Future<void> finishSession(Session s, {DateTime? at}) {
    s.finishedAt = at ?? DateTime.now();
    s.restStartedAt = s.restPausedAt = s.restSeconds = null; // only for the running training
    active = null;
    _prefs.remove('$_key.active');
    sessions.insert(0, s);
    final w = workouts.where((x) => x.id == s.workoutId).firstOrNull;
    if (w != null) {
      for (final log in s.exercises) {
        final e = w.exercises.where((x) => x.name == log.name).firstOrNull;
        // Skipped entirely (no time, no bar): not a miss, the plan stays.
        if (e == null || log.setsDone == 0) continue;
        e.applyResult(log);
      }
    }
    return _save();
  }

  /// Saves changes made in place to a stored session (body weight, note).
  Future<void> updateSession(Session s) => _save();

  Future<void> deleteSession(Session s) {
    sessions.removeWhere((x) => x.id == s.id);
    return _save();
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

/// Lower case, umlauts spelled out, only letters and digits: "Bench-Press" and "bench press"
/// both become "benchpress", "Bankdrücken" and "bankdruecken" both "bankdruecken".
String searchKey(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp('[^a-z0-9]'), '');

/// Known names (German) matching [query] in German or English, best matches first.
List<String> searchExercises(String query, Iterable<String> names) {
  final q = searchKey(query);
  if (q.isEmpty) return [];
  int score(String name) {
    final keys = [name, ...?exerciseAliases[name]].map(searchKey);
    if (keys.any((k) => k.startsWith(q))) return 0;
    if (keys.any((k) => k.contains(q))) return 1;
    return 2;
  }

  return (names.where((n) => score(n) < 2).toList()..sort((a, b) => score(a).compareTo(score(b)))).toList();
}

/// Planned sets and reps: "3×5", "3×5–8", "10/8/6"; with [seconds] "3×30 s".
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
