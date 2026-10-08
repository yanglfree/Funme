import 'dart:async';

import 'package:flutter/material.dart';

/// One piece on a board, identified by a stable [id] across moves.
@immutable
class PieceSpec {
  const PieceSpec({
    required this.id,
    required this.center,
    required this.child,
    this.lifted = false,
    this.z = 0,
  });

  final int id;
  final Offset center;
  final Widget child;
  final bool lifted;

  /// Higher paints later (on top).
  final int z;
}

/// Positions pieces by center and animates them between squares. Pieces
/// that disappear (captured) stay visible until the mover lands, then pop.
class AnimatedPieceLayer extends StatefulWidget {
  const AnimatedPieceLayer({
    super.key,
    required this.pieces,
    required this.size,
    this.pieceSize,
    this.moveDuration = const Duration(milliseconds: 300),
  });

  final List<PieceSpec> pieces;
  final double size;

  /// Non-square pieces (e.g. junqi tiles); defaults to [size] × [size].
  final Size? pieceSize;
  final Duration moveDuration;

  @override
  State<AnimatedPieceLayer> createState() => _AnimatedPieceLayerState();
}

class _AnimatedPieceLayerState extends State<AnimatedPieceLayer> {
  final Map<int, PieceSpec> _dying = {};
  final List<Timer> _timers = [];

  @override
  void didUpdateWidget(AnimatedPieceLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final alive = {for (final p in widget.pieces) p.id};
    for (final old in oldWidget.pieces) {
      if (alive.contains(old.id) || _dying.containsKey(old.id)) continue;
      _dying[old.id] = old;
      _timers.add(
          Timer(widget.moveDuration + const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _dying.remove(old.id));
      }));
    }
    for (final id in alive) {
      _dying.remove(id);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.pieceSize?.width ?? widget.size;
    final h = widget.pieceSize?.height ?? widget.size;
    final live = [...widget.pieces]..sort((a, b) => a.z.compareTo(b.z));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final p in _dying.values)
          Positioned(
            key: ValueKey('dying-${p.id}'),
            left: p.center.dx - w / 2,
            top: p.center.dy - h / 2,
            width: w,
            height: h,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(milliseconds: 260),
              curve: const Interval(0.45, 1, curve: Curves.easeInBack),
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
              ),
              child: p.child,
            ),
          ),
        for (final p in live)
          AnimatedPositioned(
            key: ValueKey(p.id),
            duration: widget.moveDuration,
            curve: Curves.easeInOutCubic,
            left: p.center.dx - w / 2,
            top: p.center.dy - h / 2,
            width: w,
            height: h,
            child: AnimatedScale(
              scale: p.lifted ? 1.16 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedSlide(
                offset: p.lifted ? const Offset(0, -0.08) : Offset.zero,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: p.child,
              ),
            ),
          ),
      ],
    );
  }
}
