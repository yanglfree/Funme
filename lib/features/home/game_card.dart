import 'package:flutter/material.dart';

import '../../app/fun_route.dart';
import '../../core/art/shapes.dart';
import '../../core/game/game_info.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/candy_panel.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/pressable.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.info,
    required this.idle,
    required this.phase,
  });

  final GameInfo info;

  /// Shared idle clock (0..1 repeating) that drives the icon animation.
  final Animation<double> idle;

  /// Per-card offset so icons don't move in lockstep.
  final double phase;

  @override
  Widget build(BuildContext context) {
    final candy = info.candy;
    final record = AppStore.instance.record(info.id);
    return Pressable(
      pressedScale: 0.94,
      onTap: () => Navigator.of(context).push(FunRoute(builder: info.builder)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Palette.ink, width: 3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [candy.light, candy.face],
          ),
          boxShadow: [
            BoxShadow(color: candy.shade, offset: const Offset(0, 6)),
            const BoxShadow(color: Palette.ink, offset: Offset(0, 8)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Transform.translate(
                    offset: const Offset(18, -18),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _IconPainter(info.icon, idle, phase),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: OutlinedText(info.name, size: 21, strokeWidth: 5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FunText.caption(
                        color: Palette.ink.withOpacity(0.75), size: 12),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CandyChip(
                            label: info.players,
                            candy: Candy.cream,
                            fontSize: 11),
                        const SizedBox(width: 6),
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: StarIcon(size: 16, filled: i < record.stars),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.idle, this.phase) : super(repaint: idle);

  final GameIconPainter icon;
  final Animation<double> idle;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    icon(canvas, size, (idle.value + phase) % 1.0);
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) => oldDelegate.icon != icon;
}
