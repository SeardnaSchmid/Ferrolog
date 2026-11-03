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

/// Change of the working weight over the last [days]: from the last session before that window
/// (or the first one in it) to the latest. Null with fewer than two sessions.
(double, DateTime)? weightChange(List<(DateTime, ExerciseLog)> history, DateTime now, {int days = 30}) {
  if (history.length < 2) return null;
  final cutoff = now.subtract(Duration(days: days));
  final before = history.lastWhere((h) => !h.$1.isAfter(cutoff), orElse: () => history.first);
  if (identical(before, history.last)) return null;
  return (history.last.$2.weight - before.$2.weight, before.$1);
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

  /// Added to the weight when every set hit [reps]; 0 = off.
  double increment;

  /// Taken off after [failsToDeload] missed sessions in a row; 0 = off.
  double decrement;
  int failsToDeload;

  /// Missed sessions in a row so far; reset on success or deload.
  int fails;
  int restSeconds;

  /// Weight per set when the sets differ (e.g. back-off sets); null = [weight] for all sets.
  List<double>? setWeights;

  /// Cardio instead of strength: one "set" whose [reps] are the target minutes, no weight,
  /// optionally a target distance.
  bool cardio;
  double? km;

  Exercise({
    required this.name,
    this.weight = 20,
    this.sets = 3,
    this.reps = 8,
    this.increment = 2.5,
    this.decrement = 0,
    this.failsToDeload = 3,
    this.fails = 0,
    this.restSeconds = 120,
    this.setWeights,
    this.cardio = false,
    this.km,
  });

  /// A cardio exercise: [minutes] long, optionally [km] far.
  Exercise.cardio({required this.name, required int minutes, this.km})
      : weight = 0,
        sets = 1,
        reps = minutes,
        increment = 0,
        decrement = 0,
        failsToDeload = 3,
        fails = 0,
        restSeconds = 0,
        cardio = true;

  /// Next session's weights from what was lifted: up on success, down after enough misses in a row.
  void applyResult(ExerciseLog log) {
    if (cardio) return; // cardio stays as planned
    var delta = 0.0;
    if (log.succeeded) {
      delta = increment;
      fails = 0;
    } else if (++fails >= failsToDeload && decrement > 0) {
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

  Exercise copy() => Exercise.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'sets': sets,
        'reps': reps,
        'increment': increment,
        'decrement': decrement,
        'failsToDeload': failsToDeload,
        'fails': fails,
        'restSeconds': restSeconds,
        if (setWeights != null) 'setWeights': setWeights,
        if (cardio) 'type': 'cardio',
        if (km != null) 'km': km,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        name: j['name'],
        weight: (j['weight'] as num).toDouble(),
        sets: j['sets'],
        reps: j['reps'],
        increment: (j['increment'] as num).toDouble(),
        decrement: (j['decrement'] as num?)?.toDouble() ?? 0,
        failsToDeload: j['failsToDeload'] ?? 3,
        fails: j['fails'] ?? 0,
        restSeconds: j['restSeconds'] ?? 120,
        setWeights: j['setWeights'] == null ? null : [for (final w in j['setWeights']) (w as num).toDouble()],
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
  final int targetReps;
  final List<int?> reps;

  /// Weight per set, same length as [reps].
  final List<double> weights;

  /// Cardio: one "set", [reps] holds the minutes done and [targetReps] the planned minutes.
  final bool cardio;
  double? km;
  final double? targetKm;

  ExerciseLog({
    required this.name,
    required double weight,
    required this.targetReps,
    required this.reps,
    List<double>? weights,
    this.cardio = false,
    this.km,
    this.targetKm,
  }) : weights = weights ?? List.filled(reps.length, weight);

  /// Working weight: the heaviest set. Progression and stats build on it.
  double get weight => weights.fold(0, max);

  bool get succeeded => reps.every((r) => r != null && r >= targetReps);
  int get setsDone => reps.where((r) => r != null).length;
  double get volume => [for (final (i, r) in reps.indexed) (r ?? 0) * weights[i]].fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'weights': weights,
        'targetReps': targetReps,
        'reps': reps,
        if (cardio) 'type': 'cardio',
        if (km != null) 'km': km,
        if (targetKm != null) 'targetKm': targetKm,
      };

  // Older data has only "weight"; it then applies to every set.
  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        name: j['name'],
        weight: (j['weight'] as num).toDouble(),
        weights: j['weights'] == null ? null : [for (final w in j['weights']) (w as num).toDouble()],
        targetReps: j['targetReps'],
        reps: List<int?>.from(j['reps']),
        cardio: j['type'] == 'cardio',
        km: (j['km'] as num?)?.toDouble(),
        targetKm: (j['targetKm'] as num?)?.toDouble(),
      );
}

