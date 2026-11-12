import 'dart:convert';

import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'units.dart';

/// What a plan in FerroLog can and can't express, for the AI proposing changes. Exported only.
/// Keep it in step with [Exercise] and the editor: a feature here the app doesn't have makes the AI
/// suggest things that can't be entered.
final capabilities = {
  'about':
      'What a FerroLog plan can express. Only suggest changes within "can"; for anything in "cannot", '
      'say so and give the closest version that fits, or leave it out.',
  'can': [
    'Several workouts (plans), each an ordered list of exercises; the order is the order they are trained in.',
    'The user picks the workout each time; there is no schedule or rotation, only a goal of trainings per week.',
    'Strength: sets × reps at a weight (weight). Per set different weights (setWeights, e.g. back-off sets) '
        'or reps (setReps, e.g. 10/8/6).',
    'Rep range: reps up to maxReps; the weight only rises once every set reaches maxReps.',
    'No weight (bodyweight): weight 0. Assistance (machine taking weight off): negative weight, -20 = 20 kg help; '
        'increment then means less help.',
    'Held or carried for time (type "timed", e.g. plank, farmer\'s walk): reps are seconds, weight optional.',
    'Cardio (type "cardio"): one set, a duration (reps = minutes) or a distance (km, reps 0), no progression.',
    'Automatic progression per exercise: +increment kg on the weight after a training where every set hit its '
        'reps (if up), -decrement kg after failsToDeload missed trainings in a row (if down). It always moves the '
        'weight, never reps or seconds: for bodyweight and held exercises without added weight set up false, '
        'unless weight should be added.',
    'Or the auto mode per exercise (auto true, see "format"): a share of the weight that adapts itself, steered by '
        'the reps in reserve, rep bridges where a step is too small to load, bad days excused, a break of two weeks '
        'or more starts lighter. increment, up, down, decrement and failsToDeload are then ignored. loadStep (kg) = '
        'what the weight can be loaded in when the user set it (e.g. a machine taking only 5 kg plates), else '
        'learned. Leave autoState out: the app keeps it.',
    'Rest per exercise in seconds (restSeconds), optionally a different rest after a missed set (failRestSeconds).',
    'Own exercises with their muscles (muscles: primary, secondary), for names the app doesn\'t know.',
    'During a training the user can swap an exercise (machine taken), add one, add or take off sets and change '
        'the order; that changes only that training, not the plan (see replaces, added in the sessions).',
    'If the user switched it on, the app asks after an exercise\'s last set how many reps were left '
        '(sessions[].exercises[].rir, 0 = at the limit, 4 = four or more): a plateau with reps left is not the '
        'weight\'s fault, twice at the limit calls for a deload. It is recorded, not planned.',
    'Barbell lifts show the plates per side for the user\'s bar and plates, and, if the user switched it on, a '
        'warm-up before the first set (empty bar × 8, then 50/70/85 % of the first set); nothing to plan for either.',
  ],
  'cannot': [
    'Supersets, circuits or giant sets: exercises are done one after the other; the rest timer runs per exercise.',
    'Planned RPE / RIR targets, percentages of the 1RM, tempo, notes per exercise.',
    'Own warm-up sets, or warm-ups for dumbbell and machine exercises; warm-up sets are never logged.',
    'Periodisation over weeks (waves, deload weeks, blocks): only the automatic steps above; a planned change '
        'has to be made by hand when it is due.',
    'A schedule (which workout on which day) or optional exercises: an exercise in the plan is planned every time.',
    'More reps or seconds automatically, except the auto mode\'s rep bridges toward the next weight.',
    'Distance or steps for carries: only seconds.',
  ],
};

