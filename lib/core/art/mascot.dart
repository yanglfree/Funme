import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'shapes.dart';

enum MascotMood { idle, happy, cheer, sad, sleep, think }

/// 豆豆 — the app mascot: a sunny bean with a sprout, drawn procedurally so it
/// can breathe, blink and react without image assets.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.mood = MascotMood.idle, this.size = 96});

  final MascotMood mood;
  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  Timer? _blinkTimer;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer =
        Timer(Duration(milliseconds: 2200 + _random.nextInt(2600)), () async {
      if (!mounted) return;
      await _blink.forward();
      if (!mounted) return;
      await _blink.reverse();
      if (mounted) _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: MascotPainter(
          mood: widget.mood,
          idle: _idle,
          blink: _blink,
        ),
      ),
    );
  }
}

class MascotPainter extends CustomPainter {
  MascotPainter({required this.mood, required this.idle, required this.blink})
      : super(repaint: Listenable.merge([idle, blink]));

  final MascotMood mood;
  final Animation<double> idle;
  final Animation<double> blink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final phase = idle.value * math.pi * 2;
    final cheering = mood == MascotMood.cheer;
    final jump = cheering ? -math.sin(phase * 2).abs() * s * 0.1 : 0.0;
    final breathe = mood == MascotMood.sleep
        ? 0.03 * math.sin(phase)
        : 0.025 * math.sin(phase * 2);
    final outline = s * 0.035;

    paintGroundShadow(canvas, Offset(s * 0.5, s * 0.95), s * (0.62 + jump / s),
        opacity: 0.16);

    canvas.save();
    canvas.translate(s * 0.5, s * 0.92 + jump);
    canvas.scale(1 - breathe * 0.6, 1 + breathe);
    canvas.translate(-s * 0.5, -s * 0.92);

