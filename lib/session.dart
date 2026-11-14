import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'language.dart';
import 'main.dart';
import 'model.dart';
import 'recap.dart';
import 'timing.dart';
import 'edit.dart';
import 'loading.dart';
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

  // The rest lives in the session, so it survives leaving the page and the app being killed.
  DateTime? get lastSetAt => s.restStartedAt;
  set lastSetAt(DateTime? t) => s.restStartedAt = t;
  DateTime? get pausedAt => s.restPausedAt;
  set pausedAt(DateTime? t) => s.restPausedAt = t;
  int get restTarget => s.restSeconds ?? 0;
  set restTarget(int seconds) => s.restSeconds = seconds;
  ExerciseLog? touched; // highlighted: the exercise last logged or edited

  /// The exercise whose last set was just logged, while its card asks how many reps were left; see
  /// [askRir]. Only on this page: an answer or the next set tapped and the question is gone.
  ExerciseLog? rirAsk;

  /// Whether the reserve is asked after an exercise's last set: a setting, off unless switched on, and
  /// always for an exercise in auto mode, which steers by it. Strength sets only: no cardio, no holds, no
  /// assistance (the reps aren't the limit there).
  bool askRir(ExerciseLog log) =>
      ((prefs.getBool('session.askRir') ?? false) || autoRir(s, log)) &&
      !log.cardio &&
      !log.timed &&
      log.weights.every((w) => w >= 0) &&
      log.setsDone == log.reps.length;

  void answerRir(ExerciseLog log, int rir) {
    setState(() {
      log.rir = rir;
      rirAsk = null;
    });
    store.saveActive(s);
  }

  /// Warm-up lines opened, and the warm-up sets ticked off: only on this page, they're never logged.
  final warmupOpen = <ExerciseLog>{};
  final warmupDone = <ExerciseLog, Set<int>>{};

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
  int get restLeft => s.restLeft(DateTime.now())!;

  void restartRest() {
    setState(() {
      lastSetAt = DateTime.now();
      if (pausedAt != null) pausedAt = lastSetAt;
      alerted = false;
    });
    store.saveActive(s);
  }

  void toggleRestPause() {
    setState(() {
      final now = DateTime.now();
      if (pausedAt == null) {
        pausedAt = now;
      } else {
        lastSetAt = lastSetAt!.add(now.difference(pausedAt!));
        pausedAt = null;
      }
    });
    store.saveActive(s);
  }

  @override
  void initState() {
    super.initState();
    ticker; // start
    // Reopened after the rest ran out: it already signalled (or the app was away), not again.
    alerted = lastSetAt != null && restLeft <= 0;
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
    if (prefs.getBool('session.showWhenLocked') ?? true) showWhenLocked(true);
  }

  @override
  void dispose() {
    ticker.cancel();
    keepScreenOn(false);
    showWhenLocked(false);
    super.dispose();
  }

  Exercise? planOf(ExerciseLog log) =>
      planEntryOf(store.workouts.where((w) => w.id == s.workoutId).firstOrNull, s.exercises, log);

  /// Rest after a set of [log]: the plan's, else what came with a swapped-in or added exercise.
  int restAfter(ExerciseLog log, {required bool missed}) {
    final plan = planOf(log);
    final rest = plan?.restSeconds ?? log.restSeconds ?? 120;
    final fail = plan != null ? plan.failRestSeconds : log.failRestSeconds;
    return missed ? fail ?? rest : rest;
  }

  /// Puts [next] where [old] was. Logs are replaced, never resized in place, and the page keys its
  /// state by log, so the highlight, a running hold and the card's scroll key move along.
  void replaceLog(ExerciseLog old, List<ExerciseLog> next) {
    final i = s.exercises.indexOf(old);
    s.exercises.replaceRange(i, i + 1, next);
    final same = next.where((l) => l.name == old.name).firstOrNull;
    if (touched == old) touched = same ?? next.firstOrNull;
    if (cardKeys.remove(old) case final key? when same != null) cardKeys[same] = key;
    if (hold case final h? when h.log == old) hold = same == null ? null : (log: same, set: h.set, start: h.start);
  }

  /// An exercise picked in the editor, or null when cancelled or already in the training.
  Future<Exercise?> pickExercise() async {
    final e = await Navigator.push<Exercise>(
        context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ExerciseEditor(null)));
    if (e == null || !mounted) return null;
    if (s.exercises.any((l) => l.name == e.name)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr.alreadyInTraining)));
      return null;
    }
    return e;
  }

  /// The exercise as it stands in this training, for the editor: the plan's settings, this training's sets.
  Exercise exerciseOf(ExerciseLog log) {
    final plan = planOf(log)?.copy() ??
        Exercise(name: log.name, increment: log.increment ?? 2.5, restSeconds: log.restSeconds ?? 120);
    return plan
      ..failRestSeconds = plan.failRestSeconds ?? log.failRestSeconds
      ..cardio = log.cardio
      ..timed = log.timed
      ..km = log.cardio ? log.targetKm : null
      ..sets = log.reps.length
      ..reps = log.targetReps
      ..setReps = log.targets.toSet().length == 1 ? null : List.of(log.targets)
      ..maxReps = log.maxReps
      ..weight = log.weight
      ..setWeights = log.weights.toSet().length == 1 ? null : List.of(log.weights);
  }

  /// "Bearbeiten": the exercise in the editor as it stands in the training. Another name swaps it (machine
  /// taken: logged sets stay, the new exercise follows for the rest); the same name reshapes its sets,
  /// reps and weights. Only this training, never the plan.
  Future<void> editExercise(ExerciseLog log) async {
    final e = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExerciseEditor(exerciseOf(log),
            forTraining: true, taken: {for (final l in s.exercises) if (l != log) l.name}),
      ),
    );
    if (e == null || !mounted) return;
    if (e.name != log.name) return swapExercise(log, e);
    if (e.cardio != log.cardio || e.timed != log.timed) {
      if (log.setsDone > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr.kindStays)));
        return;
      }
      final next = ExerciseLog.fromPlan(e, replaces: log.replaces, added: log.added);
      setState(() {
        replaceLog(log, [next]);
        touched = next;
      });
    } else {
      final next = log.reshaped(e);
      setState(() {
        replaceLog(log, [next]);
        touched = next;
      });
    }
    store.saveActive(s);
  }

  /// Machine taken: [e] in the place of [log]. With sets already logged those stay, and the new
  /// exercise follows for the sets that are left (the last of [e]'s).
  void swapExercise(ExerciseLog log, Exercise e) {
    if (log.setsDone > 0) {
      final left = max(1, e.sets - log.setsDone);
      e = e.copy()
        ..sets = left
        ..setWeights = e.setWeights?.sublist(e.sets - left)
        ..setReps = e.setReps?.sublist(e.sets - left);
    }
    final next = ExerciseLog.fromPlan(e, replaces: log.added ? null : log.replaces ?? log.name, added: log.added);
    setState(() {
      touched = next;
      if (log.setsDone == 0) {
        replaceLog(log, [next]);
      } else {
        final done = [for (final (i, r) in log.reps.indexed) if (r != null) i];
        replaceLog(log, [
          log.withSets(
            reps: [for (final i in done) log.reps[i]],
            targets: [for (final i in done) log.targets[i]],
            weights: [for (final i in done) log.weights[i]],
            doneAt: [for (final i in done) log.doneAt[i]],
          ),
          next,
        ]);
      }
    });
    store.saveActive(s);
  }

  Future<void> addExercise() async {
    final e = await pickExercise();
    if (e == null) return;
    final next = ExerciseLog.fromPlan(e, added: true);
    setState(() {
      s.exercises.add(next);
      touched = next;
    });
    store.saveActive(s);
    reveal(next);
  }

  void moveExercise(ExerciseLog log, int by) {
    setState(() {
      final i = s.exercises.indexOf(log);
      s.exercises
        ..removeAt(i)
        ..insert(i + by, log);
    });
    store.saveActive(s);
  }

  void removeExercise(ExerciseLog log) {
    setState(() => replaceLog(log, []));
    store.saveActive(s);
  }

  /// The card's menu: change the training, never the plan. Small, so it sits at the card's edge.
  Widget _exerciseMenu(ExerciseLog log) {
    final i = s.exercises.indexOf(log);
    final running = hold?.log == log || log.startedAt != null; // a hold or stopwatch on it
    PopupMenuItem<VoidCallback> item(String label, IconData icon, VoidCallback action) => PopupMenuItem(
          value: action,
          child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(label)),
        );
    return PopupMenuButton<VoidCallback>(
      tooltip: tr.editExercise,
      enabled: !running,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
          minimumSize: const Size(32, 32), fixedSize: const Size(32, 32), padding: EdgeInsets.zero),
      icon: const Icon(Icons.more_vert, size: 22),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        item(tr.edit, Icons.edit_outlined, () => editExercise(log)),
        if (i > 0) item(tr.moveUp, Icons.arrow_upward, () => moveExercise(log, -1)),
        if (i < s.exercises.length - 1) item(tr.moveDown, Icons.arrow_downward, () => moveExercise(log, 1)),
        if (log.added && log.setsDone == 0) ...[
          const PopupMenuDivider(),
          item(tr.remove, Icons.delete_outline, () => removeExercise(log)),
        ],
      ],
    );
  }

  /// Keeps [log]'s card in view once the next frame is laid out, so a set logged near the bottom
  /// edge doesn't stay half hidden.
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
    restTarget = restAfter(h.log, missed: held < target);
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
          lastSetAt = pausedAt = null; // the rest is over once the next hold starts
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
      rirAsk = null; // the next set is on, the question is over
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
        restTarget = restAfter(log, missed: done < target);
        if (r == null && askRir(log)) {
          rirAsk = log;
        }
      }
      if (log.setsDone < log.reps.length) log.rir = null; // the last set undone takes the answer along
    });
    store.saveActive(s);
  }

  /// Sets the weight of set [i], and depending on [scope] of other sets of the exercise too.
  void applyWeight(ExerciseLog log, int i, double w, WeightScope scope) {
    setState(() => applyWeightScope(log, i, w, scope));
    store.saveActive(s);
  }

  Future<void> finish() async {
    if (s.exercises.every((e) => e.setsDone == 0)) {
      if (!await confirm(context, tr.noSetsDiscard)) return;
      ticker.cancel();
      await store.saveActive(null);
    } else {
      final missing = s.exercises.any((e) => e.setsDone < e.reps.length);
      if (missing && !await confirm(context, tr.notAllSetsFinish)) return;
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
    final result = await showCardioSheet(context, log, running: running);
    if (result == null) return;
    setState(() {
      applyCardio(log, result);
      if (log.reps[0] != null) log.startedAt = null;
      log.doneAt[0] = log.reps[0] == null ? null : log.doneAt[0] ?? DateTime.now();
    });
    store.saveActive(s);
  }

  /// Sheet to edit a set's weight, see [showWeightSheet].
  Future<void> pickWeight(ExerciseLog log, int i) async {
    setState(() => touched = log);
    final result = await showWeightSheet(context, log, i, increment: planOf(log)?.increment ?? log.increment ?? 0);
    if (result case (final w, final scope)) applyWeight(log, i, w, scope);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final status = stripStatus(c);
    final muted = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    final done = s.exercises.fold(0, (n, e) => n + e.setsDone);
    final total = s.exercises.fold(0, (n, e) => n + e.reps.length);
    // Highlight the exercise last touched; before that, the first one with open sets.
    final current = touched ?? s.exercises.where((e) => e.setsDone < e.reps.length).firstOrNull;
    final now = DateTime.now();
    final left = sessionLeft(s, pace, now);
    // What's left of the training and when it'll be done, null when nothing is left.
    final (leftText, endText) = left <= Duration.zero
        ? (null, null)
        : (tr.leftAbout(aboutLabel(left)), tr.doneAround(timeOfDay(now.add(left))));
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 104,
        leading: TextButton(
          style: TextButton.styleFrom(foregroundColor: c.error),
          onPressed: () async {
            if (!await confirm(context, tr.discardTrainingAsk)) return;
            await store.saveActive(null);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(tr.discard),
        ),
        centerTitle: true,
        title: Text(s.workoutName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: finish, child: Text(tr.finish)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live strip, same look as the running-training card on the overview. Always the same height,
          // so the list below never jumps: status, the session's progress as a thin line, one big line
          // for the rest (or a timed set, or what's left of the training) and the rest bar under it.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Container(
              height: 104,
              color: Color.alphaBlend(c.primaryContainer.withValues(alpha: .45), c.surface),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Column(children: [
                SizedBox(
                  height: 18,
                  child: Row(children: [
                    const LiveDot(),
                    const SizedBox(width: 8),
                    Text(tr.running,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.primary)),
                    Text(' · ', style: TextStyle(color: c.onSurfaceVariant)),
                    Elapsed(s.date, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                    const Spacer(),
                    // While the line below is taken, what's left of the training moves up here.
                    Text(
                      [
                        tr.setsDone(done, total),
                        if (status != null && left > Duration.zero) aboutLabel(left),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                  color: c.onSurface.withValues(alpha: .55),
                  backgroundColor: c.surfaceContainerHighest,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 44,
                  child: status == null
                      ? Row(children: [
                          Text(leftText ?? '',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.onSurface)),
                          const Spacer(),
                          if (endText case final end?)
                            Text(end, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                        ])
                      : Row(children: [
                          Text(status.time,
                              style: TextStyle(
                                  fontSize: 36,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.36,
                                  color: status.color,
                                  fontFeatures: const [FontFeature.tabularFigures()])),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(status.icon, size: 14, color: status.color),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(status.word,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .66, color: status.color)),
                                  ),
                                ]),
                                const SizedBox(height: 3),
                                Text(status.detail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          for (final (i, button) in status.buttons.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            button,
                          ],
                        ]),
                ),
                const SizedBox(height: 6),
                status?.bar ?? RestBar(color: c.onSurface, empty: true),
              ]),
            ),
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
                const SizedBox(height: 4),
                DashedAddButton(tr.exercise, addExercise),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What the big line of the live strip shows: a timed set (lead-in, then held) before a running
  /// rest; null when neither runs. The rest's zones: blue while resting, orange from 30 s before the end
  /// ("go" once it's over) to 30 s over, then red with a striped bar; paused in grey with a dashed bar.
  ({String time, Color color, IconData icon, String word, String detail, List<Widget> buttons, Widget bar})? stripStatus(
      ColorScheme c) {
    if (hold case final h?) {
      final held = heldOf(h);
      final (low, top) = holdRange(h.log, h.set);
      void stop() {
        setState(endHold);
        store.saveActive(s);
      }

      return held < 0
          ? (
              time: '${-held}',
              color: c.tertiary,
              icon: Icons.back_hand_outlined,
              word: tr.stripPickUp,
              detail: h.log.name,
              buttons: [_roundButton(Icons.close, tr.cancel, stop)],
              bar: RestBar(color: c.tertiary, fraction: -held / max(1, leadIn)),
            )
          : (
              time: clock(held),
              color: c.primary,
              icon: Icons.timer_outlined,
              word: tr.stripHold,
              detail: tr.holdGoal(top > low ? '$low–$top' : '$top'),
              buttons: [_roundButton(Icons.stop, tr.stop, stop, filled: true)],
              bar: RestBar(color: c.primary, fraction: held / top, marker: top > low ? low / top : null),
            );
    }
    if (lastSetAt == null) return null;
    final left = restLeft;
    final fraction = restTarget == 0 ? 0.0 : (left / restTarget).clamp(0.0, 1.0);
    final time = left > 0 ? clock(left) : '+${clock(-left)}';
    final buttons = [
      pausedAt == null
          ? _roundButton(Icons.pause, tr.pause, toggleRestPause)
          : _roundButton(Icons.play_arrow, tr.resumeRest, toggleRestPause, filled: true),
      _roundButton(Icons.restart_alt, tr.restart, restartRest),
    ];
    final of = tr.restOf(clock(restTarget)), goal = tr.restGoal(clock(restTarget));
    if (pausedAt != null) {
      return (
        time: time,
        color: c.onSurfaceVariant,
        icon: Icons.pause,
        word: tr.stripPaused,
        detail: left > 0 ? of : goal,
        buttons: buttons,
        bar: RestBar(color: c.primary, fraction: fraction, dashed: true),
      );
    }
    return switch (restZone(left, restTarget)) {
      RestZone.rest => (
          time: time,
          color: c.primary,
          icon: Icons.timer_outlined,
          word: tr.stripRest,
          detail: of,
          buttons: buttons,
          bar: RestBar(color: c.primary, fraction: fraction),
        ),
      RestZone.soon when left > 0 => (
          time: time,
          color: c.tertiary,
          icon: Icons.arrow_forward,
          word: tr.stripSoon,
          detail: of,
          buttons: buttons,
          bar: RestBar(color: c.tertiary, fraction: fraction),
        ),
      RestZone.soon => (
          time: time,
          color: c.tertiary,
          icon: Icons.notifications_none,
          word: tr.stripGo,
          detail: goal,
          buttons: buttons,
          bar: RestBar(color: c.tertiary.withValues(alpha: .35)),
        ),
      RestZone.late => (
          time: time,
          color: c.error,
          icon: Icons.warning_amber_rounded,
          word: tr.stripLate,
          detail: goal,
          buttons: buttons,
          bar: RestBar(color: c.error, striped: true),
        ),
    };
  }

  /// On the card of the exercise whose last set was just logged, under its sets: one tap answers, the
  /// next set tapped (or ignoring it) answers nothing.
  Widget _rirQuestion(ExerciseLog log, ColorScheme c) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Text(tr.rirQuestion, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
          const SizedBox(width: 10),
          for (final n in const [0, 1, 2, 3, 4]) ...[
            if (n > 0) const SizedBox(width: 6),
            Expanded(
              child: Material(
                color: c.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => answerRir(log, n),
                  child: SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(n == 4 ? '4+' : '$n',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      );

  /// A round 44 dp button for the live strip: tonal, or filled for the action that matters now.
  Widget _roundButton(IconData icon, String tooltip, VoidCallback onPressed, {bool filled = false}) {
    final style = IconButton.styleFrom(
        fixedSize: const Size(44, 44), minimumSize: const Size(44, 44), padding: EdgeInsets.zero);
    final child = Icon(icon, size: 22);
    return filled
        ? IconButton.filled(style: style, tooltip: tooltip, onPressed: onPressed, icon: child)
        : IconButton.filledTonal(style: style, tooltip: tooltip, onPressed: onPressed, icon: child);
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
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(log.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(
                      log.cardio
                          ? tr.cardioGoal(cardioLabel(log.targetReps, log.targetKm))
                          : [
                              setsLabel(log.targets, log.maxReps, seconds: log.timed),
                              if (planOf(log)?.restSeconds ?? log.restSeconds case final rest?) tr.restLine(clock(rest)),
                              if (log.setsDone == log.reps.length ? measured(s, log) : null case final m?)
                                takenLabel(m.total)
                              else if (log.setsDone == 0)
                                aboutLabel(pace.of(shapeOfLog(log, planOf(log)))),
                            ].join(' · '),
                      style: muted,
                    ),
                    if (log.cardio ? null : rangeProgress(log) case final p?) Text(p, style: muted),
                    if (log.replaces case final r?) Text(tr.insteadOf(r), style: muted),
                    if (log.rir case final r?) Text(rirLabel(r), style: muted),
                  ]),
                ),
                // On the title's line: the state, then the menu at the edge.
                SizedBox(
                  height: 26,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (log.setsDone == log.reps.length)
                      Icon(Icons.check_circle, size: 22, color: log.succeeded ? c.primary : c.tertiary)
                    else if (current)
                      Text(tr.now,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.primary)),
                    const SizedBox(width: 2),
                    Transform.translate(offset: const Offset(6, 0), child: _exerciseMenu(log)),
                  ]),
                ),
              ]),
              ?_warmup(log, c, muted),
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
              if (rirAsk == log) _rirQuestion(log, c),
            ],
          ),
        ),
      );

  /// If switched on in the settings, before the first set of a barbell lift: the warm-up ramp to its first
  /// set, one line that opens into sets to tick off, each with the plates per side. Not logged, no volume,
  /// no rest.
  Widget? _warmup(ExerciseLog log, ColorScheme c, TextStyle muted) {
    if (!showWarmup || log.cardio || log.timed || log.setsDone > 0 || !isBarbell(log.name) || log.weights.isEmpty) {
      return null;
    }
    final sets = warmupFor(log.weights.first);
    if (sets.isEmpty) return null;
    final open = warmupOpen.contains(log);
    final done = warmupDone[log] ?? const {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => open ? warmupOpen.remove(log) : warmupOpen.add(log)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.local_fire_department_outlined, size: 16, color: c.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr.warmup([for (final (w, r) in sets) '${plateNum(w)}×$r'].join(' · ')) +
                    (done.isEmpty ? '' : '  ✓ ${done.length}/${sets.length}'),
                style: muted.copyWith(fontSize: 13),
              ),
            ),
            Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: c.onSurfaceVariant),
          ]),
        ),
      ),
      if (open)
        for (final (i, (w, r)) in sets.indexed)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            visualDensity: VisualDensity.compact,
            value: done.contains(i),
            title: Text('${plateNum(w)} $unitLabel × $r'),
            subtitle: Text(perSideLabel(toKg(w))),
            onChanged: (v) => setState(() {
              final ticks = warmupDone.putIfAbsent(log, () => {});
              v == true ? ticks.add(i) : ticks.remove(i);
            }),
          ),
    ]);
  }

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
    final goal = tr.restGoal(cardioLabel(log.targetReps, log.targetKm));
    final top = switch ((minutes, start)) {
      (final m?, _) => Text.rich(TextSpan(children: [
          TextSpan(text: tr.minutes(m), style: big),
          TextSpan(text: '  ·  $goal', style: small),
        ])),
      (null, final t?) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(clock(DateTime.now().difference(t).inSeconds), style: big),
          const SizedBox(width: 10),
          Icon(Icons.stop_circle_outlined, color: fg),
          Text(' ${tr.stop}', style: small),
        ]),
      _ => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.play_arrow, color: fg),
          Text(' ${tr.start}', style: big.copyWith(fontSize: 20)),
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
                  km == null ? tr.enterDistance : '${distanceNum(km)} $distanceLabel',
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

