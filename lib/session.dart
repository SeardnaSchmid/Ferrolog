import 'dart:async';

import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';

/// Live training: tap a set circle to log it (first tap = target reps, each
/// further tap one rep less, then back to empty). A rest timer runs after each set.
class SessionPage extends StatefulWidget {
  final Session session;
  const SessionPage(this.session, {super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  Session get s => widget.session;
  DateTime? lastSetAt;
  int restTarget = 0;
  late final Timer ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    setState(() {}); // rest timer and elapsed minutes
  });

  @override
  void initState() {
    super.initState();
    ticker; // start
  }

  @override
  void dispose() {
    ticker.cancel();
    super.dispose();
  }

  Exercise? planOf(ExerciseLog log) => store.workouts
      .where((w) => w.id == s.workoutId)
      .firstOrNull
      ?.exercises
      .where((e) => e.name == log.name)
      .firstOrNull;

  void tapSet(ExerciseLog log, int i) {
    setState(() {
      final r = log.reps[i];
      log.reps[i] = r == null ? log.targetReps : (r > 1 ? r - 1 : null);
      if (log.reps[i] != null) {
        lastSetAt = DateTime.now();
        restTarget = planOf(log)?.restSeconds ?? 120;
      }
    });
    store.saveActive(s);
  }

  void changeWeight(ExerciseLog log, int direction) {
    final step = planOf(log)?.increment ?? 2.5;
    setState(() => log.weight = (log.weight + direction * (step == 0 ? 2.5 : step)).clamp(0, 1000));
    store.saveActive(s);
  }

  Future<void> finish() async {
    if (s.exercises.every((e) => e.setsDone == 0)) {
      if (!await confirm(context, 'Keine Sätze geloggt. Training verwerfen?')) return;
      await store.saveActive(null);
    } else {
      final missing = s.exercises.any((e) => e.setsDone < e.reps.length);
      if (missing && !await confirm(context, 'Nicht alle Sätze erledigt. Trotzdem beenden?')) return;
      await store.finishSession(s);
    }
    if (mounted) Navigator.pop(context);
  }

  /// Bottom sheet to adjust an exercise's weight in its increment steps.
  void pickWeight(ExerciseLog log) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheet) {
            final c = Theme.of(context).colorScheme;
            Widget step(IconData icon, int dir) => IconButton.filledTonal(
                  iconSize: 28,
                  style: IconButton.styleFrom(fixedSize: const Size(56, 56), backgroundColor: c.surfaceContainerHigh),
                  icon: Icon(icon),
                  onPressed: () {
                    changeWeight(log, dir);
                    setSheet(() {});
                  },
                );
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(log.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  step(Icons.remove, -1),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: kgNum(log.weight)),
                      TextSpan(
                        text: ' kg',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: c.onSurfaceVariant),
                      ),
                    ]),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  step(Icons.add, 1),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
                ),
              ]),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final rest = lastSetAt == null ? null : DateTime.now().difference(lastSetAt!).inSeconds;
    final over = rest != null && rest >= restTarget;
    final muted = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 104,
        leading: TextButton(
          style: TextButton.styleFrom(foregroundColor: c.error),
          onPressed: () async {
            if (!await confirm(context, 'Training verwerfen? Nichts wird gespeichert.')) return;
            await store.saveActive(null);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Verwerfen'),
        ),
        centerTitle: true,
        title: Column(children: [
          Text(s.workoutName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          Text('${DateTime.now().difference(s.date).inMinutes} Min.', style: muted.copyWith(fontSize: 11)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: finish, child: const Text('Beenden')),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final log in s.exercises)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: .6)))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Text(
                    [
                      '${log.reps.length}×${log.targetReps}',
                      if (planOf(log) case final p?) 'Pause ${clock(p.restSeconds)}',
                    ].join(' · '),
                    style: muted,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final (i, r) in log.reps.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 84),
                            child: SetTile(
                              reps: r,
                              target: log.targetReps,
                              weight: kgNum(log.weight),
                              onTapReps: () => tapSet(log, i),
                              onTapWeight: () => pickWeight(log),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: rest == null
          ? null
          : SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                padding: const EdgeInsets.fromLTRB(16, 4, 6, 12),
                decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Text(clock(rest),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${over ? 'PAUSE VORBEI' : 'PAUSE'} · ${clock(restTarget)}',
                          style: muted.copyWith(fontWeight: FontWeight.w500, letterSpacing: .5)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Ausblenden',
                      onPressed: () => setState(() => lastSetAt = null),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: LinearProgressIndicator(
                      value: restTarget == 0 ? 1 : (rest / restTarget).clamp(0, 1),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                      color: over ? c.tertiary : c.primary,
                      backgroundColor: c.outlineVariant,
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  static String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
