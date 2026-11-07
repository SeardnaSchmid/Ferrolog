import 'dart:convert';

import 'package:flutter/material.dart';

import 'edit.dart';
import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'recap.dart';

/// What a task asks for; the UI picks icon and button from it.
enum TaskKind { balance, untrained, week, bodyWeight, muscles, sync }

/// Something worth doing, derived from the data: why, and (where possible) a one-tap fix. A task
/// disappears by itself once its reason is gone; [id] stays the same while the reason does, so it can
/// be put off.
class Task {
  final String id, title, why;
  final TaskKind kind;

  /// The fix: add [exercise] to [workout], or with [addSet] one more set of it there. [why] then starts
  /// with it, so the two lines on the home screen say what the button does.
  final Workout? workout;
  final String? exercise;
  final bool addSet;
  const Task(this.id, this.kind, this.title, this.why, {this.workout, this.exercise, this.addSet = false});

  /// Button label for the fix, null = no button.
  String? get action => switch (kind) {
        TaskKind.balance || TaskKind.untrained => workout == null ? null : (addSet ? '+1 Satz' : 'Hinzufügen'),
        TaskKind.bodyWeight => 'Eintragen',
        TaskKind.muscles => 'Festlegen',
        TaskKind.sync => 'Einrichten',
        TaskKind.week => null,
      };
}

/// Main muscles a task may ask for; the rest (neck, forearms, …) gets enough from the big lifts.
const taskMuscles = [
  Muscle.chest, Muscle.shoulders, Muscle.triceps, Muscle.biceps, Muscle.lats, Muscle.middleBack,
  Muscle.lowerBack, Muscle.abdominals, Muscle.quadriceps, Muscle.hamstrings, Muscle.glutes, Muscle.calves,
];

/// What helps a muscle group that falls behind: exercises that already train it specifically (then one
/// more set of the one in the plan), else the exercise to add. Picked to need little equipment and to
/// target the gap: knee flexion for the hamstrings (Nordic curls also cut strains), rows for the
/// upper back, pulling from above for the lats.
const _remedies = <String, (List<String>, String)>{
  'Oberer Rücken': (['Langhantelrudern', 'Kurzhantelrudern', 'Kabelrudern'], 'Kurzhantelrudern'),
  'Brust': (['Bankdrücken', 'Kurzhantel-Bankdrücken', 'Dips'], 'Kurzhantel-Bankdrücken'),
  'Hintere Kette': (['Rumänisches Kreuzheben', 'Hip Thrust'], 'Rumänisches Kreuzheben'),
  'Quadrizeps': (['Kniebeuge', 'Beinpresse', 'Bulgarian Split Squat'], 'Beinpresse'),
  'Beinbeuger': (['Nordic Curls', 'Beinbeuger'], 'Nordic Curls'),
  'Latissimus': (['Klimmzüge', 'Latzug'], 'Latzug'),
};

/// The same for a muscle without a single set lately.
const _forMuscle = <Muscle, String>{
  Muscle.chest: 'Kurzhantel-Bankdrücken',
  Muscle.shoulders: 'Kurzhantel-Schulterdrücken',
  Muscle.triceps: 'Trizepsdrücken am Kabel',
  Muscle.biceps: 'Bizepscurls',
  Muscle.lats: 'Latzug',
  Muscle.middleBack: 'Kurzhantelrudern',
  Muscle.lowerBack: 'Rumänisches Kreuzheben',
  Muscle.abdominals: 'Crunches',
  Muscle.quadriceps: 'Beinpresse',
  Muscle.hamstrings: 'Nordic Curls',
  Muscle.glutes: 'Hip Thrust',
  Muscle.calves: 'Wadenheben',
};

