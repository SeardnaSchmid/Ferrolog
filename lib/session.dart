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
    if (lastSetAt != null) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rest = lastSetAt == null ? null : DateTime.now().difference(lastSetAt!).inSeconds;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.workoutName),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Training verwerfen',
            onPressed: () async {
              if (!await confirm(context, 'Training verwerfen? Nichts wird gespeichert.')) return;
              await store.saveActive(null);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          TextButton(onPressed: finish, child: const Text('Beenden')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          for (final log in s.exercises)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(log.name, style: Theme.of(context).textTheme.titleMedium)),
                        IconButton(icon: const Icon(Icons.remove), onPressed: () => changeWeight(log, -1)),
                        Text(kg(log.weight), style: Theme.of(context).textTheme.titleMedium),
                        IconButton(icon: const Icon(Icons.add), onPressed: () => changeWeight(log, 1)),
                      ],
                    ),
                    Text('${log.reps.length}×${log.targetReps}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (i, r) in log.reps.indexed)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => tapSet(log, i),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: r == null
                                  ? scheme.surfaceContainerHighest
                                  : r >= log.targetReps
                                      ? scheme.primary
                                      : scheme.tertiary,
                              foregroundColor: r == null ? scheme.onSurfaceVariant : scheme.onPrimary,
                              child: Text(r?.toString() ?? '${log.targetReps}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomSheet: rest == null
          ? null
          : Material(
              color: rest >= restTarget ? scheme.primaryContainer : scheme.secondaryContainer,
              child: SafeArea(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text('Pause ${clock(rest)} / ${clock(restTarget)}'),
                  subtitle: rest >= restTarget ? const Text('Weiter geht’s!') : null,
                ),
              ),
            ),
    );
  }

  static String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