    final body = Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.6), width: s * 0.78, height: s * 0.66);
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        body,
        topLeft: Radius.elliptical(s * 0.4, s * 0.36),
        topRight: Radius.elliptical(s * 0.4, s * 0.36),
        bottomLeft: Radius.elliptical(s * 0.36, s * 0.28),
        bottomRight: Radius.elliptical(s * 0.36, s * 0.28),
      ));

    // Feet.
    final footPaint = Paint()..color = Candy.orange.face;
    for (final dx in [-0.17, 0.17]) {
      final foot = Rect.fromCenter(
          center: Offset(s * (0.5 + dx), s * 0.92),
          width: s * 0.2,
          height: s * 0.1);
      canvas.drawOval(foot, footPaint);
      canvas.drawOval(foot, inkStroke(outline * 0.8));
    }

    // Arms.
    final armWave =
        cheering ? math.sin(phase * 4) * 0.35 : math.sin(phase) * 0.08;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(s * (0.5 + side * 0.37), s * 0.62);
      final raise = cheering ? -1.25 : (mood == MascotMood.happy ? -0.6 : 0.35);
      canvas.rotate(side * (raise + armWave));
      final arm = Rect.fromCenter(
          center: Offset(side * s * 0.06, 0), width: s * 0.17, height: s * 0.1);
      canvas.drawOval(arm, Paint()..color = Candy.sun.face);
      canvas.drawOval(arm, inkStroke(outline * 0.8));
      canvas.restore();
    }

    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Candy.sun.light, Candy.sun.face, const Color(0xFFFFB627)],
          stops: const [0, 0.5, 1],
        ).createShader(body),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * 0.36, s * 0.38),
          width: s * 0.16,
          height: s * 0.08),
      Paint()..color = Colors.white.withOpacity(0.55),
    );
    canvas.drawPath(bodyPath, inkStroke(outline));

    _paintSprout(canvas, s, phase, outline);
    _paintFace(canvas, s, outline);
    canvas.restore();

    if (mood == MascotMood.sleep) _paintZzz(canvas, s, phase);
    if (mood == MascotMood.think) _paintThought(canvas, s, phase);
  }

  void _paintSprout(Canvas canvas, double s, double phase, double outline) {
    final sway = math.sin(phase) * 0.18;
    canvas.save();
    canvas.translate(s * 0.5, s * 0.28);
    canvas.rotate(sway);
    final stem = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(s * 0.02, -s * 0.08, 0, -s * 0.14);
    canvas.drawPath(stem, inkStroke(outline * 1.6, color: Palette.grassDark));
    for (final side in [-1.0, 1.0]) {
      final leaf = Path()
        ..moveTo(0, -s * 0.13)
        ..quadraticBezierTo(
            side * s * 0.1, -s * 0.24, side * s * 0.18, -s * 0.15)
        ..quadraticBezierTo(side * s * 0.09, -s * 0.08, 0, -s * 0.13)
        ..close();
      canvas.drawPath(leaf, Paint()..color = Palette.grass);
      canvas.drawPath(leaf, inkStroke(outline * 0.8));
    }
    canvas.restore();
  }

  void _paintFace(Canvas canvas, double s, double outline) {
    final eyeY = s * 0.53;
    final eyeDx = s * 0.13;
    final ink = Paint()..color = Palette.ink;
    final happyEyes = mood == MascotMood.happy || mood == MascotMood.cheer;

    for (final side in [-1.0, 1.0]) {
      final c = Offset(s * 0.5 + side * eyeDx, eyeY);
      if (happyEyes) {
        final arc = Path()
          ..moveTo(c.dx - s * 0.05, c.dy + s * 0.015)
          ..quadraticBezierTo(
              c.dx, c.dy - s * 0.06, c.dx + s * 0.05, c.dy + s * 0.015);
        canvas.drawPath(arc, inkStroke(outline * 1.1));
      } else if (mood == MascotMood.sleep) {
        final arc = Path()
          ..moveTo(c.dx - s * 0.05, c.dy)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.04, c.dx + s * 0.05, c.dy);
        canvas.drawPath(arc, inkStroke(outline));
      } else {
        final open = 1 - blink.value * 0.9;
        final look = mood == MascotMood.think
            ? Offset(s * 0.015, -s * 0.02)
            : Offset.zero;
        canvas.drawOval(
          Rect.fromCenter(
              center: c + look, width: s * 0.075, height: s * 0.1 * open),
          ink,
        );
        if (open > 0.5) {
          canvas.drawCircle(c + look + Offset(-s * 0.012, -s * 0.022),
              s * 0.016, Paint()..color = Colors.white);
        }
        if (mood == MascotMood.sad) {
          final brow = Path()
            ..moveTo(c.dx - side * s * 0.05, c.dy - s * 0.1)
            ..lineTo(c.dx + side * s * 0.04, c.dy - s * 0.075);
          canvas.drawPath(brow, inkStroke(outline * 0.8));
        }
      }
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.5 + side * s * 0.24, s * 0.63),
            width: s * 0.11,
            height: s * 0.06),
        Paint()..color = Candy.berry.face.withOpacity(0.55),
      );
    }

    final m = Offset(s * 0.5, s * 0.64);
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.cheer:
        final mouth = Path()
          ..moveTo(m.dx - s * 0.075, m.dy - s * 0.01)
          ..quadraticBezierTo(
              m.dx, m.dy + s * 0.13, m.dx + s * 0.075, m.dy - s * 0.01)
          ..close();
        canvas.drawPath(mouth, Paint()..color = const Color(0xFFB8324F));
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawCircle(m + Offset(0, s * 0.08), s * 0.045,
            Paint()..color = const Color(0xFFFF8FA3));
        canvas.restore();
        canvas.drawPath(mouth, inkStroke(outline * 0.9));
      case MascotMood.sad:
        final mouth = Path()
          ..moveTo(m.dx - s * 0.05, m.dy + s * 0.03)
          ..quadraticBezierTo(
              m.dx, m.dy - s * 0.02, m.dx + s * 0.05, m.dy + s * 0.03);
        canvas.drawPath(mouth, inkStroke(outline));
      case MascotMood.sleep:
        canvas.drawOval(
          Rect.fromCenter(
              center: m + Offset(0, s * 0.01),
              width: s * 0.04,
              height: s * 0.05),
          Paint()..color = const Color(0xFFB8324F),
        );
      case MascotMood.think:
        canvas.drawLine(m + Offset(-s * 0.02, s * 0.01),
            m + Offset(s * 0.05, 0), inkStroke(outline));
      case MascotMood.idle:
        final mouth = Path()
          ..moveTo(m.dx - s * 0.055, m.dy)
          ..quadraticBezierTo(m.dx, m.dy + s * 0.06, m.dx + s * 0.055, m.dy);
        canvas.drawPath(mouth, inkStroke(outline));
    }
  }

  void _paintZzz(Canvas canvas, double s, double phase) {
    for (var i = 0; i < 3; i++) {
      final k = ((idle.value + i / 3) % 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: s * (0.1 + k * 0.08),
            fontWeight: FontWeight.w900,
            color: Palette.ink.withOpacity(1 - k),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(s * (0.72 + k * 0.15), s * (0.3 - k * 0.25)));
    }
  }

  void _paintThought(Canvas canvas, double s, double phase) {
    final bob = math.sin(phase * 2) * s * 0.01;
    final fill = Paint()..color = Colors.white;
    final dots = [
      Offset(s * 0.8, s * 0.36),
      Offset(s * 0.87, s * 0.25),
      Offset(s * 0.9, s * 0.12)
    ];
    final radii = [s * 0.025, s * 0.035, s * 0.06];
    for (var i = 0; i < 3; i++) {
      final c = dots[i] + Offset(0, bob);
      canvas.drawCircle(c, radii[i], fill);
      canvas.drawCircle(c, radii[i], inkStroke(s * 0.015));
    }
  }

  @override
  bool shouldRepaint(MascotPainter oldDelegate) => oldDelegate.mood != mood;
}
