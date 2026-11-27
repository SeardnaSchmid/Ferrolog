import 'dart:math';

import 'language.dart';
import 'main.dart' show dateLabel;
import 'model.dart';
import 'pulse_chart.dart' show pulseGap;
import 'rest_learning.dart' show Preload, preloadOf;
import 'timing.dart';
import 'units.dart';

/// Heart rate per exercise of a training (docs/pulsvergleiche.md): the highest pulse measured while its
/// sets ran, never on the way to the next station, never shared with another exercise.

/// Seconds after a set's tap that still count to it, so a delayed peak is caught.
const pulseTail = 30;

/// Development value for calm texts, no sporting target: closer to the median counts as similar.
const pulseSimilarBpm = 5;

/// How many earlier trainings a comparison needs, and uses at most.
const pulseMinRefs = 3, pulseMaxRefs = 5;

/// [peak] the highest bpm of the [covered] of [sets] sets with a usable window; null if none.
typedef ExercisePulse = ({int? peak, int covered, int sets});

extension ExercisePulseX on ExercisePulse {
  bool get complete => sets > 0 && covered == sets;
}

/// The pulse of each strength exercise in [s]. Empty without a curve.
///
/// Each logged set gets a window from its estimated start (tap minus the set's work) to [pulseTail]
/// seconds after the tap, the tail cut at the start of the next set of any exercise. A sample in windows
/// of two exercises is dropped. A window counts with at least two samples, no gap over [pulseGap] and
/// samples near both its start and its tap. Without timestamps nothing is assigned: never by plan order.
Map<ExerciseLog, ExercisePulse> exercisePulses(Session s) =>
    {for (final MapEntry(key: log, value: sets) in setPulses(s).entries) log: _summed(log, sets)};

ExercisePulse _summed(ExerciseLog log, List<int?> sets) => (
      peak: sets.nonNulls.fold<int?>(null, (m, b) => max(m ?? 0, b)),
      covered: sets.nonNulls.length,
      sets: log.setsDone,
    );

/// The peak of each set of each strength exercise in [s], null where its window is not usable (see
/// [exercisePulses]). Empty without a curve.
Map<ExerciseLog, List<int?>> setPulses(Session s) {
  if (s.pulse.isEmpty) return {};
  double sec(DateTime t) => t.difference(s.date).inMilliseconds / 1000;
  final windows = <({ExerciseLog log, int set, double start, double done})>[];
  for (final log in s.exercises) {
    if (log.cardio) {
      if ((log.startedAt, log.doneAt.firstOrNull) case (final a?, final b?)) {
        windows.add((log: log, set: -1, start: sec(a), done: sec(b)));
      }
      continue;
    }
    for (var i = 0; i < log.reps.length; i++) {
      final (t, reps) = (log.doneAt[i], log.reps[i]);
      if (t == null || reps == null) continue;
      windows.add((log: log, set: i, start: sec(t) - setWorkSeconds(log, reps), done: sec(t)));
    }
  }
  windows.sort((a, b) => a.done.compareTo(b.done));
  final spans = [
    for (final (i, w) in windows.indexed)
      (
        log: w.log,
        set: w.set,
        start: w.start,
        done: w.done,
        end: i + 1 < windows.length ? max(w.done, min(w.done + pulseTail, windows[i + 1].start)) : w.done + pulseTail,
      ),
  ];
  // Samples per window, dropped where windows of two exercises overlap.
  final inWindow = [for (final _ in spans) <(int, int)>[]];
  for (final p in s.pulse) {
    final t = p.$1.toDouble();
    final hits = [for (final (i, w) in spans.indexed) if (t >= w.start && t <= w.end) i];
    if (hits.map((i) => spans[i].log).toSet().length != 1) continue;
    for (final i in hits) {
      inWindow[i].add(p);
    }
  }
  final out = {for (final log in s.exercises) if (!log.cardio) log: List<int?>.filled(log.reps.length, null)};
  for (final (i, w) in spans.indexed) {
    if (w.set < 0) continue;
    final ps = inWindow[i];
    final usable = ps.length >= 2 &&
        ps.first.$1 - w.start <= pulseGap &&
        w.done - ps.last.$1 <= pulseGap &&
        [for (var j = 1; j < ps.length; j++) ps[j].$1 - ps[j - 1].$1].every((g) => g <= pulseGap);
    if (usable) out[w.log]![w.set] = ps.map((p) => p.$2).reduce(max);
  }
  return out;
}

