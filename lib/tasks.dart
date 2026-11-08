import 'dart:convert';

import 'package:flutter/material.dart';

import 'edit.dart';
import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'recap.dart';

/// What a task asks for; the UI picks icon and button from it.
enum TaskKind { balance, week, bodyWeight, muscles }

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
        TaskKind.balance => workout == null ? null : (addSet ? '+1 Satz' : 'Hinzufügen'),
        TaskKind.bodyWeight => 'Eintragen',
        TaskKind.muscles => 'Festlegen',
        TaskKind.week => null,
      };
}

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

/// Training advice waits for a baseline: this many trainings over at least
/// two weeks, so a first week doesn't flood a new user with "train X".
const baselineTrainings = 6;

/// At most one piece of training advice at a time, and a new one at most every [advicePause] after the
/// last was acted on or put off: one thing to work on, not a list.
const advicePause = Duration(days: 7);

bool _isAdvice(String id) => id.startsWith('balance:');

/// Open tasks, situational and few. Training advice comes only from opposing muscles: once there's a
/// baseline and the last advice is a week old, the pair furthest off its guide range in the last four
/// weeks, with a fix for the workout up next. So whoever trains chest but never the back gets told to
/// row; muscles left out on both sides (no legs at all, no calves) are the program's choice. Besides it only what's due right now: the
/// weekly goal when the days get tight, own exercises without muscles, a body weight that's gone stale.
/// [sessions] newest first; [snoozed]: id → put off until.
List<Task> tasks(List<Session> sessions, List<Workout> workouts, DateTime now,
    {int perWeek = 3, Map<String, DateTime> snoozed = const {}, DateTime? lastAdvice}) {
  final result = <Task>[];
  if (workouts.isEmpty) return result;
  bool off(String id) => snoozed[id]?.isAfter(now) ?? false;

  // Up next: the workout trained longest ago (never trained first).
  DateTime lastOf(Workout w) => sessions.where((s) => s.workoutId == w.id).firstOrNull?.date ?? DateTime(0);
  final upNext = [...workouts]..sort((a, b) => lastOf(a).compareTo(lastOf(b)));

  // The fix for a group: one more set of an exercise already planned for it, else add the remedy.
  Task fix(String id, TaskKind kind, String title, String why, List<String> specific, String add) {
    for (final w in upNext) {
      for (final name in specific) {
        if (w.exercises.any((e) => e.name == name)) {
          return Task(id, kind, title, '1 Satz $name mehr in ${w.name}. $why', workout: w, exercise: name, addSet: true);
        }
      }
    }
    final w = upNext.first;
    return Task(id, kind, title, '$add in ${w.name} aufnehmen. $why', workout: w, exercise: add);
  }

  final baseline = sessions.length >= baselineTrainings && now.difference(sessions.last.date).inDays >= 14;
  if (baseline && (lastAdvice == null || now.difference(lastAdvice) >= advicePause)) {
    // Candidates with how far off they are; the worst one not put off becomes the advice.
    final candidates = <(double, Task Function())>[];
    final recent = [for (final s in sessions) if (now.difference(s.date).inDays < 28) s];
    for (final b in balances(recent, weeks: 4)) {
      final lagging = b.lagging;
      if (lagging == null || !_remedies.containsKey(lagging)) continue;
      final (specific, add) = _remedies[lagging]!;
      final gap = b.ratio < b.low ? (b.ratio == 0 ? 99.0 : b.low / b.ratio) : b.ratio / b.high;
      final range = b.high.isFinite ? '${(b.low * 100).round()}–${(b.high * 100).round()} %' : 'ab ${(b.low * 100).round()} %';
      candidates.add((
        gap,
        () => fix('balance:${b.pair.name}', TaskKind.balance, '$lagging stärken',
            '${b.title}: ${b.b} bei ${(b.ratio * 100).floor()} %, Richtwert $range.', specific, add),
      ));
    }
    // Worst first; on a tie the order of the pairs stays.
    final ranked = [for (final (i, c) in candidates.indexed) (i, c)]
      ..sort((a, b) => b.$2.$1 != a.$2.$1 ? b.$2.$1.compareTo(a.$2.$1) : a.$1.compareTo(b.$1));
    for (final (_, (_, make)) in ranked) {
      final task = make();
      if (off(task.id)) continue;
      result.add(task);
      break;
    }
  }

  // Weekly goal, only when the days left get tight and it can still be made, one training a day. Not in
  // the week of the very first training, and today counts no more once trained.
  final monday = mondayOf(now);
  final needed = perWeek - sessions.where((s) => !s.date.isBefore(monday)).length;
  final trainedToday = sessions.any((s) => !s.date.isBefore(DateTime(now.year, now.month, now.day)));
  final daysLeft = 8 - now.weekday - (trainedToday ? 1 : 0); // today included unless trained
  final firstWeek = sessions.isNotEmpty && !sessions.last.date.isBefore(monday);
  if (sessions.isNotEmpty && !firstWeek && needed > 0 && needed <= daysLeft && needed >= daysLeft - 1) {
    final week = '${monday.year}-${monday.month}-${monday.day}';
    final when = daysLeft > 1
        ? 'noch $daysLeft Tage'
        : trainedToday
            ? 'morgen ist der letzte Tag'
            : 'heute ist der letzte Tag';
    result.add(Task('week:$week', TaskKind.week, needed == 1 ? 'Noch 1 Training diese Woche' : 'Noch $needed Trainings diese Woche',
        'Für dein Wochenziel von $perWeek, $when.'));
  }

  // Own exercises without known muscles don't count in the muscle map and the balance.
  for (final w in workouts) {
    for (final e in w.exercises) {
      if (e.cardio || musclesOf(e.name) != null || result.any((t) => t.id == 'muscles:${e.name}')) continue;
      result.add(Task('muscles:${e.name}', TaskKind.muscles, 'Muskeln für ${e.name} festlegen',
          'Sonst fehlt die Übung in Muskelkarte und Balance.', workout: w, exercise: e.name));
    }
  }

  // Body weight, only for those who track it and haven't for a month.
  if (sessions.where((s) => s.bodyWeight != null).firstOrNull case final last? when now.difference(last.date).inDays > 30) {
    result.add(Task('bodyweight', TaskKind.bodyWeight, 'Körpergewicht eintragen', 'Zuletzt vor ${now.difference(last.date).inDays} Tagen.'));
  }
  return [for (final t in result) if (!off(t.id)) t];
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

/// Puts a task off. For training advice this also starts the pause before the next one.
Future<void> snoozeTask(String id, {int days = 14}) async {
  final now = DateTime.now();
  final map = {...snoozedTasks}..removeWhere((_, until) => until.isBefore(now));
  map[id] = now.add(Duration(days: days));
  await prefs.setString('tasks.snoozed', jsonEncode({for (final e in map.entries) e.key: e.value.toIso8601String()}));
  if (_isAdvice(id)) await prefs.setString('tasks.lastAdvice', now.toIso8601String());
}

/// Brings a task back (after an undo), along with the advice it started the pause for.
Future<void> unsnoozeTask(String id) async {
  final map = {...snoozedTasks}..remove(id);
  await prefs.setString('tasks.snoozed', jsonEncode({for (final e in map.entries) e.key: e.value.toIso8601String()}));
  if (_isAdvice(id)) await prefs.remove('tasks.lastAdvice');
}

/// The open tasks right now.
List<Task> openTasks() => tasks(store.sessions, store.workouts, DateTime.now(),
    perWeek: weeklyGoal.value,
    snoozed: snoozedTasks,
    lastAdvice: DateTime.tryParse(prefs.getString('tasks.lastAdvice') ?? ''));

const _icons = {
  TaskKind.balance: Icons.balance,
  TaskKind.week: Icons.event_available_outlined,
  TaskKind.bodyWeight: Icons.monitor_weight_outlined,
  TaskKind.muscles: Icons.help_outline,
};

/// Runs a task's fix. Changes to a workout can be undone from the snackbar.
Future<void> runTask(BuildContext context, Task t) async {
  final messenger = ScaffoldMessenger.of(context);
  switch (t.kind) {
    case TaskKind.balance:
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
      // The numbers only move after a few trainings: until then the advice is done.
      await snoozeTask(t.id, days: 28);
      messenger.showSnackBar(SnackBar(
        content: Text(t.addSet ? '$name in ${w.name}: jetzt ${changed.exercises.firstWhere((e) => e.name == name).sets} Sätze'
            : '$name zu ${w.name} hinzugefügt'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            await unsnoozeTask(t.id);
            await store.saveWorkout(before); // also redraws the task card
          },
        ),
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
    // Redrawn on every change of the data, e.g. an undo from the snackbar.
    return ListenableBuilder(listenable: store, builder: (context, _) => card(context));
  }

  Widget card(BuildContext context) {
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