class Session {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime date;
  final List<ExerciseLog> exercises;

  Session({String? id, required this.workoutId, required this.workoutName, DateTime? date, required this.exercises})
      : id = id ?? newId(),
        date = date ?? DateTime.now();

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
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'],
        workoutId: j['workoutId'],
        workoutName: j['workoutName'],
        date: DateTime.parse(j['date']),
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

  /// The session currently being trained, persisted so it survives the app being killed.
  Session? active;

  Store(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) _load(jsonDecode(raw));
    final a = _prefs.getString('$_key.active');
    if (a != null) active = Session.fromJson(jsonDecode(a));
  }

  Future<void> saveActive(Session? s) async {
    active = s;
    notifyListeners();
    s == null ? await _prefs.remove('$_key.active') : await _prefs.setString('$_key.active', jsonEncode(s.toJson()));
  }

  static Future<Store> open() async => Store(await SharedPreferences.getInstance());

  void _load(Map<String, dynamic> j) {
    workouts = [for (final w in j['workouts']) Workout.fromJson(w)];
    sessions = [for (final s in j['sessions']) Session.fromJson(s)];
  }

  Map<String, dynamic> toJson() => {
        'app': 'ferrolog',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'units': 'kg',
        'format': 'workouts = plans; exercise.weight is the weight for the NEXT session (setWeights, if '
            'present, per set) and rises by "increment" when all sets hit "reps" (progressive overload); '
            'after "failsToDeload" missed sessions in a row it drops by "decrement" (0 = off). sessions = completed trainings, '
            'newest first; exercises[].reps holds reps done per set, null = set skipped; exercises[].weights '
            'the weight per set, exercises[].weight the heaviest of them. type "cardio": one set whose reps are '
            'minutes (targetReps = planned minutes), km/targetKm = distance in km, no weight.',
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Called with the export JSON after every saved change (used for GitHub sync).
  void Function(String json)? onSaved;

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(toJson()));
    onSaved?.call(exportJson());
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
  Future<void> finishSession(Session s) {
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
  'Hip Thrust': (3, 10, 60.0, 5.0, 120),
  'Wadenheben': (3, 15, 40.0, 5.0, 60),
  'Bizepscurls': (3, 10, 20.0, 1.0, 60),
  'Hammercurls': (3, 10, 12.0, 1.0, 60),
  'Trizepsdrücken am Kabel': (3, 12, 20.0, 2.5, 60),
  'French Press': (3, 10, 20.0, 1.25, 60),
  'Seitheben': (3, 15, 8.0, 1.0, 60),
  'Face Pulls': (3, 15, 15.0, 2.5, 60),
  'Butterfly': (3, 12, 30.0, 5.0, 60),
};

/// Cardio catalogue: name -> default minutes and distance in km (null = no distance).
const cardioCatalogue = <String, (int, double?)>{
  'Laufen': (30, 5.0),
  'Laufband': (20, 3.0),
  'Radfahren': (45, 15.0),
  'Ergometer-Rudern': (15, 3.0),
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
