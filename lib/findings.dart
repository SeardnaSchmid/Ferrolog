import 'dart:math';

import 'model.dart';
import 'muscles.dart';
import 'units.dart';

/// What the statistics found, for the home card "Dein Training": something to act on, or something
/// that went well. Every finding says where in the statistics it comes from.
enum FindingKind { action, positive }

/// The kinds of findings; for actions the order is their rank, the first wins the top of the card.
enum FindingType {
  weekGoal(FindingKind.action),
  skipped(FindingKind.action),
  balance(FindingKind.action),
  plateau(FindingKind.action),
  record(FindingKind.positive),
  gain(FindingKind.positive),
  milestone(FindingKind.positive),
  month(FindingKind.positive);

  final FindingKind kind;
  const FindingType(this.kind);
}

/// What the button in a finding's sheet does: never more work, at most the same.
enum Fix {
  /// Moves [Finding.exercise] up in [Finding.workout], before the accessories, so it isn't the one left out.
  moveUp,

  /// One set less of [Finding.exercise] in [Finding.workout], an accessory on the side that's ahead.
  dropSet,
}

/// Where the statistics show a finding.
enum StatsView { balance, weeks, exercise, history }

/// A place in the statistics: the view, and in it the pair, the exercise or the trainings to mark.
typedef StatsTarget = ({StatsView view, Pair? pair, String? exercise, List<DateTime> dates});

StatsTarget statsAt(StatsView view, {Pair? pair, String? exercise, List<DateTime> dates = const []}) =>
    (view: view, pair: pair, exercise: exercise, dates: dates);

/// One finding. [title] and [evidence] are the two lines on the home card; [why] and [advice] are for
/// the sheet that actions open (positives go straight to [source]). [id] stays the same while the
/// reason does, so the finding can be put off.
class Finding {
  final String id, title, evidence;
  final FindingType type;
  final String? why, advice;
  final StatsTarget source;

  /// The sheet's button: [fix] for [exercise] in [workout]; none = advice only.
  final Workout? workout;
  final String? exercise;
  final Fix? fix;

  /// How far off within its type, to rank findings of the same type.
  final double weight;

  const Finding(this.id, this.type, this.title, this.evidence,
      {required this.source, this.why, this.advice, this.workout, this.exercise, this.fix, this.weight = 0});

  FindingKind get kind => type.kind;
}

/// Training advice (skipped, balance, plateau) waits for a baseline: this many trainings over at
/// least two weeks, so a first week doesn't flood a new user.
const baselineTrainings = 6;

/// At most one piece of training advice at a time, and a new one at most every [advicePause] after
/// the last was acted on or put off. The weekly goal and positives don't count.
const advicePause = Duration(days: 7);

/// Ids of findings that count as training advice, for [advicePause].
bool isAdvice(String id) => id.startsWith('skipped:') || id.startsWith('balance:') || id.startsWith('plateau:');

/// Everything the statistics found right now, ranked: actions first (weekly goal, then at most one
/// piece of advice: skipped before balance before plateau, the furthest off first), then positives of
/// the last training. [sessions] newest first; [snoozed]: id → put off until; [lastAdvice]: when the
/// last advice was acted on or put off. Nothing while a training runs is the caller's business.
List<Finding> findings(List<Session> sessions, List<Workout> workouts, DateTime now,
    {int perWeek = 3, Map<String, DateTime> snoozed = const {}, DateTime? lastAdvice}) {
  if (sessions.isEmpty) return [];
  bool off(Finding f) => snoozed[f.id]?.isAfter(now) ?? false;
  final result = <Finding>[];

  if (_weekGoal(sessions, now, perWeek) case final f? when !off(f)) result.add(f);

  if (lastAdvice == null || now.difference(lastAdvice) >= advicePause) {
    final recent = [for (final s in sessions) if (now.difference(s.date).inDays < 28) s];
    final baseline = sessions.length >= baselineTrainings && now.difference(sessions.last.date).inDays >= 14;
    // The balance over the same 30 days and weeks as the statistics shows, so the numbers match there.
    final month = [for (final s in sessions) if (s.date.isAfter(now.subtract(const Duration(days: 30)))) s];
    final balance = baseline ? _balance(month, workouts, periodStats(sessions, now, days: 30).weeks) : <Finding>[];
    final skipped = _skipped(recent, workouts, balance);
    // A skip that explains a balance gap stands for it: the cause is what can be changed.
    final explained = {for (final f in skipped) if (f.source.view == StatsView.balance) f.source.pair};
    final advice = [
      ...skipped,
      ...balance.where((b) => !explained.contains(b.source.pair)),
      ..._plateaus(sessions, workouts),
    ]..sort((a, b) => a.type != b.type ? a.type.index.compareTo(b.type.index) : b.weight.compareTo(a.weight));
    if (advice.where((f) => !off(f)).firstOrNull case final f?) result.add(f);
  }

  result.addAll(_positives(sessions, now).where((f) => !off(f)));
  return result;
}

