import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'outlined_text.dart';

/// Imperative trigger for [FlashBanner].
class FlashController extends ChangeNotifier {
  String _text = '';
  Candy _candy = Candy.cherry;
  int _serial = 0;

  String get text => _text;
  Candy get candy => _candy;
  int get serial => _serial;

  void show(String text, {Candy candy = Candy.cherry}) {
    _text = text;
    _candy = candy;
    _serial++;
    notifyListeners();
  }
}

/// Big sticker word ("将军！", "炸弹！") that pops over the board and fades.
class FlashBanner extends StatefulWidget {
  const FlashBanner({super.key, required this.controller});

  final FlashController controller;

  @override
  State<FlashBanner> createState() => _FlashBannerState();
}

class _FlashBannerState extends State<FlashBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_play);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_play);
    _anim.dispose();
    super.dispose();
  }

  void _play() => _anim.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          if (!_anim.isAnimating) return const SizedBox.shrink();
          final t = _anim.value;
          final scale = t < 0.25
              ? Curves.elasticOut.transform(t / 0.25) * 1.0
              : 1.0 + (t - 0.25) * 0.08;
          final opacity = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;
          return Center(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -0.08,
                child: Transform.scale(
                  scale: scale.clamp(0.0, 2.0),
                  child: OutlinedText(
                    widget.controller.text,
                    size: 56,
                    color: widget.controller.candy.face,
                    strokeWidth: 10,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
