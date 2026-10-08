import 'package:flutter/material.dart';

import '../art/mascot.dart';
import '../game/duel.dart';
import '../theme/palette.dart';
import 'candy_button.dart';
import 'candy_panel.dart';
import 'pressable.dart';

@immutable
class SetupChoice {
  const SetupChoice(this.value, this.label, {this.candy});

  final String value;
  final String label;
  final Candy? candy;
}

@immutable
class SetupGroup {
  const SetupGroup({
    required this.key,
    required this.title,
    required this.choices,
    this.visibleWhen,
  });

  final String key;
  final String title;
  final List<SetupChoice> choices;
  final bool Function(Map<String, String> values)? visibleWhen;
}

/// Standard groups for a two-sided match: mode, AI level and who starts.
List<SetupGroup> duelSetupGroups({
  String humanFirstLabel = '我先走',
  String aiFirstLabel = '电脑先走',
}) {
  bool vsAi(Map<String, String> v) => v['mode'] == PlayMode.vsAi.name;
  return [
    SetupGroup(
      key: 'mode',
      title: '对战方式',
      choices: [
        SetupChoice(PlayMode.vsAi.name, '和电脑玩', candy: Candy.ocean),
        SetupChoice(PlayMode.duo.name, '两人对战', candy: Candy.berry),
      ],
    ),
    SetupGroup(
      key: 'level',
      title: '电脑难度',
      visibleWhen: vsAi,
      choices: [
        SetupChoice(AiLevel.easy.name, '简单 ★', candy: Candy.mint),
        SetupChoice(AiLevel.normal.name, '普通 ★★', candy: Candy.sun),
        SetupChoice(AiLevel.hard.name, '困难 ★★★', candy: Candy.cherry),
      ],
    ),
    SetupGroup(
      key: 'first',
      title: '谁先走',
      visibleWhen: vsAi,
      choices: [
        SetupChoice('human', humanFirstLabel, candy: Candy.sun),
        SetupChoice('ai', aiFirstLabel, candy: Candy.grape),
      ],
    ),
  ];
}

Future<Map<String, String>?> showSetupSheet(
  BuildContext context, {
  required String title,
  required List<SetupGroup> groups,
  required Map<String, String> initial,
  String startLabel = '开始游戏',
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Palette.ink.withOpacity(0.35),
    builder: (context) => _SetupSheet(
      title: title,
      groups: groups,
      initial: initial,
      startLabel: startLabel,
    ),
  );
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({
    required this.title,
    required this.groups,
    required this.initial,
    required this.startLabel,
  });

  final String title;
  final List<SetupGroup> groups;
  final Map<String, String> initial;
  final String startLabel;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late final Map<String, String> _values = {
    for (final g in widget.groups)
      g.key: g.choices.any((c) => c.value == widget.initial[g.key])
          ? widget.initial[g.key]!
          : g.choices.first.value,
  };

  @override
  Widget build(BuildContext context) {
    final visible = widget.groups
        .where((g) => g.visibleWhen?.call(_values) ?? true)
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: CandyPanel(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Mascot(mood: MascotMood.happy, size: 56),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.title, style: FunText.title())),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final group in visible) ...[
                            const SizedBox(height: 12),
                            Text(group.title,
                                style: FunText.body(
                                    color: Palette.inkSoft, size: 14)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final choice in group.choices)
                                  _ChoiceChip(
                                    choice: choice,
                                    selected:
                                        _values[group.key] == choice.value,
                                    onTap: () => setState(() =>
                                        _values[group.key] = choice.value),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                CandyButton(
                  label: widget.startLabel,
                  icon: Icons.play_arrow_rounded,
                  candy: Candy.mint,
                  height: 60,
                  fontSize: 22,
                  onTap: () => Navigator.of(context)
                      .pop(Map<String, String>.of(_values)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip(
      {required this.choice, required this.selected, required this.onTap});

  final SetupChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final candy = choice.candy ?? Candy.sun;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? candy.face : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? Palette.ink : candy.shade.withOpacity(0.5),
              width: selected ? 3 : 2),
          boxShadow: selected
              ? [BoxShadow(color: candy.shade, offset: const Offset(0, 4))]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.elasticOut,
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle_rounded,
                    color: Palette.ink, size: 18),
              ),
            ),
            Text(choice.label, style: FunText.body(size: 16)),
          ],
        ),
      ),
    );
  }
}