/// The format an AI answers in so its plan can be taken over (read by [parsePlanImport]). Exported only.
final planImport = {
  'about':
      'To change the plans, answer with exactly one JSON code block in this format (valid JSON, no comments, '
      'weights in kg). app "ferrolog", kind "plan", version 1; basedOn = exportedAt of the export you read; '
      'summary = one line what changes. workouts: each listed workout replaces the one with the same id as a whole '
      '(all its exercises, in the new order); without id it is a new workout; delete true (with id) removes one; '
      'workouts not listed stay as they are. Exercises use the fields of the plan format (see "format" and '
      '"capabilities"): name, weight, sets, reps, increment, up, decrement, down, failsToDeload, auto, restSeconds, and '
      'where needed failRestSeconds, setWeights, setReps, maxReps, type, km. For an exercise the app already has, '
      'progression and rest left out (increment, up, decrement, down, failsToDeload, auto, restSeconds, failRestSeconds) '
      'stay as they are; setWeights, setReps, maxReps, type and km left out are gone. Leave out fails: the app '
      'keeps the count. Keep an exercise\'s name exactly to keep its history; a new name starts '
      'a new one. muscles (optional, only for an exercise the app doesn\'t know): primary and secondary as muscle '
      'ids from ${Muscle.values.map((m) => m.name).join(', ')}. why (optional) = one sentence, shown before taking '
      'the plan over, not stored. The user sees every change and confirms it; the trainings are never touched.',
  'example': {
    'app': 'ferrolog',
    'kind': 'plan',
    'version': 1,
    'basedOn': '2026-11-11T08:12:00.000',
    'summary': 'Rudern vor die Klimmzüge, Plank neu',
    'workouts': [
      {
        'id': '1730000000000000',
        'name': 'Full Body',
        'exercises': [
          {
            'name': 'Kniebeuge',
            'weight': 122.5,
            'sets': 3,
            'reps': 5,
            'increment': 2.5,
            'up': true,
            'decrement': 12.5,
            'down': true,
            'failsToDeload': 3,
            'restSeconds': 180,
            'why': '120 kg zweimal sauber geschafft, also das geplante Gewicht.',
          },
          {
            'name': 'Plank',
            'type': 'timed',
            'weight': 0,
            'sets': 2,
            'reps': 45,
            'increment': 2.5,
            'up': false,
            'decrement': 2.5,
            'down': false,
            'failsToDeload': 3,
            'restSeconds': 60,
            'why': 'Der Bauch bekommt bisher kein direktes Training.',
          },
        ],
      },
    ],
  },
};

enum Change { added, removed, changed, same }

/// One exercise of a workout before and after the import, as the preview shows it.
class ExerciseDiff {
  final String name;
  final Change change;

  /// What changed ("Gewicht: 120 → 122,5 kg"), or for a new exercise what it is.
  final List<String> details;

  /// New place in the workout (1-based) when the order changed, else null.
  final int? movedTo;
  final String? why;
  const ExerciseDiff(this.name, this.change, this.details, {this.movedTo, this.why});
}

class WorkoutDiff {
  final String name;
  final Change change;
  final List<ExerciseDiff> exercises;
  const WorkoutDiff(this.name, this.change, this.exercises);
}

/// A checked plan from the AI: the plans as they will be after taking it over, and what changes.
class PlanImport {
  final String summary;
  final DateTime? basedOn;

  /// All plans after the import, unlisted ones as they are; copies, the store isn't touched yet.
  final List<Workout> workouts;

  /// Muscles for exercises the app doesn't know, as stored in [Store.muscles].
  final Map<String, dynamic> muscles;
  final List<WorkoutDiff> diff;
  const PlanImport(this.summary, this.basedOn, this.workouts, this.muscles, this.diff);

  /// Trained since the export the AI read: the weights it planned from may be behind.
  bool get stale => basedOn != null && store.sessions.isNotEmpty && store.sessions.first.date.isAfter(basedOn!);

  bool get empty => diff.every((w) => w.change == Change.same);
}