/// Open tasks, most useful first: balance and untrained muscles from the last four weeks (with a fix
/// for the workout that's up next), the weekly goal when it gets tight, then missing data (body
/// weight, muscles of own exercises, sync for the AI). [sessions] newest first.
List<Task> tasks(List<Session> sessions, List<Workout> workouts, DateTime now,
    {int perWeek = 3, bool syncConfigured = false}) {
  final result = <Task>[];
  if (workouts.isEmpty) return result;

  // Up next: the workout trained longest ago (never trained first).
  DateTime lastOf(Workout w) => sessions.where((s) => s.workoutId == w.id).firstOrNull?.date ?? DateTime(0);
  final upNext = [...workouts]..sort((a, b) => lastOf(a).compareTo(lastOf(b)));

  // The fix for a group: one more set of an exercise already planned for it, else add the remedy.
  final planned = <String>{};
  void fix(String id, TaskKind kind, String title, String why, List<String> specific, String add) {
    for (final w in upNext) {
      for (final name in specific) {
        if (w.exercises.any((e) => e.name == name)) {
          if (!planned.add(name)) return;
          result.add(Task(id, kind, title, '1 Satz $name mehr in ${w.name}. $why',
              workout: w, exercise: name, addSet: true));
          return;
        }
      }
    }
    if (!planned.add(add)) return;
    final w = upNext.first;
    result.add(Task(id, kind, title, '$add in ${w.name} aufnehmen. $why', workout: w, exercise: add));
  }

  final recent = [for (final s in sessions) if (now.difference(s.date).inDays < 28) s];
  if (recent.isNotEmpty) {
    for (final b in balances(recent, weeks: 4)) {
      final lagging = b.lagging;
      if (lagging == null) continue;
      final (specific, add) = _remedies[lagging] ?? (const <String>[], '');
      if (add.isEmpty) continue;
      final pct = '${(b.ratio * 100).floor()} %';
      fix('balance:${b.pair.name}', TaskKind.balance, '$lagging stärken',
          '${b.title}: ${b.b} bei $pct, Richtwert ${b.high.isFinite ? '${(b.low * 100).round()}–${(b.high * 100).round()} %' : 'ab ${(b.low * 100).round()} %'}.',
          specific, add);
    }
    // Muscles without a set in four weeks, once there's a bit of training to judge by.
    if (recent.length >= 3) {
      final sets = setsPerSingleMuscle(recent);
      for (final m in taskMuscles) {
        if (sets[m]! > 0) continue;
        final add = _forMuscle[m]!;
        fix('untrained:${m.name}', TaskKind.untrained, '${m.label} trainieren', 'Seit 4 Wochen kein Satz.', [add], add);
      }
    }
  }

  // Weekly goal, only when the days left get tight.
  final monday = mondayOf(now);
  final needed = perWeek - sessions.where((s) => !s.date.isBefore(monday)).length;
  final daysLeft = 8 - now.weekday; // today included
  if (sessions.isNotEmpty && needed > 0 && needed >= daysLeft - 1) {
    final week = '${monday.year}-${monday.month}-${monday.day}';
    result.add(Task('week:$week', TaskKind.week, needed == 1 ? 'Noch 1 Training diese Woche' : 'Noch $needed Trainings diese Woche',
        'Für dein Wochenziel von $perWeek, ${daysLeft == 1 ? 'heute ist der letzte Tag' : 'noch $daysLeft Tage'}.'));
  }

  // Body weight: for strength relative to it, and for the AI.
  if (sessions.length >= 3) {
    final last = sessions.where((s) => s.bodyWeight != null).firstOrNull;
    if (last == null || now.difference(last.date).inDays > 30) {
      result.add(Task('bodyweight', TaskKind.bodyWeight, 'Körpergewicht eintragen',
          last == null ? 'Noch nie eingetragen. Damit wird Kraft vergleichbar.' : 'Zuletzt vor ${now.difference(last.date).inDays} Tagen.'));
    }
  }

  // Own exercises without known muscles don't count in the muscle map and the balance.
  for (final w in workouts) {
    for (final e in w.exercises) {
      if (e.cardio || musclesOf(e.name) != null || result.any((t) => t.id == 'muscles:${e.name}')) continue;
      result.add(Task('muscles:${e.name}', TaskKind.muscles, 'Muskeln für ${e.name} festlegen',
          'Sonst fehlt die Übung in Muskelkarte und Balance.', workout: w, exercise: e.name));
    }
  }

  if (!syncConfigured && sessions.length >= 5) {
    result.add(const Task('sync', TaskKind.sync, 'Daten für deine KI',
        'Mit dem GitHub-Sync liegen deine Trainings immer aktuell dort, wo deine KI sie lesen kann.'));
  }
  return result;
}

/// Tasks put off: id → until when, kept in the preferences.
Map<String, DateTime> get snoozedTasks {
  try {
    final raw = jsonDecode(prefs.getString('tasks.snoozed') ?? '{}') as Map<String, dynamic>;
    return {for (final e in raw.entries) e.key: DateTime.parse(e.value as String)};
  } catch (_) {
    return {};
  }
}

Future<void> snoozeTask(String id, {int days = 14}) {
  final now = DateTime.now();
  final map = {...snoozedTasks}..removeWhere((_, until) => until.isBefore(now));
  map[id] = now.add(Duration(days: days));
  return prefs.setString('tasks.snoozed', jsonEncode({for (final e in map.entries) e.key: e.value.toIso8601String()}));
}

/// The open tasks right now, without those put off.
List<Task> openTasks() {
  final now = DateTime.now();
  final snoozed = snoozedTasks;
  return [
    for (final t in tasks(store.sessions, store.workouts, now, perWeek: weeklyGoal.value, syncConfigured: sync.configured))
      if (!(snoozed[t.id]?.isAfter(now) ?? false)) t,
  ];
}

