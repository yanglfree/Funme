import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData buildFunTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Candy.ocean.face,
      primary: Candy.ocean.face,
      secondary: Candy.sun.face,
      surface: Palette.cream,
    ),
    fontFamily: FunFonts.family,
    scaffoldBackgroundColor: Palette.skyBottom,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
