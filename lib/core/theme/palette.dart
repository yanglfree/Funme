import 'package:flutter/widgets.dart';

/// A candy color: the visible [face], the darker [shade] used for the 3D lip
/// and outlines, and a [light] tint for highlights.
@immutable
class Candy {
  const Candy(this.face, this.shade, this.light);

  final Color face;
  final Color shade;
  final Color light;

  static const sun =
      Candy(Color(0xFFFFC83D), Color(0xFFE3A21A), Color(0xFFFFE9A8));
  static const orange =
      Candy(Color(0xFFFF8C42), Color(0xFFDB6A22), Color(0xFFFFC9A3));
  static const berry =
      Candy(Color(0xFFFF6B9D), Color(0xFFDB4A7C), Color(0xFFFFC2D7));
  static const mint =
      Candy(Color(0xFF34D1A0), Color(0xFF1FA47C), Color(0xFFA8F0D9));
  static const grape =
      Candy(Color(0xFF9B7BFF), Color(0xFF7653E0), Color(0xFFD7CBFF));
  static const ocean =
      Candy(Color(0xFF4AA8FF), Color(0xFF2A83D8), Color(0xFFB5DCFF));
  static const cherry =
      Candy(Color(0xFFFF5A5F), Color(0xFFD63A40), Color(0xFFFFB8BA));
  static const lime =
      Candy(Color(0xFF9BDB3C), Color(0xFF74B21E), Color(0xFFD9F5A8));
  static const cream =
      Candy(Color(0xFFFFF8EC), Color(0xFFEBD9BD), Color(0xFFFFFFFF));
  static const wood =
      Candy(Color(0xFFF4CE93), Color(0xFFC9955A), Color(0xFFFFE8C4));
  static const slate =
      Candy(Color(0xFF8C9BB5), Color(0xFF66748F), Color(0xFFD3DAE6));
}

abstract final class Palette {
  static const ink = Color(0xFF3A2D5C);
  static const inkSoft = Color(0xFF7A6E99);
  static const paper = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFF8EC);
  static const skyTop = Color(0xFF6CCBFF);
  static const skyBottom = Color(0xFFBFF0FF);
  static const grass = Color(0xFF7ED957);
  static const grassDark = Color(0xFF58B536);
  static const shadow = Color(0x33000000);

  /// Player colors used across multi-seat games (ludo, chinese checkers).
  static const seats = <Candy>[
    Candy.cherry,
    Candy.sun,
    Candy.ocean,
    Candy.mint,
    Candy.grape,
    Candy.orange,
  ];
}

abstract final class FunFonts {
  /// Hook for a bundled cartoon font. `null` keeps the platform font
  /// (PingFang / HarmonyOS Sans / Roboto).
  static const String? family = null;
}

abstract final class FunText {
  static TextStyle display({Color color = Palette.ink, double size = 34}) =>
      TextStyle(
        fontFamily: FunFonts.family,
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.1,
        letterSpacing: 1,
      );

  static TextStyle title({Color color = Palette.ink, double size = 22}) =>
      TextStyle(
        fontFamily: FunFonts.family,
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.2,
      );

  static TextStyle body({Color color = Palette.ink, double size = 16}) =>
      TextStyle(
        fontFamily: FunFonts.family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.35,
      );

  static TextStyle caption({Color color = Palette.inkSoft, double size = 13}) =>
      TextStyle(
        fontFamily: FunFonts.family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      );
}

abstract final class Motion {
  static const press = Duration(milliseconds: 90);
  static const release = Duration(milliseconds: 260);
  static const pop = Duration(milliseconds: 420);
  static const move = Duration(milliseconds: 280);
}
