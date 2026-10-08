import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
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
import 'merge2048_rules.dart';

class Merge2048Page extends StatefulWidget {
  const Merge2048Page({super.key});

  static Widget create(BuildContext context) => const Merge2048Page();

  @override
  State<Merge2048Page> createState() => _Merge2048PageState();
}

class _Merge2048PageState extends State<Merge2048Page> {
  final _particles = ParticleController();
  final _focus = FocusNode();
  final _boardKey = GlobalKey();

  Merge2048 _game = Merge2048();
  Merge2048? _undo;
  int _size = 4;
  bool _celebrated = false;
  bool _finishing = false;
  Offset _drag = Offset.zero;
  bool _swiped = false;
  double _side = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSetup());
  }

  @override
  void dispose() {
    _particles.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _openSetup() async {
    final raw = AppStore.instance.setup(GameCatalog.merge2048.id) ?? const {};
    final values = await showSetupSheet(
      context,
      title: '2048',
      initial: {for (final e in raw.entries) e.key: '${e.value}'},
      groups: const [
        SetupGroup(key: 'size', title: '棋盘', choices: [
          SetupChoice('4', '经典 4×4', candy: Candy.orange),
          SetupChoice('5', '轻松 5×5', candy: Candy.mint),
        ]),
      ],
    );
    if (!mounted) return;
    final v = values ?? {for (final e in raw.entries) e.key: '${e.value}'};
    if (values != null) {
      AppStore.instance.saveSetup(GameCatalog.merge2048.id, values);
    }
    _size = int.tryParse(v['size'] ?? '') == 5 ? 5 : 4;
    _newGame();
  }

  void _newGame() {
    setState(() {
      _game = Merge2048(size: _size);
      _undo = null;
      _celebrated = false;
      _finishing = false;
    });
    _focus.requestFocus();
  }

  void _slide(MergeDir d) {
    if (_finishing) return;
    final before = _game.clone();
    if (!_game.move(d)) {
      Fx.play(Sfx.error, volume: 0.4);
      return;
    }
    _undo = before;
    final merged = _game.tiles.where((t) => t.merged).toList();
    if (merged.isEmpty) {
      Fx.play(Sfx.slide, volume: 0.6, buzz: Buzz.tap);
    } else {
      Fx.play(Sfx.merge, buzz: Buzz.light);
      final big = merged.reduce((a, b) => a.value >= b.value ? a : b);
      if (big.value >= 64) _burst(big);
    }
    setState(() {});
    if (_game.maxTile >= Merge2048.target && !_celebrated) {
      _celebrated = true;
      _finish(win: true);
    } else if (!_game.canMove) {
      _finish(win: false);
    }
  }

  void _burst(MergeTile t) {
    final ctx = _boardKey.currentContext;
    if (ctx == null || _side == 0) return;
    final cell = _side / _game.size;
    _particles.burstFrom(
        ctx, Offset((t.col + 0.5) * cell, (t.row + 0.5) * cell),
        count: 16,
        colors: const [Color(0xFFFFC83D), Colors.white, Color(0xFFFF8C42)]);
  }

  void _undoMove() {
    final u = _undo;
    if (u == null || _finishing) return;
    Fx.tap();
    setState(() {
      _game = u;
      _undo = null;
    });
  }

  Future<void> _finish({required bool win}) async {
    _finishing = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final top = _game.maxTile;
    final stars = Merge2048.starsFor(top);
    final id = GameCatalog.merge2048.id;
    final outcome = AppStore.instance
        .submit(id, stars: win ? 3 : stars, win: win, score: _game.score);
    final best = AppStore.instance.record(id).bestScore ?? _game.score;
    final action = await showResultOverlay(
      context,
      kind: win || stars > 0 ? ResultKind.win : ResultKind.lose,
      title: win ? '2048 达成！' : (stars > 0 ? '好厉害！' : '没有空位啦'),
      message: win ? '你合成了 2048，太棒了！' : '再来一局，合成更大的数字吧',
      stars: win ? 3 : stars,
      newRecord: outcome.newBestScore,
      nextLabel: win ? '继续冲刺' : null,
      stats: [('分数', '${_game.score}'), ('最大', '$top'), ('最高', '$best')],
    );
    if (!mounted) return;
    switch (action) {
      case ResultAction.home:
        Navigator.of(context).maybePop();
      case ResultAction.again:
        _newGame();
      case ResultAction.next:
        setState(() => _finishing = false);
        _focus.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final dir = {
      LogicalKeyboardKey.arrowUp: MergeDir.up,
      LogicalKeyboardKey.keyW: MergeDir.up,
      LogicalKeyboardKey.arrowDown: MergeDir.down,
      LogicalKeyboardKey.keyS: MergeDir.down,
      LogicalKeyboardKey.arrowLeft: MergeDir.left,
      LogicalKeyboardKey.keyA: MergeDir.left,
      LogicalKeyboardKey.arrowRight: MergeDir.right,
      LogicalKeyboardKey.keyD: MergeDir.right,
    }[e.logicalKey];
    if (dir == null) return KeyEventResult.ignored;
    _slide(dir);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final best =
        AppStore.instance.record(GameCatalog.merge2048.id).bestScore ?? 0;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GameScaffold(
        title: '2048',
        scenery: Scenery.sunset,
        rules: GameCatalog.merge2048.rules,
        onRestart: _openSetup,
        particles: _particles,
        actions: [
          CandyIconButton(
            icon: Icons.undo_rounded,
            candy: Candy.ocean,
            onTap: _undo == null ? null : _undoMove,
          ),
        ],
        header: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            CandyChip(
                label: '分数 ${_game.score}', candy: Candy.sun, fontSize: 16),
            CandyChip(label: '最高 $best', candy: Candy.cream, fontSize: 16),
            CandyChip(
                label: '最大 ${_game.maxTile}',
                candy: Candy.orange,
                fontSize: 16),
          ],
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, c) {
              _side = c.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _drag = Offset.zero;
                  _swiped = false;
                },
                onPanUpdate: (d) {
                  if (_swiped) return;
                  _drag += d.delta;
                  if (_drag.distance < 24) return;
                  _swiped = true;
                  if (_drag.dx.abs() > _drag.dy.abs()) {
                    _slide(_drag.dx > 0 ? MergeDir.right : MergeDir.left);
                  } else {
                    _slide(_drag.dy > 0 ? MergeDir.down : MergeDir.up);
                  }
                },
                child: _Board(key: _boardKey, game: _game),
              );
            }),
          ),
        ),
        footer: const Text('滑动屏幕，相同的数字会合在一起',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Palette.ink, fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    );
  }
}

