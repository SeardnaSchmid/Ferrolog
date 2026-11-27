import 'dart:math';

import 'model.dart';
import 'muscles.dart';
import 'timing.dart';

/// Smart rests, duration only (docs/adaptive-pausen-und-progression.md, sections 1, 2 and 4): from the
/// timestamps of earlier trainings, suggest testing one rest before one set shorter or longer once. Never
/// on its own: the user confirms a test, and adopts it only after it worked repeatedly. The whole
/// exercise counts, not only the set after the rest.

/// Pilot thresholds (section 4), to calibrate on real data.
const restMinDays = 3, restMinMisses = 2, restAdoptAfter = 2, restLongest = 300, restStableDays = 4, restStep = 30;

/// The shortest rest a suggestion goes to: 2:00 for heavy sets (up to 5 reps), else 1:00.
int restFloor(Exercise e) => e.repsPerSet.reduce(min) <= 5 ? 120 : 60;

/// The rest planned before set [set] (index) of [e]: a learned one, else the exercise's.
int restBefore(Exercise e, int set) => e.setRests[set] ?? e.restSeconds;

enum RestChange {
  /// Longer: the set failed more often after shorter rests than after longer ones.
  longer,

  /// Shorter: earlier trainings went on sooner and still made the whole exercise.
  shorter,

  /// Shorter by one step: always the same rest, the whole exercise made with reps to spare.
  tryShorter,
}

/// A test to suggest: [seconds] before set [set] (index) instead of [current]. For [RestChange.longer],
/// after about [before] seconds the set reached its target [beforeMet] of [beforeN] times, after about
/// the suggested rest [met] of [n]. For [RestChange.shorter], [n] trainings went on after about [before]
/// seconds and made it; for [RestChange.tryShorter], [n] trainings in a row made it. [stage] is set when
/// only trainings of that preload were compared (others had one too), [by] the exercise most often before.
typedef RestSuggestion = ({
  RestChange change,
  int set,
  int seconds,
  int current,
  int met,
  int n,
  int before,
  int beforeMet,
  int beforeN,
  Preload? stage,
  String? by,
});

/// What came before an exercise in a training, from the timestamps, not the plan's order (machines
/// taken, the order changes).
enum Preload {
  /// No relevant preload: at most one set before that shared a primary muscle, and the data rules out two.
  none,

  /// At least [preloadMinSets] sets before that shared a primary muscle.
  loaded,

  /// Missing timestamps or muscles could change it, or it changed within the exercise (another exercise
  /// sharing a muscle in between).
  unknown,
}

/// Pilot threshold: sets of other exercises sharing a primary muscle that make an exercise preloaded.
const preloadMinSets = 2;

/// The preload of one exercise in one training; [by] the other exercise with the most such sets
/// ([sets]) before it, for the recap's "after 3 sets of squats".
typedef PreloadInfo = ({Preload stage, String? by, int sets});

const PreloadInfo _unknown = (stage: Preload.unknown, by: null, sets: 0);

/// The preload of [log] in [s]: the sets of other exercises logged before its first set that share a
/// primary muscle with it, each set once. Taken at its first and at its last set; when they differ
/// (an exercise sharing a muscle in between), unknown. [muscles] looks up an exercise's muscles.
PreloadInfo preloadOf(Session s, ExerciseLog log, [Muscles? Function(String)? muscles]) {
  final of = muscles ?? musclesOf;
  final mine = of(log.name)?.$1 ?? 0;
  final (first, last) = (log.doneAt.nonNulls.firstOrNull, log.doneAt.nonNulls.lastOrNull);
  if (mine == 0 || first == null || last == null) return _unknown;
  PreloadInfo at(DateTime t) {
    final per = <String, int>{};
    var uncertain = 0;
    for (final o in s.exercises) {
      if (identical(o, log) || o.cardio) continue;
      final theirs = of(o.name)?.$1 ?? 0;
      for (final (i, r) in o.reps.indexed) {
        if (r == null) continue;
        final done = i < o.doneAt.length ? o.doneAt[i] : null;
        if (done != null && !done.isBefore(t)) continue;
        if (theirs == 0 || done == null) {
          // Unknown muscles before, or a set of a related exercise at an unknown time.
          if (theirs == 0 || theirs & mine != 0) uncertain++;
          continue;
        }
        if (theirs & mine != 0) per[o.name] = (per[o.name] ?? 0) + 1;
      }
    }
    final count = per.values.fold(0, (a, b) => a + b);
    final top = per.entries.fold<MapEntry<String, int>?>(null, (b, x) => b == null || x.value > b.value ? x : b);
    final stage = count >= preloadMinSets
        ? Preload.loaded
        : count + uncertain >= preloadMinSets
            ? Preload.unknown
            : Preload.none;
    return (stage: stage, by: top?.key, sets: top?.value ?? 0);
  }

  final (a, b) = (at(first), at(last));
  return a.stage == b.stage ? a : _unknown;
}

