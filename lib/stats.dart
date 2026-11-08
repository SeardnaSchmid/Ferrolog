import 'dart:math';

import 'package:flutter/material.dart';

import 'balance_card.dart';
import 'body_map.dart';
import 'findings.dart';
import 'main.dart';
import 'model.dart';
import 'muscles.dart';
import 'units.dart';

/// Series colors, fixed order (a colorblind-safe categorical palette); an exercise keeps its color
/// however the period changes. Past six exercises the chart folds the rest away.
const _seriesLight = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100), Color(0xFFE87BA4), Color(0xFF008300)];
const _seriesDark = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500), Color(0xFFD55181), Color(0xFF008300)];

/// Dash pattern per series, so lines differ by more than color.
const _dashes = <List<double>>[[], [6, 3], [2, 2], [8, 3, 2, 3], [1, 3], [10, 4]];

/// The muscles listed under the body map; the small ones show on the map only.
const _mainMuscles = [
  Muscle.chest, Muscle.shoulders, Muscle.triceps, Muscle.biceps, Muscle.lats, Muscle.middleBack,
  Muscle.lowerBack, Muscle.abdominals, Muscle.quadriceps, Muscle.hamstrings, Muscle.glutes, Muscle.calves,
];

/// Period picked on the statistics (days, 0 = all), shared by the overview and the exercise page.
int get statsDays => prefs.getInt('stats.days') ?? 90;

DateTime? periodStart(int days) => days == 0 ? null : DateTime.now().subtract(Duration(days: days));

/// Where the statistics tab goes the next time it opens, set by a finding ("In der Statistik ansehen").
final statsFocus = ValueNotifier<StatsTarget?>(null);

Widget periodPicker(int days, ValueChanged<int> onChanged) => SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 30, label: Text('30 Tage')),
        ButtonSegment(value: 90, label: Text('90 Tage')),
        ButtonSegment(value: 365, label: Text('1 Jahr')),
        ButtonSegment(value: 0, label: Text('Gesamt')),
      ],
      selected: {days},
      onSelectionChanged: (v) {
        prefs.setInt('stats.days', v.single);
        onChanged(v.single);
      },
    );

/// Strength exercises with weight, most trained first (ties by name): this order picks the colors.
List<String> strengthExercises() => [
      for (final name in store.loggedExercises)
        if (store.historyOf(name).lastOrNull?.$2 case final l? when !l.cardio && !l.timed && l.weight > 0) name,
    ]..sort((a, b) => switch (store.historyOf(b).length.compareTo(store.historyOf(a).length)) {
        0 => a.compareTo(b),
        final c => c,
      });