/// What the home card shows: the top action, if any, and up to two lines below it, positives first.
(Finding?, List<Finding>) homeSelection(List<Finding> all) {
  final top = all.where((f) => f.kind == FindingKind.action).firstOrNull;
  final rest = [for (final f in all) if (f != top) f]
    ..sort((a, b) => a.kind == b.kind ? 0 : (a.kind == FindingKind.positive ? -1 : 1));
  return (top, rest.take(2).toList());
}

/// "6", "6,5": a number with at most one decimal, German style.
String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1).replaceAll('.', ',');

String _date(DateTime d) => '${d.day}.${d.month}.';

// ---------------------------------------------------------------------------------------------------
// Actions

/// The weekly goal, only when the days left get tight and it can still be made, one training a day.
/// Not in the week of the very first training, and today counts no more once trained.
Finding? _weekGoal(List<Session> sessions, DateTime now, int perWeek) {
  final monday = mondayOf(now);
  final done = sessions.where((s) => !s.date.isBefore(monday)).length;
  final needed = perWeek - done;
  final trainedToday = sessions.any((s) => !s.date.isBefore(DateTime(now.year, now.month, now.day)));
  final daysLeft = 8 - now.weekday - (trainedToday ? 1 : 0);
  final firstWeek = !sessions.last.date.isBefore(monday);
  if (firstWeek || needed <= 0 || needed > daysLeft || needed < daysLeft - 1) return null;
  final when = daysLeft > 1
      ? 'noch $daysLeft Tage'
      : trainedToday
          ? 'morgen ist der letzte Tag'
          : 'heute ist der letzte Tag';
  return Finding('week:${monday.year}-${monday.month}-${monday.day}', FindingType.weekGoal,
      needed == 1 ? 'Noch 1 Training diese Woche' : 'Noch $needed Trainings diese Woche',
      '$done von $perWeek geschafft, $when',
      why: 'Dein Wochenziel sind $perWeek Trainings.',
      advice: 'Mit einem Training ${daysLeft > 1 ? 'in den nächsten Tagen' : trainedToday ? 'morgen' : 'heute'} bleibt die Serie.',
      source: statsAt(StatsView.weeks));
}

/// Where an exercise moved up goes: right after the main lifts at the start, before the first accessory.
int earlierSlot(Workout w) {
  final i = w.exercises.indexWhere((e) => !heavyLifts.contains(e.name));
  return i < 0 ? w.exercises.length : i;
}

