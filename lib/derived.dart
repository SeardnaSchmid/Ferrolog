import 'dart:math';

import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'tasks.dart';

/// What [derivedStats] contains, for the AI reading the export.
const derivedFormat = 'derived = statistics FerroLog computed from workouts and sessions at exportedAt; read-only, '
    'recomputed on every export and sync, weights in kg. periods: key figures for the last 30/90/365 days and all '
    '(perWeek = trainings per week, volume = kg × reps, volumeBefore = the same span before, recordLifts = lifts '
    'heavier than ever before). exercises: per strength exercise e1rm = estimated one-rep max (Epley, from the '
    'average reps of all sets), e1rmNow = best of the latest 4 trainings, trend over 28 days (up = 1RM +2 % or '
    'more, stuck = reps missed in 2 of the last 3, else flat), setbacks90d = trainings with fewer reps at a weight '
    'managed before, next = planned weight for next time. setsPerMuscleWeek: done sets per muscle and week, '
    'helpers counting half (10–20 is a common guide for muscle growth). balance: opposing sides, b against a, '
    'by current 1RM (barbell lifts) or by sets per week, with the guide range (training practice, not a medical '
    'limit) and the side that lags, over the last 90 days (balance90d). tasks: hints the app currently shows the user (empty when switched off). facts: motivating facts shown '
    'on the home screen. weeks: trainings per calendar week (Monday) against goalPerWeek.';

/// Statistics for the export: the numbers behind the statistics page, balance, tasks and insights,
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
      if (store.historyOf(name) case final h when h.isNotEmpty && !h.last.$2.cardio && h.any((x) => x.$2.weight > 0))
        () {
          final e1rm = [for (final (_, l) in h) estimated1rm(l)];
          final out = setbacks(h);
          final trend = trendOf(h, now);
          return {
            'name': name,
            'trainings': h.length,
            'first': day(h.first.$1),
            'last': day(h.last.$1),
            'lastWeight': h.last.$2.weight,
            'bestWeight': h.map((x) => x.$2.weight).reduce(max),
            'e1rmNow': r1(e1rm.reversed.take(4).reduce(max)),
            'e1rmBest': r1(e1rm.reduce(max)),
            if (trend != null) 'trend': trend.$1.name,
            if (trend != null) 'trendChangePct': r1(trend.$2),
            'setbacks90d': [for (final i in out) if (now.difference(h[i].$1).inDays <= 90) i].length,
            'next': ?plannedNext[name],
          };
        }(),
  ];

  Map<String, double> perMuscle(int days) {
    final recent = [for (final s in sessions) if (now.difference(s.date).inDays < days) s];
    return {for (final e in setsPerSingleMuscle(recent).entries) e.key.label: r1(e.value / (days / 7))};
  }

  final recent = [for (final s in sessions) if (now.difference(s.date).inDays < 90) s];
  final weeks = periodStats(sessions, now, days: 90).weeks;
  return {
    'about': derivedFormat,
    'periods': {'30d': period(30), '90d': period(90), '365d': period(365), 'all': period(null)},
    'exercises': exercises,
    'setsPerMuscleWeek': {'last28d': perMuscle(28), 'last90d': perMuscle(90)},
    'balance90d': [
      for (final b in balances(recent, weeks: weeks))
        {
          'pair': b.title,
          'basis': b.strength ? '1RM kg' : 'sets per week',
          'a': {'group': b.aGroup, 'label': b.a, 'value': r1(b.aValue)},
          'b': {'group': b.bGroup, 'label': b.b, 'value': r1(b.bValue)},
          'ratio': b.ratio.isFinite ? (b.ratio * 100).round() / 100 : null,
          'guide': {'low': b.low, 'high': b.high.isFinite ? b.high : null},
          'lagging': b.lagging,
        },
    ],
    'tasks': [if (prefs.getBool('home.tasks') ?? true) for (final t in openTasks()) {'title': t.title, 'why': t.why}],
    'facts': [for (final (_, text) in homeFacts(sessions, store.workouts, now, perWeek: weeklyGoal.value)) text],
    'goalPerWeek': weeklyGoal.value,
    'weeks': [for (final (monday, n, cardio) in weeklySummary(sessions, now, weeks: 12)) {'week': day(monday), 'trainings': n, if (cardio > 0) 'cardioMinutes': cardio}],
  };
}