/// Overview, top to bottom: period, strength of every exercise in one chart, the exercises with their
/// trend, key figures with trainings per week, muscles, cardio.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int days = statsDays;

  /// A finding's target: its card scrolled into view and outlined for a moment, the pair in it too.
  StatsTarget? focus;
  final balanceKey = GlobalKey(), weeksKey = GlobalKey();
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  /// Scrolls [key]'s card to the top. The list only builds what's near the screen, so it pages down
  /// until the card exists.
  void reveal(GlobalKey key, [int tries = 12]) {
    final card = key.currentContext;
    if (card != null && card.mounted) {
      Scrollable.ensureVisible(card, duration: const Duration(milliseconds: 400), curve: Curves.easeOut, alignment: .05);
      return;
    }
    if (tries == 0 || !scroll.hasClients) return;
    final p = scroll.position;
    scroll.jumpTo(min(p.pixels + p.viewportDimension * .8, p.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => reveal(key, tries - 1));
  }

  @override
  void initState() {
    super.initState();
    final target = statsFocus.value;
    if (target == null) return;
    statsFocus.value = null;
    focus = target;
    days = 30; // the findings look at four weeks (the balance card always does); the remembered period stays
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reveal(target.view == StatsView.balance ? balanceKey : weeksKey);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => focus = null);
      });
    });
  }

  /// What the strength chart shows. Remembered.
  _ChartMode mode = _ChartMode.values.asNameMap()[prefs.getString('stats.chart')] ?? _ChartMode.percent;

  /// Exercises switched off in the chart's legend.
  final hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final sessions = store.sessions;
    if (sessions.isEmpty) return const Center(child: Text('Statistiken gibt’s nach dem ersten Training.'));
    final now = DateTime.now();
    final from = periodStart(days);
    final inPeriod = [for (final s in sessions) if (from == null || s.date.isAfter(from)) s];
    final p = periodStats(sessions, now, days: days == 0 ? null : days);
    final c = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, color: c.onSurfaceVariant);

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(12),
      children: [
        periodPicker(days, (d) => setState(() => days = d)),
        const SizedBox(height: 8),
        if (inPeriod.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Kein Training in diesem Zeitraum.', textAlign: TextAlign.center, style: small),
          )
        else ...[
          ?progressSection(from, c, small),
          exercisesSection(from, now, c, small),
          const SizedBox(height: 8),
          figures(p, c, small),
          KeyedSubtree(key: weeksKey, child: weeksSection(sessions, now, p.weeks, c, small)),
          if (balanceSection(sessions, now) case final b?) KeyedSubtree(key: balanceKey, child: b),
          musclesSection(inPeriod, p.weeks, c, small),
          ?cardioSection(sessions, now, p.weeks, c),
        ],
      ],
    );
  }

  Widget section(String title, String? trailing, List<Widget> children,
      {VoidCallback? onTap, VoidCallback? onInfo, bool highlight = false}) {
    final c = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: highlight
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.tertiary, width: 2))
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(
                child: Row(children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  if (onInfo != null)
                    IconButton(
                      icon: Icon(Icons.info_outline, size: 18, color: c.onSurfaceVariant),
                      tooltip: 'Hintergrund',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: onInfo,
                    ),
                ]),
              ),
              if (trailing != null) Text(trailing, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      ),
    );
  }

  /// Every strength exercise in one chart: the 1RM's change since the start of the period (the baseline)
  /// in percent (comparable across light and heavy lifts) or kg, or the working weight; setbacks as
  /// triangles. The legend names each exercise's change. Tap: details.
  Widget? progressSection(DateTime? from, ColorScheme c, TextStyle small) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final names = strengthExercises();
    final series = <ChartSeries>[];
    final deltas = <String, (double, double)>{}; // 1RM change since the baseline: (kg, %)
    for (final (i, name) in names.take(6).indexed) {
      final history = store.historyOf(name);
      final out = setbacks(history);
      final points = [
        for (final (j, (date, log)) in history.indexed)
          if (from == null || date.isAfter(from)) (date, estimated1rm(log), log.weight, out.contains(j)),
      ];
      if (points.isEmpty) continue;
      final base = points.first.$2;
      deltas[name] = (shown(points.last.$2) - shown(base), base == 0 ? 0.0 : (points.last.$2 / base - 1) * 100);
      series.add(ChartSeries(
        name,
        (dark ? _seriesDark : _seriesLight)[i],
        _dashes[i],
        [
          for (final (d, e1, kg, _) in points)
            (
              d,
              switch (mode) {
                _ChartMode.percent => base == 0 ? 0.0 : (e1 / base - 1) * 100,
                _ChartMode.deltaKg => shown(e1) - shown(base),
                _ChartMode.weight => shown(kg),
              }
            ),
        ],
        {for (final (j, pt) in points.indexed) if (pt.$4) j},
        hidden: hidden.contains(name),
      ));
    }
    if (series.isEmpty) return null;
    final first = series.map((s) => s.points.first.$1).reduce((a, b) => a.isBefore(b) ? a : b);
    return section('Kraftentwicklung', null, onTap: () => openExercise(series.first.name), [
      SegmentedButton<_ChartMode>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          const ButtonSegment(value: _ChartMode.percent, label: Text('Δ %')),
          ButtonSegment(value: _ChartMode.deltaKg, label: Text('Δ $unitLabel')),
          ButtonSegment(value: _ChartMode.weight, label: Text(unitLabel)),
        ],
        selected: {mode},
        onSelectionChanged: (v) {
          prefs.setString('stats.chart', v.single.name);
          setState(() => mode = v.single);
        },
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final s in series)
          InkWell(
            onTap: () => setState(() => hidden.contains(s.name) ? hidden.remove(s.name) : hidden.add(s.name)),
            child: Opacity(
              opacity: s.hidden ? .35 : 1,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CustomPaint(size: const Size(18, 8), painter: _LegendLine(s.color, s.dash)),
                const SizedBox(width: 5),
                Text.rich(TextSpan(children: [
                  TextSpan(text: s.name),
                  if (deltas[s.name] case (final kg, final pct))
                    TextSpan(
                      text: '  ${signed(kg)} $unitLabel · ${signed(pct.roundToDouble())} %',
                      style: TextStyle(fontWeight: FontWeight.w600, color: kg < 0 ? c.tertiary : c.onSurface),
                    ),
                ]), style: small),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 220,
        child: CustomPaint(
          size: Size.infinite,
          painter: ProgressChart(
            series,
            from ?? first,
            DateTime.now(),
            unit: switch (mode) { _ChartMode.percent => '%', _ChartMode.deltaKg => unitLabel, _ChartMode.weight => '' },
            signed: mode != _ChartMode.weight,
            grid: c.outlineVariant.withValues(alpha: .5),
            label: c.onSurfaceVariant,
            surface: c.surfaceContainerLow,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        switch (mode) {
          _ChartMode.weight => 'Arbeitsgewicht, wie es die Progression vorgibt; Zacken nach unten sind Deloads. ▲ = Rückschritt.',
          _ => 'Veränderung des geschätzten 1RM (aus allen Sätzen) seit dem ersten Training im Zeitraum, der Baseline. '
              '▲ = Rückschritt: weniger geschafft als zuletzt oder als schon einmal bei diesem Gewicht.',
        },
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
      ),
    ]);
  }

  void openExercise(String name) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseStats(name))).then((_) => setState(() => days = statsDays));

  /// Exercises trained in the period, most often first; with weight: 1RM line, best 1RM and the trend
  /// of the last four weeks.
  Widget exercisesSection(DateTime? from, DateTime now, ColorScheme c, TextStyle small) {
    final rows = [
      for (final name in store.loggedExercises)
        (name, store.historyOf(name), [for (final (d, l) in store.historyOf(name)) if (from == null || d.isAfter(from)) l]),
    ].where((e) => e.$3.isNotEmpty).toList()
      ..sort((a, b) => b.$3.length.compareTo(a.$3.length));
    final colored = strengthExercises();
    final palette = Theme.of(context).brightness == Brightness.dark ? _seriesDark : _seriesLight;
    return section('Übungen', 'Status: letzte 4 Wochen', [
      for (final (name, history, logs) in rows)
        InkWell(
          onTap: () => openExercise(name),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 15)),
                  Text(
                    logs.last.cardio || logs.last.timed || logs.last.weight == 0
                        ? exerciseLine(logs)
                        : '${logs.length}× · 1RM ${weightLabel(roundedKg(logs.map(estimated1rm).reduce(max)))}',
                    style: small,
                  ),
                ]),
              ),
              if (!logs.last.cardio && !logs.last.timed && logs.last.weight > 0) ...[
                CustomPaint(
                  size: const Size(64, 26),
                  // Same color as in the chart above.
                  painter: Sparkline([for (final l in logs.skip(max(0, logs.length - 12))) estimated1rm(l)],
                      switch (colored.indexOf(name)) { final i when i >= 0 && i < 6 => palette[i], _ => c.primary }),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 118,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(fit: BoxFit.scaleDown, child: TrendChip(trendOf(history, now))),
                  ),
                ),
              ] else
                Icon(Icons.chevron_right, color: c.onSurfaceVariant),
            ]),
          ),
        ),
    ]);
  }

  /// Four tiles: trainings per week against the goal, average duration, volume against the period
  /// before, records (how many lifts set one, and the latest; a count of records would only grow with
  /// linear progression).
  Widget figures(PeriodStats p,
      ColorScheme c, TextStyle small) {
    String num1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    Widget tile(IconData icon, String label, String value, String? sub, [Color? subColor]) => Expanded(
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 16, color: c.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: small)),
                ]),
                const SizedBox(height: 4),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text(sub ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: small.copyWith(color: subColor)),
              ]),
            ),
          ),
        );
    final delta = switch (p.volumeBefore) {
      final b? when b > 0 => ((p.volume / b - 1) * 100).round(),
      _ => null,
    };
    return Column(children: [
      Row(children: [
        tile(Icons.calendar_view_week, 'Pro Woche', num1(p.perWeek), 'Ziel ${weeklyGoal.value} · ${p.trainings} Trainings',
            p.perWeek >= weeklyGoal.value ? c.primary : null),
        tile(Icons.timer_outlined, 'Ø Dauer', switch (p.avgDuration) { final d? => durationLabel(d), null => '–' }, null),
      ]),
      Row(children: [
        tile(Icons.stacked_bar_chart, 'Volumen', volumeLabel(p.volume),
            delta == null ? null : '${delta >= 0 ? '+' : '−'}${delta.abs()} % zum Zeitraum davor', delta != null && delta < 0 ? c.tertiary : c.primary),
        tile(Icons.emoji_events_outlined, 'Übungen mit Rekord', p.lifts == 0 ? '–' : '${p.recordLifts} von ${p.lifts}',
            switch (p.lastRecord) { (final name, _, final d)? => '${ago(d)[0].toUpperCase()}${ago(d).substring(1)}: $name', null => 'kein neues Höchstgewicht' }),
      ]),
    ]);
  }

  /// Trainings per calendar week of the period (at most half a year of bars) against the goal.
  Widget weeksSection(List<Session> sessions, DateTime now, double periodWeeks, ColorScheme c, TextStyle small) {
    final weeks = weeklySummary(sessions, now, weeks: periodWeeks.ceil().clamp(4, 26));
    final goal = weeklyGoal.value;
    return section('Trainings pro Woche', 'Ziel $goal×', highlight: focus?.view == StatsView.weeks, [
      SizedBox(
        height: 150,
        child: CustomPaint(
          size: Size.infinite,
          painter: BarChart(
            [for (final w in weeks) w.$2.toDouble()],
            [for (final w in weeks) weekLabel(w.$1)],
            goal: goal.toDouble(),
            hit: c.primary,
            miss: c.outlineVariant,
            label: c.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text('${weeks.where((w) => w.$2 >= goal).length} von ${weeks.length} Wochen mit Ziel erreicht', style: small),
    ]);
  }

  /// The balance card: the pairs of the last four weeks as scales, independent of the period (the
  /// findings look at the same four weeks), and the strength ratios over 90 days as a course.
  Widget? balanceSection(List<Session> sessions, DateTime now) {
    final recent = [for (final s in sessions) if (now.difference(s.date).inDays < balanceDays) s];
    final pairs = balances(recent, weeks: periodStats(sessions, now, days: balanceDays).weeks);
    if (pairs.isEmpty) return null;
    final trends = strengthTrends([for (final s in sessions) if (now.difference(s.date).inDays < 90) s]);
    return section('Balance', '$balanceDays Tage',
        onInfo: () => showBalanceInfo(context), highlight: focus?.view == StatsView.balance, [
      BalanceBody(pairs, recent, trends, focus: focus?.pair),
    ]);
  }

  /// Sets per muscle and week: the body map in fixed steps (so it shows too little, not just the most),
  /// then each main muscle against 10–20 sets. Tap a muscle for the exercises behind it.
  Widget musclesSection(List<Session> sessions, double weeks, ColorScheme c, TextStyle small) {
    final perWeek = {for (final e in setsPerSingleMuscle(sessions).entries) e.key: e.value / weeks};
    if (perWeek.values.every((v) => v == 0)) return const SizedBox();
    final never = [for (final m in _mainMuscles) if (perWeek[m] == 0) m.label];
    const maxSets = 25.0;
    String n(double v) => v == 0 ? '–' : v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',');
    Widget swatch(double level, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color.lerp(c.onSurface.withValues(alpha: .16), c.primary, level),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(text, style: small),
        ]);
    return section('Muskeln', 'Sätze pro Woche', [
      Center(
        child: BodyMap.heat(
          {for (final e in perWeek.entries) e.key: muscleLevel(e.value)},
          height: 220,
          onTap: (m) => showMuscle(m, perWeek[m] ?? 0, sessions),
        ),
      ),
      const SizedBox(height: 4),
      Text('Tippe auf einen Muskel für seine Übungen', textAlign: TextAlign.center, style: small),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 4, children: [
        swatch(.35, 'unter 5'),
        swatch(.6, '5–10'),
        swatch(.82, '10–20'),
        swatch(1, 'über 20'),
      ]),
      if (never.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Nicht trainiert: ${never.join(', ')}', style: small.copyWith(color: c.tertiary, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 12),
      for (final m in _mainMuscles)
        InkWell(
          onTap: () => showMuscle(m, perWeek[m]!, sessions),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 118, child: Text(m.label, style: const TextStyle(fontSize: 14))),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  double x(double v) => box.maxWidth * min(v, maxSets) / maxSets;
                  final v = perWeek[m]!;
                  return SizedBox(
                    height: 12,
                    child: Stack(children: [
                      Positioned.fill(
                        child: DecoratedBox(
                            decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                      ),
                      // Target band.
                      Positioned(
                        left: x(10),
                        width: x(20) - x(10),
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                            decoration: BoxDecoration(color: c.primary.withValues(alpha: .35), borderRadius: BorderRadius.circular(2))),
                      ),
                      Positioned(
                        left: 0,
                        width: x(v),
                        top: 3,
                        bottom: 3,
                        child: DecoratedBox(
                            decoration: BoxDecoration(color: v < 10 ? c.tertiary : c.primary, borderRadius: BorderRadius.circular(3))),
                      ),
                    ]),
                  );
                }),
              ),
              SizedBox(width: 44, child: Text(n(perWeek[m]!), textAlign: TextAlign.end, style: small)),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        'Band: 10–20 Sätze pro Woche, ein Richtwert für Muskelaufbau. Kraftprogramme wie 5×5 lassen bewusst '
        'Muskeln aus. Hilfsmuskeln zählen halb.',
        style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
      ),
    ]);
  }

  void showMuscle(Muscle m, double perWeek, List<Session> sessions) {
    final c = Theme.of(context).colorScheme;
    final exercises = exercisesFor(m, sessions);
    String n(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',');
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            Text('${n(perWeek)} Sätze pro Woche', style: TextStyle(color: c.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (exercises.isEmpty)
              const Text('Keine Übung im Zeitraum trainiert diesen Muskel.')
            else
              for (final (name, sets) in exercises)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(name)),
                    Text('${n(sets)} Sätze', style: TextStyle(color: c.onSurfaceVariant)),
                  ]),
                ),
          ]),
        ),
      ),
    );
  }

  Widget? cardioSection(List<Session> sessions, DateTime now, double periodWeeks, ColorScheme c) {
    final weeks = weeklySummary(sessions, now, weeks: periodWeeks.ceil().clamp(4, 26));
    if (!weeks.any((w) => w.$3 > 0)) return null;
    return section('Cardio pro Woche', 'Minuten', [
      SizedBox(
        height: 130,
        child: CustomPaint(
          size: Size.infinite,
          painter: BarChart(
            [for (final w in weeks) w.$3.toDouble()],
            [for (final w in weeks) weekLabel(w.$1)],
            hit: c.tertiary,
            miss: c.tertiary,
            label: c.onSurfaceVariant,
          ),
        ),
      ),
    ]);
  }

  /// "12× · Gesamt 7,2 t", cardio "8× · 240 Min · 35 km gesamt", without weight "6× · 18 Sätze".
  static String exerciseLine(List<ExerciseLog> logs) {
    final n = '${logs.length}×';
    if (logs.last.cardio) {
      final km = logs.fold(0.0, (k, l) => k + (l.km ?? 0));
      return '$n · ${cardioLabel(logs.fold<int>(0, (m, l) => m + (l.reps.first ?? 0)), km > 0 ? km : null)} gesamt';
    }
    if (logs.last.timed) {
      final best = logs.map((l) => l.weight).reduce(max);
      return '$n · ${logs.fold(0, (s, l) => s + l.setsDone)} Sätze${best > 0 ? ' · bis ${weightLabel(best)}' : ''}';
    }
    if (logs.last.weight == 0) return '$n · ${logs.fold(0, (s, l) => s + l.setsDone)} Sätze';
    return '$n · Gesamt ${volumeLabel(logs.fold(0.0, (v, l) => v + l.volume))}';
  }
}