/// Exercises left out entirely at least twice in [recent] (four weeks) that are still planned. Where
/// it's the reason a balance pair is off, the finding names that and points to the balance.
List<Finding> _skipped(List<Session> recent, List<Workout> workouts, List<Finding> balance) {
  final planned = {for (final w in workouts) for (final e in w.exercises) if (!e.cardio) e.name};
  final skips = <String, List<Session>>{}, trained = <String, int>{};
  for (final s in recent) {
    for (final e in s.exercises) {
      if (e.cardio || !planned.contains(e.name)) continue;
      trained[e.name] = (trained[e.name] ?? 0) + 1;
      if (e.setsDone == 0) (skips[e.name] ??= []).add(s);
    }
  }
  final result = <Finding>[];
  for (final MapEntry(key: name, value: ss) in skips.entries) {
    if (ss.length < 2) continue;
    final n = ss.length, of = trained[name]!;
    // Skipped as the last exercise (cardio aside): then it's the time running out.
    bool lastIn(Session s) => s.exercises.lastWhere((e) => !e.cardio).name == name;
    final atEnd = ss.where(lastIn).length;
    final end = atEnd == n ? ', jedes Mal als letzte Übung' : atEnd * 2 >= n ? ', meist als letzte Übung' : '';
    final lagging = balance.where((b) => b.source.pair != null && sideOf(b.source.pair!, name) != null).firstOrNull;
    final consequence = lagging == null ? '' : ' Folge für die Balance: ${lagging.evidence}.';
    final w = workouts.where((w) => w.exercises.any((e) => e.name == name)).firstOrNull;
    final i = w?.exercises.indexWhere((e) => e.name == name) ?? -1;
    final canMove = w != null && earlierSlot(w) < i;
    result.add(Finding('skipped:$name', FindingType.skipped, '$name $n× ausgelassen', 'In 4 Wochen$end',
        why: 'In $n von $of Trainings komplett weggelassen$end.$consequence',
        advice: canMove
            ? '$name vor die Zusatzübungen ziehen. Gleiches Volumen, es fällt nur nicht mehr hinten runter.'
            : '$name früher im Training einplanen oder bewusst aus dem Plan nehmen.',
        source: lagging != null
            ? statsAt(StatsView.balance, pair: lagging.source.pair)
            : statsAt(StatsView.exercise, exercise: name, dates: [for (final s in ss) s.date]),
        workout: canMove ? w : null,
        exercise: name,
        fix: canMove ? Fix.moveUp : null,
        weight: n / of));
  }
  return result;
}

/// What trains a muscle group that falls behind, and the exercise to suggest when none is planned.
const _remedies = <String, (List<String>, String)>{
  'Oberer Rücken': (['Langhantelrudern', 'Kurzhantelrudern', 'Kabelrudern'], 'Kurzhantelrudern'),
  'Brust': (['Bankdrücken', 'Kurzhantel-Bankdrücken', 'Dips'], 'Kurzhantel-Bankdrücken'),
  'Hintere Kette': (['Rumänisches Kreuzheben', 'Hip Thrust'], 'Rumänisches Kreuzheben'),
  'Quadrizeps': (['Kniebeuge', 'Beinpresse', 'Bulgarian Split Squat'], 'Beinpresse'),
  'Beinbeuger': (['Nordic Curls', 'Beinbeuger'], 'Nordic Curls'),
  'Latissimus': (['Klimmzüge', 'Latzug'], 'Latzug'),
};

