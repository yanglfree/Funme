import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'shapes.dart';

enum Animal {
  elephant('大象'),
  lion('狮子'),
  tiger('老虎'),
  leopard('豹子'),
  wolf('灰狼'),
  dog('小狗'),
  cat('小猫'),
  mouse('老鼠'),
  rabbit('兔子'),
  panda('熊猫'),
  frog('青蛙'),
  pig('小猪'),
  bear('小熊'),
  chick('小鸡'),
  fox('狐狸'),
  cow('奶牛'),
  monkey('猴子'),
  koala('考拉'),
  penguin('企鹅'),
  owl('猫头鹰'),
  mole('地鼠');

  const Animal(this.label);

  final String label;
}

/// Paints a cartoon animal face filling [rect]. Every species is built from
/// the same head / ears / eyes / muzzle vocabulary so they read as one family.
void paintAnimal(
  Canvas canvas,
  Rect rect,
  Animal animal, {
  double blink = 0,
  bool happy = false,
  bool outline = true,
}) {
  _AnimalPainter(canvas, rect, animal, blink, happy, outline).paint();
}

/// Widget wrapper around [paintAnimal].
class AnimalFace extends StatelessWidget {
  const AnimalFace(this.animal,
      {super.key, this.size = 64, this.happy = false});

  final Animal animal;
  final double size;
  final bool happy;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AnimalFacePainter(animal, happy),
    );
  }
}

class _AnimalFacePainter extends CustomPainter {
  _AnimalFacePainter(this.animal, this.happy);

  final Animal animal;
  final bool happy;

  @override
  void paint(Canvas canvas, Size size) {
    paintAnimal(canvas, Offset.zero & size, animal, happy: happy);
  }

  @override
  bool shouldRepaint(_AnimalFacePainter old) =>
      old.animal != animal || old.happy != happy;
}

class _AnimalPainter {
  _AnimalPainter(
      this.canvas, Rect rect, this.animal, this.blink, this.happy, this.outline)
      : c = rect.center + Offset(0, rect.height * 0.04),
        r = rect.shortestSide * 0.34,
        w = rect.shortestSide * 0.028;

  final Canvas canvas;
  final Animal animal;
  final double blink;
  final bool happy;
  final bool outline;
  final Offset c;
  final double r;
  final double w;

  Paint fill(Color color) => Paint()..color = color;

  void stroke(Path path, [double scale = 1]) {
    if (outline) canvas.drawPath(path, inkStroke(w * scale));
  }

  void blob(Path path, Color color, [double strokeScale = 1]) {
    canvas.drawPath(path, fill(color));
    stroke(path, strokeScale);
  }

  Path circle(Offset center, double radius) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  Path oval(Offset center, double width, double height) => Path()
    ..addOval(Rect.fromCenter(center: center, width: width, height: height));

  Offset at(double dx, double dy) => c + Offset(dx * r, dy * r);

  void paint() {
    switch (animal) {
      case Animal.elephant:
        _elephant();
      case Animal.lion:
        _lion();
      case Animal.tiger:
        _feline(const Color(0xFFFFA23A), stripes: true);
      case Animal.leopard:
        _feline(const Color(0xFFFFD36B), spots: true);
      case Animal.wolf:
        _wolf();
      case Animal.dog:
        _dog();
      case Animal.cat:
        _cat();
      case Animal.mouse:
        _mouse();
      case Animal.rabbit:
        _rabbit();
      case Animal.panda:
        _panda();
      case Animal.frog:
        _frog();
      case Animal.pig:
        _pig();
      case Animal.bear:
        _roundEared(const Color(0xFFB07A4F), const Color(0xFFE8C39E),
            innerEar: const Color(0xFFE8C39E));
      case Animal.chick:
        _chick();
      case Animal.fox:
        _fox();
      case Animal.cow:
        _cow();
      case Animal.monkey:
        _monkey();
      case Animal.koala:
        _koala();
      case Animal.penguin:
        _penguin();
      case Animal.owl:
        _owl();
      case Animal.mole:
        _mole();
    }
  }

  // ---- Shared features --------------------------------------------------

  void head(Color color, {double sx = 1, double sy = 0.94}) {
    blob(oval(c, r * 2 * sx, r * 2 * sy), color);
  }

