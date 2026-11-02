import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// One exercise inside a workout plan, e.g. "Squat 3x5 @ 100 kg, +2.5 kg on success".
class Exercise {
  String name;
  double weight;
  int sets;
  int reps;
  double increment;
  int restSeconds;

  Exercise({
    required this.name,
    this.weight = 20,
    this.sets = 3,
    this.reps = 8,
    this.increment = 2.5,
    this.restSeconds = 120,
  });

  Exercise copy() => Exercise.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'name': name,
        'weight': weight,
        'sets': sets,
        'reps': reps,
        'increment': increment,
        'restSeconds': restSeconds,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        name: j['name'],
        weight: (j['weight'] as num).toDouble(),
        sets: j['sets'],
        reps: j['reps'],
        increment: (j['increment'] as num).toDouble(),
        restSeconds: j['restSeconds'] ?? 120,
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
  double weight;
  final int targetReps;
  final List<int?> reps;

  ExerciseLog({required this.name, required this.weight, required this.targetReps, required this.reps});

  bool get succeeded => reps.every((r) => r != null && r >= targetReps);
  int get setsDone => reps.where((r) => r != null).length;
  double get volume => reps.fold(0, (v, r) => v + (r ?? 0) * weight);

  Map<String, dynamic> toJson() => {'name': name, 'weight': weight, 'targetReps': targetReps, 'reps': reps};

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        name: j['name'],
        weight: (j['weight'] as num).toDouble(),
        targetReps: j['targetReps'],
        reps: List<int?>.from(j['reps']),
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
            ExerciseLog(name: e.name, weight: e.weight, targetReps: e.reps, reps: List.filled(e.sets, null)),
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
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(toJson()));
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

  /// Stores the session and applies progressive overload:
  /// every exercise where all sets hit the target gets `increment` added for next time.
  Future<void> finishSession(Session s) {
    active = null;
    _prefs.remove('$_key.active');
    sessions.insert(0, s);
    final w = workouts.where((x) => x.id == s.workoutId).firstOrNull;
    if (w != null) {
      for (final log in s.exercises) {
        final e = w.exercises.where((x) => x.name == log.name).firstOrNull;
        if (e == null) continue;
        e.weight = log.succeeded ? log.weight + e.increment : log.weight;
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

/// Catalogue for the "add exercise" helper: name -> sensible defaults (sets, reps, increment).
const exerciseCatalogue = <String, (int, int, double)>{
  'Kniebeuge': (3, 5, 2.5),
  'Kreuzheben': (1, 5, 5),
  'Rumänisches Kreuzheben': (3, 8, 2.5),
  'Bankdrücken': (3, 5, 2.5),
  'Schrägbankdrücken': (3, 8, 2.5),
  'Kurzhantel-Bankdrücken': (3, 10, 2),
  'Schulterdrücken': (3, 5, 1.25),
  'Kurzhantel-Schulterdrücken': (3, 10, 2),
  'Langhantelrudern': (3, 8, 2.5),
  'Kurzhantelrudern': (3, 10, 2),
  'Kabelrudern': (3, 10, 5),
  'Klimmzüge': (3, 8, 1.25),
  'Latzug': (3, 10, 5),
  'Dips': (3, 10, 1.25),
  'Beinpresse': (3, 10, 10),
  'Ausfallschritte': (3, 10, 2),
  'Bulgarian Split Squat': (3, 10, 2),
  'Beinstrecker': (3, 12, 5),
  'Beinbeuger': (3, 12, 5),
  'Hip Thrust': (3, 10, 5),
  'Wadenheben': (3, 15, 5),
  'Bizepscurls': (3, 10, 1),
  'Hammercurls': (3, 10, 1),
  'Trizepsdrücken am Kabel': (3, 12, 2.5),
  'French Press': (3, 10, 1.25),
  'Seitheben': (3, 15, 1),
  'Face Pulls': (3, 15, 2.5),
  'Butterfly': (3, 12, 5),
};