/// Opposing pairs off their guide range over [recent] (30 days, [weeks] long), with a tip by cause that never
/// adds work:
/// - by strength (1RM): keep raising the side behind, it catches up;
/// - by sets, planned but sets left out: plan it earlier;
/// - by sets and planned that way, with an accessory on the side ahead: one set less there;
/// - else the main lifts stay as planned and the side behind is named.
List<Finding> _balance(List<Session> recent, List<Workout> workouts, double weeks) {
  final result = <Finding>[];
  for (final b in balances(recent, weeks: weeks)) {
    final lagging = b.lagging;
    if (lagging == null || !_remedies.containsKey(lagging)) continue;
    final behindB = lagging == b.bGroup;
    final range = b.high.isFinite ? '${(b.low * 100).round()}–${(b.high * 100).round()} %' : 'ab ${(b.low * 100).round()} %';
    final unit = b.strength ? ' kg 1RM' : ' Sätze/Woche';
    // Short on the card: the lifts by strength, else the muscle groups; what counts goes in the why.
    final (an, bn) = b.strength ? (b.a, b.b) : (b.aGroup, b.bGroup);
    // The ratio first, so a narrow screen cuts the counts, not it.
    final evidence = '${(b.ratio * 100).floor()} % · $an ${_num(b.aValue)} : $bn ${_num(b.bValue)}$unit';
    final why = b.strength
        ? 'Richtwert $range. Verglichen wird das aktuelle 1RM.'
        : '${b.a} gegen ${b.b}, Richtwert $range. Gezählt werden die gemachten Sätze der letzten 30 Tage.';
    final gap = b.ratio < b.low ? (b.ratio == 0 ? 99.0 : b.low / b.ratio) : b.ratio / b.high;
    Finding make(String advice, {Workout? w, String? exercise, Fix? fix}) => Finding(
        'balance:${b.pair.name}', FindingType.balance, '$lagging kommt zu kurz', evidence,
        why: why, advice: advice, source: statsAt(StatsView.balance, pair: b.pair),
        workout: w, exercise: exercise, fix: fix, weight: gap);

    if (b.strength) {
      result.add(make('${behindB ? b.b : b.a} weiter steigern, das holt auf. Mehr Sätze lösen das nicht.'));
      continue;
    }
    // Planned evenly, but sets left out on the side behind.
    final behind = behindB ? 1 : 0;
    final planned = [0.0, 0.0], done = [0.0, 0.0];
    for (final s in recent) {
      for (final e in s.exercises) {
        if (e.cardio) continue;
        if (sideOf(b.pair, e.name) case final side?) {
          planned[side] += e.reps.length;
          done[side] += e.setsDone;
        }
      }
    }
    final plannedRatio = planned[0] == 0 ? double.infinity : planned[1] / planned[0];
    if (done[behind] < planned[behind] && plannedRatio >= b.low && plannedRatio <= b.high) {
      result.add(make('Geplant ist es ausgeglichen, aber Sätze fallen weg. ${behindB ? b.b : b.a} früher im Training einplanen.'));
      continue;
    }
    // Planned that way: an accessory ahead can give up a set.
    final ahead = 1 - behind;
    final accessory = [
      for (final w in workouts)
        for (final e in w.exercises)
          if (!e.cardio && e.sets > 1 && !heavyLifts.contains(e.name) && sideOf(b.pair, e.name) == ahead) (w, e),
    ].firstOrNull;
    if (accessory case (final w, final e)?) {
      result.add(make('Ein Satz weniger ${e.name} in ${w.name} gleicht aus, ohne mehr Arbeit.',
          w: w, exercise: e.name, fix: Fix.dropSet));
      continue;
    }
    final (specific, suggest) = _remedies[lagging]!;
    final trains = [
      for (final w in workouts)
        for (final e in w.exercises)
          if (sideOf(b.pair, e.name) == behind || specific.contains(e.name)) e.name,
    ];
    result.add(make(trains.isEmpty
        ? 'Nichts im Plan trainiert das, zum Beispiel $suggest.'
        : 'Grundübungen bleiben wie geplant, ${trains.first} nicht auslassen und weiter steigern.'));
  }
  return result;
}

/// Planned exercises with weight stuck: the last three trainings at the same weight, some set missed
/// or done lighter, no more reps at that weight than three trainings ago (a range climbing in reps is
/// no plateau), and no increase planned. Without progression switched on there's nothing to be stuck on.
List<Finding> _plateaus(List<Session> sessions, List<Workout> workouts) {
  final result = <Finding>[];
  final seen = <String>{};
  for (final w in workouts) {
    for (final e in w.exercises) {
      if (e.cardio || e.timed || e.weight == 0 || !e.up || !seen.add(e.name)) continue;
      final logs = [
        for (final s in sessions)
          for (final l in s.exercises)
            if (l.name == e.name && l.setsDone > 0) (s.date, l),
      ]; // newest first
      if (logs.length < 3) continue;
      final at = logs.first.$2.weight;
      final stuck = logs.takeWhile((x) => x.$2.weight == at).toList();
      if (stuck.length < 3 || e.weight > at) continue;
      final last3 = stuck.take(3).toList().reversed;
      // Reps at the full weight: a set dropped back doesn't count as more.
      int full(ExerciseLog l) => [for (final (i, r) in l.reps.indexed) if (l.weights[i] >= at) r ?? 0].fold(0, (a, b) => a + b);
      if (last3.every((x) => x.$2.succeeded && x.$2.weights.every((kg) => kg >= at))) continue;
      if (full(stuck.first.$2) > full(stuck[2].$2)) continue; // still more reps
      String sets(ExerciseLog l) => [
            for (final (i, r) in l.reps.indexed)
              r == null ? '–' : l.weights[i] < at ? '$r @ ${weightNum(l.weights[i])}' : '$r',
          ].join(' · ');
      final lighter = stuck.first.$2.weights.any((x) => x < at);
      final deload = e.down
          ? 'Automatischer Deload nach ${e.failsToDeload} Fehlschlägen in Folge (bisher ${e.fails}).'
          : 'Automatischer Deload ist aus.';
      result.add(Finding('plateau:${e.name}', FindingType.plateau, '${e.name} steht bei ${weightLabel(at)}',
          '${stuck.length} Trainings ohne Steigerung',
          why: [
            for (final (d, l) in last3) '${_date(d)}: ${sets(l)}',
            if (lighter) 'Zuletzt einen Satz leichter gemacht, das hält das Gewicht.',
            deload,
          ].join('\n'),
          advice: 'Gewicht halten, auf saubere Technik und genug Pause achten. Klappt es in 2 Trainings nicht, '
              'kann ein Deload helfen.',
          source: statsAt(StatsView.exercise, exercise: e.name, dates: [for (final (d, _) in stuck) d]),
          exercise: e.name,
          weight: stuck.length.toDouble()));
    }
  }
  return result;
}

