import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/feedback/haptics.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/candy_panel.dart';
import '../../core/widgets/game_scaffold.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/particles.dart';
import '../../core/widgets/result_overlay.dart';
import '../../core/widgets/setup_sheet.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'snake_rules.dart';

enum _Phase { idle, countdown, playing, paused, over }

class SnakePage extends StatefulWidget {
  const SnakePage({super.key});

  static Widget create(BuildContext context) => const SnakePage();

  @override
  State<SnakePage> createState() => _SnakePageState();
}

class _SnakePageState extends State<SnakePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _cols = 15;
  static const _rows = 18;

  final _particles = ParticleController();
  final _focus = FocusNode();
  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  SnakeGame _game = SnakeGame(cols: _cols, rows: _rows);
  List<(int, int)> _prev = const [];
  Duration _last = Duration.zero;
  double _acc = 0;
  _Phase _phase = _Phase.idle;
  bool _wrap = false;
  int _baseMs = 200;
  bool _pad = true;
  double _cell = 0;
  Offset _drag = Offset.zero;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  double _clock = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prev = List.of(_game.body);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSetup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _countdown.dispose();
    _shake.dispose();
    _particles.dispose();
    _focus.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _phase == _Phase.playing) {
      _pause();
    }
  }

  Future<void> _openSetup() async {
    if (_phase == _Phase.playing) _pause();
    final raw = AppStore.instance.setup(GameCatalog.snake.id) ?? const {};
    final values = await showSetupSheet(
      context,
      title: '贪吃蛇',
      initial: {for (final e in raw.entries) e.key: '${e.value}'},
      groups: const [
        SetupGroup(key: 'speed', title: '速度', choices: [
          SetupChoice('240', '慢慢爬 🐢', candy: Candy.mint),
          SetupChoice('190', '普通', candy: Candy.sun),
          SetupChoice('150', '飞快 ⚡', candy: Candy.cherry),
        ]),
        SetupGroup(key: 'wrap', title: '墙壁', choices: [
          SetupChoice('no', '撞墙会输', candy: Candy.orange),
          SetupChoice('yes', '可以穿墙', candy: Candy.grape),
        ]),
        SetupGroup(key: 'pad', title: '操作', choices: [
          SetupChoice('yes', '方向键 + 滑动', candy: Candy.ocean),
          SetupChoice('no', '只用滑动', candy: Candy.berry),
        ]),
      ],
    );
    if (!mounted) return;
    final v = values ?? {for (final e in raw.entries) e.key: '${e.value}'};
    if (values != null) {
      AppStore.instance.saveSetup(GameCatalog.snake.id, values);
    }
    setState(() {
      _baseMs = int.tryParse(v['speed'] ?? '') ?? 200;
      _wrap = v['wrap'] == 'yes';
      _pad = v['pad'] != 'no';
    });
    _newGame();
  }

  void _newGame() {
    _ticker.stop();
    setState(() {
      _game = SnakeGame(cols: _cols, rows: _rows, wrap: _wrap);
      _prev = List.of(_game.body);
      _acc = 0;
      _phase = _Phase.countdown;
    });
    _focus.requestFocus();
    for (var i = 0; i < 3; i++) {
      Future<void>.delayed(Duration(milliseconds: i * 1000), () {
        if (mounted && _phase == _Phase.countdown) {
          Fx.play(Sfx.tick, buzz: Buzz.tap);
        }
      });
    }
    _countdown.forward(from: 0).whenComplete(() {
      if (!mounted || _phase != _Phase.countdown) return;
      Fx.play(Sfx.go, buzz: Buzz.light);
      _start();
    });
  }

  void _start() {
    setState(() => _phase = _Phase.playing);
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _pause() {
    _ticker.stop();
    setState(() => _phase = _Phase.paused);
  }

  void _tick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _clock += dt;
    final interval = _game.interval(_baseMs).inMicroseconds / 1e6;
    _acc += dt;
    while (_acc >= interval && _phase == _Phase.playing) {
      _acc -= interval;
      _prev = List.of(_game.body);
      final event = _game.step();
      switch (event) {
        case SnakeEvent.eat:
          Fx.play(Sfx.eat, buzz: Buzz.light);
          _burst(_game.body.first,
              const [Color(0xFFFF5A5F), Color(0xFFFFC83D), Color(0xFF34D1A0)]);
        case SnakeEvent.bonus:
          Fx.play(Sfx.star, buzz: Buzz.medium);
          _burst(_game.body.first, const [Color(0xFFFFC83D), Colors.white]);
        case SnakeEvent.crash:
          _crash();
          return;
        case SnakeEvent.none:
          break;
      }
    }
    _frame.value++;
  }

  void _burst((int, int) cell, List<Color> colors) {
    final ctx = _boardKey.currentContext;
    if (ctx == null) return;
    _particles.burstFrom(
        ctx, Offset((cell.$1 + 0.5) * _cell, (cell.$2 + 0.5) * _cell),
        count: 14, colors: colors);
  }

  final _boardKey = GlobalKey();

  Future<void> _crash() async {
    _ticker.stop();
    Fx.play(Sfx.crash, buzz: Buzz.heavy);
    _shake.forward(from: 0);
    setState(() => _phase = _Phase.over);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final score = _game.score;
    final stars = SnakeGame.starsFor(score);
    final outcome = AppStore.instance.submit(GameCatalog.snake.id,
        stars: stars, win: stars > 0, score: score);
    final best =
        AppStore.instance.record(GameCatalog.snake.id).bestScore ?? score;
    final action = await showResultOverlay(
      context,
      kind: stars > 0 ? ResultKind.win : ResultKind.lose,
      title: stars > 0 ? '好厉害！' : '撞到啦！',
      message: stars > 0 ? '小蛇吃得饱饱的～' : '再来一次，吃更多水果吧',
      stars: stars,
      newRecord: outcome.newBestScore,
      stats: [('分数', '$score'), ('水果', '${_game.eaten}'), ('最高', '$best')],
    );
    if (!mounted) return;
    if (action == ResultAction.home) {
      Navigator.of(context).maybePop();
    } else {
      _newGame();
    }
  }

  void _turn(SnakeDir d) {
    if (_phase == _Phase.paused) _start();
    if (_phase != _Phase.playing && _phase != _Phase.countdown) return;
    _game.turn(d);
    Fx.play(Sfx.tap, volume: 0.4);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final dir = {
      LogicalKeyboardKey.arrowUp: SnakeDir.up,
      LogicalKeyboardKey.keyW: SnakeDir.up,
      LogicalKeyboardKey.arrowDown: SnakeDir.down,
      LogicalKeyboardKey.keyS: SnakeDir.down,
      LogicalKeyboardKey.arrowLeft: SnakeDir.left,
      LogicalKeyboardKey.keyA: SnakeDir.left,
      LogicalKeyboardKey.arrowRight: SnakeDir.right,
      LogicalKeyboardKey.keyD: SnakeDir.right,
    }[k];
    if (dir == null) return KeyEventResult.ignored;
    _turn(dir);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final best = AppStore.instance.record(GameCatalog.snake.id).bestScore ?? 0;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GameScaffold(
        title: '贪吃蛇',
        scenery: Scenery.meadow,
        rules: GameCatalog.snake.rules,
        onRestart: _openSetup,
        particles: _particles,
        isGameActive: () => _phase == _Phase.playing || _phase == _Phase.paused,
        actions: [
          CandyIconButton(
            icon: _phase == _Phase.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            candy: Candy.ocean,
            onTap: _phase == _Phase.playing
                ? _pause
                : (_phase == _Phase.paused ? _start : null),
          ),
        ],
        header: ValueListenableBuilder<int>(
          valueListenable: _frame,
          builder: (context, _, __) => Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              CandyChip(
                  label: '分数 ${_game.score}', candy: Candy.sun, fontSize: 16),
              CandyChip(label: '最高 $best', candy: Candy.cream, fontSize: 16),
              CandyChip(
                  label: '长度 ${_game.body.length}',
                  candy: Candy.mint,
                  fontSize: 16),
            ],
          ),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: _cols / _rows,
            child: LayoutBuilder(
              builder: (context, c) {
                _cell = c.maxWidth / _cols;
                return GestureDetector(
                  onPanStart: (_) => _drag = Offset.zero,
                  onPanUpdate: (d) {
                    _drag += d.delta;
                    if (_drag.distance < 16) return;
                    if (_drag.dx.abs() > _drag.dy.abs()) {
                      _turn(_drag.dx > 0 ? SnakeDir.right : SnakeDir.left);
                    } else {
                      _turn(_drag.dy > 0 ? SnakeDir.down : SnakeDir.up);
                    }
                    _drag = Offset.zero;
                  },
                  onTap: () {
                    if (_phase == _Phase.paused) _start();
                  },
                  child: AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                          math.sin(_shake.value * math.pi * 8) *
                              8 *
                              (1 - _shake.value),
                          0),
                      child: child,
                    ),
                    child: Stack(
                      key: _boardKey,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SnakePainter(
                              game: _game,
                              prev: _prev,
                              progress: () => (_acc /
                                      _game.interval(_baseMs).inMicroseconds *
                                      1e6)
                                  .clamp(0.0, 1.0),
                              clock: () => _clock,
                              frame: _frame,
                              dead: _phase == _Phase.over,
                            ),
                          ),
                        ),
                        if (_phase == _Phase.countdown)
                          Positioned.fill(child: _Countdown(_countdown)),
                        if (_phase == _Phase.paused)
                          Positioned.fill(
                            child: ColoredBox(
                              color: Palette.ink.withOpacity(0.35),
                              child: const Center(
                                  child: OutlinedText('暂停中 · 点一下继续', size: 26)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        footer: _pad ? _DPad(onDir: _turn) : null,
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown(this.anim);

  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value * 3;
        final n = 3 - t.floor();
        final f = t - t.floor();
        final scale =
            1.6 - Curves.easeOutBack.transform(f.clamp(0.0, 1.0)) * 0.6;
        return Center(
          child: Opacity(
            opacity: (1 - f * 0.6).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: OutlinedText(n > 0 ? '$n' : '开始！',
                  size: 84, color: Candy.sun.face, strokeWidth: 12),
            ),
          ),
        );
      },
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad({required this.onDir});

  final ValueChanged<SnakeDir> onDir;

  @override
  Widget build(BuildContext context) {
    Widget b(SnakeDir d, IconData icon) =>
        _PadButton(icon: icon, onPress: () => onDir(d));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        b(SnakeDir.left, Icons.arrow_back_rounded),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            b(SnakeDir.up, Icons.arrow_upward_rounded),
            const SizedBox(height: 6),
            b(SnakeDir.down, Icons.arrow_downward_rounded),
          ],
        ),
        const SizedBox(width: 10),
        b(SnakeDir.right, Icons.arrow_forward_rounded),
      ],
    );
  }
}

