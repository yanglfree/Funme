import 'package:flutter/material.dart';

import '../art/mascot.dart';
import '../theme/palette.dart';
import 'candy_button.dart';
import 'candy_panel.dart';

Future<void> showRulesSheet(
  BuildContext context, {
  required String title,
  required List<String> rules,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RulesSheet(title: title, rules: rules),
  );
}

class _RulesSheet extends StatelessWidget {
  const _RulesSheet({required this.title, required this.rules});

  final String title;
  final List<String> rules;

  static const _bubbles = [
    Candy.ocean,
    Candy.berry,
    Candy.mint,
    Candy.orange,
    Candy.grape,
    Candy.sun
  ];

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
          child: CandyPanel(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Mascot(mood: MascotMood.happy, size: 56),
                    const SizedBox(width: 8),
                    Expanded(child: Text('$title 怎么玩', style: FunText.title())),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _bubbles[i % _bubbles.length].face,
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.ink, width: 2),
                          ),
                          child: Text('${i + 1}',
                              style: FunText.caption(
                                  color: Palette.ink, size: 14)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child:
                                Text(rules[i], style: FunText.body(size: 15))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                CandyButton(
                  label: '知道啦',
                  candy: Candy.mint,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