/// What the recap shows of an exercise's pulse: the peak per set and how it compares (see
/// [setPulseDirs]), the exercise's [peak] and the [note] when it is about this training.
typedef RecapPulse = ({List<int?> sets, List<int> dirs, int? peak, PulseNote? note});

/// [RecapPulse] per strength exercise of [s] with at least one measured set, by name, against the
/// trainings before it in [sessions].
Map<String, RecapPulse> recapPulses(Session s, Iterable<Session> sessions) {
  final mine = setPulses(s);
  final older = [for (final x in sessions) if (x.id != s.id && !x.date.isAfter(s.date)) x]
    ..sort((a, b) => a.date.compareTo(b.date));
  final cache = <Session, Map<ExerciseLog, List<int?>>>{};
  final out = <String, RecapPulse>{};
  for (final MapEntry(key: log, value: sets) in mine.entries) {
    if (sets.every((b) => b == null)) continue;
    final entries = <PulseEntry>[];
    final perSet = <List<int?>>[];
    for (final x in [...older, s]) {
      for (final l in x.exercises) {
        if (l.name != log.name || l.setsDone == 0 || (x == s && !identical(l, log))) continue;
        final sp = x == s ? sets : x.pulse.isEmpty ? null : (cache[x] ??= setPulses(x))[l];
        entries.add((date: x.date, log: l, pulse: sp == null ? null : _summed(l, sp), preload: preloadOf(x, l).stage));
        perSet.add(sp ?? const []);
      }
    }
    final note = pulseNote(entries);
    out[log.name] = (
      sets: sets,
      dirs: setPulseDirs(entries, perSet),
      peak: entries.last.pulse!.peak,
      note: note != null && identical(note.log, log) ? note : null,
    );
  }
  return out;
}

/// One training of an exercise in its pulse history: [pulse] null without a curve.
typedef PulseEntry = ({DateTime date, ExerciseLog log, ExercisePulse? pulse, Preload preload});

enum PulseNoteKind { lower, higher, similar, heavierSimilar }

/// What the note under the chart says about [log] on [date]: its [bpm] against the [median] of [refs]
/// earlier comparable trainings, [fromKg] the lighter weight before when the load went up.
typedef PulseNote = ({PulseNoteKind kind, DateTime date, ExerciseLog log, int bpm, int median, int refs, double? fromKg});

/// Usable for a comparison: fully measured, every set done, no backoff, deload or lighter sets.
bool _clean(PulseEntry e) =>
    (e.pulse?.complete ?? false) &&
    e.log.reps.every((r) => r != null) &&
    _plain(e.log);

double? _uniform(ExerciseLog l) => l.weights.toSet().length == 1 ? l.weights.first : null;

String _reps(ExerciseLog l) => l.reps.join(',');

/// [bpm] against earlier [peaks]: similar within their range and near the median, lower or higher
/// outside it and clearly away from the median, else null.
PulseNoteKind? _compare(int bpm, List<int> peaks) {
  final m = median([for (final p in peaks) p.toDouble()]);
  final (lo, hi) = (peaks.reduce(min), peaks.reduce(max));
  if (bpm >= lo && bpm <= hi && (bpm - m).abs() <= pulseSimilarBpm) return PulseNoteKind.similar;
  if (bpm < lo && m - bpm >= pulseSimilarBpm) return PulseNoteKind.lower;
  if (bpm > hi && bpm - m >= pulseSimilarBpm) return PulseNoteKind.higher;
  return null;
}

/// Per set of the last of [entries] (oldest first): 1 clearly above, -1 clearly below the same set in
/// earlier trainings with the same work (same reps, weights and preload, no backoff or deload), 0
/// otherwise or with fewer than [pulseMinRefs] of them. [sets] holds each entry's peak per set.
List<int> setPulseDirs(List<PulseEntry> entries, List<List<int?>> sets) {
  final t = entries.last;
  final mine = sets.last;
  if (!_plain(t.log)) return List.filled(mine.length, 0);
  final refs = [
    for (var i = entries.length - 2; i >= 0; i--)
      if (entries[i] case final e
          when _plain(e.log) &&
              (t.preload == Preload.unknown || e.preload == Preload.unknown || e.preload == t.preload) &&
              _reps(e.log) == _reps(t.log) &&
              e.log.weights.join(',') == t.log.weights.join(','))
        sets[i],
  ].take(pulseMaxRefs).toList();
  return [
    for (final (i, bpm) in mine.indexed)
      if ((bpm, [for (final r in refs) ?r.elementAtOrNull(i)]) case (final b?, final peaks) when peaks.length >= pulseMinRefs)
        switch (_compare(b, peaks)) { PulseNoteKind.higher => 1, PulseNoteKind.lower => -1, _ => 0 }
      else
        0,
  ];
}