enum _ChartMode { percent, deltaKg, weight }

/// "+4,5", "−2", "0" with one decimal at most.
String signed(double v) {
  final n = (v.abs() * 10).round() / 10;
  final text = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1).replaceAll('.', ',');
  return n == 0 ? '0' : '${v > 0 ? '+' : '−'}$text';
}

String weekLabel(DateTime monday) => '${monday.day}.${monday.month}.';

/// An estimate shown to the half unit (±0,5).
double roundedKg(double kg) => toKg((shown(kg) * 2).round() / 2);

/// Body map shade for sets per week: 0, under 5, 5–10, 10–20, over 20.
double muscleLevel(double perWeek) => switch (perWeek) {
      0 => 0,
      < 5 => .35,
      < 10 => .6,
      <= 20 => .82,
      _ => 1,
    };

/// "steigt +4 %", "stabil +1 %", "hängt fest −2 %" for the last four weeks.
class TrendChip extends StatelessWidget {
  final (Trend, double)? trend;
  const TrendChip(this.trend, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = trend;
    if (t == null) return Text('neu', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant));
    final (label, bg, fg) = switch (t.$1) {
      Trend.up => ('steigt', c.primaryContainer, c.onPrimaryContainer),
      Trend.flat => ('stabil', c.surfaceContainerHighest, c.onSurfaceVariant),
      Trend.stuck => ('hängt fest', c.tertiaryContainer, c.onTertiaryContainer),
    };
    final pct = t.$2.round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (t.$1 == Trend.stuck) ...[Icon(Icons.warning_amber_rounded, size: 13, color: fg), const SizedBox(width: 3)],
        Text('$label ${pct >= 0 ? '+' : '−'}${pct.abs()} %',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

/// One exercise: switch exercise, period and measure (weight, 1RM, volume), its chart with setbacks
/// and every training of the period.
class ExerciseStats extends StatefulWidget {
  final String name;

  /// Trainings a finding points to: tinted in the list; those without a set of it (left out) named on top.
  final List<DateTime> marked;
  const ExerciseStats(this.name, {super.key, this.marked = const []});

  @override
  State<ExerciseStats> createState() => _ExerciseStatsState();
}

enum _Measure { weight, e1rm, volume }

class _ExerciseStatsState extends State<ExerciseStats> {
  late String name = widget.name;
  // Wide enough for the marked trainings.
  late int days = widget.marked.every((d) => !d.isBefore(periodStart(statsDays) ?? DateTime(0))) ? statsDays : 0;
  // Holds have no 1RM: their weight is what counts.
  late _Measure measure = store.historyOf(name).lastOrNull?.$2.timed ?? false ? _Measure.weight : _Measure.e1rm;

  /// A training a finding points to, for the exercise it was about.
  bool isMarked(DateTime d) => name == widget.name && widget.marked.contains(d);

  /// Marked trainings without a set of this exercise: left out.
  List<DateTime> skippedOn(List<(DateTime, ExerciseLog)> history) => name != widget.name
      ? const []
      : ([for (final d in widget.marked) if (!history.any((h) => h.$1 == d)) d]..sort());

  @override
  Widget build(BuildContext context) {
    final history = store.historyOf(name);
    if (history.lastOrNull?.$2.cardio ?? false) return _cardioStats(context, name, history);
    final c = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    final from = periodStart(days);
    final out = setbacks(history);
    final shownHistory = [for (final (i, h) in history.indexed) if (from == null || h.$1.isAfter(from)) (i, h)];
    double value(ExerciseLog l) => switch (measure) {
          _Measure.weight => shown(l.weight),
          _Measure.e1rm => shown(estimated1rm(l)),
          _Measure.volume => shown(l.volume),
        };
    final names = strengthExercises();
    final colorIndex = max(0, names.indexOf(name)) % 6;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final trend = trendOf(history, DateTime.now());
    final best = history.isEmpty ? 0.0 : history.map((h) => estimated1rm(h.$2)).reduce(max);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (names.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final n in names)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(n),
                      selected: n == name,
                      onSelected: (_) => setState(() => name = n),
                    ),
                  ),
              ]),
            ),
          if (skippedOn(history) case final skipped when skipped.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.tertiaryContainer.withValues(alpha: .35), borderRadius: BorderRadius.circular(12)),
              child: Text('Ausgelassen am ${skipped.map((d) => '${d.day}.${d.month}.').join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 12),
          periodPicker(days, (d) => setState(() => days = d)),
          const SizedBox(height: 8),
          SegmentedButton<_Measure>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Measure.weight, label: Text('Gewicht')),
              ButtonSegment(value: _Measure.e1rm, label: Text('1RM')),
              ButtonSegment(value: _Measure.volume, label: Text('Volumen')),
            ],
            selected: {measure},
            onSelectionChanged: (v) => setState(() => measure = v.single),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Bestes 1RM ${weightLabel(roundedKg(best))}', style: const TextStyle(fontWeight: FontWeight.w600))),
            if (!(history.lastOrNull?.$2.weight == 0)) TrendChip(trend),
          ]),
          const SizedBox(height: 12),
          if (shownHistory.isEmpty)
            Text('Kein Training in diesem Zeitraum.', style: small)
          else
            SizedBox(
              height: 220,
              child: CustomPaint(
                size: Size.infinite,
                painter: ProgressChart(
                  [
                    ChartSeries(
                      name,
                      (dark ? _seriesDark : _seriesLight)[colorIndex],
                      const [],
                      [for (final (_, (d, l)) in shownHistory) (d, value(l))],
                      {for (final (j, (i, _)) in shownHistory.indexed) if (out.contains(i)) j},
                      dots: true,
                    ),
                  ],
                  from ?? shownHistory.first.$2.$1,
                  DateTime.now(),
                  grid: c.outlineVariant.withValues(alpha: .5),
                  label: c.onSurfaceVariant,
                  surface: c.surface,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            switch (measure) {
              _Measure.weight => 'Arbeitsgewicht ($unitLabel). ▲ = Rückschritt.',
              _Measure.e1rm => 'Geschätztes 1RM aus allen Sätzen ($unitLabel). ▲ = Rückschritt.',
              _Measure.volume => 'Volumen: Gewicht × Wiederholungen ($unitLabel). ▲ = Rückschritt.',
            },
            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
          ),
          const Divider(height: 32),
          for (final (i, (date, log)) in shownHistory.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: isMarked(date) ? 8 : 0),
              tileColor: isMarked(date) ? c.tertiaryContainer.withValues(alpha: .35) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Text('${log.weight > 0 ? '${weightLabel(log.weight)} × ' : ''}${log.reps.map((r) => r ?? '–').join('/')}'),
              subtitle: Text(dateLabel(date)),
              trailing: out.contains(i)
                  ? Icon(Icons.change_history, color: c.tertiary)
                  : Icon(log.succeeded ? Icons.check_circle : Icons.remove_circle_outline,
                      color: log.succeeded ? c.primary : c.outline),
            ),
        ],
      ),
    );
  }
}

