import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/art/shapes.dart';
import '../../core/theme/palette.dart';
import 'pusher_rules.dart';

/// One projection for the cabinet, coin heights, and chute input mapping.
abstract final class PusherProjection {
  static const width = 10.0;
  static const height = 12.0;
  static double scaleAt(double y) => 0.7 + y * 0.027;
  static Offset point(double x, double y, [double z = 0]) =>
      Offset(5 + (x - 5) * scaleAt(y), 2 + y * 0.72 - z * 0.9);
  static double aimFromX(double x) =>
      (5 + (x - 5) / scaleAt(0.85)).clamp(0.6, 9.4);
}

class PusherPainter extends CustomPainter {
  PusherPainter(
      {required this.game,
      required this.aim,
      required ValueNotifier<int> frame})
      : super(repaint: frame);

  final PusherGame Function() game;
  final double Function() aim;
  static const _metal = Color(0xFFC7D4E2);
  static const _dark = Color(0xFF243449);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / PusherProjection.width);
    final g = game();
    final casing = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.08, 0.08, 9.84, 11.84),
        const Radius.circular(0.5));
    canvas.drawRRect(
        casing,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF466380), _dark, Color(0xFF19293D)],
          ).createShader(casing.outerRect));
    canvas.drawRRect(casing, inkStroke(0.08));
    _label(canvas, 'COIN PUSHER', const Offset(5, 0.5), 0.32, Candy.sun.face);
    // Chute rail and carriage.
    canvas.drawLine(const Offset(1.25, 1.08), const Offset(8.75, 1.08),
        inkStroke(0.12, color: _metal));
    final slotX = PusherProjection.point(aim(), 0.85).dx;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(slotX, 1.08), width: 0.85, height: 0.42),
            const Radius.circular(0.12)),
        Paint()..color = Candy.sun.face);
    canvas.drawLine(Offset(slotX - 0.25, 1.08), Offset(slotX + 0.25, 1.08),
        inkStroke(0.1, color: _dark));

    _surface(canvas, 0, 0, 10, PusherGame.depth, 0, _metal);
    for (var y = 1.0; y < PusherGame.depth; y++) {
      canvas.drawLine(
          PusherProjection.point(0, y),
          PusherProjection.point(10, y),
          inkStroke(0.02, color: Colors.white.withOpacity(0.25)));
    }
    // Side return gutters are visibly separate from the winning front tray.
    for (final x in [0.0, 10 - PusherGame.gutter]) {
      _surface(canvas, x, PusherGame.gutterStart, PusherGame.gutter,
          PusherGame.depth - PusherGame.gutterStart, 0.01, _dark);
      for (var y = 5.6; y < 9.2; y += 0.55) {
        canvas.drawLine(
            PusherProjection.point(x + 0.12, y),
            PusherProjection.point(x + 0.53, y + 0.18),
            inkStroke(0.055, color: Candy.orange.face.withOpacity(0.7)));
      }
    }
    // The vertical front face makes the upper/lower shelf transfer readable.
    _quad(
        canvas,
        [
          PusherProjection.point(0, g.front, PusherGame.plateHeight),
          PusherProjection.point(10, g.front, PusherGame.plateHeight),
          PusherProjection.point(10, g.front),
          PusherProjection.point(0, g.front),
        ],
        Candy.ocean.shade);
    _surface(
        canvas, 0, 0, 10, g.front, PusherGame.plateHeight, Candy.ocean.face);
    for (var x = 1.0; x < 10; x += 1.5) {
      canvas.drawLine(
          PusherProjection.point(x, 0.15, PusherGame.plateHeight),
          PusherProjection.point(x, g.front - 0.15, PusherGame.plateHeight),
          inkStroke(0.035, color: Colors.white.withOpacity(0.3)));
    }
    canvas.drawLine(
        PusherProjection.point(0, g.front, PusherGame.plateHeight),
        PusherProjection.point(10, g.front, PusherGame.plateHeight),
        inkStroke(0.09, color: Colors.white.withOpacity(0.8)));
    // Draw the guide after the surfaces so it is not painted over.
    final target = PusherProjection.point(aim(), 1.4, PusherGame.plateHeight);
    canvas.drawLine(Offset(slotX, 1.4), target,
        inkStroke(0.025, color: Candy.sun.face.withOpacity(0.8)));

    final items = List<Coin>.of(g.coins)
      ..sort((a, b) => (a.y + a.z * 0.6).compareTo(b.y + b.z * 0.6));
    for (final co in items) {
      final p = PusherProjection.point(co.x, co.y, co.z);
      final ground = PusherProjection.point(
          co.x, co.y, co.onPlate ? PusherGame.plateHeight : 0);
      final r = co.r * PusherProjection.scaleAt(co.y);
      canvas.drawOval(
          Rect.fromCenter(
              center: ground + const Offset(0.05, 0.08),
              width: r * 2,
              height: r * 1.25),
          Paint()..color = Colors.black.withOpacity(0.18));
      _coin(canvas, p, r, co.kind, co.angle);
    }

    // Glass side rails and a front lip leave the hanging coins exposed.
    for (final x in [0.0, 10.0]) {
      canvas.drawLine(
          PusherProjection.point(x, 0, 0.8),
          PusherProjection.point(x, PusherGame.depth, 0),
          inkStroke(0.1, color: Colors.white.withOpacity(0.6)));
    }
    canvas.drawLine(
        PusherProjection.point(0, PusherGame.depth),
        PusherProjection.point(10, PusherGame.depth),
        inkStroke(0.10, color: Candy.sun.face));
    final tray = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.5, 9.35, 9, 1.6), const Radius.circular(0.22));
    canvas.drawRRect(tray, Paint()..color = const Color(0xFF101B2A));
    canvas.drawRRect(tray, inkStroke(0.06, color: _metal));
    for (final f in g.falls.where((f) => !f.side)) {
      final t = (f.age / 0.7).clamp(0.0, 1.0);
      canvas.save();
      canvas.clipRRect(tray);
      _coin(canvas, Offset(5 + (f.x - 5) * 0.95, 9.35 + t * t * 1.6),
          f.kind.radius * (1 - 0.25 * t), f.kind, t * math.pi * 2);
      canvas.restore();
    }
    _label(canvas, '落入前槽返币', const Offset(5, 11.35), 0.27, Colors.white);
    for (var i = 0; i < 8; i++) {
      final active = ((g.time * 3).floor() + i) % 4 == 0;
      canvas.drawCircle(Offset(0.6 + i * 1.25, 11.7), 0.055,
          Paint()..color = active ? Candy.sun.face : _metal.withOpacity(0.3));
    }
    canvas.restore();
  }

  void _surface(Canvas canvas, double x, double y, double w, double h, double z,
          Color color) =>
      _quad(
          canvas,
          [
            PusherProjection.point(x, y, z),
            PusherProjection.point(x + w, y, z),
            PusherProjection.point(x + w, y + h, z),
            PusherProjection.point(x, y + h, z),
          ],
          color);

  void _quad(Canvas canvas, List<Offset> points, Color color) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  void _coin(
      Canvas canvas, Offset center, double r, CoinKind kind, double tilt) {
    final color = switch (kind) {
      CoinKind.silver => const Color(0xFFE5EAF2),
      CoinKind.gold => Candy.sun.face,
      CoinKind.gem => Candy.berry.face,
    };
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final flatten = math.max(0.12, math.cos(tilt).abs());
    final face = Rect.fromCenter(
        center: Offset.zero, width: 2 * r, height: 1.35 * r * flatten);
    final lip = face.shift(const Offset(0, PusherGame.thickness * 0.65));
    canvas.drawOval(lip, Paint()..color = Color.lerp(color, _dark, 0.45)!);
    canvas.drawOval(
        face,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, color, Color.lerp(color, _dark, 0.18)!],
          ).createShader(face));
    canvas.drawOval(face, inkStroke(0.025, color: _dark.withOpacity(0.7)));
    canvas.drawOval(face.deflate(r * 0.18),
        inkStroke(0.025, color: _dark.withOpacity(0.3)));
    canvas.save();
    canvas.scale(1, 0.675 * flatten);
    if (kind == CoinKind.gem) {
      final diamond = Path()
        ..addPolygon([
          Offset(0, -r * 0.6),
          Offset(r * 0.5, 0),
          Offset(0, r * 0.6),
          Offset(-r * 0.5, 0),
        ], true);
      canvas.drawPath(diamond, Paint()..color = Colors.white.withOpacity(0.9));
    } else if (kind == CoinKind.gold) {
      paintStar(canvas, Offset.zero, r * 0.48, outlineWidth: 0.025);
    } else {
      canvas.drawLine(Offset(0, -r * 0.35), Offset(0, r * 0.35),
          inkStroke(0.07, color: _dark.withOpacity(0.5)));
    }
    canvas.restore();
    canvas.restore();
  }

  void _label(
      Canvas canvas, String text, Offset center, double size, Color color) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: size, color: color, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(PusherPainter oldDelegate) => true;
}
