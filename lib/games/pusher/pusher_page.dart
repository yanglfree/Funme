import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/candy_panel.dart';
import '../../core/widgets/game_scaffold.dart';
import '../../core/widgets/particles.dart';
import '../../core/widgets/result_overlay.dart';
import '../../core/widgets/setup_sheet.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'pusher_rules.dart';

/// World rows above the shelf (the chute) and below it (the tray).
const _chute = 1.6;
const _tray = 2.0;

class PusherPage extends StatefulWidget {
  const PusherPage({super.key});

  static Widget create(BuildContext context) => const PusherPage();

  @override
  State<PusherPage> createState() => _PusherPageState();
}

class _PusherPageState extends State<PusherPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _particles = ParticleController();
  final _focus = FocusNode();
  final _boardKey = GlobalKey();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_tick);

  PusherGame _game = PusherGame();
  Duration _last = Duration.zero;
  double _cell = 0;
  double _aim = PusherGame.width / 2;
  double _cooldown = 0;
  int _coins = 25;
  double _speed = 1.7;
  bool _running = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSetup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _particles.dispose();
    _focus.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ticker.muted = state != AppLifecycleState.resumed;
    _last = Duration.zero;
  }

  Future<void> _openSetup() async {
    _ticker.stop();
    final raw = AppStore.instance.setup(GameCatalog.pusher.id) ?? const {};
    final values = await showSetupSheet(
      context,
      title: '推币机',
      initial: {for (final e in raw.entries) e.key: '${e.value}'},
      groups: const [
        SetupGroup(key: 'coins', title: '起始硬币', choices: [
          SetupChoice('20', '20 枚', candy: Candy.orange),
          SetupChoice('30', '30 枚', candy: Candy.sun),
          SetupChoice('40', '40 枚', candy: Candy.mint),
        ]),
        SetupGroup(key: 'speed', title: '推板速度', choices: [
          SetupChoice('1.3', '慢慢推 🐢', candy: Candy.mint),
          SetupChoice('1.7', '普通', candy: Candy.sun),
          SetupChoice('2.2', '飞快 ⚡', candy: Candy.cherry),
        ]),
      ],
    );
    if (!mounted) return;
    final v = values ?? {for (final e in raw.entries) e.key: '${e.value}'};
    if (values != null) {
      AppStore.instance.saveSetup(GameCatalog.pusher.id, values);
    }
    _coins = int.tryParse(v['coins'] ?? '') ?? 30;
    _speed = double.tryParse(v['speed'] ?? '') ?? 1.7;
    _newGame();
  }

  void _newGame() {
    setState(() {
      _game = PusherGame(startCoins: _coins, speed: _speed);
      _aim = PusherGame.width / 2;
      _cooldown = 0;
      _finishing = false;
      _running = true;
    });
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    _focus.requestFocus();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _cooldown = math.max(0, _cooldown - dt);
    final fell = _game.advance(dt);
    for (final f in fell) {
      final big = f.kind != CoinKind.silver;
      Fx.play(big ? Sfx.star : Sfx.pop, buzz: big ? Buzz.medium : Buzz.light);
      _burst(
          f.x,
          big
              ? const [Color(0xFFFFC83D), Colors.white, Color(0xFFFF7BB0)]
              : const [Color(0xFFFFE08A), Colors.white],
          big ? 16 : 6);
    }
    _frame.value++;
    if (_running && _game.over) _finish();
  }

  void _burst(double x, List<Color> colors, int count) {
    final ctx = _boardKey.currentContext;
    if (ctx == null || _cell == 0) return;
    _particles.burstFrom(
        ctx, Offset(x * _cell, (PusherGame.depth + _chute + 0.8) * _cell),
        count: count, colors: colors);
  }

  void _dropAt() {
    if (!_running || _cooldown > 0) return;
    if (_game.drop(_aim)) {
      _cooldown = 0.16;
      Fx.play(Sfx.place, volume: 0.6, buzz: Buzz.tap);
    } else {
      Fx.play(Sfx.error, volume: 0.4);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _running = false;
    _ticker.stop();
    final score = _game.score;
    final stars = PusherGame.starsFor(score);
    final outcome = AppStore.instance.submit(GameCatalog.pusher.id,
        stars: stars, win: stars > 0, score: score);
    final best =
        AppStore.instance.record(GameCatalog.pusher.id).bestScore ?? score;
    final action = await showResultOverlay(
      context,
      kind: stars > 0 ? ResultKind.win : ResultKind.lose,
      title: stars > 0 ? '赢了好多币！' : '时间到啦',
      message: stars > 0 ? '推币机被你推空啦～' : '再来一次，多推一些币下来吧',
      stars: stars,
      newRecord: outcome.newBestScore,
      stats: [('赢得', '$score'), ('宝石', '${_game.gems}'), ('最高', '$best')],
    );
    if (!mounted) return;
    if (action == ResultAction.home) {
      Navigator.of(context).maybePop();
    } else {
      _newGame();
    }
  }

  void _setAim(double dx) {
    if (_cell == 0) return;
    _aim = (dx / _cell).clamp(0.5, PusherGame.width - 0.5);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _aim = math.max(0.5, _aim - 0.5);
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.keyD) {
      _aim = math.min(PusherGame.width - 0.5, _aim + 0.5);
    } else if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.enter) {
      _dropAt();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final best = AppStore.instance.record(GameCatalog.pusher.id).bestScore ?? 0;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GameScaffold(
        title: '推币机',
        scenery: Scenery.candy,
        rules: GameCatalog.pusher.rules,
        onRestart: _openSetup,
        particles: _particles,
        header: ValueListenableBuilder<int>(
          valueListenable: _frame,
          builder: (context, _, __) => Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              CandyChip(
                  label: '手上 ${_game.ammo}', candy: Candy.sun, fontSize: 16),
              CandyChip(
                  label: '赢得 ${_game.score}', candy: Candy.mint, fontSize: 16),
              CandyChip(
                  label: '时间 ${_game.remaining.ceil()}',
                  candy: Candy.ocean,
                  fontSize: 16),
              CandyChip(label: '最高 $best', candy: Candy.cream, fontSize: 16),
            ],
          ),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: PusherGame.width / (PusherGame.depth + _chute + _tray),
            child: LayoutBuilder(
              builder: (context, c) {
                _cell = c.maxWidth / PusherGame.width;
                return GestureDetector(
                  onPanDown: (d) => _setAim(d.localPosition.dx),
                  onPanUpdate: (d) => _setAim(d.localPosition.dx),
                  onPanEnd: (_) => _dropAt(),
                  onTapDown: (d) => _setAim(d.localPosition.dx),
                  onTap: _dropAt,
                  child: CustomPaint(
                    key: _boardKey,
                    painter: _PusherPainter(
                      game: () => _game,
                      aim: () => _aim,
                      frame: _frame,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        footer: ValueListenableBuilder<int>(
          valueListenable: _frame,
          builder: (context, _, __) => Center(
            child: CandyButton(
              label: _game.ammo > 0 ? '投币！' : '没有币啦',
              icon: Icons.paid_rounded,
              candy: Candy.sun,
              width: 200,
              height: 60,
              fontSize: 24,
              onTap: _game.ammo > 0 ? _dropAt : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _PusherPainter extends CustomPainter {
  _PusherPainter({
    required this.game,
    required this.aim,
    required ValueNotifier<int> frame,
  }) : super(repaint: frame);

  final PusherGame Function() game;
  final double Function() aim;

  @override
  void paint(Canvas canvas, Size size) {
    final g = game();
    final c = size.width / PusherGame.width;
    final board =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(c * 0.7));
    canvas.drawRRect(
        board.shift(Offset(0, c * 0.2)), Paint()..color = Palette.ink);
    canvas.save();
    canvas.clipRRect(board);
    canvas.translate(0, _chute * c);

    // Chute (above the back wall).
    canvas.drawRect(Rect.fromLTWH(0, -_chute * c, size.width, _chute * c),
        Paint()..color = Candy.berry.shade);
    final slotX = aim() * c;
    final slot = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(slotX, -_chute * c * 0.45),
            width: c * 1.3,
            height: c * 0.5),
        Radius.circular(c * 0.25));
    canvas.drawRRect(slot, Paint()..color = Palette.ink);
    _coin(canvas, c, Offset(slotX, -_chute * c * 0.45), CoinKind.silver,
        scale: 0.9, shadow: false);
    // Aim guide.
    canvas.drawLine(
        Offset(slotX, -_chute * c * 0.2),
        Offset(slotX, g.front * c),
        inkStroke(c * 0.06, color: Colors.white.withOpacity(0.45)));

    // Shelf.
    final shelfH = PusherGame.depth * c;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, shelfH),
        Paint()..color = const Color(0xFFFFF1C9));
    for (var i = 0; i < PusherGame.depth; i++) {
      if (i.isEven) continue;
      canvas.drawRect(Rect.fromLTWH(0, i * c, size.width, c),
          Paint()..color = const Color(0xFFFFE9B0));
    }

    // Shelf coins sit under the plate coins.
    final items = List.of(g.coins)..sort((a, b) => a.y.compareTo(b.y));
    for (final co in items.where((e) => !e.onPlate)) {
      _drawCoin(canvas, c, co);
    }

    // Pusher plate.
    final plate = Rect.fromLTWH(0, 0, size.width, g.front * c);
    canvas.drawRect(plate.shift(Offset(0, c * 0.18)),
        Paint()..color = Colors.black.withOpacity(0.18));
    canvas.drawRect(plate, Paint()..color = Candy.ocean.face);
    canvas.save();
    canvas.clipRect(plate);
    final stripe = Paint()..color = Candy.ocean.light.withOpacity(0.6);
    for (var x = -plate.height; x < size.width; x += c * 1.4) {
      final p = Path()
        ..moveTo(x, plate.bottom)
        ..lineTo(x + c * 0.7, plate.bottom)
        ..lineTo(x + c * 0.7 + plate.height, 0)
        ..lineTo(x + plate.height, 0)
        ..close();
      canvas.drawPath(p, stripe);
    }
    canvas.restore();
    canvas.drawLine(Offset(0, plate.bottom), Offset(size.width, plate.bottom),
        inkStroke(c * 0.14));
    canvas.drawLine(
        Offset(0, plate.bottom - c * 0.1),
        Offset(size.width, plate.bottom - c * 0.1),
        inkStroke(c * 0.06, color: Candy.ocean.shade));

    for (final co in items.where((e) => e.onPlate)) {
      _drawCoin(canvas, c, co);
    }

    // Side walls.
    for (final x in [0.0, size.width]) {
      canvas.drawLine(Offset(x, 0), Offset(x, shelfH),
          inkStroke(c * 0.36, color: Candy.berry.face));
    }

    // Tray.
    final tray = Rect.fromLTWH(0, shelfH, size.width, _tray * c);
    canvas.drawRect(tray, Paint()..color = Candy.berry.shade);
    canvas.drawRect(
        Rect.fromLTWH(c * 0.4, shelfH + c * 0.5, size.width - c * 0.8, c * 1.2),
        Paint()..color = Palette.ink.withOpacity(0.55));
    for (final f in g.falls) {
      final t = (f.age / 0.7).clamp(0.0, 1.0);
      canvas.save();
      canvas.clipRect(tray);
      _coin(canvas, c, Offset(f.x * c, shelfH + c * (0.2 + t * 1.3)), f.kind,
          scale: 1 - t * 0.4, shadow: false);
      canvas.restore();
    }
    canvas.drawLine(
        Offset(0, shelfH), Offset(size.width, shelfH), inkStroke(c * 0.12));

    canvas.restore();
    canvas.drawRRect(board, inkStroke(3));
  }

  void _drawCoin(Canvas canvas, double c, Coin co) {
    final lift = co.z;
    _coin(canvas, c, Offset(co.x * c, (co.y - lift * 0.35) * c), co.kind,
        scale: 1 + lift * 0.1, shadowGap: lift);
  }

  void _coin(Canvas canvas, double c, Offset p, CoinKind kind,
      {double scale = 1, bool shadow = true, double shadowGap = 0}) {
    final r = kind.radius * c * scale;
    if (shadow) {
      canvas.drawCircle(p + Offset(r * 0.1, r * (0.18 + shadowGap * 0.25)), r,
          Paint()..color = Colors.black.withOpacity(0.2));
    }
    switch (kind) {
      case CoinKind.silver:
        canvas.drawCircle(p, r, Paint()..color = const Color(0xFFD7DEEC));
        canvas.drawCircle(p, r, inkStroke(c * 0.07));
        canvas.drawCircle(
            p, r * 0.62, inkStroke(c * 0.05, color: const Color(0xFF9AA6C2)));
        canvas.drawCircle(p + Offset(-r * 0.35, -r * 0.35), r * 0.16,
            Paint()..color = Colors.white.withOpacity(0.8));
      case CoinKind.gold:
        canvas.drawCircle(p, r, Paint()..color = Candy.sun.face);
        canvas.drawCircle(p, r, inkStroke(c * 0.07));
        canvas.drawCircle(
            p, r * 0.64, inkStroke(c * 0.05, color: Candy.sun.shade));
        paintStar(canvas, p, r * 0.46, outlineWidth: c * 0.04);
      case CoinKind.gem:
        final d = Path()
          ..moveTo(p.dx - r * 0.7, p.dy - r * 0.35)
          ..lineTo(p.dx - r * 0.35, p.dy - r * 0.85)
          ..lineTo(p.dx + r * 0.35, p.dy - r * 0.85)
          ..lineTo(p.dx + r * 0.7, p.dy - r * 0.35)
          ..lineTo(p.dx, p.dy + r * 0.9)
          ..close();
        canvas.drawPath(d, Paint()..color = Candy.berry.face);
        canvas.drawPath(d, inkStroke(c * 0.08));
        canvas.drawLine(Offset(p.dx - r * 0.7, p.dy - r * 0.35),
            Offset(p.dx + r * 0.7, p.dy - r * 0.35), inkStroke(c * 0.05));
        canvas.drawLine(Offset(p.dx - r * 0.2, p.dy - r * 0.35),
            Offset(p.dx, p.dy + r * 0.9), inkStroke(c * 0.04));
        canvas.drawLine(Offset(p.dx + r * 0.2, p.dy - r * 0.35),
            Offset(p.dx, p.dy + r * 0.9), inkStroke(c * 0.04));
        canvas.drawCircle(p + Offset(-r * 0.3, -r * 0.6), r * 0.12,
            Paint()..color = Colors.white.withOpacity(0.85));
    }
  }

  @override
  bool shouldRepaint(_PusherPainter old) => true;
}
