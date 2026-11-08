import 'dart:math';

import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'training_card.dart';
import 'timing.dart';

/// What [derivedStats] contains, for the AI reading the export.
const derivedFormat = 'derived = statistics FerroLog computed from workouts and sessions at exportedAt; read-only, '
    'recomputed on every export and sync, weights in kg. periods: key figures for the last 30/90/365 days and all '
    '(perWeek = trainings per week, volume = kg × reps, volumeBefore = the same span before, recordLifts = lifts '
    'heavier than ever before, an exercise\'s first training sets no record). Per week everywhere (perWeek, '
    'setsPerMuscleWeek, balance) divides by the weeks of the period, or since the first training in it when that is '
    'later, at least 1. exercises: per strength exercise (timed = held for seconds; bodyweight = no added weight; '
    'both without 1RM, with repsLast / repsBest = reps or seconds of all sets of a training) e1rm = estimated one-rep '
    'max (Epley, from the average reps of all sets), e1rmNow = best of the latest 4 trainings, trend over 28 days, '
    'only from 2 trainings on (up = 1RM, or reps × weight without one, +2 % or more, stuck = reps missed in 2 of the '
    'last 3, else flat), setbacks90d = trainings with fewer reps at a weight '
    'managed before, next = planned weight for next time. setsPerMuscleWeek: done sets per muscle and week, '
    'helpers counting half (10–20 is a common guide for muscle growth). balance: opposing sides, b against a, '
    'by done sets per week (helpers half), with the guide range (training practice, not a medical limit, the user '
    'can change it) and the side that lags, over the last 28 days (balance28d); strength90d: rows to bench press and '
    'deadlift to squat by 1RM in percent, at the start of the last 90 days and now, a course only. findings: what the app shows the user on the home '
    'card "Dein Training" right now, as switched on in the settings (kind action = something to act on, at most one '
    'piece of training advice at a time; positive = a success of the last training). type weekGoal, skipped (left out '
    'entirely at least twice in 4 weeks), balance, plateau, record, gain, milestone or month; title and evidence as shown (in the unit the user picked, the only place not in kg), '
    'why and advice as in the sheet that actions open, fix = the one-tap change offered (moveUp, dropSet; it never adds '
    'work), source = where the statistics show it (view balance with pair, exercise with the dates marked, weeks, history). minutesTypical / secondsSetToSet: median time an exercise took (setup and warm-ups '
    'included, from the set logged before it to its last set) and from one of its sets to the next (rest plus the set), '
    'from per-set timestamps (sessions[].exercises[].doneAt), latest 10 trainings. workoutMinutesEstimated: the app estimate '
    'per workout. weeks: trainings per calendar week (Monday) against goalPerWeek.';

