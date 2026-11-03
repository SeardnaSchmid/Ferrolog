import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';
import 'units.dart';

/// Epley estimate of the one-rep max from the best set.
double estimated1rm(ExerciseLog log) {
  final best = log.reps.whereType<int>().fold(0, max);
  return best == 0 ? 0 : log.weight * (1 + best / 30);
}

/// Overview: progress of one exercise and trainings per week right at the top, then totals and
/// the list of exercises.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  /// Period for the key figures and the exercise list, in days; 0 = all. Remembered.
  int days = prefs.getInt('stats.days') ?? 90;

  @override
  Widget build(BuildContext context) {
    final sessions = store.sessions;
    if (sessions.isEmpty) return const Center(child: Text('Statistiken gibt’s nach dem ersten Training.'));
    final now = DateTime.now();
    final p = periodStats(sessions, now, days: days == 0 ? null : days);
    final from = days == 0 ? null : now.subtract(Duration(days: days));
    final text = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    // Strength exercises with weight, most trained first; the chart shows the last one picked, else the top one.
    final strength = [
      for (final name in store.loggedExercises)
        if (store.historyOf(name).lastOrNull?.$2 case final l? when !l.cardio && l.weight > 0) name,
    ]..sort((a, b) => store.historyOf(b).length.compareTo(store.historyOf(a).length));
    final saved = prefs.getString('stats.exercise');
    final picked = strength.contains(saved) ? saved! : strength.firstOrNull;
    final weeks = weeklySummary(sessions, DateTime.now());
    final goal = weeklyGoal.value;

    String num1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    Widget tile(IconData icon, String label, String value) => Expanded(
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 16, color: c.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );

    Widget section(String title, String? trailing, List<Widget> children) => Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                if (trailing != null) Text(trailing, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
              ]),
              const SizedBox(height: 10),
              ...children,
            ]),
          ),
        );

    String weekLabel(DateTime monday) => '${monday.day}.${monday.month}.';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (picked != null) progressSection(picked, strength, section, c),
        const SizedBox(height: 8),
        // Key figures and exercises for the chosen period.
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 30, label: Text('30 Tage')),
            ButtonSegment(value: 90, label: Text('90 Tage')),
            ButtonSegment(value: 365, label: Text('1 Jahr')),
            ButtonSegment(value: 0, label: Text('Gesamt')),
          ],
          selected: {days},
          onSelectionChanged: (v) {
            setState(() => days = v.single);
            prefs.setInt('stats.days', v.single);
          },
        ),
        const SizedBox(height: 6),
        Row(children: [
          tile(Icons.event_available, 'Trainings', '${p.trainings}'),
          tile(Icons.calendar_view_week, 'Ø pro Woche', num1(p.perWeek)),
        ]),
        Row(children: [
          tile(Icons.repeat, 'Sätze pro Woche', num1(p.setsPerWeek)),
          tile(Icons.timer_outlined, 'Ø Dauer', switch (p.avgDuration) { final d? => durationLabel(d), null => '–' }),
        ]),
        Row(children: [
          tile(Icons.stacked_bar_chart, 'Volumen', volumeLabel(p.volume)),
          tile(Icons.local_fire_department_outlined, 'Schwerstes Training', volumeLabel(p.maxVolume)),
        ]),
        if (p.top case (final name, final kg))
          Row(children: [tile(Icons.emoji_events_outlined, 'Höchstes Gewicht', '$name · ${weightLabel(kg)}')]),
        const SizedBox(height: 8),
        section('Trainings pro Woche', 'Ziel $goal×', [
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
          Text(
            '${weeks.where((w) => w.$2 >= goal).length} von ${weeks.length} Wochen mit Ziel erreicht',
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
        ]),
        if (weeks.any((w) => w.$3 > 0))
          section('Cardio pro Woche', 'Minuten', [
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
          ]),
        Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text('Übungen', style: text.titleMedium)),
        // Exercises trained in the period, most often first: total lifted and best estimated 1RM there.
        for (final (name, logs) in [
          for (final name in store.loggedExercises)
            (name, [for (final (d, l) in store.historyOf(name)) if (from == null || d.isAfter(from)) l]),
        ].where((e) => e.$2.isNotEmpty).toList()
          ..sort((a, b) => b.$2.length.compareTo(a.$2.length)))
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: ListTile(
              title: Text(name),
              subtitle: Text(exerciseLine(logs)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!logs.last.cardio && logs.last.weight > 0)
                  Text('1RM ${weightLabel(toKg((shown(logs.map(estimated1rm).reduce(max)) * 2).round() / 2))}', // an estimate: ±0,5
                      style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                const Icon(Icons.chevron_right),
              ]),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseStats(name))),
            ),
          ),
      ],
    );
  }

  /// "12× · Gesamt 7,2 t", cardio "8× · 240 Min · 35 km gesamt", without weight "6× · 18 Sätze".
  static String exerciseLine(List<ExerciseLog> logs) {
    final n = '${logs.length}×';
    if (logs.last.cardio) {
      final km = logs.fold(0.0, (k, l) => k + (l.km ?? 0));
      return '$n · ${cardioLabel(logs.fold<int>(0, (m, l) => m + (l.reps.first ?? 0)), km > 0 ? km : null)} gesamt';
    }
    if (logs.last.weight == 0) return '$n · ${logs.fold(0, (s, l) => s + l.setsDone)} Sätze';
    return '$n · Gesamt ${volumeLabel(logs.fold(0.0, (v, l) => v + l.volume))}';
  }

  /// Weight line and estimated 1RM for one exercise, with chips to switch and the change in 30 days.
  Widget progressSection(String name, List<String> names, Widget Function(String, String?, List<Widget>) section,
      ColorScheme c) {
    final history = store.historyOf(name);
    final change = weightChange(history, DateTime.now());
    final headline = switch (change) {
      (final d, _) when d > 0 => '+${weightLabel(d)} in 30 Tagen',
      (final d, _) when d < 0 => '−${weightLabel(-d)} in 30 Tagen',
      (_, _) => 'gleich in 30 Tagen',
      null => '${history.length}× trainiert',
    };
    return section(name, null, [
      Text('${weightLabel(history.last.$2.weight)} · $headline',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: (change?.$1 ?? 0) > 0 ? c.primary : c.onSurfaceVariant)),
      const SizedBox(height: 10),
      SizedBox(
        height: 170,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseStats(name))),
          child: CustomPaint(
            size: Size.infinite,
            painter: LineChart(
              [for (final h in history) shown(h.$2.weight)],
              [for (final h in history) shown(estimated1rm(h.$2))],
              c.primary,
              c.outlineVariant,
              c.onSurfaceVariant,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text('Linie: Gewicht · gestrichelt: geschätztes 1RM', style: TextStyle(fontSize: 11, color: c.onSurfaceVariant)),
      if (names.length > 1) ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final n in names.take(8))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(n),
                  selected: n == name,
                  onSelected: (_) {
                    prefs.setString('stats.exercise', n);
                    setState(() {});
                  },
                ),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class ExerciseStats extends StatelessWidget {
  final String name;
  const ExerciseStats(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    final history = store.historyOf(name);
    final scheme = Theme.of(context).colorScheme;
    final best = history.map((h) => estimated1rm(h.$2)).fold(0.0, max);
    if (history.lastOrNull?.$2.cardio ?? false) return _cardioStats(context, name, history);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Gewicht (Linie) und geschätztes 1RM (gestrichelt)', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: LineChart(
                [for (final h in history) shown(h.$2.weight)],
                [for (final h in history) shown(estimated1rm(h.$2))],
                scheme.primary,
                scheme.outlineVariant,
                scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Bestes geschätztes 1RM: ${weightLabel(best)}'),
          const Divider(height: 32),
          for (final (date, log) in history.reversed)
            ListTile(
              dense: true,
              title: Text('${weightLabel(log.weight)} × ${log.reps.map((r) => r ?? '–').join('/')}'),
              subtitle: Text(dateLabel(date)),
              trailing: Icon(log.succeeded ? Icons.check_circle : Icons.remove_circle_outline,
                  color: log.succeeded ? scheme.primary : scheme.outline),
            ),
        ],
      ),
    );
  }
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

    for (final (i, v) in values.indexed) {
      final x = slot * i + slot / 2;
      final reached = goal == null || v >= goal!;
      if (v > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTRB(x - barW / 2, y(v), x + barW / 2, top + h),
              topLeft: const Radius.circular(5), topRight: const Radius.circular(5)),
          Paint()..color = reached ? hit : miss,
        );
        text(v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1), Offset(x, y(v) - 8), bold: true);
      }
      // Every other label when it gets tight.
      if (values.length <= 6 || i.isEven || i == values.length - 1) text(labels[i], Offset(x, size.height - bottom / 2));
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