/// One earlier training of the exercise, as far as rests go.
typedef RestUnit = ({
  Session session,
  ExerciseLog log,
  List<RestObservation> obs,
  bool made,
  int total,
  PreloadInfo preload,
});

bool _made(ExerciseLog l) => [for (final (i, r) in l.reps.indexed) (r ?? -1) >= l.targets[i]].every((ok) => ok);

int _total(ExerciseLog l) => l.reps.fold(0, (sum, r) => sum + (r ?? 0));

bool _known(RestUnit u) => u.preload.stage != Preload.unknown;

/// Made with reps to spare: every set reached, and the reserve asked after the last set, if answered,
/// wasn't zero. A missing answer stays unknown and doesn't count against it.
bool _good(RestUnit u) => u.made && (u.log.rir ?? 1) >= 1;

/// Earlier trainings comparable with [e] as planned now, newest first and one per day: same sets, loads
/// and targets, a regular training (no swap, pain, bad day, lighter or skipped sets) and no deload.
List<RestUnit> comparableUnits(List<Session> sessions, Exercise e) =>
    _units(sessions, e, e.weights, e.repsPerSet);

List<RestUnit> _units(List<Session> sessions, Exercise e, List<double> weights, List<int> targets) {
  if (e.cardio || e.sets < 2) return const [];
  final memo = <String, Muscles?>{};
  Muscles? muscles(String name) => memo.putIfAbsent(name, () => musclesOf(name));
  final days = <DateTime>{};
  final out = <RestUnit>[];
  for (final s in sessions) {
    for (final log in s.exercises) {
      if (log.name != e.name || log.cardio || log.reps.length != weights.length || log.progression == Progression.deload) {
        continue;
      }
      if (log.weights.join(',') != weights.join(',') || log.targets.join(',') != targets.join(',')) continue;
      final obs = restObservations(s, log, plan: e);
      if (obs.isEmpty || !obs.first.regular) continue;
      if (!days.add(DateTime(s.date.year, s.date.month, s.date.day))) continue;
      out.add((
        session: s,
        log: log,
        obs: obs,
        made: _made(log),
        total: _total(log),
        preload: preloadOf(s, log, muscles),
      ));
    }
  }
  return out;
}

/// The preloads [e] regularly has: of the last 8 comparable trainings with a known one, each with at
/// least a quarter of them.
Set<Preload> regularPreloads(List<RestUnit> units) {
  final known = units.where(_known).take(8).toList();
  return {
    for (final st in [Preload.none, Preload.loaded])
      if (known.any((u) => u.preload.stage == st) && known.where((u) => u.preload.stage == st).length * 4 >= known.length)
        st,
  };
}

/// The comparable rests before set [set] of [e], newest first: the sets before it all reached, and a
/// normal rest or a test (the rest after a miss learns apart).
List<(RestObservation, RestUnit)> comparableRests(List<Session> sessions, Exercise e, int set) => [
  for (final u in comparableUnits(sessions, e))
    for (final o in u.obs)
      if (o.set == set && o.priorMet && o.kind != RestKind.afterMiss) (o, u),
];

/// The test [e] has pending: accepted, not run yet in a training since, and still fitting the plan (a
/// changed load, target or set count drops it).
RestTrial? pendingTrial(List<Session> sessions, Exercise e) {
  final t = e.restTrial;
  if (!e.learnRest || t == null || t.set >= e.sets || e.weights[t.set] != t.kg || e.repsPerSet[t.set] != t.target) {
    return null;
  }
  final ran = sessions.any(
    (s) =>
        !s.date.isBefore(t.since) &&
        s.exercises.any((l) => l.name == e.name && l.trialSet == t.set && l.trialSeconds == t.seconds),
  );
  return ran ? null : t;
}