/// One line of a [ProgressChart]: (date, value) oldest first; [setbacks] are point indexes drawn as
/// triangles.
class ChartSeries {
  final String name;
  final Color color;
  final List<double> dash;
  final List<(DateTime, double)> points;
  final Set<int> setbacks;
  final bool hidden, dots;
  const ChartSeries(this.name, this.color, this.dash, this.points, this.setbacks, {this.hidden = false, this.dots = false});
}

/// Lines over real time (gaps like a holiday stay visible) on one y-axis with a few round ticks.
class ProgressChart extends CustomPainter {
  final List<ChartSeries> series;
  final DateTime from, to;

  /// After the tick labels, e.g. "%".
  final String unit;

  /// Changes around a baseline: ticks with a sign and a stronger zero line.
  final bool signed;
  final Color grid, label, surface;
  ProgressChart(this.series, this.from, this.to,
      {this.unit = '', this.signed = false, required this.grid, required this.label, required this.surface});

  @override
  void paint(Canvas canvas, Size size) {
    final visible = series.where((s) => !s.hidden && s.points.isNotEmpty).toList();
    final values = [for (final s in visible) for (final p in s.points) p.$2, if (signed) 0.0];
    if (values.isEmpty) return;
    var lo = values.reduce(min), hi = values.reduce(max);
    if (hi - lo < 1) (lo, hi) = (lo - 1, hi + 1);
    // Round step giving about four ticks.
    final raw = (hi - lo) / 4;
    final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
    final step = [1, 2, 2.5, 5, 10].map((m) => m * mag).firstWhere((s) => s >= raw);
    lo = (lo / step).floor() * step;
    hi = (hi / step).ceil() * step;

    TextPainter text(String s) => TextPainter(
          text: TextSpan(text: s, style: TextStyle(color: label, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
    String tick(double v) {
      final n = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');
      return '${signed && v > 0 ? '+' : ''}$n${unit.isEmpty ? '' : ' $unit'}';
    }

    final left = [for (var v = lo; v <= hi + step / 2; v += step) text(tick(v)).width].reduce(max) + 6;
    const bottom = 16.0, top = 6.0;
    final w = size.width - left - 4, h = size.height - bottom - top;
    final span = max(1, to.difference(from).inHours);
    double x(DateTime d) => left + w * (d.difference(from).inHours / span).clamp(0, 1);
    double y(double v) => top + h * (1 - (v - lo) / (hi - lo));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = lo; v <= hi + step / 2; v += step) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)),
          signed && v.abs() < step / 2 ? (Paint()..color = label.withValues(alpha: .6)) : gridPaint);
      final tp = text(tick(v));
      tp.paint(canvas, Offset(left - 6 - tp.width, y(v) - tp.height / 2));
    }
    // Four dates along the bottom.
    for (var i = 0; i <= 3; i++) {
      final d = from.add(Duration(hours: (span * i / 3).round()));
      final tp = text('${d.day}.${d.month}.');
      final cx = (x(d) - tp.width / 2).clamp(left, size.width - tp.width);
      tp.paint(canvas, Offset(cx, size.height - tp.height));
    }

    for (final s in visible) {
      final pts = [for (final p in s.points) Offset(x(p.$1), y(p.$2))];
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..addPolygon(pts, false);
      if (s.dash.isEmpty) {
        canvas.drawPath(path, line);
      } else {
        for (final metric in path.computeMetrics()) {
          var d = 0.0, k = 0;
          while (d < metric.length) {
            final len = s.dash[k % s.dash.length];
            if (k.isEven) canvas.drawPath(metric.extractPath(d, d + len), line);
            d += len;
            k++;
          }
        }
      }
      final fill = Paint()..color = s.color;
      if (s.dots || pts.length == 1) {
        for (final p in pts) {
          canvas.drawCircle(p, 3, fill);
        }
      }
      // Setbacks: a triangle with a ring of the background, so it stands out on crossing lines.
      for (final i in s.setbacks) {
        if (i >= pts.length) continue;
        final p = pts[i];
        final tri = Path()
          ..moveTo(p.dx, p.dy - 6)
          ..lineTo(p.dx + 5.5, p.dy + 4)
          ..lineTo(p.dx - 5.5, p.dy + 4)
          ..close();
        canvas.drawPath(
            tri,
            Paint()
              ..color = surface
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        canvas.drawPath(tri, fill);
      }
    }
  }

  @override
  bool shouldRepaint(ProgressChart old) => true;
}