/// Fires on pointer-down for zero-latency game control.
class _PadButton extends StatefulWidget {
  const _PadButton({required this.icon, required this.onPress});

  final IconData icon;
  final VoidCallback onPress;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _down = true);
        Haptics.tap();
        widget.onPress();
      },
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 64,
        height: 52,
        margin: EdgeInsets.only(top: _down ? 4 : 0, bottom: _down ? 0 : 4),
        decoration: BoxDecoration(
          color: _down ? Candy.mint.shade : Candy.mint.face,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.ink, width: 2.5),
          boxShadow: _down
              ? const []
              : [
                  BoxShadow(color: Candy.mint.shade, offset: const Offset(0, 4))
                ],
        ),
        child: Icon(widget.icon, color: Palette.ink, size: 30),
      ),
    );
  }
}

class _SnakePainter extends CustomPainter {
  _SnakePainter({
    required this.game,
    required this.prev,
    required this.progress,
    required this.clock,
    required ValueNotifier<int> frame,
    required this.dead,
  }) : super(repaint: frame);

  final SnakeGame game;
  final List<(int, int)> prev;
  final double Function() progress;
  final double Function() clock;
  final bool dead;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / game.cols;
    final board =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(c * 0.8));
    canvas.drawRRect(
        board.shift(Offset(0, c * 0.25)), Paint()..color = Palette.ink);
    canvas.save();
    canvas.clipRRect(board);
    for (var y = 0; y < game.rows; y++) {
      for (var x = 0; x < game.cols; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * c, y * c, c + 0.5, c + 0.5),
          Paint()
            ..color = (x + y).isEven
                ? const Color(0xFFB6EE8F)
                : const Color(0xFFA3E37A),
        );
      }
    }
    final time = clock();
    _fruit(canvas, game.food, c, game.fruit, time);
    final bonus = game.bonus;
    if (bonus != null && (game.bonusSteps > 10 || (time * 6).floor().isEven)) {
      final center = Offset((bonus.$1 + 0.5) * c, (bonus.$2 + 0.5) * c);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(time * 2);
      paintStar(canvas, Offset.zero, c * (0.48 + 0.05 * math.sin(time * 8)),
          outlineWidth: c * 0.08);
      canvas.restore();
    }
    _snake(canvas, c, progress(), time);
    canvas.restore();
    canvas.drawRRect(board, inkStroke(3));
  }

  void _fruit(Canvas canvas, (int, int) cell, double c, int kind, double time) {
    final center = Offset((cell.$1 + 0.5) * c, (cell.$2 + 0.5) * c);
    final r = c * (0.36 + 0.03 * math.sin(time * 5));
    canvas.drawOval(
        Rect.fromCenter(
            center: center + Offset(0, r * 0.9),
            width: r * 1.6,
            height: r * 0.5),
        Paint()..color = Colors.black.withOpacity(0.15));
    switch (kind) {
      case 1: // orange
        canvas.drawCircle(center, r, Paint()..color = Candy.orange.face);
        canvas.drawCircle(center, r, inkStroke(c * 0.07));
        canvas.drawOval(
            Rect.fromCenter(
                center: center + Offset(r * 0.2, -r * 1.0),
                width: r * 0.7,
                height: r * 0.35),
            Paint()..color = Palette.grass);
      case 2: // strawberry
        final berry = Path()
          ..moveTo(center.dx - r, center.dy - r * 0.4)
          ..quadraticBezierTo(center.dx, center.dy - r * 1.1, center.dx + r,
              center.dy - r * 0.4)
          ..quadraticBezierTo(center.dx + r * 0.7, center.dy + r * 0.9,
              center.dx, center.dy + r * 1.1)
          ..quadraticBezierTo(center.dx - r * 0.7, center.dy + r * 0.9,
              center.dx - r, center.dy - r * 0.4)
          ..close();
        canvas.drawPath(berry, Paint()..color = Candy.cherry.face);
        canvas.drawPath(berry, inkStroke(c * 0.07));
        for (final p in const [
          (-0.4, 0.0),
          (0.35, 0.05),
          (0.0, 0.45),
          (-0.1, -0.3),
          (0.3, -0.35)
        ]) {
          canvas.drawCircle(center + Offset(p.$1 * r, p.$2 * r), r * 0.08,
              Paint()..color = Candy.sun.light);
        }
        canvas.drawOval(
            Rect.fromCenter(
                center: center + Offset(0, -r * 0.8),
                width: r * 1.0,
                height: r * 0.35),
            Paint()..color = Palette.grass);
      case 3: // grapes
        for (final p in const [
          (-0.45, -0.3),
          (0.45, -0.3),
          (0.0, -0.3),
          (-0.22, 0.15),
          (0.22, 0.15),
          (0.0, 0.58)
        ]) {
          final g = center + Offset(p.$1 * r, p.$2 * r);
          canvas.drawCircle(g, r * 0.36, Paint()..color = Candy.grape.face);
          canvas.drawCircle(g, r * 0.36, inkStroke(c * 0.05));
        }
      default: // apple
        canvas.drawCircle(center, r, Paint()..color = Candy.cherry.face);
        canvas.drawCircle(center + Offset(-r * 0.35, -r * 0.35), r * 0.22,
            Paint()..color = Colors.white.withOpacity(0.6));
        canvas.drawCircle(center, r, inkStroke(c * 0.07));
        canvas.drawLine(
            center + Offset(0, -r * 0.8),
            center + Offset(r * 0.15, -r * 1.25),
            inkStroke(c * 0.07, color: const Color(0xFF8A5A2B)));
        canvas.drawOval(
            Rect.fromCenter(
                center: center + Offset(r * 0.45, -r * 1.05),
                width: r * 0.6,
                height: r * 0.3),
            Paint()..color = Palette.grass);
    }
  }

  Offset _lerpCell((int, int) a, (int, int) b, double t, double c) {
    var dx = (b.$1 - a.$1).toDouble();
    var dy = (b.$2 - a.$2).toDouble();
    // Wrap-around: slide toward the edge rather than across the board.
    if (dx.abs() > 1) dx = -dx.sign;
    if (dy.abs() > 1) dy = -dy.sign;
    return Offset((a.$1 + dx * t + 0.5) * c, (a.$2 + dy * t + 0.5) * c);
  }

  void _snake(Canvas canvas, double c, double t, double time) {
    final body = game.body;
    final pts = <Offset>[];
    for (var i = 0; i < body.length; i++) {
      final from = i < prev.length ? prev[i] : body[i];
      final to = body[i];
      pts.add(dead
          ? Offset((to.$1 + 0.5) * c, (to.$2 + 0.5) * c)
          : _lerpCell(from, to, t, c));
    }
    if (pts.isEmpty) return;
    final color = dead ? Candy.cherry : Candy.mint;
    // Break the path where the snake wraps across an edge.
    final paths = <Path>[];
    var path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      if ((pts[i] - pts[i - 1]).distance > c * 1.5) {
        paths.add(path);
        path = Path()..moveTo(pts[i].dx, pts[i].dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }
    paths.add(path);
    for (final p in paths) {
      canvas.drawPath(p, inkStroke(c * 0.86));
    }
    for (final p in paths) {
      canvas.drawPath(p, inkStroke(c * 0.7, color: color.face));
    }
    for (var i = 2; i < pts.length; i += 2) {
      canvas.drawCircle(
          pts[i], c * 0.13, Paint()..color = color.shade.withOpacity(0.7));
    }
    for (final p in paths) {
      canvas.drawPath(p.shift(Offset(-c * 0.1, -c * 0.12)),
          inkStroke(c * 0.16, color: color.light.withOpacity(0.7)));
    }
    final head = pts.first;
    final d = game.dir;
    final fwd = Offset(d.dx.toDouble(), d.dy.toDouble());
    final side = Offset(-fwd.dy, fwd.dx);
    if (!dead && (time * 0.8 % 1.0) < 0.25) {
      final tip = head + fwd * c * 0.75;
      canvas.drawLine(head + fwd * c * 0.4, tip,
          inkStroke(c * 0.08, color: Candy.cherry.face));
      canvas.drawLine(tip, tip + (fwd + side) * c * 0.12,
          inkStroke(c * 0.06, color: Candy.cherry.face));
      canvas.drawLine(tip, tip + (fwd - side) * c * 0.12,
          inkStroke(c * 0.06, color: Candy.cherry.face));
    }
    canvas.drawCircle(head, c * 0.52, Paint()..color = Palette.ink);
    canvas.drawCircle(head, c * 0.45, Paint()..color = color.face);
    for (final s in [-1.0, 1.0]) {
      final eye = head + fwd * c * 0.12 + side * s * c * 0.22;
      canvas.drawCircle(eye, c * 0.15, Paint()..color = Colors.white);
      canvas.drawCircle(eye, c * 0.15, inkStroke(c * 0.04));
      if (dead) {
        canvas.drawLine(eye - const Offset(1, 1) * 3,
            eye + const Offset(1, 1) * 3, inkStroke(c * 0.05));
        canvas.drawLine(eye - const Offset(1, -1) * 3,
            eye + const Offset(1, -1) * 3, inkStroke(c * 0.05));
      } else {
        canvas.drawCircle(
            eye + fwd * c * 0.05, c * 0.07, Paint()..color = Palette.ink);
      }
    }
    canvas.drawCircle(head - fwd * c * 0.05 + side * c * 0.32, c * 0.08,
        Paint()..color = Candy.berry.face.withOpacity(0.6));
    canvas.drawCircle(head - fwd * c * 0.05 - side * c * 0.32, c * 0.08,
        Paint()..color = Candy.berry.face.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(_SnakePainter old) => true;
}