/// How a test went.
enum TrialOutcome {
  /// The whole exercise made, no fewer reps in all than usual with the same preload. Counts for adopting.
  worked,

  /// A set missed, or fewer reps than usual (a range of 8–12 going from 12/11/10 to 12/9/8).
  failed,

  /// Made, but no usual training with the same preload to compare with, or the preload is unknown.
  /// Doesn't count for adopting.
  noComparison,
}

/// How [test] went against the [usual] trainings without a test, only those with the same preload.
TrialOutcome trialOutcome(RestUnit test, List<RestUnit> usual) {
  if (!test.made) return TrialOutcome.failed;
  if (!_known(test)) return TrialOutcome.noComparison;
  final totals = [
    for (final u in usual)
      if (u.preload.stage == test.preload.stage) u.total,
  ]..sort();
  if (totals.isEmpty) return TrialOutcome.noComparison;
  return test.total >= totals[totals.length ~/ 2] ? TrialOutcome.worked : TrialOutcome.failed;
}

/// The comparable trainings (same load, targets and sets as planned now, regular, no deload) that ran a
/// test of [seconds] before [set] of [e], newest first, with how it went.
List<(RestUnit, TrialOutcome)> trialResults(List<Session> sessions, Exercise e, int set, int seconds) {
  final units = comparableUnits(sessions, e);
  final usual = [for (final u in units) if (u.log.trialSet == null) u];
  return [
    for (final u in units)
      if (u.log.trialSet == set && u.log.trialSeconds == seconds) (u, trialOutcome(u, usual)),
  ];
}

/// How the test in [log] went, compared with trainings at its own load and targets (the plan may have
/// gone up since), with its preload; null when it isn't a regular comparable training.
(TrialOutcome, PreloadInfo)? trialOutcomeOf(List<Session> sessions, ExerciseLog log, Exercise e) {
  if (log.trialSet == null) return null;
  final units = _units(sessions, e, log.weights, log.targets);
  final test = units.where((u) => identical(u.log, log)).firstOrNull;
  if (test == null) return null;
  return (trialOutcome(test, [for (final u in units) if (u.log.trialSet == null) u]), test.preload);
}

/// The test to adopt for good: [restAdoptAfter] tests of the same rest worked, it's not adopted yet and
/// wasn't turned down after the latest of them. A shorter rest needs one that worked with each preload
/// [e] regularly has: shorter rests cost sets, longer ones only time.
({int set, int seconds, int worked})? restToAdopt(List<Session> sessions, Exercise e) {
  if (!e.learnRest) return null;
  for (final s in sessions) {
    for (final l in s.exercises) {
      if (l.name != e.name || l.trialSet == null || l.trialSeconds == null) continue;
      final (set, seconds) = (l.trialSet!, l.trialSeconds!);
      if (set >= e.sets || restBefore(e, set) == seconds) return null;
      if (e.restDeclined case final d? when !d.isBefore(s.date)) return null;
      final worked = [
        for (final (u, outcome) in trialResults(sessions, e, set, seconds))
          if (outcome == TrialOutcome.worked) u,
      ];
      if (worked.length < restAdoptAfter) return null;
      if (seconds < restBefore(e, set)) {
        final regular = regularPreloads(comparableUnits(sessions, e));
        if (!regular.every((st) => worked.any((u) => u.preload.stage == st))) return null;
      }
      return (set: set, seconds: seconds, worked: worked.length);
    }
  }
  return null;
}

/// Keeps a confirmed test: as a rest before its set, or none when it's the exercise's rest anyway.
void adoptRest(Exercise e, int set, int seconds) =>
    seconds == e.restSeconds ? e.setRests.remove(set) : e.setRests[set] = seconds;

/// A test to suggest for [e], or null: none while a test is pending or one is to adopt, after a deload,
/// before newer trainings than a turned-down suggestion, or when the assignment of a rest close to the
/// border of two ranges would turn the result. Longer comes first (a set fails), then shorter. Trainings
/// with an unknown preload neither back nor contradict a suggestion.
RestSuggestion? restSuggestion(List<Session> sessions, Exercise e) {
  if (!e.learnRest || pendingTrial(sessions, e) != null || restToAdopt(sessions, e) != null) return null;
  final latest = sessions.expand((s) => s.exercises).where((l) => l.name == e.name).firstOrNull;
  if (latest == null || latest.progression == Progression.deload) return null;
  final units = comparableUnits(sessions, e);
  if (units.isEmpty) return null;
  if (e.restDeclined case final d? when !units.first.session.date.isAfter(d)) return null;
  final regular = regularPreloads(units);
  final sets = [for (var i = 1; i < e.sets; i++) i];
  // Longer: the latest set first, it carries the most fatigue.
  for (final set in sets.reversed) {
    if (_robust(sessions, e, set, _longer) case final g?) return g;
  }
  for (final set in sets) {
    if (_robust(sessions, e, set, (obs, halves, e, set) => _shorter(obs, halves, e, set, regular)) case final g?) {
      return g;
    }
  }
  return _tryShorter(units, e);
}