  void eyes(
      {double dy = -0.12,
      double dx = 0.36,
      double size = 1,
      Color color = Palette.ink}) {
    for (final side in [-1.0, 1.0]) {
      final e = at(side * dx, dy);
      if (happy) {
        final p = Path()
          ..moveTo(e.dx - r * 0.13 * size, e.dy + r * 0.04)
          ..quadraticBezierTo(e.dx, e.dy - r * 0.14 * size,
              e.dx + r * 0.13 * size, e.dy + r * 0.04);
        canvas.drawPath(p, inkStroke(w * 1.3, color: color));
        continue;
      }
      final open = 1 - blink * 0.9;
      canvas.drawOval(
        Rect.fromCenter(
            center: e, width: r * 0.2 * size, height: r * 0.26 * size * open),
        fill(color),
      );
      if (open > 0.5) {
        canvas.drawCircle(e + Offset(-r * 0.04 * size, -r * 0.06 * size),
            r * 0.05 * size, fill(Colors.white));
      }
    }
  }

  void cheeks({double dy = 0.22, double dx = 0.58}) {
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: at(side * dx, dy), width: r * 0.32, height: r * 0.18),
        fill(Candy.berry.face.withOpacity(0.45)),
      );
    }
  }

  void muzzle(Color color,
      {double dy = 0.32, double width = 0.9, double height = 0.62}) {
    blob(oval(at(0, dy), r * width, r * height), color, 0.8);
  }

  void nose({double dy = 0.2, Color color = Palette.ink, double size = 1}) {
    final n = at(0, dy);
    final p = Path()
      ..moveTo(n.dx - r * 0.13 * size, n.dy - r * 0.05 * size)
      ..quadraticBezierTo(n.dx, n.dy - r * 0.1 * size, n.dx + r * 0.13 * size,
          n.dy - r * 0.05 * size)
      ..quadraticBezierTo(n.dx + r * 0.05 * size, n.dy + r * 0.1 * size, n.dx,
          n.dy + r * 0.1 * size)
      ..quadraticBezierTo(n.dx - r * 0.05 * size, n.dy + r * 0.1 * size,
          n.dx - r * 0.13 * size, n.dy - r * 0.05 * size)
      ..close();
    canvas.drawPath(p, fill(color));
  }

  void mouth({double dy = 0.38, double width = 0.18}) {
    final m = at(0, dy);
    final p = Path()
      ..moveTo(m.dx - r * width, m.dy - r * 0.02)
      ..quadraticBezierTo(m.dx - r * width * 0.5, m.dy + r * 0.12, m.dx, m.dy)
      ..quadraticBezierTo(m.dx + r * width * 0.5, m.dy + r * 0.12,
          m.dx + r * width, m.dy - r * 0.02);
    canvas.drawPath(p, inkStroke(w * 0.9));
    if (happy) {
      canvas.drawOval(
        Rect.fromCenter(
            center: m + Offset(0, r * 0.1), width: r * 0.16, height: r * 0.12),
        fill(const Color(0xFFB8324F)),
      );
    }
  }

  void whiskers({double dy = 0.3}) {
    for (final side in [-1.0, 1.0]) {
      for (final k in [-0.08, 0.06]) {
        final a = at(side * 0.42, dy + k);
        final b = at(side * 0.92, dy + k * 2.2);
        canvas.drawLine(a, b, inkStroke(w * 0.6));
      }
    }
  }

  void roundEars(Color color, Color inner,
      {double dx = 0.72, double dy = -0.72, double size = 0.38}) {
    for (final side in [-1.0, 1.0]) {
      final e = at(side * dx, dy);
      blob(circle(e, r * size), color);
      canvas.drawCircle(e, r * size * 0.55, fill(inner));
    }
  }

  void pointyEars(Color color, Color inner,
      {double spread = 0.62,
      double height = 1.25,
      double tipColorShare = 0,
      Color? tip}) {
    for (final side in [-1.0, 1.0]) {
      final base1 = at(side * (spread - 0.36), -0.66);
      final base2 = at(side * (spread + 0.3), -0.42);
      final apex = at(side * (spread + 0.12), -height);
      final ear = Path()
        ..moveTo(base1.dx, base1.dy)
        ..quadraticBezierTo(
            apex.dx - side * r * 0.06, apex.dy + r * 0.2, apex.dx, apex.dy)
        ..quadraticBezierTo(
            apex.dx + side * r * 0.12, apex.dy + r * 0.3, base2.dx, base2.dy)
        ..close();
      blob(ear, color);
      final innerEar = Path()
        ..moveTo(at(side * (spread - 0.2), -0.66).dx, at(0, -0.66).dy)
        ..lineTo(at(side * (spread + 0.1), -height + 0.25).dx,
            at(0, -height + 0.25).dy)
        ..lineTo(at(side * (spread + 0.2), -0.5).dx, at(0, -0.5).dy)
        ..close();
      canvas.drawPath(innerEar, fill(inner));
      if (tip != null && tipColorShare > 0) {
        canvas.save();
        canvas.clipPath(ear);
        canvas.drawRect(
            Rect.fromLTRB(apex.dx - r, apex.dy - r, apex.dx + r,
                apex.dy + r * tipColorShare),
            fill(tip));
        canvas.restore();
        stroke(ear);
      }
    }
  }

  // ---- Species ----------------------------------------------------------

  void _elephant() {
    const skin = Color(0xFFA9B8D6);
    for (final side in [-1.0, 1.0]) {
      final ear = oval(at(side * 0.95, -0.05), r * 1.0, r * 1.25);
      blob(ear, skin);
      canvas.drawPath(oval(at(side * 0.98, -0.02), r * 0.62, r * 0.85),
          fill(const Color(0xFFF7B6C8)));
    }
    head(skin);
    eyes(dy: -0.18, dx: 0.34);
    cheeks(dy: 0.12, dx: 0.62);
    final trunk = Path()
      ..moveTo(at(-0.2, 0.05).dx, at(0, 0.05).dy)
      ..quadraticBezierTo(
          at(-0.22, 0.75).dx, at(0, 0.75).dy, at(0.12, 1.02).dx, at(0, 1.02).dy)
      ..lineTo(at(0.34, 0.9).dx, at(0, 0.9).dy)
      ..quadraticBezierTo(
          at(0.16, 0.7).dx, at(0, 0.7).dy, at(0.2, 0.05).dx, at(0, 0.05).dy)
      ..close();
    blob(trunk, skin);
    for (final k in [0.4, 0.58, 0.76]) {
      canvas.drawLine(at(-0.12, k), at(0.14, k + 0.02), inkStroke(w * 0.6));
    }
  }

  void _lion() {
    const mane = Color(0xFFE5822E);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      blob(circle(c + Offset(math.cos(a), math.sin(a)) * r * 0.98, r * 0.38),
          mane, 0.8);
    }
    blob(circle(c, r * 1.02), mane, 0);
    roundEars(const Color(0xFFFFC65C), const Color(0xFFE8A040),
        dx: 0.62, dy: -0.66, size: 0.26);
    head(const Color(0xFFFFC65C), sx: 0.86, sy: 0.84);
    eyes(dy: -0.14, dx: 0.32);
    muzzle(const Color(0xFFFFF0D2), dy: 0.3, width: 0.78, height: 0.5);
    nose(dy: 0.18, color: const Color(0xFF7A3E1D));
    mouth(dy: 0.36, width: 0.15);
    cheeks(dy: 0.12, dx: 0.52);
  }

  void _feline(Color skin, {bool stripes = false, bool spots = false}) {
    roundEars(skin, Colors.white, dx: 0.66, dy: -0.7, size: 0.3);
    head(skin);
    if (stripes) {
      final mark = fill(Palette.ink);
      for (final dx in [-0.18, 0.0, 0.18]) {
        final top = at(dx, -0.92);
        final stripe = Path()
          ..moveTo(top.dx - r * 0.06, top.dy)
          ..lineTo(top.dx + r * 0.06, top.dy)
          ..lineTo(top.dx, top.dy + r * (dx == 0 ? 0.36 : 0.26))
          ..close();
        canvas.drawPath(stripe, mark);
      }
      for (final side in [-1.0, 1.0]) {
        for (final dy in [-0.02, 0.18]) {
          final edge = at(side * 0.95, dy);
          final stripe = Path()
            ..moveTo(edge.dx, edge.dy - r * 0.06)
            ..lineTo(edge.dx, edge.dy + r * 0.06)
            ..lineTo(edge.dx - side * r * 0.3, edge.dy)
            ..close();
          canvas.drawPath(stripe, mark);
        }
      }
    }
    if (spots) {
      final mark = fill(const Color(0xFF8A5A2B));
      for (final p in const [
        (-0.5, -0.5),
        (0.45, -0.55),
        (-0.2, -0.75),
        (0.15, -0.7),
        (-0.75, 0.0),
        (0.75, 0.05),
        (-0.6, 0.45),
        (0.62, 0.42)
      ]) {
        canvas.drawCircle(at(p.$1, p.$2), r * 0.08, mark);
      }
    }
    eyes(dy: -0.14);
    muzzle(Colors.white, dy: 0.32, width: 0.82, height: 0.5);
    nose(dy: 0.18, color: const Color(0xFFE0607E));
    mouth(dy: 0.36, width: 0.15);
    whiskers(dy: 0.32);
  }

  void _wolf() {
    const fur = Color(0xFF9AA3B5);
    pointyEars(fur, const Color(0xFFE6E9F0), spread: 0.55, height: 1.3);
    head(fur);
    final mask = Path()
      ..moveTo(at(-0.6, 0.0).dx, at(0, 0.0).dy)
      ..quadraticBezierTo(
          at(0, -0.3).dx, at(0, -0.3).dy, at(0.6, 0.0).dx, at(0, 0.0).dy)
      ..quadraticBezierTo(
          at(0.55, 0.75).dx, at(0, 0.75).dy, at(0, 0.82).dx, at(0, 0.82).dy)
      ..quadraticBezierTo(
          at(-0.55, 0.75).dx, at(0, 0.75).dy, at(-0.6, 0.0).dx, at(0, 0.0).dy)
      ..close();
    canvas.drawPath(mask, fill(const Color(0xFFE6E9F0)));
    eyes(dy: -0.18, dx: 0.34);
    muzzle(Colors.white, dy: 0.38, width: 0.66, height: 0.5);
    nose(dy: 0.24);
    mouth(dy: 0.44, width: 0.12);
  }

  void _dog() {
    const fur = Color(0xFFE2AC6E);
    const ear = Color(0xFF9A6236);
    for (final side in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(at(side * 0.5, -0.8).dx, at(0, -0.8).dy)
        ..quadraticBezierTo(at(side * 1.35, -0.7).dx, at(0, -0.7).dy,
            at(side * 1.1, 0.25).dx, at(0, 0.25).dy)
        ..quadraticBezierTo(at(side * 0.85, 0.35).dx, at(0, 0.35).dy,
            at(side * 0.7, -0.2).dx, at(0, -0.2).dy)
        ..close();
      blob(p, ear);
    }
    head(fur);
    canvas.drawOval(
        Rect.fromCenter(
            center: at(0.36, -0.14), width: r * 0.5, height: r * 0.48),
        fill(const Color(0xFFC88A4E)));
    eyes(dy: -0.14);
    muzzle(const Color(0xFFFFF0D9), dy: 0.34, width: 0.84, height: 0.56);
    nose(dy: 0.2, size: 1.2);
    mouth(dy: 0.4, width: 0.16);
    if (!happy) {
      canvas.drawPath(oval(at(0.02, 0.56), r * 0.16, r * 0.2),
          fill(const Color(0xFFFF8FA3)));
    }
  }

  void _cat() {
    const fur = Color(0xFFFFB86B);
    pointyEars(fur, const Color(0xFFFFB3C7), spread: 0.55, height: 1.18);
    head(fur);
    final mark = fill(const Color(0xFFE88E3A));
    for (final dx in [-0.16, 0.0, 0.16]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: at(dx, -0.72), width: r * 0.1, height: r * 0.3),
          mark);
    }
    eyes(dy: -0.08);
    nose(dy: 0.16, color: const Color(0xFFE0607E), size: 0.8);
    mouth(dy: 0.28, width: 0.15);
    whiskers(dy: 0.22);
    cheeks(dy: 0.24, dx: 0.6);
  }

  void _mouse() {
    const fur = Color(0xFFC9C3D6);
    roundEars(fur, const Color(0xFFFFB3C7), dx: 0.78, dy: -0.66, size: 0.52);
    head(fur, sx: 0.96, sy: 0.9);
    eyes(dy: -0.08, dx: 0.32);
    nose(dy: 0.2, color: const Color(0xFFE0607E), size: 0.8);
    mouth(dy: 0.32, width: 0.12);
    whiskers(dy: 0.25);
    cheeks(dy: 0.22, dx: 0.56);
  }

  void _rabbit() {
    const fur = Color(0xFFFFF5F7);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(at(side * 0.38, -0.7).dx, at(0, -0.7).dy);
      canvas.rotate(side * 0.18);
      blob(oval(Offset(0, -r * 0.55), r * 0.42, r * 1.25), fur);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, -r * 0.55), width: r * 0.2, height: r * 0.9),
          fill(const Color(0xFFFFB3C7)));
      canvas.restore();
    }
    head(fur);
    eyes(dy: -0.1);
    nose(dy: 0.18, color: const Color(0xFFFF8FA3), size: 0.8);
    mouth(dy: 0.3, width: 0.13);
    final teeth =
        Rect.fromCenter(center: at(0, 0.42), width: r * 0.2, height: r * 0.16);
    canvas.drawRRect(RRect.fromRectAndRadius(teeth, Radius.circular(r * 0.03)),
        fill(Colors.white));
    if (outline) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(teeth, Radius.circular(r * 0.03)),
          inkStroke(w * 0.6));
    }
    cheeks();
  }

  void _panda() {
    roundEars(const Color(0xFF3A3F5C), const Color(0xFF3A3F5C),
        dx: 0.72, dy: -0.72, size: 0.34);
    head(Colors.white);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(at(side * 0.36, -0.08).dx, at(0, -0.08).dy);
      canvas.rotate(side * -0.5);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: r * 0.44, height: r * 0.58),
          fill(const Color(0xFF3A3F5C)));
      canvas.restore();
    }
    eyes(dy: -0.1, size: 0.8, color: Colors.white);
    if (!happy) {
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(at(side * 0.36, -0.1), r * 0.06, fill(Palette.ink));
      }
    }
    nose(dy: 0.24, color: const Color(0xFF3A3F5C));
    mouth(dy: 0.38, width: 0.14);
    cheeks(dy: 0.3, dx: 0.62);
  }

  void _frog() {
    const skin = Color(0xFF7ED957);
    for (final side in [-1.0, 1.0]) {
      blob(circle(at(side * 0.45, -0.62), r * 0.38), skin);
    }
    blob(oval(at(0, 0.1), r * 2.1, r * 1.6), skin);
    for (final side in [-1.0, 1.0]) {
      final e = at(side * 0.45, -0.64);
      canvas.drawCircle(e, r * 0.26, fill(Colors.white));
      if (outline) canvas.drawCircle(e, r * 0.26, inkStroke(w * 0.7));
      if (happy) {
        final p = Path()
          ..moveTo(e.dx - r * 0.12, e.dy + r * 0.03)
          ..quadraticBezierTo(
              e.dx, e.dy - r * 0.12, e.dx + r * 0.12, e.dy + r * 0.03);
        canvas.drawPath(p, inkStroke(w * 1.2));
      } else {
        canvas.drawOval(
            Rect.fromCenter(
                center: e,
                width: r * 0.16,
                height: r * 0.2 * (1 - blink * 0.9)),
            fill(Palette.ink));
      }
    }
    final smile = Path()
      ..moveTo(at(-0.6, 0.2).dx, at(0, 0.2).dy)
      ..quadraticBezierTo(
          at(0, 0.62).dx, at(0, 0.62).dy, at(0.6, 0.2).dx, at(0, 0.2).dy);
    canvas.drawPath(smile, inkStroke(w));
    cheeks(dy: 0.32, dx: 0.7);
  }

  void _pig() {
    const skin = Color(0xFFFFB3C7);
    for (final side in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(at(side * 0.35, -0.82).dx, at(0, -0.82).dy)
        ..lineTo(at(side * 0.95, -1.0).dx, at(0, -1.0).dy)
        ..lineTo(at(side * 0.82, -0.36).dx, at(0, -0.36).dy)
        ..close();
      blob(ear, const Color(0xFFFF9AB5));
    }
    head(skin);
    eyes(dy: -0.2, dx: 0.38);
    blob(oval(at(0, 0.28), r * 0.72, r * 0.5), const Color(0xFFFF8FAE), 0.8);
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: at(side * 0.14, 0.28), width: r * 0.12, height: r * 0.2),
          fill(const Color(0xFFB8324F)));
    }
    cheeks(dy: 0.1, dx: 0.66);
  }

  void _roundEared(Color skin, Color muzzleColor, {required Color innerEar}) {
    roundEars(skin, innerEar);
    head(skin);
    eyes(dy: -0.14);
    muzzle(muzzleColor, dy: 0.32, width: 0.78, height: 0.56);
    nose(dy: 0.2);
    mouth(dy: 0.38, width: 0.14);
    cheeks(dy: 0.18, dx: 0.62);
  }

  void _chick() {
    const feather = Color(0xFFFFE066);
    for (final dx in [-0.12, 0.08]) {
      blob(oval(at(dx, -0.95), r * 0.22, r * 0.42), feather, 0.8);
    }
    head(feather, sx: 1, sy: 1);
    eyes(dy: -0.16, dx: 0.34);
    final beak = Path()
      ..moveTo(at(-0.2, 0.08).dx, at(0, 0.08).dy)
      ..lineTo(at(0.2, 0.08).dx, at(0, 0.08).dy)
      ..lineTo(at(0, 0.36).dx, at(0, 0.36).dy)
      ..close();
    blob(beak, Candy.orange.face, 0.8);
    cheeks(dy: 0.14, dx: 0.6);
  }

  void _fox() {
    const fur = Color(0xFFFF8A3D);
    pointyEars(fur, const Color(0xFFFFE0C7),
        spread: 0.55, height: 1.3, tipColorShare: 0.32, tip: Palette.ink);
    head(fur, sx: 1.04, sy: 0.9);
    final cheeksPath = Path()
      ..moveTo(at(-1.0, 0.05).dx, at(0, 0.05).dy)
      ..quadraticBezierTo(
          at(-0.3, -0.05).dx, at(0, -0.05).dy, at(0, 0.3).dx, at(0, 0.3).dy)
      ..quadraticBezierTo(
          at(0.3, -0.05).dx, at(0, -0.05).dy, at(1.0, 0.05).dx, at(0, 0.05).dy)
      ..quadraticBezierTo(
          at(0.6, 0.8).dx, at(0, 0.8).dy, at(0, 0.86).dx, at(0, 0.86).dy)
      ..quadraticBezierTo(
          at(-0.6, 0.8).dx, at(0, 0.8).dy, at(-1.0, 0.05).dx, at(0, 0.05).dy)
      ..close();
    canvas.save();
    canvas.clipPath(oval(c, r * 2.08, r * 1.8));
    canvas.drawPath(cheeksPath, fill(Colors.white));
    canvas.restore();
    eyes(dy: -0.16, dx: 0.36);
    nose(dy: 0.32);
    mouth(dy: 0.48, width: 0.12);
  }

  void _cow() {
    const skin = Color(0xFFFFFBF5);
    for (final side in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(at(side * 0.3, -0.8).dx, at(0, -0.8).dy)
        ..quadraticBezierTo(at(side * 0.5, -1.25).dx, at(0, -1.25).dy,
            at(side * 0.62, -1.1).dx, at(0, -1.1).dy)
        ..lineTo(at(side * 0.55, -0.75).dx, at(0, -0.75).dy)
        ..close();
      blob(horn, const Color(0xFFF2D49B), 0.8);
      blob(oval(at(side * 1.0, -0.38), r * 0.55, r * 0.3), skin);
    }
    head(skin);
    canvas.save();
    canvas.clipPath(oval(c, r * 2, r * 1.88));
    canvas.drawPath(
        oval(at(0.55, -0.55), r * 0.8, r * 0.7), fill(const Color(0xFF3A3F5C)));
    canvas.drawPath(
        oval(at(-0.75, 0.1), r * 0.45, r * 0.5), fill(const Color(0xFF3A3F5C)));
    canvas.restore();
    stroke(oval(c, r * 2, r * 1.88));
    eyes(dy: -0.18, color: Palette.ink);
    blob(oval(at(0, 0.42), r * 1.0, r * 0.62), const Color(0xFFFFB3C7), 0.8);
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: at(side * 0.2, 0.42), width: r * 0.12, height: r * 0.18),
          fill(const Color(0xFFB8324F)));
    }
  }

  void _monkey() {
    const fur = Color(0xFFB07A4F);
    const face = Color(0xFFF6D3AE);
    roundEars(fur, face, dx: 0.98, dy: -0.05, size: 0.34);
    head(fur);
    final mask = Path()
      ..moveTo(at(0, -0.3).dx, at(0, -0.3).dy)
      ..cubicTo(at(-0.5, -0.85).dx, at(0, -0.85).dy, at(-0.95, -0.2).dx,
          at(0, -0.2).dy, at(-0.6, 0.3).dx, at(0, 0.3).dy)
      ..quadraticBezierTo(
          at(0, 0.95).dx, at(0, 0.95).dy, at(0.6, 0.3).dx, at(0, 0.3).dy)
      ..cubicTo(at(0.95, -0.2).dx, at(0, -0.2).dy, at(0.5, -0.85).dx,
          at(0, -0.85).dy, at(0, -0.3).dx, at(0, -0.3).dy)
      ..close();
    canvas.drawPath(mask, fill(face));
    eyes(dy: -0.16, dx: 0.3);
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(at(side * 0.08, 0.2), r * 0.04, fill(Palette.ink));
    }
    mouth(dy: 0.42, width: 0.22);
  }

  void _koala() {
    const fur = Color(0xFFA9A9BC);
    roundEars(fur, Colors.white, dx: 0.85, dy: -0.55, size: 0.48);
    head(fur);
    eyes(dy: -0.14, dx: 0.4, size: 0.85);
    blob(oval(at(0, 0.18), r * 0.42, r * 0.56), const Color(0xFF3A3F5C), 0.5);
    canvas.drawCircle(
        at(-0.06, 0.04), r * 0.06, fill(Colors.white.withOpacity(0.6)));
    mouth(dy: 0.5, width: 0.12);
    cheeks(dy: 0.2, dx: 0.62);
  }

  void _penguin() {
    const body = Color(0xFF3A3F5C);
    head(body, sx: 1, sy: 1);
    final mask = Path()
      ..addOval(Rect.fromCircle(center: at(-0.3, 0.02), radius: r * 0.52))
      ..addOval(Rect.fromCircle(center: at(0.3, 0.02), radius: r * 0.52))
      ..addOval(
          Rect.fromCenter(center: at(0, 0.4), width: r * 1.3, height: r * 0.9));
    canvas.drawPath(mask, fill(Colors.white));
    eyes(dy: -0.04, dx: 0.3);
    final beak = Path()
      ..moveTo(at(-0.18, 0.24).dx, at(0, 0.24).dy)
      ..lineTo(at(0.18, 0.24).dx, at(0, 0.24).dy)
      ..lineTo(at(0, 0.48).dx, at(0, 0.48).dy)
      ..close();
    blob(beak, Candy.orange.face, 0.8);
    cheeks(dy: 0.3, dx: 0.56);
  }

  void _owl() {
    const feather = Color(0xFFB0835A);
    for (final side in [-1.0, 1.0]) {
      final tuft = Path()
        ..moveTo(at(side * 0.4, -0.78).dx, at(0, -0.78).dy)
        ..lineTo(at(side * 0.85, -1.15).dx, at(0, -1.15).dy)
        ..lineTo(at(side * 0.82, -0.5).dx, at(0, -0.5).dy)
        ..close();
      blob(tuft, feather);
    }
    head(feather, sx: 1.02, sy: 0.96);
    for (final side in [-1.0, 1.0]) {
      final e = at(side * 0.38, -0.08);
      blob(circle(e, r * 0.4), const Color(0xFFFFF0D2), 0.7);
      canvas.drawCircle(e, r * 0.27, fill(Candy.sun.face));
    }
    eyes(dy: -0.08, dx: 0.38, size: 1.05);
    final beak = Path()
      ..moveTo(at(-0.12, 0.2).dx, at(0, 0.2).dy)
      ..lineTo(at(0.12, 0.2).dx, at(0, 0.2).dy)
      ..lineTo(at(0, 0.45).dx, at(0, 0.45).dy)
      ..close();
    blob(beak, Candy.orange.face, 0.8);
  }

  void _mole() {
    const fur = Color(0xFF9C7A63);
    head(fur, sx: 1, sy: 1);
    blob(oval(at(0, 0.36), r * 1.1, r * 0.78), const Color(0xFFE8C6A8), 0.7);
    eyes(dy: -0.24, dx: 0.32, size: 0.8);
    blob(oval(at(0, 0.18), r * 0.42, r * 0.3), const Color(0xFFFF8FA3), 0.7);
    mouth(dy: 0.44, width: 0.14);
    final teeth =
        Rect.fromCenter(center: at(0, 0.56), width: r * 0.18, height: r * 0.14);
    canvas.drawRect(teeth, fill(Colors.white));
    if (outline) canvas.drawRect(teeth, inkStroke(w * 0.5));
    cheeks(dy: 0.22, dx: 0.66);
  }
}
