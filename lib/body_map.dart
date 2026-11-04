import 'package:flutter/material.dart';

import 'muscles.dart';

/// Front and back of a body with the muscles of an exercise filled in: primary strong,
/// secondary light, the rest grey.
class BodyMap extends StatelessWidget {
  final Muscles muscles;
  final double height;
  const BodyMap(this.muscles, {super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final label = TextStyle(fontSize: 11, color: c.onSurfaceVariant);
    Widget view(bool front) => Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: height * _w / _h,
            height: height,
            child: CustomPaint(
              painter: _BodyPainter(
                front: front,
                muscles: muscles,
                primary: c.primary,
                secondary: c.primary.withValues(alpha: .4),
                idle: c.onSurface.withValues(alpha: .16),
                body: c.onSurface.withValues(alpha: .07),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(front ? 'Vorne' : 'Hinten', style: label),
        ]);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [view(true), const SizedBox(width: 28), view(false)]);
  }
}

// Drawing grid of one view; the body is symmetric around x = 50.
const double _w = 100, _h = 200;

class _BodyPainter extends CustomPainter {
  final bool front;
  final Muscles muscles;
  final Color primary, secondary, idle, body;
  const _BodyPainter({
    required this.front,
    required this.muscles,
    required this.primary,
    required this.secondary,
    required this.idle,
    required this.body,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);
    final (p, s) = muscles;
    Paint fill(Muscle? m) => Paint()
      ..color = m == null
          ? body
          : p & m.bit != 0
              ? primary
              : s & m.bit != 0
                  ? secondary
                  : idle;

    // Shapes are given for the left half (as seen) and mirrored.
    void oval(Muscle? m, double x, double y, double rx, double ry, {bool mirror = true}) {
      for (final cx in mirror ? [x, _w - x] : [x]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, y), width: 2 * rx, height: 2 * ry), fill(m));
      }
    }

    void box(Muscle? m, double l, double t, double r, double b, double radius, {bool mirror = true}) {
      for (final (a, z) in mirror ? [(l, r), (_w - r, _w - l)] : [(l, r)]) {
        canvas.drawRRect(RRect.fromLTRBR(a, t, z, b, Radius.circular(radius)), fill(m));
      }
    }

    void shape(Muscle? m, List<Offset> points, {bool mirror = true}) {
      for (final pts in mirror ? [points, [for (final o in points) Offset(_w - o.dx, o.dy)]] : [points]) {
        canvas.drawPath(Path()..addPolygon(pts, true), fill(m));
      }
    }

    // Silhouette underneath, so the muscles read as one body.
    final limb = Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final x in [0.0, _w]) {
      Offset at(double dx, double dy) => Offset((x - dx).abs(), dy);
      canvas.drawLine(at(30, 36), at(20, 96), limb..strokeWidth = 10); // arm
      canvas.drawLine(at(41, 96), at(40.5, 188), limb..strokeWidth = 15); // leg
    }
    canvas.drawRRect(RRect.fromLTRBR(32, 28, 68, 100, const Radius.circular(12)), Paint()..color = body);

    // Head, hands, knees, feet: not muscles.
    oval(null, 50, 11, 8, 9.5, mirror: false);
    oval(null, 17.5, 102, 3.5, 5);
    oval(null, 40.5, 147, 4.5, 4);
    oval(null, 40.5, 192, 5, 3.5);

    box(Muscle.neck, 45, 19, 55, 29, 3, mirror: false);
    if (front) {
      shape(Muscle.traps, const [Offset(44.5, 24), Offset(35, 31), Offset(44.5, 31)]);
      oval(Muscle.shoulders, 30, 37, 7.5, 7.5);
      box(Muscle.chest, 37, 31, 49.3, 49, 5);
      oval(Muscle.biceps, 25.5, 56, 4.8, 10);
      oval(Muscle.forearms, 21, 80, 4.3, 12);
      box(Muscle.abdominals, 41, 51, 59, 88, 6, mirror: false);
      oval(Muscle.abductors, 35.5, 92, 4, 7);
      oval(Muscle.quadriceps, 40.5, 118, 7.5, 22);
      oval(Muscle.adductors, 47.6, 108, 2.4, 11);
      oval(Muscle.calves, 40.5, 168, 4.5, 15);
    } else {
      shape(Muscle.traps, const [Offset(50, 25), Offset(36, 32), Offset(50, 54), Offset(64, 32)], mirror: false);
      oval(Muscle.shoulders, 30, 37, 7.5, 7.5);
      oval(Muscle.triceps, 25.5, 56, 4.8, 10);
      oval(Muscle.forearms, 21, 80, 4.3, 12);
      shape(Muscle.lats, const [Offset(36.5, 44), Offset(42, 52), Offset(44, 72), Offset(37, 64)]);
      box(Muscle.middleBack, 43.5, 52, 49.3, 70, 3);
      box(Muscle.lowerBack, 41.5, 72, 58.5, 87, 5, mirror: false);
      oval(Muscle.abductors, 34.5, 93, 3.5, 7);
      oval(Muscle.glutes, 43.5, 98, 7.5, 9);
      oval(Muscle.hamstrings, 41, 126, 7, 18);
      oval(Muscle.calves, 40.5, 166, 5.5, 14);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.muscles != muscles || old.primary != primary || old.idle != idle || old.front != front;
}
