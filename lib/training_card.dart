import 'dart:convert';

import 'package:flutter/material.dart';

import 'findings.dart';
import 'language.dart';
import 'main.dart';
import 'model.dart';
import 'stats.dart';

/// Bumped when findings are put off or brought back, so the home screen redraws.
final findingsVersion = ValueNotifier(0);

/// Findings put off: id → until when, kept in the preferences.
Map<String, DateTime> get snoozedFindings {
  try {
    final raw = jsonDecode(prefs.getString('tasks.snoozed') ?? '{}') as Map<String, dynamic>;
    return {for (final e in raw.entries) e.key: DateTime.parse(e.value as String)};
  } catch (_) {
    return {};
  }
}

/// Puts a finding off. For training advice this also starts the pause before the next one.
Future<void> snoozeFinding(String id, {int days = 14}) async {
  final now = DateTime.now();
  final map = {...snoozedFindings}..removeWhere((_, until) => until.isBefore(now));
  map[id] = now.add(Duration(days: days));
  await prefs.setString('tasks.snoozed', jsonEncode({for (final e in map.entries) e.key: e.value.toIso8601String()}));
  if (isAdvice(id)) await prefs.setString('tasks.lastAdvice', now.toIso8601String());
  findingsVersion.value++;
}

/// Brings a finding back (after an undo), along with the advice it started the pause for.
Future<void> unsnoozeFinding(String id) async {
  final map = {...snoozedFindings}..remove(id);
  await prefs.setString('tasks.snoozed', jsonEncode({for (final e in map.entries) e.key: e.value.toIso8601String()}));
  if (isAdvice(id)) await prefs.remove('tasks.lastAdvice');
  findingsVersion.value++;
}

/// The findings right now, as switched on in the settings: "Hinweise zum Training" (actions) and
/// "Erfolge" (positives).
List<Finding> openFindings() {
  final actions = prefs.getBool('home.tasks') ?? true, positives = prefs.getBool('home.insights') ?? true;
  return [
    for (final f in findings(store.sessions, store.workouts, DateTime.now(),
        perWeek: weeklyGoal.value,
        snoozed: snoozedFindings,
        lastAdvice: DateTime.tryParse(prefs.getString('tasks.lastAdvice') ?? '')))
      if (f.kind == FindingKind.action ? actions : positives) f,
  ];
}

const _icons = {
  FindingType.weekGoal: Icons.event_available_outlined,
  FindingType.skipped: Icons.skip_next_outlined,
  FindingType.balance: Icons.balance,
  FindingType.plateau: Icons.landscape_outlined,
  FindingType.record: Icons.local_fire_department_outlined,
  FindingType.gain: Icons.trending_up,
  FindingType.milestone: Icons.emoji_events_outlined,
  FindingType.month: Icons.calendar_month_outlined,
};

String? _label(FindingType t) => switch (t) {
      FindingType.weekGoal => tr.cardWeekGoal,
      FindingType.skipped => tr.cardSkipped,
      FindingType.balance => tr.cardBalance,
      FindingType.plateau => tr.cardPlateau,
      _ => null,
    };

/// Opens where the statistics show a finding.
void openSource(BuildContext context, StatsTarget t) {
  switch (t.view) {
    case StatsView.exercise:
      Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseStats(t.exercise!, marked: t.dates)));
    case StatsView.balance || StatsView.weeks:
      statsFocus.value = t;
      homeTab.value = 1;
    case StatsView.history:
      homeTab.value = 2;
  }
}

/// Top of the workouts tab: what the statistics found. The top action with its evidence, up to two
/// lines below (successes first), or one quiet line when there's nothing. At most about a third of
/// the screen, so the next workout's start button stays in view.
class TrainingCard extends StatelessWidget {
  const TrainingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = prefs.getBool('home.tasks') ?? true, positives = prefs.getBool('home.insights') ?? true;
    if (!actions && !positives) return const SizedBox();
    // A bug here must not take the home screen down with it (a release build shows only grey).
    final List<Finding> all;
    try {
      all = openFindings();
    } catch (e, stack) {
      debugPrint('Dein Training: $e\n$stack');
      return const SizedBox();
    }
    final c = Theme.of(context).colorScheme;
    final (top, rows) = homeSelection(all);
    if (top == null && rows.isEmpty) {
      return Card(
        child: _Line(
          icon: Icons.check,
          color: c.primary,
          text: Text.rich(TextSpan(children: [
            TextSpan(text: tr.cardAllGood, style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: tr.cardSeeStats),
          ])),
          onTap: () => homeTab.value = 1,
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(children: [
              Expanded(child: Text(tr.cardTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              Text(tr.cardFromStats, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 8),
          if (top != null) _Top(top),
          for (final (i, f) in rows.indexed) ...[
            if (i > 0 || top != null) Divider(height: 1, color: c.outlineVariant.withValues(alpha: .5)),
            _Line(
              icon: _icons[f.type]!,
              color: f.kind == FindingKind.action ? c.tertiary : c.primary,
              text: Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => f.kind == FindingKind.action ? showFinding(context, f) : openSource(context, f.source),
            ),
          ],
        ]),
      ),
    );
  }
}

/// The top action: title, evidence in one line, and the way into its sheet.
class _Top extends StatelessWidget {
  final Finding f;
  const _Top(this.f);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: Color.alphaBlend(c.tertiaryContainer.withValues(alpha: .3), c.surfaceContainerLow),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.tertiary.withValues(alpha: .45))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showFinding(context, f),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_icons[f.type], size: 18, color: c.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(f.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.tertiary),
            ]),
            const SizedBox(height: 2),
            Text(f.evidence,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: c.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(tr.cardWhyWhat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.primary)),
          ]),
        ),
      ),
    );
  }
}