/// Reads the AI's answer: the JSON block, also with code fences or text around it. Checks it against
/// the current plans; a [FormatException] says in German what's wrong.
PlanImport parsePlanImport(String text) {
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start < 0 || end < start) throw const FormatException('Kein JSON gefunden. Kopier den ganzen Codeblock aus dem Chat.');
  final Object? j;
  try {
    j = jsonDecode(text.substring(start, end + 1));
  } on FormatException catch (e) {
    throw FormatException('Das JSON ist unvollständig oder fehlerhaft: ${e.message}');
  }
  if (j is Map<String, dynamic> && j['app'] == 'ferrolog' && j['kind'] == null && j.containsKey('sessions')) {
    throw const FormatException('Das ist ein Export mit allen Daten, kein Plan. Nimm den JSON-Block aus der Antwort der KI.');
  }
  if (j is! Map<String, dynamic> || j['app'] != 'ferrolog' || j['kind'] != 'plan') {
    throw const FormatException('Das ist kein FerroLog-Plan (app "ferrolog", kind "plan" fehlt).');
  }
  if (j['version'] case final v? when v != 1) throw FormatException('Version $v kennt diese App nicht.');
  final entries = j['workouts'];
  if (entries is! List || entries.isEmpty) throw const FormatException('Der Plan enthält keine Workouts.');

  final current = {for (final w in store.workouts) w.id: w};
  final replaced = <String, Workout?>{}; // by id; null = deleted
  final added = <Workout>[];
  final muscles = <String, dynamic>{};
  final diff = <WorkoutDiff>[];
  for (final (i, raw) in entries.indexed) {
    if (raw is! Map<String, dynamic>) throw FormatException('Workout ${i + 1} ist kein Objekt.');
    final id = raw['id']?.toString();
    final old = current[id];
    if (id != null && replaced.containsKey(id)) throw FormatException('Workout $id steht zweimal im Plan.');
    if (raw['delete'] == true) {
      if (old == null) throw FormatException('Das Workout zum Löschen (${raw['name'] ?? id}) gibt es nicht.');
      replaced[id!] = null;
      diff.add(WorkoutDiff(old.name, Change.removed, [
        for (final e in old.exercises) ExerciseDiff(e.name, Change.removed, const []),
      ]));
      continue;
    }
    final name = raw['name'];
    if (name is! String || name.trim().isEmpty) throw FormatException('Workout ${i + 1} hat keinen Namen.');
    final list = raw['exercises'];
    if (list is! List || list.isEmpty) throw FormatException('„$name“ hat keine Übungen.');
    final why = <String, String>{};
    final exercises = [
      for (final (k, e) in list.indexed) _exercise(e, '„$name“, Übung ${k + 1}', old, why, muscles),
    ];
    for (final (k, e) in exercises.indexed) {
      if (exercises.take(k).any((x) => searchKey(x.name) == searchKey(e.name))) {
        throw FormatException('„$name“ hat „${e.name}“ zweimal. Mehr Sätze oder setWeights statt einer zweiten Übung.');
      }
    }
    final w = Workout(id: old?.id, name: name.trim(), exercises: exercises);
    old == null ? added.add(w) : replaced[old.id] = w;
    diff.add(_diff(old, w, why));
  }
  for (final w in store.workouts) {
    if (!replaced.containsKey(w.id)) diff.add(WorkoutDiff(w.name, Change.same, const []));
  }
  return PlanImport(
    (j['summary'] as String?)?.trim() ?? '',
    DateTime.tryParse('${j['basedOn']}'),
    [
      for (final w in store.workouts)
        if (replaced.containsKey(w.id)) ?replaced[w.id] else w.copy(),
      ...added,
    ],
    muscles,
    diff,
  );
}

/// Settings an exercise keeps when the AI leaves them out.
const _kept = ['increment', 'up', 'decrement', 'down', 'failsToDeload', 'auto', 'autoState', 'loadStep', 'restSeconds', 'failRestSeconds'];

/// One exercise from the AI: what it left out from the plan's exercise of that name ([_kept]) or the app's
/// defaults, and [Exercise.fails] kept. Its why and muscles go into [why] and [muscles].
Exercise _exercise(Object? raw, String where, Workout? old, Map<String, String> why, Map<String, dynamic> muscles) {
  if (raw is! Map<String, dynamic>) throw FormatException('$where ist kein Objekt.');
  final name = raw['name'];
  if (name is! String || name.trim().isEmpty) throw FormatException('$where hat keinen Namen.');
  final label = '„${name.trim()}“';
  for (final k in const ['sets', 'reps']) {
    if (raw[k] is! int) throw FormatException('$label: "$k" fehlt oder ist keine ganze Zahl.');
  }
  if (raw['weight'] is! num && raw['type'] != 'cardio') throw FormatException('$label: "weight" fehlt.');
  if (raw['type'] case final t? when t != 'cardio' && t != 'timed') throw FormatException('$label: Art "$t" gibt es nicht.');
  final k = searchKey(name);
  final prev = [...?old?.exercises, for (final w in store.workouts) ...w.exercises].where((x) => searchKey(x.name) == k).firstOrNull;
  final Exercise e;
  try {
    e = Exercise.fromJson({
      'weight': 0,
      'increment': 2.5,
      // Left out for an exercise the app has: its progression and rest stay, the app's defaults only for new ones.
      if (prev?.toJson() case final p?) for (final f in _kept) if (p.containsKey(f)) f: p[f],
      ...raw,
      'name': name.trim(),
      'fails': prev?.fails ?? 0,
    });
  } catch (x) {
    throw FormatException('$label: $x');
  }
  if (e.sets < 1 || e.reps < 0) throw FormatException('$label: Sätze oder Wiederholungen ungültig.');
  if (e.setWeights case final w? when w.length != e.sets) throw FormatException('$label: setWeights passt nicht zu ${e.sets} Sätzen.');
  if (e.setReps case final r? when r.length != e.sets) throw FormatException('$label: setReps passt nicht zu ${e.sets} Sätzen.');
  if (e.maxReps case final m? when m <= e.reps) throw FormatException('$label: maxReps muss über reps liegen.');
  if (e.weights.any((w) => w < minWeight)) throw FormatException('$label: Gewicht unter ${minWeight.round()} kg.');

  if (raw['why'] case final String w when w.trim().isNotEmpty) why[k] = w.trim();
  if (raw['muscles'] case final Map<String, dynamic> m when musclesOf(e.name) == null) {
    List<String> ids(Object? l) => [
          for (final n in l is List ? l : const [])
            if (Muscle.values.asNameMap().containsKey(n)) n as String
            else throw FormatException('$label: Muskel "$n" gibt es nicht.'),
        ];
    muscles[e.name] = {'primary': ids(m['primary']), 'secondary': ids(m['secondary'])};
  }
  return e;
}

