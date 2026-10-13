import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/rules_sheet.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/candy_panel.dart';
import '../../core/widgets/game_scaffold.dart';
import '../../core/widgets/particles.dart';
import '../../core/widgets/result_overlay.dart';
import '../../core/widgets/setup_sheet.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'pusher_rules.dart';
import 'pusher_painter.dart';

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
  double _soundCooldown = 0;
  PusherMode _mode = PusherMode.arcade;
  bool _dialog = false;
  bool _paused = false;
  int _coins = 30;
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
    _dialog = true;
    final raw = AppStore.instance.setup(GameCatalog.pusher.id) ?? const {};
    final values = await showSetupSheet(
      context,
      title: '推币机',
      initial: {
        'coins': '30',
        'speed': '1.7',
        'mode': 'arcade',
        for (final e in raw.entries) e.key: '${e.value}'
      },
      groups: const [
        SetupGroup(key: 'mode', title: '游玩模式', choices: [
          SetupChoice('arcade', '街机 · 不限时', candy: Candy.sun),
          SetupChoice('timed', '90 秒挑战', candy: Candy.ocean),
        ]),
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
    _dialog = false;
    if (values == null && _running) {
      _resume();
      return;
    }
    final v = values ?? {for (final e in raw.entries) e.key: '${e.value}'};
    if (values != null) {
      AppStore.instance.saveSetup(GameCatalog.pusher.id, values);
    }
    _mode = v['mode'] == 'timed' ? PusherMode.timed : PusherMode.arcade;
    _coins = int.tryParse(v['coins'] ?? '') ?? 30;
    _speed = double.tryParse(v['speed'] ?? '') ?? 1.7;
    _newGame();
  }

  void _newGame() {
    setState(() {
      _game = PusherGame(startCoins: _coins, speed: _speed, mode: _mode);
      _aim = PusherGame.width / 2;
      _soundCooldown = 0;
      _paused = false;
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
    if (!_running ||
        _dialog ||
        _paused ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _soundCooldown = math.max(0, _soundCooldown - dt);
    final fell = _game.advance(dt);
    if (_game.contacts > 0 && _soundCooldown <= 0) {
      Fx.play(Sfx.coinContact, volume: 0.25);
      _soundCooldown = 0.12;
    }
    if (_game.stroke) Fx.play(Sfx.pusherMotor, volume: 0.2);
    final paid = fell.where((f) => !f.side).toList();
    if (paid.isNotEmpty) {
      Fx.play(Sfx.coinTray,
          volume: 0.65, buzz: paid.length > 2 ? Buzz.medium : Buzz.light);
    }
    for (final f in paid) {
      final big = f.kind != CoinKind.silver;
      if (big) Fx.play(Sfx.star, volume: 0.4);
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
        ctx, Offset((5 + (x - 5) * 0.95) * _cell, 10.4 * _cell),
        count: count, colors: colors);
  }

  void _dropAt() {
    if (!_running || _paused || _dialog || !_game.canDrop) return;
    if (_game.drop(_aim)) {
      Fx.play(Sfx.coinSlot, volume: 0.6, buzz: Buzz.tap);
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
    final compactResult = MediaQuery.sizeOf(context).height < 500;
    final action = await showResultOverlay(
      context,
      kind: stars > 0 ? ResultKind.win : ResultKind.lose,
      title: switch (_game.end) {
        PusherEnd.time => '挑战完成',
        PusherEnd.empty => '硬币用完啦',
        _ => '本次收获',
      },
      message: compactResult ? null : '收获了 $score 个币，找准落点再来一局吧！',
      showStars: !compactResult,
      stars: stars,
      newRecord: outcome.newBestScore,
      stats: [
        if (compactResult) ('星星', '$stars/3'),
        ('赢得', '$score'),
        ('宝石', '${_game.gems}'),
        ('回收', '${_game.lost}'),
        ('最高', '$best')
      ],
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
    _aim = PusherProjection.aimFromX(dx / _cell);
    _frame.value++;
  }

  void _resume() {
    _last = Duration.zero;
    if (_running && !_paused && !_dialog && !_ticker.isActive) _ticker.start();
    _focus.requestFocus();
  }

  Future<void> _showRules() async {
    _dialog = true;
    _ticker.stop();
    await showRulesSheet(context,
        title: '推币机', rules: GameCatalog.pusher.rules);
    if (!mounted) return;
    _dialog = false;
    _resume();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _ticker.stop();
    } else {
      _resume();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (_dialog || _paused || !_running) return KeyEventResult.ignored;
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
    _frame.value++;
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
        actions: [
          CandyIconButton(
              icon: Icons.question_mark_rounded,
              candy: Candy.sun,
              onTap: _showRules),
          CandyIconButton(
              icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              candy: Candy.ocean,
              onTap: _togglePause),
        ],
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
                  label: _paused
                      ? '已暂停'
                      : _game.settling
                          ? '等待落币…'
                          : _mode == PusherMode.timed
                              ? '时间 ${_game.remaining.ceil()}'
                              : '街机 · 不限时',
                  candy: Candy.ocean,
                  fontSize: 16),
              CandyChip(label: '最高 $best', candy: Candy.cream, fontSize: 16),
            ],
          ),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: PusherProjection.width / PusherProjection.height,
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
                    painter: PusherPainter(
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
          builder: (context, _, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  _paused
                      ? '点击播放按钮继续'
                      : _game.settling
                          ? '推板归位后结算，请稍候'
                          : '拖动选落点 · 松手投币 · 侧槽不返币',
                  textAlign: TextAlign.center,
                  style: FunText.caption(size: 12)),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  CandyButton(
                    label: _game.ammo > 0 ? '投币！' : '等待落币',
                    icon: Icons.paid_rounded,
                    candy: Candy.sun,
                    width: 140,
                    sound: false,
                    height: 56,
                    fontSize: 22,
                    onTap: !_paused && _game.canDrop ? _dropAt : null,
                  ),
                  CandyButton(
                    label: '收币结算',
                    candy: Candy.mint,
                    width: 104,
                    height: 56,
                    fontSize: 16,
                    onTap: !_paused && !_game.settling && _running
                        ? () {
                            _game.collect();
                            _frame.value++;
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
