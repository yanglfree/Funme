import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../feedback/fx.dart';
import '../theme/palette.dart';
import 'candy_button.dart';
import 'candy_panel.dart';

/// Simple parental gate: a multiplication young kids can't answer yet.
/// Resolves to `true` only when answered correctly.
Future<bool> showParentGate(BuildContext context,
    {String reason = '进入家长中心'}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Palette.ink.withOpacity(0.5),
    builder: (context) => Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ParentGatePanel(
          reason: reason,
          onDone: (ok) => Navigator.of(context).pop(ok),
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// The gate itself, embeddable outside of a dialog (e.g. the rest overlay).
class ParentGatePanel extends StatefulWidget {
  const ParentGatePanel(
      {super.key, required this.reason, required this.onDone});

  final String reason;
  final ValueChanged<bool> onDone;

  @override
  State<ParentGatePanel> createState() => _ParentGatePanelState();
}

class _ParentGatePanelState extends State<ParentGatePanel>
    with SingleTickerProviderStateMixin {
  final _random = math.Random();
  late int _a;
  late int _b;
  String _input = '';
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    _a = 3 + _random.nextInt(7);
    _b = 6 + _random.nextInt(4);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      if (key == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (_input.length < 3) {
        _input += key;
      }
    });
  }

  void _submit() {
    if (int.tryParse(_input) == _a * _b) {
      Fx.play(Sfx.unlock, buzz: Buzz.light);
      widget.onDone(true);
      return;
    }
    Fx.error();
    _shake.forward(from: 0);
    setState(() {
      _input = '';
      _newQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fixed 340-wide layout, scaled down when the viewport is shorter than the
    // keypad (landscape tablets / phones) instead of overflowing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 340,
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                  math.sin(_shake.value * math.pi * 6) *
                      10 *
                      (1 - _shake.value),
                  0),
              child: child,
            ),
            child: CandyPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: Palette.ink, size: 36),
                  const SizedBox(height: 6),
                  Text('请家长回答', style: FunText.title()),
                  Text(widget.reason, style: FunText.caption()),
                  const SizedBox(height: 12),
                  Text('$_a × $_b = ${_input.isEmpty ? '?' : _input}',
                      style: FunText.display(size: 32)),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final key in const [
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9',
                        '⌫',
                        '0',
                        '✓'
                      ])
                        CandyButton(
                          label: key,
                          height: 44,
                          lip: 4,
                          radius: 14,
                          fontSize: 22,
                          candy: key == '✓'
                              ? Candy.mint
                              : (key == '⌫' ? Candy.berry : Candy.cream),
                          onTap: key == '✓' ? _submit : () => _press(key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => widget.onDone(false),
                    child:
                        Text('取消', style: FunText.body(color: Palette.inkSoft)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
