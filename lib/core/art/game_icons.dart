import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'cartoon_animal.dart';
import 'shapes.dart';

/// Procedural card icons. Each takes the icon box [size] and an idle phase
/// [t] in 0..1 so cards can gently animate on the home screen.
abstract final class GameIcons {
  static double _wave(double t, [double cycles = 1]) =>
      math.sin(t * math.pi * 2 * cycles);

  static Paint _fill(Color c) => Paint()..color = c;

  static void _disc(Canvas canvas, Offset c, double r, Color color,
      {double outline = 0.08, bool gloss = true}) {
    canvas.drawCircle(
        c + Offset(0, r * 0.12), r, _fill(Colors.black.withOpacity(0.18)));
    canvas.drawCircle(c, r, _fill(color));
    if (gloss) {
      canvas.drawCircle(c + Offset(-r * 0.32, -r * 0.34), r * 0.24,
          _fill(Colors.white.withOpacity(0.55)));
    }
    canvas.drawCircle(c, r, inkStroke(r * outline * 2));
  }

  static void _roundRect(
      Canvas canvas, Rect r, double radius, Color color, double stroke) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, _fill(color));
    canvas.drawRRect(rr, inkStroke(stroke));
  }

  static void _label(
      Canvas canvas, String text, Offset center, double size, Color color,
      {FontWeight weight = FontWeight.w900}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size, fontWeight: weight, color: color, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  // ---- Board ------------------------------------------------------------

  static void ludo(Canvas canvas, Size size, double t) {
    final s = size.width;
    final dice = Rect.fromCenter(
        center: Offset(s * 0.36, s * 0.64), width: s * 0.4, height: s * 0.4);
    canvas.save();
    canvas.translate(dice.center.dx, dice.center.dy);
    canvas.rotate(-0.18 + _wave(t) * 0.05);
    canvas.translate(-dice.center.dx, -dice.center.dy);
    _roundRect(canvas, dice, s * 0.08, Colors.white, s * 0.03);
    for (final p in const [
      (0.28, 0.28),
      (0.72, 0.72),
      (0.5, 0.5),
      (0.72, 0.28),
      (0.28, 0.72)
    ]) {
      canvas.drawCircle(
          dice.topLeft + Offset(dice.width * p.$1, dice.height * p.$2),
          s * 0.035,
          _fill(Candy.cherry.face));
    }
    canvas.restore();
    final bob = _wave(t) * s * 0.04;
    canvas.save();
    canvas.translate(s * 0.64, s * 0.34 + bob);
    canvas.rotate(-0.6);
    paintPlane(canvas, s * 0.5, Candy.cherry);
    canvas.restore();
  }

  /// Cartoon airplane pointing up (−y), centered at origin, [len] long.
  static void paintPlane(Canvas canvas, double len, Candy candy,
      {double outline = 0.06}) {
    final w = len * outline;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: len * 0.26, height: len),
      Radius.circular(len * 0.13),
    );
    final wings = Path()
      ..moveTo(-len * 0.5, len * 0.08)
      ..lineTo(0, -len * 0.18)
      ..lineTo(len * 0.5, len * 0.08)
      ..lineTo(len * 0.44, len * 0.2)
      ..lineTo(0, len * 0.06)
      ..lineTo(-len * 0.44, len * 0.2)
      ..close();
    final tail = Path()
      ..moveTo(-len * 0.24, len * 0.48)
      ..lineTo(0, len * 0.3)
      ..lineTo(len * 0.24, len * 0.48)
      ..close();
    for (final p in [wings, tail]) {
      canvas.drawPath(p, _fill(candy.face));
      canvas.drawPath(p, inkStroke(w));
    }
    canvas.drawRRect(body, _fill(candy.face));
    canvas.drawRRect(body, inkStroke(w));
    canvas.drawCircle(
        Offset(0, -len * 0.26), len * 0.075, _fill(const Color(0xFFBDEBFF)));
    canvas.drawCircle(Offset(0, -len * 0.26), len * 0.075, inkStroke(w * 0.7));
  }

  static void gomoku(Canvas canvas, Size size, double t) {
    final s = size.width;
    final board = Rect.fromLTWH(s * 0.1, s * 0.1, s * 0.8, s * 0.8);
    _roundRect(canvas, board, s * 0.1, Candy.wood.face, s * 0.03);
    final grid = inkStroke(s * 0.012, color: Candy.wood.shade);
    for (var i = 1; i < 5; i++) {
      final d = board.left + board.width * i / 5;
      canvas.drawLine(Offset(d, board.top + s * 0.06),
          Offset(d, board.bottom - s * 0.06), grid);
      final e = board.top + board.height * i / 5;
      canvas.drawLine(Offset(board.left + s * 0.06, e),
          Offset(board.right - s * 0.06, e), grid);
    }
    final cells = [(1, 3), (2, 2), (3, 1), (2, 3), (3, 2), (4, 0)];
    for (var i = 0; i < cells.length; i++) {
      final (x, y) = cells[i];
      final c = Offset(
          board.left + board.width * (x + 0.5) / 5 + board.width * 0.1,
          board.top + board.height * (y + 0.5) / 5 + board.height * 0.1);
      final pulse = i == cells.length - 1 ? 1 + _wave(t, 2) * 0.08 : 1.0;
      _disc(canvas, c, s * 0.075 * pulse,
          i.isEven ? const Color(0xFF3A3F5C) : Colors.white,
          outline: 0.06);
    }
  }

  static void checkers(Canvas canvas, Size size, double t) {
    final s = size.width;
    final c = Offset(s * 0.5, s * 0.52);
    final r = s * 0.42;
    final star = Path();
    for (var k = 0; k < 2; k++) {
      final tri = Path();
      for (var i = 0; i < 3; i++) {
        final a = -math.pi / 2 + k * math.pi + i * math.pi * 2 / 3;
        final p = c + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? tri.moveTo(p.dx, p.dy) : tri.lineTo(p.dx, p.dy);
      }
      star.addPath(tri..close(), Offset.zero);
    }
    canvas.drawPath(star, _fill(Colors.white.withOpacity(0.9)));
    canvas.drawPath(star, inkStroke(s * 0.025));
    final colors = [
      Candy.cherry,
      Candy.ocean,
      Candy.sun,
      Candy.mint,
      Candy.grape,
      Candy.orange
    ];
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final hop = i == 0 ? -(_wave(t) * 0.5 + 0.5) * s * 0.08 : 0.0;
      _disc(
          canvas,
          c + Offset(math.cos(a), math.sin(a)) * r * 0.7 + Offset(0, hop),
          s * 0.07,
          colors[i].face,
          outline: 0.07);
    }
    _disc(canvas, c, s * 0.07, Candy.berry.face, outline: 0.07);
  }

  static void xiangqi(Canvas canvas, Size size, double t) {
    final s = size.width;
    canvas.save();
    canvas.translate(s * 0.5, s * 0.52);
    canvas.rotate(_wave(t) * 0.08);
    paintXiangqiPiece(canvas, s * 0.36, '帥', red: true);
    canvas.restore();
  }

  /// Wooden xiangqi disc centered at origin.
  static void paintXiangqiPiece(Canvas canvas, double r, String glyph,
      {required bool red, double lift = 0}) {
    canvas.drawCircle(
        Offset(0, r * (0.14 + lift)), r, _fill(Colors.black.withOpacity(0.2)));
    canvas.drawCircle(Offset(0, r * 0.1), r, _fill(const Color(0xFFC9955A)));
    canvas.drawCircle(Offset.zero, r, _fill(const Color(0xFFF7DDAE)));
    canvas.drawCircle(
        Offset.zero, r, inkStroke(r * 0.09, color: const Color(0xFF8A5A2B)));
    final ink = red ? const Color(0xFFD63A40) : const Color(0xFF2E3550);
    canvas.drawCircle(Offset.zero, r * 0.78, inkStroke(r * 0.06, color: ink));
    _label(canvas, glyph, Offset(0, -r * 0.02), r * 1.0, ink);
  }

  static void junqi(Canvas canvas, Size size, double t) {
    final s = size.width;
    final pole = Offset(s * 0.3, s * 0.18);
    canvas.drawLine(pole, Offset(s * 0.3, s * 0.88),
        inkStroke(s * 0.05, color: const Color(0xFF8A5A2B)));
    canvas.drawCircle(pole, s * 0.05, _fill(Candy.sun.face));
    canvas.drawCircle(pole, s * 0.05, inkStroke(s * 0.02));
    final flag = Path()..moveTo(s * 0.32, s * 0.22);
    for (var i = 0; i <= 10; i++) {
      final x = s * 0.32 + s * 0.5 * i / 10;
      flag.lineTo(
          x,
          s * 0.22 +
              math.sin(i / 10 * math.pi * 2 + t * math.pi * 2) * s * 0.035);
    }
    for (var i = 10; i >= 0; i--) {
      final x = s * 0.32 + s * 0.5 * i / 10;
      flag.lineTo(
          x,
          s * 0.56 +
              math.sin(i / 10 * math.pi * 2 + t * math.pi * 2) * s * 0.035);
    }
    flag.close();
    canvas.drawPath(flag, _fill(Candy.cherry.face));
    canvas.drawPath(flag, inkStroke(s * 0.025));
    paintStar(
        canvas, Offset(s * 0.52, s * 0.39 + _wave(t) * s * 0.01), s * 0.09,
        outlineWidth: s * 0.018);
    final base = Rect.fromCenter(
        center: Offset(s * 0.3, s * 0.88), width: s * 0.36, height: s * 0.1);
    _roundRect(canvas, base, s * 0.05, Candy.wood.face, s * 0.025);
  }

  static void jungle(Canvas canvas, Size size, double t) {
    final s = size.width;
    canvas.save();
    canvas.translate(0, _wave(t) * s * 0.02);
    paintAnimal(canvas, Rect.fromLTWH(s * 0.06, s * 0.06, s * 0.88, s * 0.88),
        Animal.lion,
        happy: t > 0.45 && t < 0.6);
    canvas.restore();
  }

  static void reversi(Canvas canvas, Size size, double t) {
    final s = size.width;
    final board = Rect.fromLTWH(s * 0.1, s * 0.14, s * 0.8, s * 0.72);
    _roundRect(canvas, board, s * 0.1, Candy.mint.face, s * 0.03);
    _disc(canvas, Offset(s * 0.33, s * 0.5), s * 0.15, const Color(0xFF3A3F5C));
    final flip = math.cos(t * math.pi * 2);
    canvas.save();
    canvas.translate(s * 0.67, s * 0.5);
    canvas.scale(flip.abs().clamp(0.08, 1.0), 1);
    _disc(canvas, Offset.zero, s * 0.15,
        flip > 0 ? Colors.white : const Color(0xFF3A3F5C));
    canvas.restore();
  }

  static void connect4(Canvas canvas, Size size, double t) {
    final s = size.width;
    final frame = Rect.fromLTWH(s * 0.1, s * 0.22, s * 0.8, s * 0.66);
    final cell = frame.width / 4;
    final grid = [
      [0, 0, 0, 0],
      [0, 2, 0, 0],
      [1, 1, 2, 0],
    ];
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 4; x++) {
        final v = grid[y][x];
        if (v == 0) continue;
        _disc(
            canvas,
            Offset(frame.left + cell * (x + 0.5),
                frame.top + frame.height * (y + 0.5) / 3),
            cell * 0.36,
            v == 1 ? Candy.cherry.face : Candy.sun.face,
            gloss: false);
      }
    }
    final drop = Curves.bounceOut.transform((t * 1.6).clamp(0.0, 1.0));
    final y = lerp(s * 0.06, frame.top + frame.height * 2.5 / 3, drop);
    _disc(canvas, Offset(frame.left + cell * 3.5, y), cell * 0.36,
        Candy.cherry.face,
        gloss: false);
    final holes = Path()
      ..addRRect(RRect.fromRectAndRadius(frame, Radius.circular(s * 0.06)));
    for (var yy = 0; yy < 3; yy++) {
      for (var x = 0; x < 4; x++) {
        holes.addOval(Rect.fromCircle(
            center: Offset(frame.left + cell * (x + 0.5),
                frame.top + frame.height * (yy + 0.5) / 3),
            radius: cell * 0.38));
      }
    }
    holes.fillType = PathFillType.evenOdd;
    canvas.drawPath(holes, _fill(Candy.ocean.face));
    canvas.drawRRect(RRect.fromRectAndRadius(frame, Radius.circular(s * 0.06)),
        inkStroke(s * 0.03));
  }

  static void tictactoe(Canvas canvas, Size size, double t) {
    final s = size.width;
    final line = inkStroke(s * 0.05, color: Colors.white);
    for (final k in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(s * (0.12 + 0.76 * k), s * 0.12),
          Offset(s * (0.12 + 0.76 * k), s * 0.88), line);
      canvas.drawLine(Offset(s * 0.12, s * (0.12 + 0.76 * k)),
          Offset(s * 0.88, s * (0.12 + 0.76 * k)), line);
    }
    void cross(Offset c, double r) {
      final p = Path()
        ..moveTo(c.dx - r, c.dy - r)
        ..lineTo(c.dx + r, c.dy + r)
        ..moveTo(c.dx + r, c.dy - r)
        ..lineTo(c.dx - r, c.dy + r);
      canvas.drawPath(p, inkStroke(r * 0.75));
      canvas.drawPath(p, inkStroke(r * 0.42, color: Candy.berry.face));
    }

    void ring(Offset c, double r) {
      canvas.drawCircle(c, r, inkStroke(r * 0.75));
      canvas.drawCircle(c, r, inkStroke(r * 0.42, color: Candy.ocean.light));
    }

    final cell = s * 0.76 / 3;
    Offset at(int x, int y) =>
        Offset(s * 0.12 + cell * (x + 0.5), s * 0.12 + cell * (y + 0.5));
    cross(at(0, 0), cell * 0.26);
    ring(at(1, 1), cell * 0.28);
    cross(at(2, 0), cell * 0.26);
    ring(at(0, 2), cell * 0.28 * (0.9 + 0.1 * _wave(t, 2)));
  }

  // ---- Puzzle -----------------------------------------------------------

  static void memory(Canvas canvas, Size size, double t) {
    final s = size.width;
    final back = Rect.fromCenter(
        center: Offset(s * 0.36, s * 0.52), width: s * 0.44, height: s * 0.6);
    canvas.save();
    canvas.translate(back.center.dx, back.center.dy);
    canvas.rotate(-0.16);
    canvas.translate(-back.center.dx, -back.center.dy);
    _roundRect(canvas, back, s * 0.08, Candy.grape.face, s * 0.03);
    _label(canvas, '?', back.center, s * 0.3, Colors.white);
    canvas.restore();
    final front = Rect.fromCenter(
        center: Offset(s * 0.64, s * 0.5), width: s * 0.44, height: s * 0.6);
    canvas.save();
    canvas.translate(front.center.dx, front.center.dy);
    canvas.rotate(0.14 + _wave(t) * 0.04);
    canvas.translate(-front.center.dx, -front.center.dy);
    _roundRect(canvas, front, s * 0.08, Colors.white, s * 0.03);
    paintAnimal(canvas, front.deflate(s * 0.04), Animal.cat, happy: true);
    canvas.restore();
  }

  static void ballSort(Canvas canvas, Size size, double t) {
    final s = size.width;
    final tubes = [
      [Candy.cherry, Candy.ocean, Candy.cherry],
      [Candy.ocean, Candy.cherry],
    ];
    for (var i = 0; i < 2; i++) {
      final tube =
          Rect.fromLTWH(s * (0.18 + i * 0.36), s * 0.3, s * 0.28, s * 0.62);
      final rr = RRect.fromRectAndCorners(tube,
          bottomLeft: Radius.circular(s * 0.14),
          bottomRight: Radius.circular(s * 0.14));
      canvas.drawRRect(rr, _fill(Colors.white.withOpacity(0.7)));
      final balls = tubes[i];
      for (var k = 0; k < balls.length; k++) {
        _disc(
            canvas,
            Offset(tube.center.dx, tube.bottom - s * 0.11 - k * s * 0.17),
            s * 0.085,
            balls[k].face,
            outline: 0.07);
      }
      canvas.drawRRect(rr, inkStroke(s * 0.03));
    }
    final y = s * 0.17 + _wave(t) * s * 0.04;
    _disc(canvas, Offset(s * 0.68, y), s * 0.085, Candy.ocean.face,
        outline: 0.07);
  }

  static void blocks(Canvas canvas, Size size, double t) {
    final s = size.width;
    final cell = s * 0.2;
    final cells = <(int, int, Candy)>[
      (0, 3, Candy.cherry),
      (1, 3, Candy.cherry),
      (2, 3, Candy.sun),
      (3, 3, Candy.mint),
      (0, 2, Candy.ocean),
      (2, 2, Candy.sun),
      (3, 2, Candy.mint),
      (3, 1, Candy.grape),
    ];
    final origin = Offset(s * 0.1, s * 0.06);
    for (final (x, y, candy) in cells) {
      _block(
          canvas,
          Rect.fromLTWH(origin.dx + x * cell, origin.dy + y * cell, cell, cell),
          candy,
          s);
    }
    final hover = _wave(t) * s * 0.03;
    for (final (x, y) in const [(0, 0), (1, 0), (1, 1)]) {
      _block(
          canvas,
          Rect.fromLTWH(
              origin.dx + x * cell, origin.dy + y * cell + hover, cell, cell),
          Candy.berry,
          s);
    }
  }

  static void _block(Canvas canvas, Rect r, Candy candy, double s) {
    final inner = r.deflate(s * 0.008);
    final rr = RRect.fromRectAndRadius(inner, Radius.circular(s * 0.04));
    canvas.drawRRect(rr, _fill(candy.shade));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(
                inner.left, inner.top, inner.right, inner.bottom - s * 0.03),
            Radius.circular(s * 0.04)),
        _fill(candy.face));
    canvas.drawRRect(rr, inkStroke(s * 0.018));
  }

  static void sliding(Canvas canvas, Size size, double t) {
    final s = size.width;
    final cell = s * 0.26;
    final origin = Offset(s * 0.11, s * 0.11);
    final tiles = <(int, int, int)>[
      (0, 0, 1),
      (1, 0, 2),
      (2, 0, 3),
      (0, 1, 4),
      (1, 1, 5),
      (2, 1, 6),
      (0, 2, 7)
    ];
    final slide =
        Curves.easeInOut.transform((math.sin(t * math.pi * 2) * 0.5 + 0.5));
    for (final (x, y, n) in tiles) {
      final r =
          Rect.fromLTWH(origin.dx + x * cell, origin.dy + y * cell, cell, cell)
              .deflate(s * 0.012);
      _roundRect(canvas, r, s * 0.05,
          n.isOdd ? Candy.sun.face : Candy.orange.face, s * 0.02);
      _label(canvas, '$n', r.center, s * 0.14, Palette.ink);
    }
    final r8 = Rect.fromLTWH(
            origin.dx + (1 + slide) * cell, origin.dy + 2 * cell, cell, cell)
        .deflate(s * 0.012);
    _roundRect(canvas, r8, s * 0.05, Candy.sun.face, s * 0.02);
    _label(canvas, '8', r8.center, s * 0.14, Palette.ink);
  }

  static void merge2048(Canvas canvas, Size size, double t) {
    final s = size.width;
    final pop = 1 + _wave(t, 2) * 0.04;
    final big = Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.56),
        width: s * 0.72 * pop,
        height: s * 0.5 * pop);
    _roundRect(canvas, big, s * 0.1, Candy.orange.face, s * 0.03);
    _label(canvas, '2048', big.center, s * 0.2, Colors.white);
    final a = Rect.fromCenter(
        center: Offset(s * 0.26, s * 0.22), width: s * 0.26, height: s * 0.26);
    final b = Rect.fromCenter(
        center: Offset(s * 0.62, s * 0.2), width: s * 0.22, height: s * 0.22);
    _roundRect(canvas, a, s * 0.06, Candy.sun.face, s * 0.022);
    _label(canvas, '2', a.center, s * 0.15, Palette.ink);
    _roundRect(canvas, b, s * 0.06, Candy.berry.face, s * 0.022);
    _label(canvas, '4', b.center, s * 0.13, Colors.white);
  }

  static void mines(Canvas canvas, Size size, double t) {
    final s = size.width;
    final c = Offset(s * 0.46, s * 0.58);
    canvas.drawLine(
        c + Offset(s * 0.16, -s * 0.2),
        c + Offset(s * 0.28, -s * 0.36),
        inkStroke(s * 0.04, color: const Color(0xFF8A5A2B)));
    final spark = c + Offset(s * 0.3, -s * 0.4);
    final k = 1 + _wave(t, 3) * 0.3;
    paintStar(canvas, spark, s * 0.08 * k,
        fill: Candy.sun.face, outlineWidth: s * 0.015);
    _disc(canvas, c, s * 0.28, const Color(0xFF3A3F5C), outline: 0.05);
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(c + Offset(side * s * 0.09, -s * 0.02), s * 0.04,
          _fill(Colors.white));
      canvas.drawCircle(c + Offset(side * s * 0.09, -s * 0.015), s * 0.02,
          _fill(Palette.ink));
    }
    final smile = Path()
      ..moveTo(c.dx - s * 0.07, c.dy + s * 0.08)
      ..quadraticBezierTo(
          c.dx, c.dy + s * 0.14, c.dx + s * 0.07, c.dy + s * 0.08);
    canvas.drawPath(smile, inkStroke(s * 0.02, color: Colors.white));
  }

  // ---- Arcade -----------------------------------------------------------

  static void snake(Canvas canvas, Size size, double t) {
    final s = size.width;
    final pts = <Offset>[];
    for (var i = 0; i <= 24; i++) {
      final k = i / 24;
      pts.add(Offset(s * (0.12 + 0.62 * k),
          s * (0.62 + math.sin(k * math.pi * 2.2 + t * math.pi * 2) * 0.12)));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, inkStroke(s * 0.2));
    canvas.drawPath(path, inkStroke(s * 0.15, color: Candy.mint.face));
    canvas.drawPath(path, inkStroke(s * 0.04, color: Candy.mint.light));
    final head = pts.last;
    canvas.drawCircle(head, s * 0.13, _fill(Candy.mint.face));
    canvas.drawCircle(head, s * 0.13, inkStroke(s * 0.025));
    for (final dy in [-0.05, 0.05]) {
      canvas.drawCircle(
          head + Offset(s * 0.03, s * dy), s * 0.035, _fill(Colors.white));
      canvas.drawCircle(
          head + Offset(s * 0.045, s * dy), s * 0.018, _fill(Palette.ink));
    }
    final apple = Offset(s * 0.86, s * 0.3);
    _disc(canvas, apple, s * 0.09, Candy.cherry.face, outline: 0.08);
    canvas.drawOval(
        Rect.fromCenter(
            center: apple + Offset(s * 0.04, -s * 0.11),
            width: s * 0.08,
            height: s * 0.04),
        _fill(Palette.grass));
  }

  static void whack(Canvas canvas, Size size, double t) {
    final s = size.width;
    final hole = Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.8), width: s * 0.74, height: s * 0.22);
    canvas.drawOval(hole, _fill(const Color(0xFF5B3B2A)));
    canvas.drawOval(hole, inkStroke(s * 0.025));
    final up = (math.sin(t * math.pi * 2) * 0.5 + 0.5);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, s, hole.center.dy));
    paintAnimal(
        canvas,
        Rect.fromCenter(
            center: Offset(s * 0.5, s * (0.66 - up * 0.22)),
            width: s * 0.6,
            height: s * 0.6),
        Animal.mole);
    canvas.restore();
    final rim = Path()..addArc(hole, 0, math.pi);
    canvas.drawPath(rim, inkStroke(s * 0.04, color: const Color(0xFF9C7A63)));
  }

  static void flappy(Canvas canvas, Size size, double t) {
    final s = size.width;
    final pipe = Rect.fromLTWH(s * 0.7, s * 0.5, s * 0.2, s * 0.46);
    _roundRect(canvas, pipe, s * 0.04, Palette.grass, s * 0.025);
    _roundRect(canvas, Rect.fromLTWH(s * 0.66, s * 0.46, s * 0.28, s * 0.1),
        s * 0.04, Palette.grass, s * 0.025);
    final c = Offset(s * 0.4, s * 0.42 + _wave(t) * s * 0.05);
    paintBird(canvas, c, s * 0.25, wing: _wave(t, 3));
  }

  /// Round yellow bird facing right; [wing] in -1..1 animates the flap.
  static void paintBird(Canvas canvas, Offset c, double r,
      {double wing = 0, double tilt = 0}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    canvas.drawCircle(Offset.zero, r, _fill(Candy.sun.face));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(r * 0.05, r * 0.38),
            width: r * 1.2,
            height: r * 0.7),
        _fill(const Color(0xFFFFF1C2)));
    canvas.drawCircle(Offset.zero, r, inkStroke(r * 0.12));
    canvas.save();
    canvas.translate(-r * 0.35, r * 0.1);
    canvas.rotate(-0.5 + wing * 0.6);
    final wingRect = Rect.fromCenter(
        center: Offset(-r * 0.15, 0), width: r * 0.8, height: r * 0.5);
    canvas.drawOval(wingRect, _fill(Candy.orange.face));
    canvas.drawOval(wingRect, inkStroke(r * 0.1));
    canvas.restore();
    canvas.drawCircle(
        Offset(r * 0.38, -r * 0.25), r * 0.28, _fill(Colors.white));
    canvas.drawCircle(
        Offset(r * 0.38, -r * 0.25), r * 0.28, inkStroke(r * 0.08));
    canvas.drawCircle(
        Offset(r * 0.46, -r * 0.24), r * 0.12, _fill(Palette.ink));
    final beak = Path()
      ..moveTo(r * 0.7, r * 0.0)
      ..lineTo(r * 1.25, r * 0.15)
      ..lineTo(r * 0.7, r * 0.34)
      ..close();
    canvas.drawPath(beak, _fill(Candy.orange.face));
    canvas.drawPath(beak, inkStroke(r * 0.08));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(r * 0.2, r * 0.25),
            width: r * 0.28,
            height: r * 0.16),
        _fill(Candy.berry.face.withOpacity(0.5)));
    canvas.restore();
  }
}