typedef _Decide = RestSuggestion? Function(List<(RestObservation, RestUnit)>, List<int>, Exercise, int);

int _half(int seconds) => (seconds / 30).round();

/// [decide] on the rests before [set] in 30 s ranges; within 5 s of a border the other range is as
/// likely, so wait if it would change the answer.
RestSuggestion? _robust(List<Session> sessions, Exercise e, int set, _Decide decide) {
  final obs = [
    for (final x in comparableRests(sessions, e, set))
      if (_known(x.$2)) x,
  ];
  if (obs.isEmpty) return null;
  final base = [for (final (o, _) in obs) _half(o.rest.inSeconds)];
  final found = decide(obs, base, e, set);
  for (final (i, (o, _)) in obs.indexed) {
    final r = o.rest.inSeconds % 30;
    if ((r - 15).abs() >= 5) continue;
    final other = [...base]..[i] = r < 15 ? base[i] + 1 : base[i] - 1;
    if (decide(obs, other, e, set)?.seconds != found?.seconds) return null;
  }
  return found;
}

({int n, int met, int days}) _count(List<(RestObservation, RestUnit)> obs, List<int> halves, int h, bool Function(RestObservation, RestUnit) ok) {
  final mine = [
    for (final (i, x) in obs.indexed)
      if (halves[i] == h) x,
  ];
  return (
    n: mine.length,
    met: mine.where((x) => ok(x.$1, x.$2)).length,
    days: {for (final (o, _) in mine) DateTime(o.date.year, o.date.month, o.date.day)}.length,
  );
}

bool _reached(RestObservation o, RestUnit _) => o.reps >= o.target;

/// The exercise most often before [e] in [obs] of [stage].
String? _mostlyBy(List<(RestObservation, RestUnit)> obs, Preload stage) {
  final by = <String, int>{};
  for (final (_, u) in obs) {
    if (u.preload.stage == stage && u.preload.by != null) by[u.preload.by!] = (by[u.preload.by!] ?? 0) + 1;
  }
  return by.entries.fold<MapEntry<String, int>?>(null, (b, x) => b == null || x.value > b.value ? x : b)?.key;
}

/// Longer, compared within one preload only, so a longer rest that only ever came without preload and a
/// shorter one only after it don't make a case: one preload must show on its own that the set failed
/// more often after a shorter rest than after a longer one. When the other preload, backed as well,
/// shows it the other way round, wait. Of several, the shorter one.
RestSuggestion? _longer(List<(RestObservation, RestUnit)> obs, List<int> halves, Exercise e, int set) {
  final stages = {for (final (_, u) in obs) u.preload.stage};
  RestSuggestion? best;
  for (final stage in [Preload.none, Preload.loaded]) {
    final idx = [
      for (final (i, (_, u)) in obs.indexed)
        if (u.preload.stage == stage) i,
    ];
    if (idx.isEmpty) continue;
    final g = _longerIn([for (final i in idx) obs[i]], [for (final i in idx) halves[i]], e, set);
    if (g == null) continue;
    final other = stage == Preload.none ? Preload.loaded : Preload.none;
    final rest = [
      for (final (i, (_, u)) in obs.indexed)
        if (u.preload.stage == other) i,
    ];
    final (os, oh) = ([for (final i in rest) obs[i]], [for (final i in rest) halves[i]]);
    final (l, s) = (_count(os, oh, g.seconds ~/ 30, _reached), _count(os, oh, g.before ~/ 30, _reached));
    if (l.days >= restMinDays && s.days >= restMinDays && l.met / l.n < s.met / s.n) return null;
    if (best != null && best.seconds <= g.seconds) continue;
    best = (
      change: g.change,
      set: g.set,
      seconds: g.seconds,
      current: g.current,
      met: g.met,
      n: g.n,
      before: g.before,
      beforeMet: g.beforeMet,
      beforeN: g.beforeN,
      stage: stages.length > 1 ? stage : null,
      by: stages.length > 1 && stage == Preload.loaded ? _mostlyBy(obs, stage) : null,
    );
  }
  return best;
}

