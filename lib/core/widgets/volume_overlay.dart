import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/shapes.dart';
import '../audio/volume_keys.dart';
import '../storage/app_store.dart';
import '../theme/palette.dart';

/// Draws the cartoon volume panel over the whole app whenever the volume keys
/// are pressed.
class VolumeOverlay extends StatefulWidget {
  const VolumeOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<VolumeOverlay> createState() => _VolumeOverlayState();
}

class _VolumeOverlayState extends State<VolumeOverlay>
    with SingleTickerProviderStateMixin {
  static const _visibleFor = Duration(milliseconds: 1600);

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 200),
  );
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    VolumeKeys.instance.changes.addListener(_show);
  }

  @override
  void dispose() {
    VolumeKeys.instance.changes.removeListener(_show);
    _hide?.cancel();
    _pop.dispose();
    super.dispose();
  }

  void _show() {
    if (_pop.status != AnimationStatus.completed) _pop.forward();
    _hide?.cancel();
    _hide = Timer(_visibleFor, () {
      if (mounted) _pop.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final top = pad.top + 10;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: top,
          right: math.max(pad.right, 0) + 12,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pop, AppStore.instance]),
              builder: (context, _) {
                if (_pop.isDismissed) return const SizedBox.shrink();
                final t = Curves.easeOutBack.transform(_pop.value);
                return Opacity(
                  opacity: _pop.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset((1 - t) * 48, 0),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * t,
                      alignment: Alignment.topRight,
                      child: _VolumePanel(volume: AppStore.instance.volume),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _VolumePanel extends StatelessWidget {
  const _VolumePanel({required this.volume});

  final double volume;

  static const _notches = 10;

  @override
  Widget build(BuildContext context) {
    final level = (volume * _notches).round();
    final candy = level >= 8
        ? Candy.cherry
        : level >= 4
            ? Candy.sun
            : Candy.mint;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Palette.ink, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 30,
              child: CustomPaint(painter: _SpeakerPainter(level, candy)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 124,
              height: 22,
              child: CustomPaint(painter: _NotchesPainter(level, candy)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text(
                '${level * 10}',
                textAlign: TextAlign.center,
                style: FunText.title(size: 16, color: Palette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerPainter extends CustomPainter {
  _SpeakerPainter(this.level, this.candy);

  final int level;
  final Candy candy;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final body = Path()
      ..moveTo(s * 0.12, s * 0.38)
      ..lineTo(s * 0.3, s * 0.38)
      ..lineTo(s * 0.52, s * 0.18)
      ..lineTo(s * 0.52, s * 0.82)
      ..lineTo(s * 0.3, s * 0.62)
      ..lineTo(s * 0.12, s * 0.62)
      ..close();
    canvas.drawPath(body, Paint()..color = candy.face);
    canvas.drawPath(body, inkStroke(2.4)..strokeJoin = StrokeJoin.round);

    final waves = level == 0 ? 0 : (level / 4).ceil().clamp(1, 3);
    for (var i = 1; i <= waves; i++) {
      final r = s * (0.14 + 0.13 * i);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(s * 0.52, s * 0.5), radius: r),
        -math.pi / 3.2,
        math.pi / 1.6,
        false,
        inkStroke(2.6)..strokeCap = StrokeCap.round,
      );
    }
    if (level == 0) {
      final cross = inkStroke(4, color: Candy.cherry.shade)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(s * 0.66, s * 0.36), Offset(s * 0.9, s * 0.64), cross);
      canvas.drawLine(
          Offset(s * 0.9, s * 0.36), Offset(s * 0.66, s * 0.64), cross);
    }
  }

  @override
  bool shouldRepaint(_SpeakerPainter old) =>
      old.level != level || old.candy != candy;
}

class _NotchesPainter extends CustomPainter {
  _NotchesPainter(this.level, this.candy);

  final int level;
  final Candy candy;

  @override
  void paint(Canvas canvas, Size size) {
    const n = _VolumePanel._notches;
    const gap = 3.0;
    final w = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final on = i < level;
      // Notches grow taller towards the loud end, like a signal meter.
      final h = size.height * (0.45 + 0.55 * (i + 1) / n);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (w + gap), size.height - h, w, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(
          rect, Paint()..color = on ? candy.face : const Color(0xFFE9E1D2));
      canvas.drawRRect(rect,
          inkStroke(1.8, color: on ? Palette.ink : const Color(0xFFCFC5B1)));
      if (on) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
                i * (w + gap) + 2.5, size.height - h + 3, w * 0.35, h * 0.4),
            const Radius.circular(3),
          ),
          Paint()..color = Colors.white.withOpacity(0.55),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_NotchesPainter old) =>
      old.level != level || old.candy != candy;
}
