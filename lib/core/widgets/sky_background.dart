import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/shapes.dart';
import '../theme/palette.dart';

/// Background moods; each game picks one that fits its world.
enum Scenery {
  sky([Color(0xFF6CCBFF), Color(0xFFBFF0FF)], true),
  meadow([Color(0xFF7FD8FF), Color(0xFFD6F7FF)], true),
  sunset([Color(0xFFFFA477), Color(0xFFFFE1A8)], true),
  candy([Color(0xFFFFB3D1), Color(0xFFFFE6F0)], false),
  grape([Color(0xFFB59BFF), Color(0xFFE9E1FF)], false),
  mint([Color(0xFF7BE3C2), Color(0xFFDDFBF1)], false),
  night([Color(0xFF3B3A7A), Color(0xFF6D6BC2)], false);

  const Scenery(this.gradient, this.clouds);

  final List<Color> gradient;
  final bool clouds;
}

/// Animated gradient sky with drifting clouds and rising bubbles.
class SkyBackground extends StatefulWidget {
  const SkyBackground({
    super.key,
    this.scenery = Scenery.sky,
    this.hills = false,
    required this.child,
  });

  final Scenery scenery;
  final bool hills;
  final Widget child;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _SkyPainter(
              clock: _clock,
              scenery: widget.scenery,
              hills: widget.hills,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.clock, required this.scenery, required this.hills})
      : super(repaint: clock);

  final Animation<double> clock;
  final Scenery scenery;
  final bool hills;

  // Speeds are whole laps per 120 s clock cycle so the loop is seamless.
  static const _lap = 1 / 120;
  static const _clouds = <(double y, double w, double speed, double phase)>[
    (0.08, 120, _lap, 0.1),
    (0.20, 86, _lap * 2, 0.55),
    (0.34, 140, _lap, 0.8),
    (0.52, 70, _lap * 3, 0.3),
    (0.70, 110, _lap * 2, 0.65),
  ];
  static const _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: scenery.gradient,
        ).createShader(rect),
    );
    final seconds = clock.value * 120;

    if (scenery == Scenery.night) {
      _paintStars(canvas, size, seconds);
    } else {
      _paintSun(canvas, size, seconds);
    }

    if (scenery.clouds) {
      final cloudPaint = Paint()..color = Colors.white.withOpacity(0.85);
      for (final (y, w, speed, phase) in _clouds) {
        final span = size.width + w * 2;
        final x = ((phase + seconds * speed) % 1.0) * span - w;
        final r = Rect.fromLTWH(x, size.height * y, w, w * 0.55);
        canvas.drawPath(cloudPath(r), cloudPaint);
      }
    } else {
      _paintBubbles(canvas, size, seconds);
    }

    if (hills) _paintHills(canvas, size);
  }

  void _paintSun(Canvas canvas, Size size, double seconds) {
    final c = Offset(size.width * 0.86, size.height * 0.07);
    final glow = Paint()..color = Colors.white.withOpacity(0.25);
    final pulse = 1 + 0.06 * math.sin(seconds * _tau / 5);
    canvas.drawCircle(c, 64 * pulse, glow);
    canvas.drawCircle(c, 44 * pulse, glow);
    canvas.drawCircle(
        c, 30, Paint()..color = const Color(0xFFFFF1A6).withOpacity(0.9));
  }

  void _paintStars(Canvas canvas, Size size, double seconds) {
    final rnd = math.Random(7);
    for (var i = 0; i < 40; i++) {
      final p = Offset(
          rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.8);
      final twinkle =
          0.4 + 0.6 * (0.5 + 0.5 * math.sin(seconds * _tau / 3 + i));
      canvas.drawCircle(p, 1.2 + rnd.nextDouble() * 1.6,
          Paint()..color = Colors.white.withOpacity(twinkle));
    }
  }

  void _paintBubbles(Canvas canvas, Size size, double seconds) {
    final rnd = math.Random(11);
    final fill = Paint()..color = Colors.white.withOpacity(0.22);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.45);
    for (var i = 0; i < 14; i++) {
      final speed = _lap * (1 + rnd.nextInt(2));
      final r = 6 + rnd.nextDouble() * 18;
      final x0 = rnd.nextDouble() * size.width;
      final phase = rnd.nextDouble();
      final y = size.height +
          r -
          ((phase + seconds * speed) % 1.0) * (size.height + r * 2);
      final x = x0 + math.sin(seconds * _tau / 8 + i) * 12;
      canvas.drawCircle(Offset(x, y), r, fill);
      canvas.drawCircle(Offset(x, y), r, ring);
      canvas.drawCircle(Offset(x - r * 0.35, y - r * 0.35), r * 0.2,
          Paint()..color = Colors.white.withOpacity(0.6));
    }
  }

  void _paintHills(Canvas canvas, Size size) {
    final h = size.height;
    final back = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(
          size.width * 0.25, h * 0.78, size.width * 0.55, h * 0.86)
      ..quadraticBezierTo(size.width * 0.8, h * 0.93, size.width, h * 0.84)
      ..lineTo(size.width, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFFA6E87F));
    final front = Path()
      ..moveTo(0, h * 0.92)
      ..quadraticBezierTo(
          size.width * 0.4, h * 0.86, size.width * 0.7, h * 0.93)
      ..quadraticBezierTo(size.width * 0.88, h * 0.97, size.width, h * 0.92)
      ..lineTo(size.width, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = Palette.grass);
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.scenery != scenery || oldDelegate.hills != hills;
}