/// The rest bar under the big line of the live strip, 6 dp: filled from the left to [fraction] (all
/// of it when null), dashed while paused, striped when the rest ran far over, with an optional [marker]
/// (the bottom of a timed range). [empty]: just the track, faded.
class RestBar extends StatelessWidget {
  final Color color;
  final double? fraction, marker;
  final bool dashed, striped, empty;
  const RestBar(
      {required this.color, this.fraction, this.marker, this.dashed = false, this.striped = false, this.empty = false, super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Opacity(
      opacity: empty ? .5 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          width: double.infinity,
          child: CustomPaint(painter: _RestBarPainter(this, c.surfaceContainerHighest, c.onSurface)),
        ),
      ),
    );
  }
}

class _RestBarPainter extends CustomPainter {
  final RestBar bar;
  final Color track, markerColor;
  _RestBarPainter(this.bar, this.track, this.markerColor);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    if (bar.empty) return;
    final fill = Paint()..color = bar.color;
    final w = size.width * (bar.fraction ?? 1).clamp(0.0, 1.0);
    if (bar.striped) {
      // Diagonal stripes, 6 on and 5 off, leaning right.
      for (var x = -size.height; x < size.width; x += 11) {
        canvas.drawPath(
            Path()
              ..moveTo(x, size.height)
              ..lineTo(x + 6, size.height)
              ..lineTo(x + 6 + size.height, 0)
              ..lineTo(x + size.height, 0)
              ..close(),
            fill);
      }
    } else if (bar.dashed) {
      fill.color = bar.color.withValues(alpha: .7);
      for (var x = 0.0; x < w; x += 12) {
        canvas.drawRect(Rect.fromLTWH(x, 0, min(8, w - x), size.height), fill);
      }
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), const Radius.circular(3)), fill);
    }
    if (bar.marker case final m?) {
      canvas.drawRect(Rect.fromLTWH(size.width * m - 1, 0, 2, size.height), Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(_RestBarPainter old) =>
      old.bar.fraction != bar.fraction ||
      old.bar.color != bar.color ||
      old.bar.dashed != bar.dashed ||
      old.bar.striped != bar.striped ||
      old.bar.marker != bar.marker ||
      old.track != track;
}

/// How far a rep range is from its increase: before the first set what it takes (3×8), then what the
/// done sets still miss of the top, until every set made it. Null without a range.
String? rangeProgress(ExerciseLog log) {
  final top = log.maxReps;
  if (top == null) return null;
  final goal = '${log.reps.length}×$top${log.timed ? ' s' : ''}';
  final missing = [for (final r in log.reps) if (r != null) max(0, top - r)].fold(0, (a, b) => a + b);
  if (log.setsDone == log.reps.length && missing == 0) return tr.rangeDone(goal);
  if (log.setsDone == 0) return tr.rangeIncreaseAt(goal);
  if (missing == 0) return tr.rangeAllTop(goal);
  return (log.timed ? tr.rangeMissingSeconds : tr.rangeMissingReps)(goal, missing);
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
/// Whether [log] trains an exercise in auto mode in [s]'s plan: the reserve is then always asked.
bool autoRir(Session s, ExerciseLog log) =>
    planEntryOf(store.workouts.where((w) => w.id == s.workoutId).firstOrNull, s.exercises, log)?.auto ?? false;

enum WeightScope { set, open, all }

/// Sheet to edit the weight of set [i]: type it or step it by [increment], choose which sets it applies
/// to ([scope] preselected), then save. Null when closed without saving.
Future<(double, WeightScope)?> showWeightSheet(BuildContext context, ExerciseLog log, int i,
    {required double increment, WeightScope scope = WeightScope.open}) async {
  // The sheet works in the shown unit (kg or lb) and converts to kg on save.
  final step = stepShown(increment);
  final field = TextEditingController(text: weightNum(log.weights[i]));
  double? parse() => switch (parseWeight(field.text)) {
        final kg? when kg >= minWeight && kg <= 1000 => kg,
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
          final next = (shown(w ?? log.weights[i]) + dir * step).clamp(shown(minWeight), shown(1000)).toDouble();
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
                Text(tr.setOf(i + 1, log.reps.length), style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                stepButton(Icons.remove, -1),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: field,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                    decoration: InputDecoration(
                      suffixText: unitLabel,
                      errorText: w == null ? tr.weightBetween(weightLabel(minWeight), weightLabel(1000)) : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onChanged: (_) => setSheet(() {}),
                    onTap: () => field.selection = TextSelection(baseOffset: 0, extentOffset: field.text.length),
                  ),
                ),
                const SizedBox(width: 12),
                stepButton(Icons.add, 1),
              ]),
              if (w != null && w > 0 && !log.timed && isBarbell(log.name)) ...[
                const SizedBox(height: 8),
                Text(perSideLabel(w), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              Text(tr.applyTo, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
              const SizedBox(height: 8),
              SegmentedButton<WeightScope>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: WeightScope.set, label: Text(tr.thisSet)),
                  ButtonSegment(value: WeightScope.open, label: Text(tr.openSets)),
                  ButtonSegment(value: WeightScope.all, label: Text(tr.allSets)),
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
                    child: Text(tr.close),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: w == null ? null : () => Navigator.pop(context, (w, scope)),
                    child: Text(tr.save),
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
  return result;
}

/// Sets the weight of set [i], and depending on [scope] of other sets of the exercise too.
void applyWeightScope(ExerciseLog log, int i, double w, WeightScope scope) {
  for (var j = 0; j < log.weights.length; j++) {
    final hit = switch (scope) {
      WeightScope.set => j == i,
      WeightScope.open => j == i || log.reps[j] == null,
      WeightScope.all => true,
    };
    if (hit) log.weights[j] = w;
  }
}

/// Sheet to enter the minutes and distance of a cardio exercise; null when closed without saving.
/// [running]: minutes on the stopwatch, the suggestion when nothing is entered yet.
Future<({int? minutes, double? km})?> showCardioSheet(BuildContext context, ExerciseLog log, {int? running}) async {
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
              decoration: InputDecoration(labelText: tr.durationGoal, suffixText: tr.minutesUnit, border: const OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: distance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: tr.distanceOptional, suffixText: distanceLabel, border: const OutlineInputBorder()),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(context),
              child: Text(tr.close),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr.save),
            ),
          ),
        ]),
      ]),
    ),
  );
  if (saved != true) return null;
  final m = int.tryParse(minutes.text.trim());
  return (minutes: m != null && m > 0 ? m : null, km: parseDistance(distance.text));
}

/// What the cardio sheet returned, into the log; no minutes means not done, and then no distance either.
void applyCardio(ExerciseLog log, ({int? minutes, double? km}) result) {
  log.reps[0] = result.minutes;
  log.km = result.minutes == null ? null : result.km;
}

const _alert = MethodChannel('ferrolog/alert');

/// Keeps the display on while [on] (Android, see MainActivity.kt); elsewhere nothing.
Future<void> keepScreenOn(bool on) async {
  try {
    await _alert.invokeMethod('keepScreenOn', {'on': on});
  } on MissingPluginException {
    // web, tests
  }
}

/// Shows the app over the lock screen while [on] (Android, see MainActivity.kt), so a glance
/// at the rest timer doesn't need an unlock. Leaving the page clears it again.
Future<void> showWhenLocked(bool on) async {
  try {
    await _alert.invokeMethod('showWhenLocked', {'on': on});
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