/// Statistics for the export: the numbers behind the statistics page, balance and the findings,
/// so an AI doesn't have to recompute them (and get them wrong).
Map<String, dynamic> derivedStats(DateTime now) {
  final sessions = store.sessions;
  double r1(double v) => (v * 10).round() / 10;
  String day(DateTime d) => d.toIso8601String().substring(0, 10);

  Map<String, dynamic> period(int? days) {
    final p = periodStats(sessions, now, days: days);
    return {
      'trainings': p.trainings,
      'perWeek': r1(p.perWeek),
      'volume': p.volume.round(),
      if (p.volumeBefore != null) 'volumeBefore': p.volumeBefore!.round(),
      if (p.avgDuration != null) 'avgMinutes': p.avgDuration!.inMinutes,
      'lifts': p.lifts,
      'recordLifts': p.recordLifts,
      if (p.lastRecord case (final name, final kg, final d)?) 'lastRecord': {'exercise': name, 'kg': kg, 'date': day(d)},
    };
  }

  final plannedNext = {
    for (final w in store.workouts)
      for (final e in w.exercises)
        if (!e.cardio && !e.noWeight) e.name: e.weight,
  };
  final exercises = [
    for (final name in store.loggedExercises)
      if (store.historyOf(name) case final h when h.isNotEmpty && !h.last.$2.cardio)
        () {
          final e1rm = [for (final (_, l) in h) estimated1rm(l)];
          final bodyweight = h.every((x) => x.$2.weight == 0);
          final total = [for (final (_, l) in h) l.reps.fold(0, (n, r) => n + (r ?? 0))];
          final out = setbacks(h);
          final trend = trendOf(h, now);
          final times = [
            for (final s in sessions)
              for (final l in s.exercises)
                if (l.name == name) ?measured(s, l),
          ].take(10).toList();
          final gaps = [for (final m in times) ...m.gaps.map((g) => g.inSeconds.toDouble())];
          return {
            'name': name,
            if (h.last.$2.timed) 'timed': true,
            if (bodyweight) 'bodyweight': true,
            'trainings': h.length,
            'first': day(h.first.$1),
            'last': day(h.last.$1),
            if (!bodyweight) 'lastWeight': h.last.$2.weight,
            if (!bodyweight) 'bestWeight': h.map((x) => x.$2.weight).reduce(max),
            if (e1rm.any((v) => v > 0)) ...{
              'e1rmNow': r1(e1rm.reversed.take(4).reduce(max)),
              'e1rmBest': r1(e1rm.reduce(max)),
            } else ...{
              'repsLast': total.last,
              'repsBest': total.reduce(max),
            },
            if (trend != null) 'trend': trend.$1.name,
            if (trend != null) 'trendChangePct': r1(trend.$2),
            'setbacks90d': [for (final i in out) if (now.difference(h[i].$1).inDays <= 90) i].length,
            'next': ?plannedNext[name],
            if (times.isNotEmpty) 'minutesTypical': r1(median([for (final m in times) m.total.inSeconds / 60])),
            if (gaps.isNotEmpty) 'secondsSetToSet': median(gaps).round(),
          };
        }(),
  ];

  Map<String, double> perMuscle(int days) {
    final recent = [for (final s in sessions) if (now.difference(s.date).inDays < days) s];
    final weeks = periodStats(sessions, now, days: days).weeks;
    return {for (final e in setsPerSingleMuscle(recent).entries) e.key.label: r1(e.value / weeks)};
  }

  final pace = currentPace();
  final recent = [for (final s in sessions) if (now.difference(s.date).inDays < balanceDays) s];
  final weeks = periodStats(sessions, now, days: balanceDays).weeks;
  return {
    'about': derivedFormat,
    'periods': {'30d': period(30), '90d': period(90), '365d': period(365), 'all': period(null)},
    'exercises': exercises,
    'setsPerMuscleWeek': {'last28d': perMuscle(28), 'last90d': perMuscle(90)},
    'balance28d': [
      for (final b in balances(recent, weeks: weeks))
        {
          'pair': b.title,
          'a': {'group': b.aGroup, 'label': b.a, 'value': r1(b.aValue)},
          'b': {'group': b.bGroup, 'label': b.b, 'value': r1(b.bValue)},
          'ratio': b.ratio.isFinite ? (b.ratio * 100).round() / 100 : null,
          'guide': {'low': b.low, 'high': b.high.isFinite ? b.high : null},
          'lagging': b.lagging,
        },
    ],
    'strength90d': [
      for (final (name, start, current) in strengthTrends([for (final s in sessions) if (now.difference(s.date).inDays < 90) s]))
        {'pair': name, 'startPct': start.round(), 'nowPct': current.round()},
    ],
    'findings': [
      for (final f in openFindings())
        {
          'type': f.type.name,
          'kind': f.kind.name,
          'title': f.title,
          'evidence': f.evidence,
          'why': ?f.why,
          'advice': ?f.advice,
          if (f.fix case final fix?) 'fix': {'action': fix.name, 'exercise': f.exercise, 'workout': f.workout?.name},
          'source': {
            'view': f.source.view.name,
            'pair': ?f.source.pair?.name,
            'exercise': ?f.source.exercise,
            if (f.source.dates.isNotEmpty) 'dates': [for (final d in f.source.dates) day(d)],
          },
        },
    ],
    'goalPerWeek': weeklyGoal.value,
    'workoutMinutesEstimated': {for (final w in store.workouts) w.name: (pace.ofWorkout(w).inSeconds / 60).round()},
    'weeks': [for (final (monday, n, cardio) in weeklySummary(sessions, now, weeks: 12)) {'week': day(monday), 'trainings': n, if (cardio > 0) 'cardioMinutes': cardio}],
  };
}