Candy _candyFor(int v) => switch (v) {
      2 => Candy.cream,
      4 => Candy.wood,
      8 => Candy.orange,
      16 => Candy.cherry,
      32 => Candy.berry,
      64 => Candy.grape,
      128 => Candy.sun,
      256 => Candy.lime,
      512 => Candy.mint,
      1024 => Candy.ocean,
      2048 => Candy.sun,
      _ => Candy.slate,
    };

class _Board extends StatelessWidget {
  const _Board({super.key, required this.game});

  final Merge2048 game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = game.size;
      final side = c.maxWidth;
      final inner = side - 6; // inside the 3px border
      final gap = inner * 0.025;
      final cell = (inner - gap * (n + 1)) / n;
      Offset pos(int r, int col) =>
          Offset(gap + col * (cell + gap), gap + r * (cell + gap));
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Candy.wood.shade,
          borderRadius: BorderRadius.circular(side * 0.04),
          border: Border.all(color: Palette.ink, width: 3),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var r = 0; r < n; r++)
              for (var col = 0; col < n; col++)
                Positioned(
                  left: pos(r, col).dx,
                  top: pos(r, col).dy,
                  width: cell,
                  height: cell,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.ink.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(cell * 0.16),
                    ),
                  ),
                ),
            // Absorbed tiles first so survivors draw on top of them.
            for (final t in game.ghosts)
              _tile(t, pos(t.row, t.col), cell, ghost: true),
            for (final t in game.tiles) _tile(t, pos(t.row, t.col), cell),
          ],
        ),
      );
    });
  }

  Widget _tile(MergeTile t, Offset p, double cell, {bool ghost = false}) {
    return AnimatedPositioned(
      key: ValueKey('t${t.id}${ghost ? 'g' : ''}'),
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      left: p.dx,
      top: p.dy,
      width: cell,
      height: cell,
      child: _TileFace(
        key: ValueKey('${t.id}:${t.value}'),
        value: t.value,
        cell: cell,
        begin: t.fresh ? 0.0 : (t.merged ? 1.22 : 1.0),
      ),
    );
  }
}

class _TileFace extends StatelessWidget {
  const _TileFace(
      {super.key,
      required this.value,
      required this.cell,
      required this.begin});

  final int value;
  final double cell;
  final double begin;

  @override
  Widget build(BuildContext context) {
    final candy = _candyFor(value);
    final digits = '$value'.length;
    final size = cell * (digits <= 2 ? 0.46 : (digits == 3 ? 0.38 : 0.3));
    final light = value <= 4;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: candy.face,
          borderRadius: BorderRadius.circular(cell * 0.16),
          border: Border.all(color: Palette.ink, width: 2.5),
          boxShadow: [
            BoxShadow(color: candy.shade, offset: Offset(0, cell * 0.05))
          ],
        ),
        child: Center(
          child: light
              ? Text('$value',
                  style: FunText.display(color: Palette.ink, size: size))
              : OutlinedText('$value', size: size, strokeWidth: size * 0.2),
        ),
      ),
    );
  }
}
