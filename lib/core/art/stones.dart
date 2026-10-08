import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'shapes.dart';

/// Glossy go-style stone used by gomoku and reversi. [side] 0 = dark, 1 = light.
void paintStone(Canvas canvas, Offset c, double r, int side,
    {double opacity = 1}) {
  final dark = side == 0;
  canvas.drawCircle(
    c + Offset(r * 0.08, r * 0.18),
    r,
    Paint()..color = Colors.black.withOpacity(0.22 * opacity),
  );
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: dark
            ? [
                const Color(0xFF6A7096).withOpacity(opacity),
                const Color(0xFF242842).withOpacity(opacity)
              ]
            : [
                Colors.white.withOpacity(opacity),
                const Color(0xFFE2DACD).withOpacity(opacity)
              ],
      ).createShader(rect),
  );
  canvas.drawOval(
    Rect.fromCenter(
        center: c + Offset(-r * 0.3, -r * 0.38),
        width: r * 0.62,
        height: r * 0.36),
    Paint()..color = Colors.white.withOpacity((dark ? 0.35 : 0.85) * opacity),
  );
  canvas.drawCircle(
      c, r, inkStroke(r * 0.12, color: Palette.ink.withOpacity(opacity)));
}

class StoneToken extends StatelessWidget {
  const StoneToken(this.side, {super.key});

  final int side;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _StoneTokenPainter(side));
}

class _StoneTokenPainter extends CustomPainter {
  _StoneTokenPainter(this.side);

  final int side;

  @override
  void paint(Canvas canvas, Size size) {
    paintStone(
        canvas, size.center(Offset.zero), size.shortestSide * 0.42, side);
  }

  @override
  bool shouldRepaint(_StoneTokenPainter oldDelegate) =>
      oldDelegate.side != side;
}