/// One line of the card: icon, text, chevron.
class _Line extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget text;
  final VoidCallback onTap;
  const _Line({required this.icon, required this.color, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(children: [
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: text)),
            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 2),
          ]),
        ),
      );
}

/// An action's sheet: what was found, why, what to do (with its button, if any), put off, and the
/// way into the statistics.
Future<void> showFinding(BuildContext context, Finding f) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) {
        final c = Theme.of(sheet).colorScheme;
        final heading = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: .5, color: c.onSurfaceVariant);
        final body = const TextStyle(fontSize: 14.5, height: 1.45);
        final plan = f.type == FindingType.plateau ? _workoutWith(f.exercise) : null;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(_label(f.type) ?? '',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.tertiary)),
              const SizedBox(height: 4),
              Text(f.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(f.evidence, style: body.copyWith(color: c.onSurfaceVariant)),
              if (f.why case final why?) ...[
                const SizedBox(height: 16),
                Text(tr.cardWhy, style: heading),
                const SizedBox(height: 4),
                Text(why, style: body),
              ],
              if (f.advice case final advice?) ...[
                const SizedBox(height: 16),
                Text(tr.cardAdvice, style: heading),
                const SizedBox(height: 4),
                Text(advice, style: body),
              ],
              const SizedBox(height: 16),
              Row(children: [
                if (f.fix != null)
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () {
                        Navigator.pop(sheet);
                        runFix(context, f);
                      },
                      child: Text(f.fix == Fix.moveUp ? tr.fixMoveUp(f.workout!.name) : tr.fixDropSet(f.exercise!),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                else if (plan != null)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () {
                        Navigator.pop(sheet);
                        editExerciseIn(context, plan, f.exercise!);
                      },
                      child: Text(tr.fixInEditor),
                    ),
                  ),
                if (f.fix != null || plan != null) const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () {
                    Navigator.pop(sheet);
                    snoozeFinding(f.id);
                  },
                  child: Text(tr.later),
                ),
              ]),
              const SizedBox(height: 8),
              Divider(color: c.outlineVariant.withValues(alpha: .6)),
              InkWell(
                onTap: () {
                  Navigator.pop(sheet);
                  openSource(context, f.source);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(_sourceLabel(f.source),
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: c.primary)),
                    ),
                    Icon(Icons.chevron_right, color: c.primary),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );

String _sourceLabel(StatsTarget t) => switch (t.view) {
      StatsView.balance => tr.sourceBalance,
      StatsView.weeks => tr.sourceWeeks,
      StatsView.exercise => tr.sourceExercise(t.exercise ?? ''),
      StatsView.history => tr.sourceHistory,
    };

Workout? _workoutWith(String? exercise) =>
    exercise == null ? null : store.workouts.where((w) => w.exercises.any((e) => e.name == exercise)).firstOrNull;

/// Runs a finding's fix: moves the exercise up or drops a set. Undo from the snackbar.
Future<void> runFix(BuildContext context, Finding f) async {
  final messenger = ScaffoldMessenger.of(context);
  final w = f.workout!, name = f.exercise!;
  final before = w.copy();
  final changed = w.copy();
  final i = changed.exercises.indexWhere((e) => e.name == name);
  if (i < 0) return;
  final e = changed.exercises[i];
  switch (f.fix!) {
    case Fix.moveUp:
      changed.exercises
        ..removeAt(i)
        ..insert(earlierSlot(changed), e);
    case Fix.dropSet:
      e
        ..sets -= 1
        ..setWeights = e.setWeights?.sublist(0, e.sets)
        ..setReps = e.setReps?.sublist(0, e.sets);
  }
  // The numbers only move after a few trainings: until then the finding is done.
  await snoozeFinding(f.id, days: 28);
  await store.saveWorkout(changed);
  messenger.showSnackBar(SnackBar(
    content: Text(f.fix == Fix.moveUp
        ? tr.fixMovedUp(name, w.name)
        : tr.fixDroppedSet(name, w.name, tr.setsCount(e.sets))),
    action: SnackBarAction(
      label: tr.undo,
      onPressed: () async {
        await unsnoozeFinding(f.id);
        await store.saveWorkout(before); // also redraws the card
      },
    ),
  ));
}
