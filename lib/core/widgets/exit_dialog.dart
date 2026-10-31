import 'package:flutter/material.dart';

import '../art/mascot.dart';
import '../theme/palette.dart';
import 'candy_button.dart';
import 'candy_panel.dart';

/// Shows a candy-themed confirmation dialog when the player attempts to exit
/// an ongoing game, assuring them that game progress is preserved.
Future<bool> showExitGameDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _ExitGameDialog(),
  );
  return result ?? false;
}

class _ExitGameDialog extends StatelessWidget {
  const _ExitGameDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CandyPanel(
          candy: Candy.cream,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mascot(mood: MascotMood.think, size: 68),
              const SizedBox(height: 12),
              Text(
                '要退出游戏吗？',
                style: FunText.title(size: 24, color: Palette.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '别担心，你的游戏进度已自动保存～\n下次进入时可以继续玩哦！',
                style: FunText.body(size: 15, color: Palette.ink.withOpacity(0.75)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CandyButton(
                      label: '退出',
                      candy: Candy.slate,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CandyButton(
                      label: '继续玩',
                      candy: Candy.mint,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