/// The short line in the chart legend, dashed like its series.
class _LegendLine extends CustomPainter {
  final Color color;
  final List<double> dash;
  const _LegendLine(this.color, this.dash);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final y = size.height / 2;
    if (dash.isEmpty) return canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    var x = 0.0, k = 0;
    while (x < size.width) {
      final len = dash[k % dash.length];
      if (k.isEven) canvas.drawLine(Offset(x, y), Offset(min(x + len, size.width), y), paint);
      x += len;
      k++;
    }
  }

  @override
  bool shouldRepaint(_LegendLine old) => old.color != color;
}

/// Tiny line of the last values, scaled to its own range.
class Sparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  const Sparkline(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(min), hi = values.reduce(max);
    final range = hi - lo == 0 ? 1 : hi - lo;
    final pts = [
      for (final (i, v) in values.indexed)
        Offset(size.width * i / (values.length - 1), 2 + (size.height - 4) * (1 - (v - lo) / range)),
    ];
    canvas.drawPath(
      Path()..addPolygon(pts, false),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(Sparkline old) => old.values != values || old.color != color;
}

/// Bars for e.g. trainings per week: [hit] color when the value reaches [goal] (or always without
/// one), a dashed goal line, the value above each bar and a label below.
class BarChart extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double? goal;
  final Color hit, miss, label;
  BarChart(this.values, this.labels, {this.goal, required this.hit, required this.miss, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 18.0, top = 16.0;
    final top0 = max(values.fold(0.0, max), goal ?? 0);
    final hi = top0 == 0 ? 1 : top0;
    final h = size.height - bottom - top;
    final slot = size.width / values.length;
    final barW = min(28.0, slot * .6);
    double y(double v) => top + h * (1 - v / hi);
    void text(String s, Offset center, {bool bold = false}) {
      final tp = TextPainter(
        text: TextSpan(
            text: s, style: TextStyle(color: label, fontSize: 10, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    // Labels on every bar while they fit, else on every n-th (and the last).
    final every = max(1, (36 / slot).ceil());
    for (final (i, v) in values.indexed) {
      final x = slot * i + slot / 2;
      final reached = goal == null || v >= goal!;
      if (v > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTRB(x - barW / 2, y(v), x + barW / 2, top + h),
              topLeft: const Radius.circular(5), topRight: const Radius.circular(5)),
          Paint()..color = reached ? hit : miss,
        );
        if (slot >= 14) text(v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1), Offset(x, y(v) - 8), bold: true);
      }
      if ((values.length - 1 - i) % every == 0) text(labels[i], Offset(x, size.height - bottom / 2));
    }
    if (goal case final g?) {
      final paint = Paint()
        ..color = hit.withValues(alpha: .6)
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y(g)), Offset(min(x + 4, size.width), y(g)), paint);
      }
    }
    canvas.drawLine(Offset(0, top + h), Offset(size.width, top + h), Paint()..color = miss);
  }

  @override
  bool shouldRepaint(BarChart old) => true;
}

