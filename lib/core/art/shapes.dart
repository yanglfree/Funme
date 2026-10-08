import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Rounded five-point star path centered at [center].
Path starPath(Offset center, double radius,
    {double inner = 0.5, int points = 5}) {
  final path = Path();
  final step = math.pi / points;
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? radius : radius * inner;
    final a = -math.pi / 2 + i * step;
    final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// Paints a cartoon star with ink outline and a glossy highlight.
void paintStar(
  Canvas canvas,
  Offset center,
  double radius, {
  Color fill = const Color(0xFFFFC83D),
  Color outline = Palette.ink,
  double outlineWidth = 3,
  bool glossy = true,
}) {
  final path = starPath(center, radius, inner: 0.52);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = outlineWidth
    ..strokeJoin = StrokeJoin.round
    ..color = outline;
  canvas.drawPath(path, Paint()..color = fill);
  if (glossy) {
    canvas.drawCircle(
      center + Offset(-radius * 0.22, -radius * 0.25),
      radius * 0.16,
      Paint()..color = Colors.white.withOpacity(0.7),
    );
  }
  canvas.drawPath(path, stroke);
}

class StarIcon extends StatelessWidget {
  const StarIcon({super.key, this.size = 28, this.filled = true});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StarPainter(filled),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.filled);

  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    paintStar(
      canvas,
      size.center(Offset.zero),
      size.width * 0.46,
      fill: filled ? Candy.sun.face : const Color(0xFFE4DDF0),
      outline: filled ? Palette.ink : Palette.inkSoft,
      outlineWidth: size.width * 0.07,
      glossy: filled,
    );
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.filled != filled;
}

/// Soft drop shadow ellipse under an object.
void paintGroundShadow(Canvas canvas, Offset center, double width,
    {double opacity = 0.18}) {
  canvas.drawOval(
    Rect.fromCenter(center: center, width: width, height: width * 0.28),
    Paint()
      ..color = Colors.black.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
}

/// Cloud silhouette made of overlapping circles.
Path cloudPath(Rect r) {
  final path = Path()
    ..addOval(Rect.fromCircle(
        center: Offset(r.left + r.width * 0.28, r.bottom - r.height * 0.36),
        radius: r.height * 0.36))
    ..addOval(Rect.fromCircle(
        center: Offset(r.left + r.width * 0.5, r.top + r.height * 0.45),
        radius: r.height * 0.45))
    ..addOval(Rect.fromCircle(
        center: Offset(r.left + r.width * 0.74, r.bottom - r.height * 0.38),
        radius: r.height * 0.38))
    ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(r.left + r.width * 0.12, r.bottom - r.height * 0.42,
          r.right - r.width * 0.1, r.bottom),
      Radius.circular(r.height * 0.21),
    ));
  return path;
}

/// Linear interpolation helper usable outside of Flutter animation classes.
double lerp(double a, double b, double t) => lerpDouble(a, b, t)!;

/// Ink outline paint for sticker-style edges.
Paint inkStroke(double width, {Color color = Palette.ink}) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = color;
