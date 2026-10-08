import 'package:flutter/material.dart';

import '../feedback/fx.dart';

/// Squashes its child while pressed and springs back on release.
///
/// The default tap sound plays on release so a cancelled drag stays silent.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.92,
    this.sound = true,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool sound;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: widget.pressedScale,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.elasticIn,
    ),
  );

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (_active) _controller.forward();
  }

  void _up(TapUpDetails _) {
    if (!_active) return;
    _controller.reverse();
    if (widget.sound) Fx.tap();
    widget.onTap!.call();
  }

  void _cancel() {
    if (_active) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
