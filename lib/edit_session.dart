import 'dart:convert';

import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';
import 'session.dart';
import 'units.dart';

/// Corrects a finished training: reps, weights, cardio and the date. Works on a copy, saved only with
/// "Speichern"; for the newest training of a workout the plan weights follow (see [Store.replaceSession]).
class EditSessionPage extends StatefulWidget {
  final Session session;
  const EditSessionPage(this.session, {super.key});

  @override
  State<EditSessionPage> createState() => _EditSessionPageState();
}

class _EditSessionPageState extends State<EditSessionPage> {
  late final Session draft = widget.session.copy();
  late final String original = jsonEncode(widget.session.toJson());

  bool get changed => jsonEncode(draft.toJson()) != original;

  /// The step of the weight sheet: the plan's, else what the log brought along.
  double incrementOf(ExerciseLog log) =>
      store.workouts
          .where((w) => w.id == draft.workoutId)
          .expand((w) => w.exercises)
          .where((e) => e.name == log.name)
          .firstOrNull
          ?.increment ??
      log.increment ??
      2.5;

  Future<void> editReps(ExerciseLog log, int i) async {
    final result = await showRepsSheet(context, log, i);
    if (result == null) return;
    setState(() {
      log.reps[i] = result.reps;
      if (result.reps == null) log.doneAt[i] = null;
    });
  }

  Future<void> editWeight(ExerciseLog log, int i) async {
    final result = await showWeightSheet(context, log, i, increment: incrementOf(log), scope: WeightScope.set);
    if (result case (final w, final scope)) setState(() => applyWeightScope(log, i, w, scope));
  }

  Future<void> editCardio(ExerciseLog log) async {
    final result = await showCardioSheet(context, log);
    if (result == null) return;
    setState(() {
      applyCardio(log, result);
      if (log.reps[0] == null) log.doneAt[0] = null;
    });
  }

  /// Day, then start time; everything else in the training moves by the same amount.
  Future<void> editDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: draft.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Tag des Trainings',
      cancelText: 'Abbrechen',
      confirmText: 'Weiter',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(draft.date),
      helpText: 'Beginn',
      cancelText: 'Abbrechen',
      confirmText: 'OK',
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (time == null) return;
    setState(() => draft.shift(DateTime(day.year, day.month, day.day, time.hour, time.minute).difference(draft.date)));
  }

  Future<void> save() async {
    if (changed) await store.replaceSession(draft);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    final d = draft.date;
    return PopScope(
      canPop: !changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirm(context, 'Änderungen verwerfen?') && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Training bearbeiten')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(dayLabel(d)),
                subtitle: Text('${dateLabel(d)} · Beginn ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: editDate,
              ),
            ),
            for (final log in draft.exercises)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(log.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(
                      log.cardio
                          ? 'Cardio · Ziel ${cardioLabel(log.targetReps, log.targetKm)}'
                          : setsLabel(log.targets, log.maxReps, seconds: log.timed),
                      style: muted,
                    ),
                    if (log.replaces case final r?) Text('statt $r', style: muted),
                    const SizedBox(height: 10),
                    if (log.cardio)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => editCardio(log),
                        child: Text(switch (log.reps[0]) {
                          null => 'Nicht gemacht',
                          final m => cardioLabel(m, log.km),
                        }),
                      )
                    else
                      Row(children: [
                        for (final (i, r) in log.reps.indexed) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 84),
                              child: SetTile(
                                reps: r,
                                target: log.targets[i],
                                targetMax: log.maxReps,
                                repsUnit: log.timed ? ' s' : '',
                                weight: log.weights[i] == 0 ? '–' : weightNum(log.weights[i]),
                                weightUnit: log.weights[i] == 0 ? '' : null,
                                onTapReps: () => editReps(log, i),
                                onTapWeight: () => editWeight(log, i),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    if (!log.cardio &&
                        !log.timed &&
                        log.weights.every((w) => w >= 0) &&
                        ((prefs.getBool('session.askRir') ?? false) || log.rir != null || autoRir(draft, log))) ...[
                      const SizedBox(height: 10),
                      // The reserve after the last set; the chosen one again takes it off.
                      Row(children: [
                        Text('Gingen noch', style: muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(spacing: 6, children: [
                            for (final n in const [0, 1, 2, 3, 4])
                              ChoiceChip(
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                label: Text(n == 4 ? '4+' : '$n'),
                                selected: log.rir == n,
                                onSelected: (on) => setState(() => log.rir = on ? n : null),
                              ),
                          ]),
                        ),
                      ]),
                    ],
                  ]),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: save,
                    child: const Text('Speichern'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                store.movesPlan(widget.session)
                    ? 'Die Plan-Gewichte werden neu berechnet.'
                    : 'Ältere Trainings ändern nur Verlauf und Statistik, nicht den Plan.',
                style: muted,
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Sheet to correct the reps (seconds when timed) of set [i]: a stepper, or "Nicht gemacht".
/// Not the tap-to-count-down of the live page, that one is tuned for speed. Null when closed without saving.
Future<({int? reps})?> showRepsSheet(BuildContext context, ExerciseLog log, int i) {
  var value = log.reps[i] ?? log.targets[i];
  final unit = log.timed ? ' s' : '';
  return showModalBottomSheet<({int? reps})>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final c = Theme.of(context).colorScheme;
        Widget step(IconData icon, int dir) => IconButton.filledTonal(
              iconSize: 28,
              style: IconButton.styleFrom(fixedSize: const Size(56, 56), backgroundColor: c.surfaceContainerHigh),
              icon: Icon(icon),
              tooltip: dir < 0 ? 'Weniger' : 'Mehr',
              onPressed: value + dir < 0 ? null : () => setSheet(() => value += dir),
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(log.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              Text('Satz ${i + 1} von ${log.reps.length} · Ziel ${log.targets[i]}$unit',
                  style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              step(Icons.remove, -1),
              Expanded(
                child: Text('$value$unit',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
              ),
              step(Icons.add, 1),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context, (reps: null)),
                  child: const Text('Nicht gemacht'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context, (reps: value)),
                  child: const Text('Speichern'),
                ),
              ),
            ]),
          ]),
        );
      },
    ),
  );
}
