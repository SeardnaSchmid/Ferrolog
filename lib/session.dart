import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'model.dart';
import 'recap.dart';
import 'timing.dart';
import 'units.dart';

/// Live training: tap a set circle to log it (first tap = target reps, each
/// further tap one rep less, then back to empty). A rest timer runs after each set, in the live strip on top.
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

  /// Estimates from the trainings before this one; they don't change while training.
  final pace = currentPace();

  /// A timed set, hands-free: a tap starts a lead-in of [leadIn] seconds to pick up the weights, so
  /// [start] lies ahead until "go"; then it counts up and is logged by itself at the top of the range
  /// (the target without one), with a signal at go, at the bottom of a range and at the end. A tap
  /// while held logs the seconds so far, a tap during the lead-in cancels.
  ({ExerciseLog log, int set, DateTime start})? hold;
  bool holdGo = false, holdLow = false;

  static int get leadIn => prefs.getInt('timed.leadIn') ?? 10;

  /// Seconds held so far; negative during the lead-in.
  int heldOf(({ExerciseLog log, int set, DateTime start}) h) =>
      (DateTime.now().difference(h.start).inMilliseconds / 1000).floor();

  /// The seconds a timed set aims for at least, and at most (the top of the range).
  (int, int) holdRange(ExerciseLog log, int set) => (log.targets[set], max(log.targets[set], log.maxReps ?? 0));

  /// One key per exercise card, to scroll a card back into view.
  final cardKeys = <ExerciseLog, GlobalKey>{};
  int restTarget = 0;
  bool alerted = false;
  late final Timer ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    // Ended elsewhere (finished automatically after a long break, see Store.autoFinish): close.
    if (store.active != s) {
      ticker.cancel();
      if (mounted) Navigator.pop(context);
      return;
    }
    // Timed set: signal at go and at the bottom of a range; at the top it's done, with a signal too.
    if (hold case final h?) {
      final held = heldOf(h);
      final (low, top) = holdRange(h.log, h.set);
      if (!holdGo && held >= 0) {
        holdGo = true;
        restAlert();
      }
      if (top > low && !holdLow && held >= low) {
        holdLow = true;
        restAlert();
      }
      if (held >= top) {
        setState(endHold);
        store.saveActive(s);
        restAlert();
      }
    }
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
    // A timed set running when the app was closed carries on.
    for (final log in s.exercises) {
      if (log.timed && log.startedAt != null) {
        final i = log.reps.indexWhere((r) => r == null);
        hold = (log: log, set: i < 0 ? 0 : i, start: log.startedAt!);
        holdGo = heldOf(hold!) >= 0;
        holdLow = heldOf(hold!) >= holdRange(log, hold!.set).$1;
      }
    }
    if (prefs.getBool('session.keepScreenOn') ?? true) keepScreenOn(true);
  }

  @override
  void dispose() {
    ticker.cancel();
    keepScreenOn(false);
    super.dispose();
  }

  Exercise? planOf(ExerciseLog log) => store.workouts
      .where((w) => w.id == s.workoutId)
      .firstOrNull
      ?.exercises
      .where((e) => e.name == log.name)
      .firstOrNull;

  /// Keeps [log]'s card in view once the next frame is laid out: the rest line appearing in the live
  /// strip shrinks the list and would otherwise push a card near the end out of view.
  void reveal(ExerciseLog log) => WidgetsBinding.instance.addPostFrameCallback((_) {
        final card = cardKeys[log]?.currentContext;
        if (card == null || !card.mounted) return;
        Scrollable.ensureVisible(card,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      });

  /// Ends the hold: the seconds held (up to the top of the range) are the set's result, then the rest
  /// runs. During the lead-in nothing is logged.
  void endHold() {
    final h = hold!;
    hold = null;
    h.log.startedAt = null;
    final target = h.log.targets[h.set];
    final held = min(holdRange(h.log, h.set).$2, heldOf(h));
    h.log.reps[h.set] = held >= 1 ? held : null;
    h.log.doneAt[h.set] = held >= 1 ? DateTime.now() : null;
    if (held < 1) return;
    lastSetAt = DateTime.now();
    pausedAt = null;
    alerted = false;
    final plan = planOf(h.log);
    restTarget = (held < target ? plan?.failRestSeconds : null) ?? plan?.restSeconds ?? 120;
  }

  void tapSet(ExerciseLog log, int i) {
    reveal(log);
    if (log.timed) {
      // Timed set: start the lead-in, tap again to cancel it or to stop early; a done set goes back to empty.
      setState(() {
        touched = log;
        if (hold case final h? when h.log == log && h.set == i) {
          endHold();
        } else if (log.reps[i] != null) {
          log.reps[i] = log.doneAt[i] = null;
        } else {
          if (hold != null) endHold();
          final start = DateTime.now().add(Duration(seconds: leadIn));
          hold = (log: log, set: i, start: start);
          log.startedAt = start;
          holdGo = leadIn == 0;
          holdLow = false;
          lastSetAt = null; // the rest is over once the next hold starts
        }
      });
      store.saveActive(s);
      return;
    }
    if (log.cardio) {
      // Cardio stopwatch: start, stop (the minutes are logged, a distance goal counts as reached),
      // tap again to undo. No rest timer.
      setState(() {
        touched = log;
        if (log.reps[0] != null) {
          log.reps[0] = log.km = null;
          log.doneAt[0] = null;
        } else if (log.startedAt case final start?) {
          log.reps[0] = max(1, (DateTime.now().difference(start).inSeconds / 60).round());
          log.doneAt[0] = DateTime.now();
          log.km ??= log.targetKm;
          log.startedAt = null;
        } else {
          log.startedAt = DateTime.now();
        }
      });
      store.saveActive(s);
      return;
    }
    setState(() {
      touched = log;
      final r = log.reps[i], target = log.targets[i];
      // First tap: the goal (top of the range, if any), then one rep less per tap, then empty again.
      log.reps[i] = r == null ? log.maxReps ?? target : (r > 1 ? r - 1 : null);
      // Logged at the first tap; fewer reps later keep the time, undoing the set drops it.
      if (r == null) log.doneAt[i] = DateTime.now();
      if (log.reps[i] == null) log.doneAt[i] = null;
      if (log.reps[i] case final done?) {
        lastSetAt = DateTime.now();
        pausedAt = null;
        alerted = false;
        final plan = planOf(log);
        restTarget = (done < target ? plan?.failRestSeconds : null) ?? plan?.restSeconds ?? 120;
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
      ticker.cancel();
      await store.saveActive(null);
    } else {
      final missing = s.exercises.any((e) => e.setsDone < e.reps.length);
      if (missing && !await confirm(context, 'Nicht alle Sätze erledigt. Trotzdem beenden?')) return;
      // Stop the "ended elsewhere → close" check first, it would close the recap pushed below.
      ticker.cancel();
      await store.finishSession(s);
      homeTab.value = 0; // "Fertig" on the recap lands on the workouts
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RecapPage(s)));
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  /// Sheet to enter the actual minutes and distance of a cardio exercise.
  Future<void> editCardio(ExerciseLog log) async {
    setState(() => touched = log);
    final running = switch (log.startedAt) { final t? => (DateTime.now().difference(t).inSeconds / 60).round(), null => null };
    final minutes = TextEditingController(text: '${log.reps[0] ?? running ?? (log.targetReps > 0 ? log.targetReps : '')}');
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
      if (log.reps[0] != null) log.startedAt = null;
      log.doneAt[0] = log.reps[0] == null ? null : log.doneAt[0] ?? DateTime.now();
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
    final zone = left == null ? RestZone.rest : restZone(left, restTarget);
    final zoneBar = switch (zone) {
      RestZone.rest => c.primary,
      RestZone.soon => c.tertiary,
      RestZone.late => c.error,
    };
    final muted = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    final done = s.exercises.fold(0, (n, e) => n + e.setsDone);
    final total = s.exercises.fold(0, (n, e) => n + e.reps.length);
    // Highlight the exercise last touched; before that, the first one with open sets.
    final current = touched ?? s.exercises.where((e) => e.setsDone < e.reps.length).firstOrNull;
    final leftText = leftLabel(s, pace, DateTime.now());
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
              // Rest: a thin bar under the progress that shrinks to the left, and one line with the
              // time left (orange from 30 s before the end to 30 s over, then red) and its controls.
              if (left != null) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: restTarget == 0 ? 0 : (left / restTarget).clamp(0, 1),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  color: zoneBar,
                  backgroundColor: c.surface,
                ),
              ],
              if (hold case final h?) ..._holdLine(h, c),
              if (hold == null && (left != null || leftText != null))
                SizedBox(
                  height: 30,
                  child: Row(children: [
                    if (left != null) ...[
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '${pausedAt != null ? 'Pausiert' : 'Pause'} ${left > 0 ? clock(left) : '+${clock(-left)}'}',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: zoneBar),
                          ),
                          TextSpan(text: ' / ${clock(restTarget)}', style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
                        ]),
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      _stripButton(pausedAt == null ? Icons.pause : Icons.play_arrow,
                          pausedAt == null ? 'Anhalten' : 'Weiter', toggleRestPause),
                      _stripButton(Icons.restart_alt, 'Neu starten', restartRest),
                      _stripButton(Icons.close, 'Ausblenden', () => setState(() => lastSetAt = null)),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      // Beside the rest only what's left, the finishing time doesn't fit on a phone.
                      child: Text((left != null ? leftText?.split(' · ').first : leftText) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
                    ),
                  ]),
                ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                for (final log in s.exercises)
                  KeyedSubtree(
                    key: cardKeys.putIfAbsent(log, GlobalKey.new),
                    child: _exerciseCard(log, log == current, c, muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A timed set in the live strip: lead-in to go, then the seconds held against the range, with a
  /// bar filling up to its top and a button to stop (or cancel during the lead-in).
  List<Widget> _holdLine(({ExerciseLog log, int set, DateTime start}) h, ColorScheme c) {
    final held = heldOf(h);
    final (low, top) = holdRange(h.log, h.set);
    final color = held < 0 ? c.tertiary : c.primary;
    return [
      const SizedBox(height: 4),
      LinearProgressIndicator(
        value: held < 0 ? 1 + held / max(1, leadIn) : (held / top).clamp(0, 1),
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
        color: color,
        backgroundColor: c.surface,
      ),
      SizedBox(
        height: 30,
        child: Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: held < 0 ? 'Aufnehmen ${-held}' : '${h.log.name} ${clock(held)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
                TextSpan(
                  text: held < 0 ? ' · ${h.log.name}' : ' / ${top > low ? '$low–$top' : '$top'} s',
                  style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant),
                ),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          _stripButton(held < 0 ? Icons.close : Icons.stop, held < 0 ? 'Abbrechen' : 'Stopp', () {
            setState(endHold);
            store.saveActive(s);
          }),
        ]),
      ),
    ];
  }

  /// A small icon button for the live strip, so the rest line stays one line high.
  Widget _stripButton(IconData icon, String tooltip, VoidCallback onPressed) => IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 30),
        onPressed: onPressed,
      );

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
                              setsLabel(log.targets, log.maxReps, seconds: log.timed),
                              if (planOf(log) case final p?) 'Pause ${clock(p.restSeconds)}',
                              if (log.setsDone == log.reps.length ? measured(s, log) : null case final m?)
                                takenLabel(m.total)
                              else if (log.setsDone == 0)
                                aboutLabel(pace.of(shapeOfLog(log, planOf(log)))),
                            ].join(' · '),
                      style: muted,
                    ),
                    if (log.cardio ? null : rangeProgress(log) case final p?) Text(p, style: muted),
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
                _cardioTile(log, c)
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
                          target: log.targets[i],
                          targetMax: log.maxReps,
                          repsUnit: log.timed ? ' s' : '',
                          // Held: the seconds so far; in the lead-in the seconds to go, negative.
                          live: switch (hold) {
                            final h? when h.log == log && h.set == i => '${heldOf(h)}',
                            _ => null,
                          },
                          // No weight: reps only, the weight can still be added by tapping.
                          weight: log.weights[i] == 0 ? '–' : weightNum(log.weights[i]),
                          weightUnit: log.weights[i] == 0 ? '' : null,
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

  /// Cardio as one wide tile: a stopwatch on top (start / stop / undo), what was done below (tap to edit).
  Widget _cardioTile(ExerciseLog log, ColorScheme c) {
    final minutes = log.reps[0], start = log.startedAt;
    final (bg, fg) = minutes != null
        ? (log.succeeded ? (c.primary, c.onPrimary) : (c.tertiaryContainer, c.onTertiaryContainer))
        : start != null
            ? (c.primaryContainer, c.onPrimaryContainer)
            : (c.surfaceContainerHigh, c.onSurfaceVariant);
    final big = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: fg, fontFeatures: const [FontFeature.tabularFigures()]);
    final small = TextStyle(fontSize: 13, color: fg.withValues(alpha: .75));
    final goal = 'Ziel ${cardioLabel(log.targetReps, log.targetKm)}';
    final top = switch ((minutes, start)) {
      (final m?, _) => Text.rich(TextSpan(children: [
          TextSpan(text: '$m Min', style: big),
          TextSpan(text: '  ·  $goal', style: small),
        ])),
      (null, final t?) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(clock(DateTime.now().difference(t).inSeconds), style: big),
          const SizedBox(width: 10),
          Icon(Icons.stop_circle_outlined, color: fg),
          Text(' Stopp', style: small),
        ]),
      _ => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.play_arrow, color: fg),
          Text(' Start', style: big.copyWith(fontSize: 20)),
          Text('  ·  $goal', style: small),
        ]),
    };
    final km = log.km;
    final radius = BorderRadius.circular(14);
    return ClipRRect(
      borderRadius: radius,
      child: Column(children: [
        Material(
          color: bg,
          child: InkWell(onTap: () => tapSet(log, 0), child: SizedBox(height: 56, child: Center(child: top))),
        ),
        const SizedBox(height: 2),
        Material(
          color: c.surfaceContainer,
          child: InkWell(
            onTap: () => editCardio(log),
            child: SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  km == null ? 'Distanz eintragen' : '${distanceNum(km)} $distanceLabel',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: km == null ? c.onSurfaceVariant : c.onSurface),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  static String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// How far a rep range is from its increase: before the first set what it takes (3×8), then what the
/// done sets still miss of the top, until every set made it. Null without a range.
String? rangeProgress(ExerciseLog log) {
  final top = log.maxReps;
  if (top == null) return null;
  final unit = log.timed ? 's' : 'Wdh.';
  final goal = '${log.reps.length}×$top${log.timed ? ' s' : ''}';
  final missing = [for (final r in log.reps) if (r != null) max(0, top - r)].fold(0, (a, b) => a + b);
  if (log.setsDone == log.reps.length && missing == 0) return '$goal geschafft · nächstes Mal schwerer';
  if (log.setsDone == 0) return 'Steigerung bei $goal';
  return 'Steigerung bei $goal · ${missing == 0 ? 'bisher alle oben' : 'noch $missing $unit'}';
}

/// Rest timer colors: resting, about to go or just over, too long.
enum RestZone { rest, soon, late }

/// The zone with [left] seconds of rest left of [target]: orange from 30 s before the end (half the
/// rest when it's shorter than a minute) to 30 s over, red after that.
RestZone restZone(int left, int target) => left <= -30
    ? RestZone.late
    : left <= min(30, target ~/ 2)
        ? RestZone.soon
        : RestZone.rest;

/// Which sets a weight change in the sheet applies to.
enum WeightScope { set, open, all }

const _alert = MethodChannel('ferrolog/alert');

/// Keeps the display on while [on] (Android, see MainActivity.kt); elsewhere nothing.
Future<void> keepScreenOn(bool on) async {
  try {
    await _alert.invokeMethod('keepScreenOn', {'on': on});
  } on MissingPluginException {
    // web, tests
  }
}

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