// ---------------------------------------------------------------------------------------------------
// Positives: what the last training brought; they stand until the next one.

List<Finding> _positives(List<Session> sessions, DateTime now) {
  final result = <Finding>[];
  final last = sessions.first;
  List<(DateTime, ExerciseLog)> logsOf(String name, Iterable<Session> from) => [
        for (final s in from)
          for (final e in s.exercises)
            if (e.name == name && e.setsDone > 0) (s.date, e),
      ];

  // A record: heavier than ever before (not on an exercise's first training); the heaviest one.
  (String, double)? record;
  for (final l in last.exercises) {
    if (l.cardio || l.setsDone == 0 || l.weight == 0) continue;
    final before = logsOf(l.name, sessions.skip(1));
    if (before.isNotEmpty && l.weight > before.map((x) => x.$2.weight).reduce(max) && l.weight > (record?.$2 ?? 0)) {
      record = (l.name, l.weight);
    }
  }
  if (record case (final name, final kg)?) {
    result.add(Finding('record:$name:${last.date.toIso8601String()}', FindingType.record,
        'Rekord: $name ${weightLabel(kg)}', 'Schwerer als je zuvor',
        source: statsAt(StatsView.exercise, exercise: name, dates: [last.date])));
  }

  // Progress over 90 days, where the last training moved it: the biggest relative gain.
  final window = [for (final s in sessions) if (now.difference(s.date).inDays <= 90) s];
  (String, double, double, DateTime)? gain;
  for (final l in last.exercises) {
    if (l.cardio || l.weight == 0 || l.setsDone == 0 || l.name == record?.$1) continue;
    final logs = logsOf(l.name, window);
    final (since, first) = logs.last;
    if (l.weight > first.weight && (gain == null || l.weight / first.weight > gain.$3 / gain.$2)) {
      gain = (l.name, first.weight, l.weight, since);
    }
  }
  if (gain case (final name, final from, final to, final since)?) {
    result.add(Finding('gain:$name:${last.date.toIso8601String()}', FindingType.gain,
        'Fortschritt: $name ${weightNum(from)} → ${weightLabel(to)}', 'Seit ${_date(since)}',
        source: statsAt(StatsView.exercise, exercise: name, dates: [since, last.date])));
  }

  const marks = [10, 25, 50, 75, 100, 150, 200, 250, 300, 400, 500];
  if (marks.contains(sessions.length)) {
    result.add(Finding('milestone:${sessions.length}', FindingType.milestone, '${sessions.length}. Training geschafft',
        'Seit ${_date(sessions.last.date)}${sessions.last.date.year}', source: statsAt(StatsView.history)));
  }

  // A record month, broken by the last training.
  final perMonth = <int, int>{};
  for (final s in sessions) {
    perMonth.update(s.date.year * 12 + s.date.month, (n) => n + 1, ifAbsent: () => 1);
  }
  final key = last.date.year * 12 + last.date.month;
  final thisMonth = perMonth.remove(key) ?? 0;
  if (perMonth.isNotEmpty && thisMonth == perMonth.values.reduce(max) + 1) {
    result.add(Finding('month:$key', FindingType.month, 'Rekordmonat: $thisMonth Trainings', 'So viele wie noch nie',
        source: statsAt(StatsView.history, dates: [last.date])));
  }
  return result;
}
