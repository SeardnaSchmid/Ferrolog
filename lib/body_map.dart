import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'body_shapes.dart';
import 'muscles.dart';

/// Front and back of a body with muscles filled in by how much they work, 0 (grey) to 1 (full colour).
/// With [onTap], a tap on a muscle reports it.
class BodyMap extends StatelessWidget {
  final Map<Muscle, double> level;
  final double height;
  final ValueChanged<Muscle>? onTap;

  /// The muscles of an exercise: primary strong, secondary light.
  BodyMap(Muscles muscles, {super.key, this.height = 200})
      : onTap = null,
        level = {
          for (final m in musclesIn(muscles.$2)) m: .4,
          for (final m in musclesIn(muscles.$1)) m: 1,
        };

  /// How much each muscle was trained, as a share of the most trained one.
  const BodyMap.heat(this.level, {super.key, this.height = 200, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final label = TextStyle(fontSize: 11, color: c.onSurfaceVariant);
    Widget view(_View v) {
      final size = Size(height * v.bounds.width / v.bounds.height, height);
      final painter = _BodyPainter(
        view: v,
        level: level,
        primary: c.primary,
        idle: c.onSurface.withValues(alpha: .16),
        body: c.onSurface.withValues(alpha: .07),
      );
      return Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTapUp: onTap == null
              ? null
              : (d) {
                  if (v.muscleAt(d.localPosition, size) case final m?) onTap!(m);
                },
          child: CustomPaint(size: size, painter: painter),
        ),
        const SizedBox(height: 4),
        Text(v == _View.front ? 'Vorne' : 'Hinten', style: label),
      ]);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [view(_View.front), const SizedBox(width: 28), view(_View.back)],
    );
  }
}

/// One side of the body, its SVG paths parsed once.
class _View {
  final Path outline;
  final List<(Muscle?, Path)> parts;
  final Rect bounds;
  _View(String outline, List<(Muscle?, String)> parts)
      : outline = parseSvgPathData(outline),
        parts = [for (final (m, d) in parts) (m, parseSvgPathData(d))],
        bounds = parseSvgPathData(outline).getBounds().inflate(4);

  static final front = _View(bodyOutline.$1, bodyFront);
  static final back = _View(bodyOutline.$2, bodyBack);

  /// Scales the drawing grid to [size].
  Matrix4 transform(Size size) {
    final s = size.height / bounds.height;
    return Matrix4.diagonal3Values(s, s, 1)..translateByDouble(-bounds.left, -bounds.top, 0, 1);
  }

  /// The muscle under a point of the widget, or the nearest one within a finger's reach.
  Muscle? muscleAt(Offset at, Size size) {
    final s = size.height / bounds.height;
    final p = at / s + bounds.topLeft;
    for (final (m, path) in parts) {
      if (m != null && path.contains(p)) return m;
    }
    // Small muscles are hard to hit: take the closest one by its centre within ~12 px.
    Muscle? best;
    var dist = 12 / s;
    for (final (m, path) in parts) {
      if (m == null) continue;
      final d = (path.getBounds().center - p).distance;
      if (d < dist) (best, dist) = (m, d);
    }
    return best;
  }
}

class _BodyPainter extends CustomPainter {
  final _View view;
  final Map<Muscle, double> level;
  final Color primary, idle, body;
  const _BodyPainter({
    required this.view,
    required this.level,
    required this.primary,
    required this.idle,
    required this.body,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.transform(view.transform(size).storage);
    // Silhouette underneath, so the muscles read as one body.
    canvas.drawPath(view.outline, Paint()..color = body);
    for (final (m, path) in view.parts) {
      canvas.drawPath(path, Paint()..color = m == null ? body : Color.lerp(idle, primary, level[m] ?? 0)!);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.level != level || old.primary != primary || old.idle != idle || old.view != view;
}