/// [old] against [neu], exercises matched by name.
WorkoutDiff _diff(Workout? old, Workout neu, Map<String, String> why) {
  if (old == null) {
    return WorkoutDiff(neu.name, Change.added, [
      for (final e in neu.exercises) ExerciseDiff(e.name, Change.added, [planLabel(e)], why: why[searchKey(e.name)]),
    ]);
  }
  final before = {for (final e in old.exercises) searchKey(e.name): e};
  final after = {for (final e in neu.exercises) searchKey(e.name): e};
  final oldOrder = [for (final k in before.keys) if (after.containsKey(k)) k];
  final newOrder = [for (final k in after.keys) if (before.containsKey(k)) k];
  final rows = <ExerciseDiff>[];
  for (final (i, e) in neu.exercises.indexed) {
    final k = searchKey(e.name);
    final was = before[k];
    if (was == null) {
      rows.add(ExerciseDiff(e.name, Change.added, [planLabel(e)], why: why[k]));
      continue;
    }
    final details = [
      for (final (label, f) in _aspects)
        if (f(was) != f(e)) '$label: ${_or(f(was))} → ${_or(f(e))}',
      if (was.name != e.name) 'Name: ${was.name} → ${e.name}',
    ];
    final moved = oldOrder.indexOf(k) != newOrder.indexOf(k) ? i + 1 : null;
    rows.add(ExerciseDiff(e.name, details.isEmpty && moved == null ? Change.same : Change.changed, details,
        movedTo: moved, why: why[k]));
  }
  for (final e in old.exercises) {
    if (!after.containsKey(searchKey(e.name))) rows.add(ExerciseDiff(e.name, Change.removed, const []));
  }
  final same = old.name == neu.name && rows.every((r) => r.change == Change.same);
  return WorkoutDiff(neu.name, same ? Change.same : Change.changed, rows);
}

String _or(String s) => s.isEmpty ? '–' : s;

/// "3×5 · 120 kg", what a plan exercise is in short.
String planLabel(Exercise e) => [_kind(e), _scheme(e), _load(e)].where((s) => s.isNotEmpty).join(' · ');

final List<(String, String Function(Exercise))> _aspects = [
  ('Art', _kind),
  ('Sätze', _scheme),
  ('Gewicht', _load),
  ('Steigerung', (e) => e.cardio ? '' : e.auto ? 'automatisch' : e.up ? '+${weightLabel(e.increment)}' : 'aus'),
  ('Entlastung', (e) => e.cardio || e.auto ? '' : e.down ? '−${weightLabel(e.decrement)} nach ${e.failsToDeload} Fehlversuchen' : 'aus'),
  ('Pause', (e) => [if (e.restSeconds > 0) '${e.restSeconds} s', if (e.failRestSeconds case final f?) 'nach Fehlversuch $f s'].join(', ')),
];

String _kind(Exercise e) => e.cardio ? 'Cardio' : e.timed ? 'auf Zeit' : '';

String _scheme(Exercise e) {
  if (e.cardio) return cardioLabel(e.km == null ? e.reps : null, e.km);
  final s = e.timed ? ' s' : '';
  if (e.setReps case final r?) return '${r.join('/')}$s';
  return '${e.sets}×${e.reps}${e.maxReps == null ? '' : '–${e.maxReps}'}$s';
}

String _load(Exercise e) => e.cardio
    ? ''
    : e.noWeight
        ? 'ohne Gewicht'
        : e.setWeights != null
            ? '${e.setWeights!.map(weightNum).join('/')} $unitLabel'
            : weightLabel(e.weight);

/// Saves [plan]'s workouts (and muscles of new exercises); the trainings stay. Returns the undo.
Future<Future<void> Function()> applyPlanImport(PlanImport plan) async {
  final before = [for (final w in store.workouts) w.copy()];
  final muscles = Map<String, dynamic>.of(store.muscles);
  await store.replacePlans(plan.workouts, muscles: {...muscles, ...plan.muscles});
  return () => store.replacePlans(before, muscles: muscles);
}
