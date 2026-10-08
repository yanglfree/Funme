import 'package:flutter/material.dart';

import '../core/art/cartoon_animal.dart';
import '../core/art/mascot.dart';
import '../core/game/game_info.dart';
import '../core/theme/palette.dart';
import '../core/widgets/game_scaffold.dart';
import '../games/catalog.dart';

/// Debug-only page listing every procedural art asset for visual QA.
class ArtGalleryPage extends StatefulWidget {
  const ArtGalleryPage({super.key});

  @override
  State<ArtGalleryPage> createState() => _ArtGalleryPageState();
}

class _ArtGalleryPageState extends State<ArtGalleryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '美术图鉴',
      body: ListView(
        children: [
          Text('吉祥物', style: FunText.title()),
          Wrap(
            children: [
              for (final mood in MascotMood.values)
                Column(children: [
                  Mascot(mood: mood, size: 96),
                  Text(mood.name, style: FunText.caption()),
                ]),
            ],
          ),
          const SizedBox(height: 12),
          Text('动物', style: FunText.title()),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in Animal.values)
                Column(children: [
                  Container(
                    color: Colors.white54,
                    child: AnimalFace(a, size: 80),
                  ),
                  Text(a.label, style: FunText.caption()),
                ]),
              for (final a in Animal.values.take(4))
                AnimalFace(a, size: 80, happy: true),
            ],
          ),
          const SizedBox(height: 12),
          Text('游戏图标', style: FunText.title()),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in gameCatalog)
                Column(children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: g.candy.face,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CustomPaint(painter: _Icon(g.icon, _idle)),
                  ),
                  Text(g.name, style: FunText.caption()),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Icon extends CustomPainter {
  _Icon(this.icon, this.t) : super(repaint: t);

  final GameIconPainter icon;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) => icon(canvas, size, t.value);

  @override
  bool shouldRepaint(_Icon oldDelegate) => false;
}