/// Cardio: minutes per session as the line, over time.
Widget _cardioStats(BuildContext context, String name, List<(DateTime, ExerciseLog)> history) {
  final scheme = Theme.of(context).colorScheme;
  final minutes = history.fold(0, (n, h) => n + (h.$2.reps.first ?? 0));
  return Scaffold(
    appBar: AppBar(title: Text(name)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Minuten pro Training', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: ProgressChart(
              [
                ChartSeries(name, scheme.tertiary, const [], [for (final h in history) (h.$1, (h.$2.reps.first ?? 0).toDouble())], const {},
                    dots: true),
              ],
              history.first.$1,
              DateTime.now(),
              grid: scheme.outlineVariant.withValues(alpha: .5),
              label: scheme.onSurfaceVariant,
              surface: scheme.surface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Gesamt: $minutes Min in ${history.length} Trainings'),
        const Divider(height: 32),
        for (final (date, log) in history.reversed)
          ListTile(
            dense: true,
            title: Text(cardioLabel(log.reps.first, log.km)),
            subtitle: Text(dateLabel(date)),
            trailing: Icon(log.succeeded ? Icons.check_circle : Icons.remove_circle_outline,
                color: log.succeeded ? scheme.primary : scheme.outline),
          ),
      ],
    ),
  );
}

