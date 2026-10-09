import 'package:flutter/material.dart';

import '../core/layout/adaptive_scale.dart';
import '../core/theme/fun_theme.dart';
import '../core/widgets/volume_overlay.dart';
import '../features/home/home_page.dart';
import '../features/parents/play_time_guard.dart';

class FunmeApp extends StatelessWidget {
  const FunmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '趣玩岛',
      debugShowCheckedModeBanner: false,
      theme: buildFunTheme(),
      builder: (context, child) {
        // Kids' UI is laid out for a fixed type scale; clamp extreme system
        // text scaling so boards and buttons keep their proportions.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler
                .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
          ),
          child: AdaptiveScale(
            child: VolumeOverlay(
              child: PlayTimeGuard(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
      home: const HomePage(),
    );
  }
}
