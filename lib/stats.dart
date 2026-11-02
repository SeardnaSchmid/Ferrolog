import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';

/// Epley estimate of the one-rep max from the best set.
double estimated1rm(ExerciseLog log) {
  final best = log.reps.whereType<int>().fold(0, max);
  return best == 0 ? 0 : log.weight * (1 + best / 30);
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = store.sessions;
    if (sessions.isEmpty) return const Center(child: Text('Statistiken gibt’s nach dem ersten Training.'));
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    final volume = sessions.expand((s) => s.exercises).fold(0.0, (v, e) => v + e.volume);
    final text = Theme.of(context).textTheme;

    Widget tile(String label, String value) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [Text(value, style: text.headlineSmall), Text(label, style: text.bodySmall)]),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          tile('Trainings', '${sessions.length}'),
          tile('Letzte 30 Tage', '${sessions.where((s) => s.date.isAfter(monthAgo)).length}'),
          tile('Volumen', '${(volume / 1000).toStringAsFixed(1)} t'),
        ]),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.all(8), child: Text('Übungen', style: text.titleMedium)),
        for (final name in store.loggedExercises)
          Builder(builder: (context) {
            final h = store.historyOf(name);
            final last = h.last.$2;
            return ListTile(
              title: Text(name),
              subtitle: Text('${h.length}× trainiert · zuletzt ${kg(last.weight)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseStats(name))),
            );
          }),
      ],
    );
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
                [for (final h in history) h.$2.weight],
                [for (final h in history) estimated1rm(h.$2)],
                scheme.primary,
                scheme.outlineVariant,
                scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Bestes geschätztes 1RM: ${kg(double.parse(best.toStringAsFixed(1)))}'),
          const Divider(height: 32),
          for (final (date, log) in history.reversed)
            ListTile(
              dense: true,
              title: Text('${kg(log.weight)} × ${log.reps.map((r) => r ?? '–').join('/')}'),
              subtitle: Text(dateLabel(date)),
              trailing: Icon(log.succeeded ? Icons.check_circle : Icons.remove_circle_outline,
                  color: log.succeeded ? scheme.primary : scheme.outline),
            ),
        ],
      ),
    );
  }
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
