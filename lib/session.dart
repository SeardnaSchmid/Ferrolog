import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'model.dart';
import 'units.dart';

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
  DateTime? lastSetAt, pausedAt;
  ExerciseLog? touched; // highlighted: the exercise last logged or edited
  int restTarget = 0;
  bool alerted = false;
  late final Timer ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    // Rest over: sound and/or vibration once, as configured in the settings.
    if (lastSetAt != null && pausedAt == null && !alerted && restLeft <= 0) {
      alerted = true;
      restAlert();
    }
    setState(() {}); // rest timer and elapsed minutes
  });

  /// Seconds of rest left; negative once the rest is over.
  int get restLeft => restTarget - (pausedAt ?? DateTime.now()).difference(lastSetAt!).inSeconds;

  void restartRest() => setState(() {
        lastSetAt = DateTime.now();
        if (pausedAt != null) pausedAt = lastSetAt;
        alerted = false;
      });

  void toggleRestPause() => setState(() {
        final now = DateTime.now();
        if (pausedAt == null) {
          pausedAt = now;
        } else {
          lastSetAt = lastSetAt!.add(now.difference(pausedAt!));
          pausedAt = null;
        }
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
    if (log.cardio) {
      // Cardio: done as planned, tap again to undo. No rest timer.
      setState(() {
        touched = log;
        final done = log.reps[0] != null;
        log.reps[0] = done ? null : log.targetReps;
        log.km = done ? null : log.targetKm;
      });
      store.saveActive(s);
      return;
    }
    setState(() {
      touched = log;
      final r = log.reps[i];
      log.reps[i] = r == null ? log.targetReps : (r > 1 ? r - 1 : null);
      if (log.reps[i] != null) {
        lastSetAt = DateTime.now();
        pausedAt = null;
        alerted = false;
        restTarget = planOf(log)?.restSeconds ?? 120;
      }
    });
    store.saveActive(s);
  }

  /// Sets the weight of set [i], and depending on [scope] of other sets of the exercise too.
  void applyWeight(ExerciseLog log, int i, double w, WeightScope scope) {
    setState(() {
      for (var j = 0; j < log.weights.length; j++) {
        final hit = switch (scope) {
          WeightScope.set => j == i,
          WeightScope.open => j == i || log.reps[j] == null,
          WeightScope.all => true,
        };
        if (hit) log.weights[j] = w;
      }
    });
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

  /// Sheet to enter the actual minutes and distance of a cardio exercise.
  Future<void> editCardio(ExerciseLog log) async {
    setState(() => touched = log);
    final minutes = TextEditingController(text: '${log.reps[0] ?? log.targetReps}');
    final distance = TextEditingController(text: switch (log.km ?? log.targetKm) { final km? => distanceNum(km), null => '' });
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(log.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: minutes,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dauer', suffixText: 'Min', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: distance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Distanz (optional)', suffixText: distanceLabel, border: const OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Speichern'),
              ),
            ),
          ]),
        ]),
      ),
    );
    if (saved != true) return;
    final m = int.tryParse(minutes.text.trim());
    setState(() {
      log.reps[0] = m != null && m > 0 ? m : null;
      log.km = log.reps[0] == null ? null : parseDistance(distance.text);
    });
    store.saveActive(s);
  }

  /// Sheet to edit a set's weight: type it or step it, choose which sets it applies to, then save.
  Future<void> pickWeight(ExerciseLog log, int i) async {
    setState(() => touched = log);
    // The sheet works in the shown unit (kg or lb) and converts to kg on save.
    final step = stepShown(planOf(log)?.increment ?? 0);
    final field = TextEditingController(text: weightNum(log.weights[i]));
    var scope = WeightScope.open;
    double? parse() => switch (parseWeight(field.text)) {
          final kg? when kg >= 0 && kg <= 1000 => kg,
          _ => null,
        };
    final result = await showModalBottomSheet<(double, WeightScope)>(
      context: context,
      isScrollControlled: true, // lets the sheet move above the keyboard
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final c = Theme.of(context).colorScheme;
          final w = parse();
          void nudge(int dir) {
            final next = (shown(w ?? log.weights[i]) + dir * step).clamp(0, shown(1000)).toDouble();
            setSheet(() => field.text = weightNum(toKg(next)));
          }

          Widget stepButton(IconData icon, int dir) => IconButton.filledTonal(
                iconSize: 28,
                style: IconButton.styleFrom(fixedSize: const Size(56, 56), backgroundColor: c.surfaceContainerHigh),
                icon: Icon(icon),
                tooltip: '${dir < 0 ? '−' : '+'}${weightNum(toKg(step))} $unitLabel',
                onPressed: () => nudge(dir),
              );
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(log.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Text('Satz ${i + 1} von ${log.reps.length}', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  stepButton(Icons.remove, -1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: field,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                      decoration: InputDecoration(
                        suffixText: unitLabel,
                        errorText: w == null ? 'Gewicht zwischen 0 und ${weightLabel(1000)}' : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onChanged: (_) => setSheet(() {}),
                      onTap: () => field.selection = TextSelection(baseOffset: 0, extentOffset: field.text.length),
                    ),
                  ),
                  const SizedBox(width: 12),
                  stepButton(Icons.add, 1),
                ]),
                const SizedBox(height: 16),
                Text('Übernehmen für', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                const SizedBox(height: 8),
                SegmentedButton<WeightScope>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: WeightScope.set, label: Text('Dieser Satz')),
                    ButtonSegment(value: WeightScope.open, label: Text('Offene Sätze')),
                    ButtonSegment(value: WeightScope.all, label: Text('Alle Sätze')),
                  ],
                  selected: {scope},
                  onSelectionChanged: (v) => setSheet(() => scope = v.single),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: w == null ? null : () => Navigator.pop(context, (w, scope)),
                      child: const Text('Speichern'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
    // No field.dispose() here: the sheet's closing animation still rebuilds the TextField.
    if (result case (final w, final scope)) applyWeight(log, i, w, scope);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final left = lastSetAt == null ? null : restLeft;
    final over = left != null && left <= 0;
    final muted = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    final done = s.exercises.fold(0, (n, e) => n + e.setsDone);
    final total = s.exercises.fold(0, (n, e) => n + e.reps.length);
    // Highlight the exercise last touched; before that, the first one with open sets.
    final current = touched ?? s.exercises.where((e) => e.setsDone < e.reps.length).firstOrNull;
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
        title: Text(s.workoutName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: finish, child: const Text('Beenden')),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live strip, same look as the running-training card on the overview.
          Container(
            color: Color.alphaBlend(c.primaryContainer.withValues(alpha: .45), c.surface),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(children: [
              Row(children: [
                const LiveDot(),
                const SizedBox(width: 8),
                Text('LÄUFT',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.primary)),
                Text(' · ', style: TextStyle(color: c.onSurfaceVariant)),
                Elapsed(s.date, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                const Spacer(),
                Text('$done/$total Sätze', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                backgroundColor: c.surface,
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                for (final log in s.exercises) _exerciseCard(log, log == current, c, muted),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: left == null
          ? null
          : SafeArea(
              // Rest timer: big centered countdown, blue while resting, orange once the rest is over.
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
                decoration: BoxDecoration(
                  color: over ? c.tertiaryContainer : c.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Equal-width sides keep the countdown exactly centered.
                  Row(children: [
                    Expanded(
                      child: Row(children: [
                        IconButton(icon: const Icon(Icons.restart_alt), tooltip: 'Neu starten', onPressed: restartRest),
                        IconButton(
                          icon: Icon(pausedAt == null ? Icons.pause : Icons.play_arrow),
                          tooltip: pausedAt == null ? 'Anhalten' : 'Weiter',
                          onPressed: toggleRestPause,
                        ),
                      ]),
                    ),
                    Column(children: [
                      // Counts down to 0:00, then up to show how long the rest has run over.
                      Text(left > 0 ? clock(left) : '+${clock(-left)}',
                          style: TextStyle(
                              fontSize: 52,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: over ? c.onTertiaryContainer : c.onPrimaryContainer,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                      Text(
                        '${pausedAt != null ? 'PAUSIERT' : over ? 'PAUSE VORBEI' : 'PAUSE'} · ${clock(restTarget)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: (over ? c.onTertiaryContainer : c.onPrimaryContainer).withValues(alpha: .75),
                        ),
                      ),
                    ]),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Ausblenden',
                          onPressed: () => setState(() => lastSetAt = null),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LinearProgressIndicator(
                      value: restTarget == 0 ? 1 : (1 - left / restTarget).clamp(0, 1),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: over ? c.tertiary : c.primary,
                      backgroundColor: c.surface.withValues(alpha: .6),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  /// One exercise as a card; the current one outlined and tinted like the running training on the overview.
  Widget _exerciseCard(ExerciseLog log, bool current, ColorScheme c, TextStyle muted) => Card(
        color: current ? Color.alphaBlend(c.primaryContainer.withValues(alpha: .45), c.surfaceContainerLow) : null,
        shape: current
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.primary, width: 2))
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(log.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(
                      log.cardio
                          ? 'Cardio · Ziel ${cardioLabel(log.targetReps, log.targetKm)}'
                          : [
                              '${log.reps.length}×${log.targetReps}',
                              if (planOf(log) case final p?) 'Pause ${clock(p.restSeconds)}',
                            ].join(' · '),
                      style: muted,
                    ),
                  ]),
                ),
                if (log.setsDone == log.reps.length)
                  Icon(Icons.check_circle, color: log.succeeded ? c.primary : c.tertiary)
                else if (current)
                  Text('JETZT',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.primary)),
              ]),
              const SizedBox(height: 10),
              if (log.cardio)
                // One wide tile: minutes on top (tap = done as planned), distance below (tap = enter actual).
                SetTile(
                  reps: log.reps[0],
                  target: log.targetReps,
                  repsUnit: ' Min',
                  weight: switch (log.km ?? log.targetKm) { final km? => distanceNum(km), null => '–' },
                  weightUnit: distanceLabel,
                  onTapReps: () => tapSet(log, 0),
                  onTapWeight: () => editCardio(log),
                )
              else
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
                          weight: weightNum(log.weights[i]),
                          onTapReps: () => tapSet(log, i),
                          onTapWeight: () => pickWeight(log, i),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );

  static String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Which sets a weight change in the sheet applies to.
enum WeightScope { set, open, all }

const _alert = MethodChannel('ferrolog/alert');

/// Plays the notification sound and/or vibrates (Android, see MainActivity.kt).
Future<void> restAlert() async {
  final sound = prefs.getBool('rest.sound') ?? true, vibrate = prefs.getBool('rest.vibrate') ?? true;
  if (!sound && !vibrate) return;
  try {
    await _alert.invokeMethod('restOver', {'sound': sound, 'vibrate': vibrate});
  } on MissingPluginException {
    if (vibrate) HapticFeedback.heavyImpact(); // other platforms: best effort
  }
}
