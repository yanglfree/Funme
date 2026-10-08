import 'package:flutter/material.dart';

/// Bouncy zoom-in page transition used for every in-app navigation.
class FunRoute<T> extends PageRouteBuilder<T> {
  FunRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 460),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final scale = Tween(begin: 0.86, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeInCubic,
              ),
            );
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.6, curve: Curves.easeOut),
            );
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
        );
}
