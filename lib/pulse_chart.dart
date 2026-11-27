import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'language.dart';
import 'model.dart';
import 'pulse_rest.dart';
import 'stats_colors.dart';

/// Heart rate over the training, for the recap: the curve, the rest threshold dashed, each
/// exercise's first set as a numbered marker (named below) and each set as a tick on the axis.
class PulseCard extends StatelessWidget {
  final Session session;
  const PulseCard(this.session, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final c = Theme.of(context).colorScheme;
    final summary = pulseSummary(s.pulse)!;
    final small = TextStyle(fontSize: 12, color: c.onSurfaceVariant);
    final markers = exerciseMarkers(s);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(tr.recapPulse, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(tr.recapPulseSummary(summary.avg, summary.max),
                style: small.copyWith(color: c.onSurface, fontWeight: FontWeight.w600)),
          ]),
          if (summary.above.inMinutes > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text(tr.recapPulseAbove(summary.above.inMinutes, pulseRestThreshold), style: small),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: CustomPaint(
              size: Size.infinite,
              painter: PulseChart(
                s.pulse,
                markers: markers,
                sets: [
                  for (final l in s.exercises)
                    for (final t in l.doneAt)
                      if (t != null) t.difference(s.date).inSeconds,
                ],
                end: s.duration?.inSeconds,
                line: c.pulseColor,
                threshold: c.referenceAmber,
                grid: c.outlineVariant,
                label: c.onSurfaceVariant,
                marker: c.surfaceContainerHighest,
                markerText: c.onSurface,
                thresholdLabel: tr.recapPulseRest,
              ),
            ),
          ),
          if (markers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              for (final (i, m) in markers.indexed)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: c.surfaceContainerHighest,
                    child: Text('${i + 1}', style: TextStyle(fontSize: 10, color: c.onSurface, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 4),
                  Text(m.name, style: small),
                ]),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Average and peak heart rate and the time spent at or above the rest threshold, null without data.
({int avg, int max, Duration above})? pulseSummary(List<(int, int)> pulse) {
  if (pulse.length < 2) return null;
  var above = 0;
  for (var i = 1; i < pulse.length; i++) {
    final gap = pulse[i].$1 - pulse[i - 1].$1;
    if (gap <= pulseGap && pulse[i - 1].$2 >= pulseRestThreshold) above += gap;
  }
  return (
    avg: (pulse.fold(0, (n, p) => n + p.$2) / pulse.length).round(),
    max: pulse.map((p) => p.$2).reduce(max),
    above: Duration(seconds: above),
  );
}

/// Longer than this between two samples and the curve breaks (no signal, sensor off).
const pulseGap = pulseSampleSeconds * 4;

/// Each logged exercise with the second its first set was logged, in training order. Cardio is logged
/// at its end, so its marker goes back by the minutes run.
List<({String name, int at})> exerciseMarkers(Session s) => [
      for (final l in s.exercises)
        if (l.doneAt.whereType<DateTime>().firstOrNull case final t?)
          (name: l.name, at: max(0, t.difference(s.date).inSeconds - (l.cardio ? (l.reps.first ?? 0) * 60 : 0))),
    ]..sort((a, b) => a.at.compareTo(b.at));

class PulseChart extends CustomPainter {
  final List<(int, int)> pulse;
  final List<({String name, int at})> markers;
  final List<int> sets;
  final int? end;
  final Color line, threshold, grid, label, marker, markerText;
  final String thresholdLabel;

  PulseChart(
    this.pulse, {
    required this.markers,
    required this.sets,
    required this.end,
    required this.line,
    required this.threshold,
    required this.grid,
    required this.label,
    required this.marker,
    required this.markerText,
    required this.thresholdLabel,
  });

  static const _top = 22.0, _bottom = 18.0, _right = 4.0;

  TextPainter _text(String s, Color color, {double size = 10, FontWeight? weight}) => TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
        textDirection: TextDirection.ltr,
      )..layout();

  /// h:mm, as the training lasts an hour, not minutes.
  static String clock(int seconds) => '${seconds ~/ 3600}:${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}';

