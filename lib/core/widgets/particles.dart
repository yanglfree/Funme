import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/shapes.dart';

enum ParticleShape { confetti, star, dot, heart }

class _Particle {
  _Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.shape,
    required this.life,
    required this.gravity,
    required this.spin,
    this.global = false,
  });

  /// Position is in global coordinates until the layer adopts it.
  bool global;
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final ParticleShape shape;
  final double life;
  final double gravity;
  final double spin;
  double age = 0;
  double rotation = 0;
}

/// Imperative handle for spawning particles into a [ParticleLayer].
class ParticleController extends ChangeNotifier {
  final List<_Particle> _pending = [];
  final math.Random _random = math.Random();

  static const defaultColors = <Color>[
    Color(0xFFFFC83D),
    Color(0xFFFF6B9D),
    Color(0xFF4AA8FF),
    Color(0xFF34D1A0),
    Color(0xFF9B7BFF),
    Color(0xFFFF8C42),
  ];

  /// Radial burst, e.g. a capture or a line clear at [origin] (layer-local).
  void burst(
    Offset origin, {
    int count = 18,
    List<Color> colors = defaultColors,
    ParticleShape shape = ParticleShape.star,
    double speed = 260,
    double size = 9,
    double gravity = 420,
    double life = 0.9,
    bool global = false,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final v = speed * (0.45 + _random.nextDouble() * 0.75);
      _pending.add(_Particle(
        position: origin,
        velocity:
            Offset(math.cos(angle) * v, math.sin(angle) * v - speed * 0.35),
        color: colors[_random.nextInt(colors.length)],
        size: size * (0.7 + _random.nextDouble() * 0.6),
        shape: shape,
        life: life * (0.7 + _random.nextDouble() * 0.5),
        gravity: gravity,
        spin: (_random.nextDouble() - 0.5) * 10,
        global: global,
      ));
    }
    notifyListeners();
  }

  /// Burst at [local] inside the widget owning [context], wherever the
  /// [ParticleLayer] sits in the tree.
  void burstFrom(
    BuildContext context,
    Offset local, {
    int count = 18,
    List<Color> colors = defaultColors,
    ParticleShape shape = ParticleShape.star,
    double speed = 260,
    double size = 9,
  }) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    burst(
      box.localToGlobal(local),
      count: count,
      colors: colors,
      shape: shape,
      speed: speed,
      size: size,
      global: true,
    );
  }

  /// Confetti rain falling from the top edge across [width].
  void rain(double width,
      {int count = 90, List<Color> colors = defaultColors}) {
    for (var i = 0; i < count; i++) {
      _pending.add(_Particle(
        position: Offset(
            _random.nextDouble() * width, -20 - _random.nextDouble() * 160),
        velocity: Offset((_random.nextDouble() - 0.5) * 140,
            120 + _random.nextDouble() * 180),
        color: colors[_random.nextInt(colors.length)],
        size: 8 + _random.nextDouble() * 7,
        shape: _random.nextInt(5) == 0
            ? ParticleShape.star
            : ParticleShape.confetti,
        life: 2.6 + _random.nextDouble() * 1.2,
        gravity: 90,
        spin: (_random.nextDouble() - 0.5) * 12,
      ));
    }
    notifyListeners();
  }

  List<_Particle> _drain() {
    final out = List<_Particle>.of(_pending);
    _pending.clear();
    return out;
  }
}

/// Paints particles above [child]. Ticks only while particles are alive.
class ParticleLayer extends StatefulWidget {
  const ParticleLayer(
      {super.key, required this.controller, required this.child});

  final ParticleController controller;
  final Widget child;

  @override
  State<ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<ParticleLayer>
    with SingleTickerProviderStateMixin {
  final List<_Particle> _live = [];
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    widget.controller.addListener(_onEmit);
  }

  @override
  void didUpdateWidget(ParticleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onEmit);
      widget.controller.addListener(_onEmit);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onEmit);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onEmit() {
    final fresh = widget.controller._drain();
    final box = context.findRenderObject();
    for (final p in fresh) {
      if (p.global && box is RenderBox && box.attached) {
        p.position = box.globalToLocal(p.position);
        p.global = false;
      }
    }
    _live.addAll(fresh);
    if (!_ticker.isActive && _live.isNotEmpty) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    for (final p in _live) {
      p.age += dt;
      p.velocity = Offset(
          p.velocity.dx * (1 - 0.6 * dt), p.velocity.dy + p.gravity * dt);
      p.position += p.velocity * dt;
      p.rotation += p.spin * dt;
    }
    _live.removeWhere((p) => p.age >= p.life);
    _frame.value++;
    if (_live.isEmpty) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ParticlePainter(_live, _frame)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, Listenable repaint)
      : super(repaint: repaint);

  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final fade = (1 - p.age / p.life).clamp(0.0, 1.0);
      final alpha = fade < 0.3 ? fade / 0.3 : 1.0;
      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);
      final paint = Paint()..color = p.color.withOpacity(alpha);
      switch (p.shape) {
        case ParticleShape.confetti:
          final flutter = 0.35 + 0.65 * math.cos(p.rotation * 1.7).abs();
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: p.size,
                  height: p.size * 0.55 * flutter),
              const Radius.circular(2),
            ),
            paint,
          );
        case ParticleShape.star:
          canvas.drawPath(
              starPath(Offset.zero, p.size * 0.75, inner: 0.5), paint);
        case ParticleShape.dot:
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
        case ParticleShape.heart:
          _heart(canvas, p.size, paint);
      }
      canvas.restore();
    }
  }

  void _heart(Canvas canvas, double s, Paint paint) {
    final path = Path()
      ..moveTo(0, s * 0.35)
      ..cubicTo(-s * 0.9, -s * 0.25, -s * 0.35, -s * 0.85, 0, -s * 0.3)
      ..cubicTo(s * 0.35, -s * 0.85, s * 0.9, -s * 0.25, 0, s * 0.35)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
