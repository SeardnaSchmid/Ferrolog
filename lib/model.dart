import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  if (log.cardio || log.weight == 0 || log.reps.isEmpty) return 0;
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

/// How an exercise is going, with the 1RM change in percent over the last [days]: up when the 1RM rose
/// by more than 2 % (catching up after a deload counts, misses or not), else stuck when at least two of
/// the last three trainings missed reps, else flat.
/// Null with fewer than two trainings.
(Trend, double)? trendOf(List<(DateTime, ExerciseLog)> history, DateTime now, {int days = 28}) {
  if (history.length < 2) return null;
  final cutoff = now.subtract(Duration(days: days));
  final before = estimated1rm(history.lastWhere((h) => !h.$1.isAfter(cutoff), orElse: () => history.first).$2);
  final change = before == 0 ? 0.0 : (estimated1rm(history.last.$2) / before - 1) * 100;
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
        cardio = true;

  /// Next session's weights from what was lifted: up on success, down after enough misses in a row.
  void applyResult(ExerciseLog log) {
    if (cardio) return; // cardio stays as planned
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
      setWeights = [for (final w in base) max(0.0, w + delta)];
      weight = setWeights!.reduce(max);
    } else {
      weight = max(0.0, log.weight + delta);
    }
  }

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

  /// Cardio stopwatch: when it was started, while it runs.
  DateTime? startedAt;

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
    this.startedAt,
  })  : weights = weights ?? List.filled(reps.length, weight),
        targets = targets ?? List.filled(reps.length, targetReps);

  /// Target reps of the first set; for cardio the planned minutes.
  int get targetReps => targets.first;

  /// Working weight: the heaviest set. Progression and stats build on it.
  double get weight => weights.fold(0, max);

  bool get succeeded => cardio && targetKm != null
      ? reps.first != null && (km ?? 0) >= targetKm!
      : [for (final (i, r) in reps.indexed) r != null && r >= targets[i]].every((ok) => ok);
  int get setsDone => reps.where((r) => r != null).length;
  double get volume => [for (final (i, r) in reps.indexed) (r ?? 0) * weights[i]].fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'weights': weights,
        'targetReps': targetReps,
        if (targets.any((t) => t != targetReps)) 'targets': targets,
        if (maxReps != null) 'maxReps': maxReps,
        'reps': reps,
        if (cardio) 'type': 'cardio',
        if (km != null) 'km': km,
        if (targetKm != null) 'targetKm': targetKm,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
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
        startedAt: j['startedAt'] == null ? null : DateTime.parse(j['startedAt']),
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
  })  : id = id ?? newId(),
        tags = tags ?? [],
        date = date ?? DateTime.now();

  int get setsDone => exercises.fold(0, (n, e) => n + e.setsDone);

  Duration? get duration => finishedAt?.difference(date);

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
            'after "failsToDeload" missed sessions in a row it drops by "decrement" if "down" is true. sessions = completed trainings, '
            'newest first; exercises[].reps holds reps done per set, null = set skipped (targets = target per set when '
            'they differ); "failRestSeconds" = rest after a missed set; finishedAt = end of the training; bodyWeight (kg), note, mood (1 bad, 2 okay, 3 good) and tags (circumstances like "Schlecht geschlafen", "Alkohol") as entered after it; exercises[].weights '
            'the weight per set, exercises[].weight the heaviest of them. type "cardio": one set whose reps are '
            'minutes (targetReps = planned minutes, 0 when the goal is targetKm), km/targetKm = distance in km, no weight. '
            'muscles = muscle groups the user set for an exercise (primary; secondary count half); other exercises '
            'use a built-in list.',
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        if (muscles.isNotEmpty) 'muscles': muscles,
      };

  /// Added to the export only (not to what's stored): statistics and the like, computed fresh each time.
  /// A failure there must not stop the export or sync of the data itself.
  Map<String, dynamic> Function()? exportExtras;

  String exportJson() {
    final j = toJson();
    if (exportExtras case final extras?) {
      try {
        j.addAll(extras());
      } catch (e) {
        j['derivedError'] = '$e';
      }
    }
    return const JsonEncoder.withIndent('  ').convert(j);
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

  Future<void> deleteWorkout(Workout w) {
    workouts.removeWhere((x) => x.id == w.id);
    return _save();
  }

  /// Stores the session and adjusts next time's weights: every exercise where all sets hit the
  /// target gets `increment` added; after `failsToDeload` misses in a row it drops by `decrement`.
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
    active = null;
    _prefs.remove('$_key.active');
    sessions.insert(0, s);
    final w = workouts.where((x) => x.id == s.workoutId).firstOrNull;
    if (w != null) {
      for (final log in s.exercises) {
        final e = w.exercises.where((x) => x.name == log.name).firstOrNull;
        if (e == null) continue;
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
/// Bodyweight exercises start at 0 kg extra.
const exerciseCatalogue = <String, (int, int, double, double, int)>{
  'Kniebeuge': (3, 5, 60.0, 2.5, 180),
  'Kreuzheben': (1, 5, 80.0, 5.0, 240),
  'Rumänisches Kreuzheben': (3, 8, 50.0, 2.5, 120),
  'Bankdrücken': (3, 5, 50.0, 2.5, 180),
  'Schrägbankdrücken': (3, 8, 40.0, 2.5, 120),
  'Kurzhantel-Bankdrücken': (3, 10, 20.0, 2.0, 90),
  'Schulterdrücken': (3, 5, 30.0, 1.25, 180),
  'Kurzhantel-Schulterdrücken': (3, 10, 14.0, 2.0, 90),
  'Langhantelrudern': (3, 8, 40.0, 2.5, 150),
  'Kurzhantelrudern': (3, 10, 20.0, 2.0, 90),
  'Kabelrudern': (3, 10, 40.0, 5.0, 90),
  'Klimmzüge': (3, 8, 0.0, 1.25, 150),
  'Latzug': (3, 10, 40.0, 5.0, 90),
  'Dips': (3, 10, 0.0, 1.25, 120),
  'Beinpresse': (3, 10, 100.0, 10.0, 120),
  'Ausfallschritte': (3, 10, 20.0, 2.0, 90),
  'Bulgarian Split Squat': (3, 10, 16.0, 2.0, 90),
  'Beinstrecker': (3, 12, 30.0, 5.0, 60),
  'Beinbeuger': (3, 12, 30.0, 5.0, 60),
  'Nordic Curls': (3, 5, 0.0, 1.25, 120),
  'Hip Thrust': (3, 10, 60.0, 5.0, 120),
  'Wadenheben': (3, 15, 40.0, 5.0, 60),
  'Bizepscurls': (3, 10, 20.0, 1.0, 60),
  'Hammercurls': (3, 10, 12.0, 1.0, 60),
  'Trizepsdrücken am Kabel': (3, 12, 20.0, 2.5, 60),
  'French Press': (3, 10, 20.0, 1.25, 60),
  'Seitheben': (3, 15, 8.0, 1.0, 60),
  'Face Pulls': (3, 15, 15.0, 2.5, 60),
  'Butterfly': (3, 12, 30.0, 5.0, 60),
  'Crunches': (3, 15, 0.0, 1.25, 60),
};

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
  'Klimmzüge': ['Pull-ups', 'Chin-ups', 'Pullups'],
  'Latzug': ['Lat Pulldown', 'Pulldown'],
  'Dips': ['Dips'],
  'Beinpresse': ['Leg Press'],
  'Ausfallschritte': ['Lunges'],
  'Bulgarian Split Squat': ['Bulgarische Kniebeuge', 'Split Squat'],
  'Beinstrecker': ['Leg Extension'],
  'Beinbeuger': ['Leg Curl'],
  'Nordic Curls': ['Nordic Hamstring Curl', 'Nordics'],
  'Crunches': ['Crunch'],
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

/// Planned sets and reps: "3×5", "3×5–8", "10/8/6".
String setsLabel(List<int> reps, int? maxReps) {
  final range = maxReps == null ? '' : '–$maxReps';
  return reps.toSet().length == 1 ? '${reps.length}×${reps.first}$range' : '${reps.join('/')}$range';
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
      if (e.cardio || e.weight == 0 || e.setsDone == 0) continue;
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

/// Kinds of facts on the home card; the UI picks an icon per kind.
enum Fact { record, today, next, fresh, streak, gain, journey, bodyWeight, close, milestone, month, week, stall, pause, tonnage }

/// Little motivating facts for the home card, freshest first (sessions newest first). Only what's
/// true right now, worded positively; no "do this" prompts.
List<(Fact, String)> homeFacts(List<Session> sessions, List<Workout> workouts, DateTime now, {int perWeek = 1}) {
  final facts = <(Fact, String)>[];
  final last = sessions.firstOrNull;
  if (last == null) return facts;
  List<ExerciseLog> logsOf(String name, Iterable<Session> from) => [
        for (final s in from)
          for (final e in s.exercises)
            if (e.name == name && e.setsDone > 0) e,
      ];

  // Last training: a record, else the longest run of trainings with every set hit.
  (String, double)? record;
  (String, int)? streak;
  for (final l in last.exercises) {
    if (l.cardio || l.setsDone == 0 || l.weight == 0) continue;
    final before = logsOf(l.name, sessions.skip(1));
    if (before.isNotEmpty && l.weight > before.map((e) => e.weight).reduce(max) && l.weight > (record?.$2 ?? 0)) {
      record = (l.name, l.weight);
    }
    final run = l.succeeded ? 1 + before.takeWhile((e) => e.succeeded).length : 0;
    if (run >= 3 && run > (streak?.$2 ?? 0)) streak = (l.name, run);
  }
  if (record case (final name, final kg)?) facts.add((Fact.record, '$name: neues Höchstgewicht, ${weightLabel(kg)}'));

  // Right after a training (same day): how it went, against the last time of the same workout.
  if (last.date.year == now.year && last.date.month == now.month && last.date.day == now.day) {
    final r = sessionRecap(last, sessions);
    final delta = switch (r.volumeBefore) {
      final b? when b > 0 && r.volume > 0 => ((r.volume / b - 1) * 100).round(),
      _ => null,
    };
    final moved = r.volume > 0
        ? '${volumeLabel(r.volume)} bewegt${delta == null ? '' : ' (${delta >= 0 ? '+' : ''}$delta % zum letzten Mal)'}'
        : null;
    final all = r.succeeded == last.exercises.length;
    facts.add((
      Fact.today,
      all ? 'Heute alles geschafft${moved == null ? '' : ', $moved'}' : 'Heute ${moved ?? 'trainiert'}',
    ));
  }

  // What the last training earned: heavier weights next time.
  if (workouts.where((w) => w.id == last.workoutId).firstOrNull case final plan?) {
    final up = [
      for (final l in last.exercises)
        if (plan.exercises.where((e) => e.name == l.name && !e.cardio && !e.noWeight).firstOrNull case final e?
            when l.setsDone > 0 && e.weight > l.weight)
          '${e.name} ${weightLabel(e.weight)}',
    ];
    if (up.isNotEmpty) facts.add((Fact.next, 'Nächstes Mal schwerer: ${up.join(', ')}'));
  }

  // Recently added exercises and how they're coming along.
  for (final name in {for (final s in sessions) for (final e in s.exercises) if (!e.cardio && e.setsDone > 0) e.name}) {
    final logs = logsOf(name, sessions); // newest first
    final firstDay = sessions.lastWhere((s) => logsOf(name, [s]).isNotEmpty).date;
    if (now.difference(firstDay).inDays > 42 || logs.length < 2 || sessions.last.date == firstDay) continue;
    final up = logs.first.weight - logs.last.weight;
    facts.add((
      Fact.fresh,
      'Neu dabei seit ${firstDay.day}.${firstDay.month}.: $name, '
          '${up > 0 ? 'schon +${weightLabel(up)}' : '${logs.length} Trainings bisher'}',
    ));
  }
  if (streak case (final name, final n)?) facts.add((Fact.streak, '$name: $n× in Folge alle Sätze geschafft'));

  // Before and after: the biggest relative gain within 90 days, only if there is one.
  final window = [for (final s in sessions) if (now.difference(s.date).inDays <= 90) s];
  (String, double, double, DateTime)? gain;
  for (final name in {for (final s in window) for (final e in s.exercises) if (!e.cardio && e.weight > 0 && e.setsDone > 0) e.name}) {
    final firstSession = window.lastWhere((s) => logsOf(name, [s]).isNotEmpty);
    final from = logsOf(name, [firstSession]).first.weight, to = logsOf(name, window).first.weight;
    if (to > from && (gain == null || to / from > gain.$3 / gain.$2)) gain = (name, from, to, firstSession.date);
  }
  // A new exercise's gain is already told above.
  if (gain case (final name, final from, final to, final since)? when !facts.any((f) => f.$1 == Fact.fresh && f.$2.contains(': $name,'))) {
    facts.add((Fact.gain, '$name: ${weightNum(from)} → ${weightLabel(to)} seit ${since.day}.${since.month}.'));
  }

  // The whole way so far, once it's longer than the 90 days above: the lift that grew most.
  final start = sessions.last.date;
  if (now.difference(start).inDays > 120) {
    (String, double, double)? best;
    for (final name in {for (final e in last.exercises) if (!e.cardio && e.weight > 0) e.name}) {
      final logs = logsOf(name, sessions);
      if (logs.length < 2) continue;
      final (from, to) = (logs.last.weight, logs.first.weight);
      if (from > 0 && to > from && (best == null || to - from > best.$3 - best.$2)) best = (name, from, to);
    }
    if (best case (final name, final from, final to)?) {
      facts.add((
        Fact.journey,
        'Seit dem Start am ${start.day}.${start.month}.${start.year}: $name ${weightNum(from)} → ${weightLabel(to)} '
            '(+${((to / from - 1) * 100).round()} %)',
      ));
    }
  }

  // Strength against body weight: the big lifts at their heaviest, the best multiple.
  if (sessions.map((s) => s.bodyWeight).nonNulls.firstOrNull case final bw? when bw > 0) {
    (String, double)? top;
    for (final name in {for (final s in sessions) for (final e in s.exercises) if (e.weight > 0) e.name}) {
      final k = searchKey(name);
      if (!const ['kniebeuge', 'squat', 'bankdrueck', 'benchpress', 'kreuzheb', 'deadlift'].any(k.contains) ||
          const ['kurzhantel', 'dumbbell'].any(k.contains)) {
        continue;
      }
      final heaviest = logsOf(name, sessions).map((e) => e.weight).fold(0.0, max);
      if (heaviest / bw > (top?.$2 ?? 0)) top = (name, heaviest / bw);
    }
    if (top case (final name, final x)? when x >= .5) {
      facts.add((Fact.bodyWeight, '$name: ${x.toStringAsFixed(2).replaceAll('.', ',')}× dein Körpergewicht'));
    }
  }

  // Planned exercises that missed last time: 1–2 reps short, or stuck for a while.
  for (final w in workouts) {
    for (final e in w.exercises) {
      if (e.cardio || e.fails == 0) continue;
      final log = logsOf(e.name, sessions).firstOrNull;
      if (log == null) continue;
      final missing = [for (final (i, r) in log.reps.indexed) max(0, (log.maxReps ?? log.targets[i]) - (r ?? 0))]
          .fold(0, (a, b) => a + b);
      if (missing case 1 || 2) {
        facts.add((Fact.close, '${e.name}: nur $missing ${missing == 1 ? 'Wiederholung' : 'Wiederholungen'} bis zur Steigerung'));
      } else if (e.fails >= 3) {
        facts.add((Fact.stall, '${e.name}: seit ${e.fails} Trainings bei ${weightLabel(e.weight)}, das Plateau wackelt'));
      }
    }
  }

  const marks = [10, 25, 50, 75, 100, 150, 200, 250, 300, 400, 500];
  if (marks.contains(sessions.length)) facts.add((Fact.milestone, '${sessions.length}. Training geschafft 🎉'));

  // A month with more trainings than any before (once there is a month to compare with).
  final perMonth = <int, int>{};
  for (final s in sessions) {
    perMonth.update(s.date.year * 12 + s.date.month, (n) => n + 1, ifAbsent: () => 1);
  }
  final thisMonth = perMonth.remove(now.year * 12 + now.month) ?? 0;
  if (perMonth.isNotEmpty && thisMonth > perMonth.values.reduce(max)) {
    facts.add((Fact.month, 'Rekordmonat: schon $thisMonth Trainings, so viele wie noch nie'));
  }

  final thisWeek = sessions.where((s) => !s.date.isBefore(mondayOf(now))).length;
  final weeks = weekStreak(sessions.map((s) => s.date), now, perWeek: perWeek);
  final series = weeks > 1 ? ' · $weeks Wochen in Folge' : '';
  facts.add((
    Fact.week,
    thisWeek >= perWeek ? 'Woche geschafft ✓$series' : '$thisWeek von $perWeek Trainings diese Woche$series',
  ));

  final rest = now.difference(last.date).inDays;
  if (rest >= 5) facts.add((Fact.pause, '$rest Tage Pause, Erholung zählt auch'));

  // Tonnage: the next round mark, in tonnes lifted overall.
  final total = sessions.fold(0.0, (v, s) => v + s.exercises.fold(0.0, (v, e) => v + e.volume));
  final next = [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000].map((t) => t * 1000.0).where((t) => t > total).firstOrNull;
  if (total > 0) {
    facts.add((
      Fact.tonnage,
      'Insgesamt ${volumeLabel(total)} bewegt${next == null ? '' : ', noch ${volumeLabel(next - total)} bis ${volumeLabel(next)}'}',
    ));
  }
  return facts;
}

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