  @override
  void paint(Canvas canvas, Size size) {
    if (pulse.length < 2) return;
    final span = max(end ?? 0, pulse.last.$1).toDouble();
    final lo = (min(pulse.map((p) => p.$2).reduce(min), pulseRestThreshold) - 10) ~/ 10 * 10;
    final hi = (max(pulse.map((p) => p.$2).reduce(max), pulseRestThreshold) + 14) ~/ 10 * 10;
    final w = size.width - _right, h = size.height - _top - _bottom;
    double x(num t) => t / span * w;
    double y(num bpm) => _top + h - (bpm - lo) / (hi - lo) * h;
    final base = _top + h;

    // Time axis: a baseline with a few round labels.
    canvas.drawLine(Offset(0, base), Offset(w, base), Paint()..color = grid..strokeWidth = 1);
    final step = [300, 600, 900, 1200, 1800, 3600].firstWhere((s) => span / s <= 5, orElse: () => 3600);
    for (var t = 0; t <= span; t += step) {
      final tp = _text(clock(t), label);
      final left = (x(t) - tp.width / 2).clamp(0.0, w - tp.width);
      tp.paint(canvas, Offset(left, base + 4));
    }

    // Each set: a small tick on the axis.
    final tick = Paint()..color = label.withValues(alpha: .6)..strokeWidth = 1.5;
    for (final t in sets) {
      if (t < 0 || t > span) continue;
      canvas.drawLine(Offset(x(t), base - 4), Offset(x(t), base), tick);
    }

    // Each exercise: a dotted line from a numbered circle down to the axis.
    // Circles close together move apart sideways; the line stays at the real time.
    final dot = Paint()..color = label.withValues(alpha: .45)..strokeWidth = 1;
    var lastCx = double.negativeInfinity;
    for (final (i, m) in markers.indexed) {
      final mx = x(m.at.clamp(0, span));
      for (var yy = _top - 2.0; yy < base; yy += 4) {
        canvas.drawLine(Offset(mx, yy), Offset(mx, min(yy + 1.5, base)), dot);
      }
      final cx = max(max(mx, lastCx + 17), 8.0);
      lastCx = cx;
      if (cx != mx) canvas.drawLine(Offset(mx, _top - 2), Offset(cx, 14), dot);
      canvas.drawCircle(Offset(cx, 9), 8, Paint()..color = marker);
      final tp = _text('${i + 1}', markerText, weight: FontWeight.w600);
      tp.paint(canvas, Offset(cx - tp.width / 2, 9 - tp.height / 2));
    }

    // Rest threshold, dashed, with its label at the right end.
    final ty = y(pulseRestThreshold);
    final dash = Paint()..color = threshold..strokeWidth = 1.2;
    for (var xx = 0.0; xx < w; xx += 7) {
      canvas.drawLine(Offset(xx, ty), Offset(min(xx + 4, w), ty), dash);
    }
    final tl = _text('$thresholdLabel $pulseRestThreshold', threshold);
    tl.paint(canvas, Offset(w - tl.width, ty - tl.height - 1));

    // The curve, broken at gaps, with a soft fill below.
    final path = Path(), fill = Path();
    var open = false;
    double? startX;
    void close(double lastX) {
      fill
        ..lineTo(lastX, base)
        ..lineTo(startX!, base)
        ..close();
    }
    for (var i = 0; i < pulse.length; i++) {
      final (t, bpm) = pulse[i];
      final p = Offset(x(t), y(bpm));
      if (!open || t - pulse[i - 1].$1 > pulseGap) {
        if (open) close(x(pulse[i - 1].$1));
        path.moveTo(p.dx, p.dy);
        fill.moveTo(p.dx, p.dy);
        startX = p.dx;
        open = true;
      } else {
        path.lineTo(p.dx, p.dy);
        fill.lineTo(p.dx, p.dy);
      }
    }
    close(x(pulse.last.$1));
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, _top), Offset(0, base), [line.withValues(alpha: .28), line.withValues(alpha: 0)]),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // The peak, labelled.
    final peak = pulse.reduce((a, b) => b.$2 > a.$2 ? b : a);
    final pp = Offset(x(peak.$1), y(peak.$2));
    canvas.drawCircle(pp, 3, Paint()..color = line);
    final pl = _text('${peak.$2}', line, weight: FontWeight.w700);
    pl.paint(canvas, Offset((pp.dx - pl.width / 2).clamp(0.0, w - pl.width), pp.dy - pl.height - 3));
  }

  @override
  bool shouldRepaint(PulseChart old) =>
      old.pulse != pulse || old.line != line || old.markers.length != markers.length || old.end != end;
}