const _icons = {
  TaskKind.balance: Icons.balance,
  TaskKind.untrained: Icons.accessibility_new,
  TaskKind.week: Icons.event_available_outlined,
  TaskKind.bodyWeight: Icons.monitor_weight_outlined,
  TaskKind.muscles: Icons.help_outline,
  TaskKind.sync: Icons.cloud_upload_outlined,
};

/// Runs a task's fix. Changes to a workout can be undone from the snackbar.
Future<void> runTask(BuildContext context, Task t) async {
  final messenger = ScaffoldMessenger.of(context);
  switch (t.kind) {
    case TaskKind.balance || TaskKind.untrained:
      final w = t.workout!, name = t.exercise!;
      final before = w.copy();
      final changed = w.copy();
      if (t.addSet) {
        final e = changed.exercises.firstWhere((e) => e.name == name);
        e
          ..sets += 1
          ..setWeights = e.setWeights == null ? null : [...e.setWeights!, e.setWeights!.last]
          ..setReps = e.setReps == null ? null : [...e.setReps!, e.setReps!.last];
      } else {
        changed.exercises.add(knownExercise(name));
      }
      await store.saveWorkout(changed);
      messenger.showSnackBar(SnackBar(
        content: Text(t.addSet ? '$name in ${w.name}: jetzt ${changed.exercises.firstWhere((e) => e.name == name).sets} Sätze'
            : '$name zu ${w.name} hinzugefügt'),
        action: SnackBarAction(label: 'Rückgängig', onPressed: () => store.saveWorkout(before)),
      ));
    case TaskKind.bodyWeight:
      if (store.sessions.firstOrNull case final s?) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => RecapPage(s)));
      }
    case TaskKind.muscles:
      final w = t.workout!;
      final i = w.exercises.indexWhere((e) => e.name == t.exercise);
      if (i < 0) return;
      final result = await Navigator.push<Exercise>(
        context,
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => ExerciseEditor(w.exercises[i].copy())),
      );
      if (result == null) return;
      await store.saveWorkout(w.copy()..exercises[i] = result);
    case TaskKind.sync:
      homeTab.value = 3;
    case TaskKind.week:
      break;
  }
}

/// One task in a single row: icon, what and why, its fix, and × to put it off for two weeks. [compact]
/// (home screen) keeps the why to two lines.
class TaskTile extends StatelessWidget {
  final Task task;
  final bool compact;
  final VoidCallback onChanged;
  const TaskTile(this.task, {super.key, required this.onChanged, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final action = task.action;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(_icons[task.kind], size: 20, color: task.kind == TaskKind.balance ? c.tertiary : c.primary),
        const SizedBox(width: 12),
        Expanded(
          // On the home screen a tap shows the whole text on the task page.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: compact
                ? () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()));
                    onChanged();
                  }
                : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(task.why,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(fontSize: 12.5, height: 1.3, color: c.onSurfaceVariant)),
            ]),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
            ),
            onPressed: () async {
              await runTask(context, task);
              onChanged();
            },
            child: Text(action),
          ),
        ],
        IconButton(
          icon: Icon(Icons.close, size: 18, color: c.onSurfaceVariant),
          tooltip: 'Später (2 Wochen ausblenden)',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await snoozeTask(task.id);
            onChanged();
          },
        ),
      ]),
    );
  }
}

/// On the workouts tab, under the insights: the top two tasks (the workouts stay in view), the rest
/// one tap away.
class TasksCard extends StatefulWidget {
  const TasksCard({super.key});

  @override
  State<TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends State<TasksCard> {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    // A bug here must not take the home screen down with it (a release build shows only grey).
    final List<Task> all;
    try {
      all = openTasks();
    } catch (e, stack) {
      debugPrint('Aufgaben: $e\n$stack');
      return const SizedBox();
    }
    if (all.isEmpty) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Aufgaben', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
            if (all.length > 2)
              TextButton(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksPage()));
                  if (mounted) setState(() {});
                },
                child: Text('Alle ${all.length}'),
              ),
          ]),
          for (final (i, t) in all.take(2).indexed) ...[
            if (i > 0) Divider(height: 8, color: c.outlineVariant.withValues(alpha: .5)),
            TaskTile(t, key: ValueKey(t.id), compact: true, onChanged: () => setState(() {})),
          ],
        ]),
      ),
    );
  }
}

/// Every open task.
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  @override
  Widget build(BuildContext context) {
    final all = openTasks();
    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: all.isEmpty
          ? const Center(child: Text('Alles erledigt.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: all.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (_, i) => TaskTile(all[i], key: ValueKey(all[i].id), onChanged: () => setState(() {})),
            ),
    );
  }
}