/// Longer within one preload: a range longer than now with a better rate of reaching the set than a
/// shorter range that missed it repeatedly.
RestSuggestion? _longerIn(List<(RestObservation, RestUnit)> obs, List<int> halves, Exercise e, int set) {
  final current = restBefore(e, set);
  final ranges = {...halves}.toList()..sort();
  for (final long in ranges) {
    if (long * 30 <= current || long * 30 > restLongest) continue;
    final l = _count(obs, halves, long, _reached);
    if (l.days < restMinDays) continue;
    for (final short in ranges.reversed.where((h) => h < long)) {
      final s = _count(obs, halves, short, _reached);
      if (s.days < restMinDays || s.n - s.met < restMinMisses || l.met / l.n <= s.met / s.n) continue;
      return (
        change: RestChange.longer,
        set: set,
        seconds: long * 30,
        current: current,
        met: l.met,
        n: l.n,
        before: short * 30,
        beforeMet: s.met,
        beforeN: s.n,
        stage: null,
        by: null,
      );
    }
  }
  return null;
}

/// Shorter: the shortest range below now, not below the floor, where every training on enough days made
/// the whole exercise with reps to spare, among them at least one with each preload [e] regularly has.
RestSuggestion? _shorter(List<(RestObservation, RestUnit)> obs, List<int> halves, Exercise e, int set, Set<Preload> regular) {
  final current = restBefore(e, set);
  final ranges = {...halves}.toList()..sort();
  for (final h in ranges) {
    if (h * 30 >= current || h * 30 < restFloor(e)) continue;
    final c = _count(obs, halves, h, (_, u) => _good(u));
    if (c.days < restMinDays || c.met < c.n) continue;
    final seen = {
      for (final (i, (_, u)) in obs.indexed)
        if (halves[i] == h) u.preload.stage,
    };
    if (!regular.every(seen.contains)) continue;
    return (
      change: RestChange.shorter,
      set: set,
      seconds: h * 30,
      current: current,
      met: c.met,
      n: c.n,
      before: h * 30,
      beforeMet: c.met,
      beforeN: c.n,
      stage: null,
      by: null,
    );
  }
  return null;
}

/// Always the same rests, and the last [restStableDays] trainings with a known preload made it with reps
/// to spare (a reserve of 2 or more where answered): one step shorter before the set with the longest
/// rest, the earliest of equals, while it stays above the floor.
RestSuggestion? _tryShorter(List<RestUnit> units, Exercise e) {
  final recent = units.where(_known).take(restStableDays).toList();
  if (recent.length < restStableDays) return null;
  if (!recent.every((u) => _good(u) && (u.log.rir ?? 2) >= 2)) return null;
  final sets = [for (var i = 1; i < e.sets; i++) i]
    ..sort((a, b) => restBefore(e, b) != restBefore(e, a) ? restBefore(e, b) - restBefore(e, a) : a - b);
  for (final set in sets) {
    final current = restBefore(e, set);
    final seconds = current - restStep;
    if (seconds < restFloor(e)) continue;
    // Each of them has a known rest before this set.
    if (!recent.every((u) => u.obs.any((o) => o.set == set))) continue;
    return (
      change: RestChange.tryShorter,
      set: set,
      seconds: seconds,
      current: current,
      met: restStableDays,
      n: restStableDays,
      before: current,
      beforeMet: restStableDays,
      beforeN: restStableDays,
      stage: null,
      by: null,
    );
  }
  return null;
}

/// The set of [e] that missed repeatedly, all at about the same rest: without other rests to compare,
/// there's nothing to suggest yet. Null when there is none.
int? restNeedsVariety(List<Session> sessions, Exercise e) {
  if (!e.learnRest) return null;
  for (var set = e.sets - 1; set >= 1; set--) {
    final obs = comparableRests(sessions, e, set);
    final misses = obs.where((x) => x.$1.reps < x.$1.target).length;
    if (obs.length >= restMinDays && misses >= restMinMisses && {for (final (o, _) in obs) _half(o.rest.inSeconds)}.length == 1) {
      return set;
    }
  }
  return null;
}