/// Minimal two-series line chart sharing one y-axis; x is session index.
class LineChart extends CustomPainter {
  final List<double> main, secondary;
  final Color mainColor, secondaryColor, labelColor;
  LineChart(this.main, this.secondary, this.mainColor, this.secondaryColor, this.labelColor);

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...main, ...secondary].where((v) => v > 0);
    if (all.isEmpty) return;
    var lo = all.reduce(min), hi = all.reduce(max);
    if (hi - lo < 1) (lo, hi) = (lo - 5, hi + 5);
    const left = 40.0;
    final w = size.width - left, h = size.height - 8;
    Offset at(int i, double v) =>
        Offset(left + (main.length == 1 ? w / 2 : w * i / (main.length - 1)), 4 + h * (1 - (v - lo) / (hi - lo)));

    for (final v in [lo, hi]) {
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(0), style: TextStyle(color: labelColor, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, at(0, v).dy - tp.height / 2));
    }

    void series(List<double> values, Color color, bool dashed) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      for (var i = 1; i < values.length; i++) {
        final a = at(i - 1, values[i - 1]), b = at(i, values[i]);
        if (!dashed) {
          canvas.drawLine(a, b, paint);
          continue;
        }
        final steps = ((b - a).distance / 6).floor();
        for (var k = 0; k < steps; k += 2) {
          canvas.drawLine(Offset.lerp(a, b, k / steps)!, Offset.lerp(a, b, (k + 1) / steps)!, paint);
        }
      }
      for (final (i, v) in values.indexed) {
        canvas.drawCircle(at(i, v), dashed ? 2 : 4, paint..style = PaintingStyle.fill);
      }
    }

    series(secondary, secondaryColor, true);
    series(main, mainColor, false);
  }

  @override
  bool shouldRepaint(LineChart old) => true;

}

/// Cardio: minutes per session as the line, distance (if logged) dashed on the same axis.
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
            painter: LineChart(
              [for (final h in history) (h.$2.reps.first ?? 0).toDouble()],
              const [],
              scheme.primary,
              scheme.outlineVariant,
              scheme.onSurfaceVariant,
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