/// No backoff, deload or lighter sets: work to compare.
bool _plain(ExerciseLog l) =>
    l.backoff == null &&
    !const {Progression.deload, Progression.lighter, Progression.fewer, Progression.pain}.contains(l.progression);

/// The note for the newest fully measured training in [entries] (oldest first, the period shown), or
/// null: no comparable base, or the pulse between similar and clearly different.
PulseNote? pulseNote(List<PulseEntry> entries) {
  final ti = entries.lastIndexWhere((e) => e.pulse?.complete ?? false);
  if (ti < 0 || !_clean(entries[ti])) return null;
  final t = entries[ti];
  final bpm = t.pulse!.peak!;
  bool samePreload(PulseEntry e) =>
      t.preload == Preload.unknown || e.preload == Preload.unknown || e.preload == t.preload;
  final earlier = [
    for (final e in entries.sublist(0, ti).reversed)
      if (_clean(e) && samePreload(e) && e.log.reps.length == t.log.reps.length && _reps(e.log) == _reps(t.log)) e,
  ];
  PulseNote note(PulseNoteKind k, List<PulseEntry> refs, double? fromKg) {
    final peaks = [for (final r in refs) r.pulse!.peak!.toDouble()];
    return (kind: k, date: t.date, log: t.log, bpm: bpm, median: median(peaks).round(), refs: refs.length, fromKg: fromKg);
  }

  PulseNoteKind? compare(List<PulseEntry> refs) => _compare(bpm, [for (final r in refs) r.pulse!.peak!]);

  // The same work: same sets, reps done and weights.
  final same = [for (final e in earlier) if (e.log.weights.join(',') == t.log.weights.join(',')) e].take(pulseMaxRefs).toList();
  if (same.length >= pulseMinRefs) {
    final k = compare(same);
    return k == null ? null : note(k, same, null);
  }
  // More load, one thing changed: a single lighter uniform weight before, everything else the same.
  final w = _uniform(t.log);
  if (w == null) return null;
  final lighter = [for (final e in earlier) if ((_uniform(e.log) ?? w) < w) e];
  if (lighter.isEmpty) return null;
  final from = _uniform(lighter.first.log)!;
  final refs = [for (final e in lighter) if (_uniform(e.log) == from) e].take(pulseMaxRefs).toList();
  if (refs.length < pulseMinRefs || compare(refs) != PulseNoteKind.similar) return null;
  return note(PulseNoteKind.heavierSimilar, refs, from);
}

/// "3×8 mit 80 kg", or the sets as the history shows them when weights or reps differ.
String pulseWorkLabel(ExerciseLog l) {
  final reps = l.reps.nonNulls.toList();
  final w = _uniform(l);
  if (w != null && reps.length == l.reps.length && reps.toSet().length == 1) {
    final sets = setsLabel(reps, null, seconds: l.timed);
    return w == 0 ? sets : tr.pulseWorkKg(sets, weightLabel(w));
  }
  return '${l.weight != 0 ? '${weightLabel(l.weight)} × ' : ''}${l.reps.map((r) => r ?? '–').join('/')}';
}

/// The note as at most two sentences: the work, then the pulse.
String pulseNoteText(PulseNote n, DateTime now) {
  final today = n.date.year == now.year && n.date.month == now.month && n.date.day == now.day;
  final when = today ? tr.pulseToday : tr.pulseOn(dateLabel(n.date));
  final work = pulseWorkLabel(n.log);
  final first = switch (n.kind) {
    PulseNoteKind.heavierSimilar => tr.pulseHeavier(when, work, n.refs, weightLabel(n.fromKg!)),
    _ => n.log.succeeded ? tr.pulseSameDone(when, work) : tr.pulseSame(when, work),
  };
  final second = switch (n.kind) {
    PulseNoteKind.lower => tr.pulseLower(n.bpm, n.refs, n.median),
    PulseNoteKind.higher => tr.pulseHigher(n.bpm, n.refs),
    PulseNoteKind.similar || PulseNoteKind.heavierSimilar => tr.pulseSimilar(n.bpm),
  };
  return '$first $second';
}
