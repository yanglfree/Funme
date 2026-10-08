import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/shapes.dart';
import '../../core/art/stones.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/duel.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/duel_frame.dart';
import '../../core/widgets/flash_banner.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'reversi_rules.dart';

class ReversiController extends DuelController<RvState, int> {
  final flash = FlashController();

  @override
  RvState initialState() => RvState.initial();

  @override
  int sideToMove(RvState state) => state.turn;

  @override
  RvState apply(RvState state, int move) => state.play(move);

  @override
  DuelOutcome? judge(RvState state) {
    if (!state.over) return null;
    final b = state.count(0);
    final w = state.count(1);
    if (b == w) return DuelOutcome.draw('$b 比 $w');
    return DuelOutcome.win(
        b > w ? 0 : 1, '${math.max(b, w)} 比 ${math.min(b, w)}');
  }

  @override
  Future<int?> aiMove(RvState s, AiLevel level) async {
    final m = await compute(reversiAiEntry, (s.cells, s.turn, level.index));
    return m < 0 ? null : m;
  }

  @override
  void onMovePlayed(RvState before, int move, RvState after) {
    Fx.play(Sfx.place, buzz: Buzz.light);
    for (var k = 0; k < math.min(after.flipped.length, 6); k++) {
      Future<void>.delayed(Duration(milliseconds: 160 + k * 70),
          () => Fx.play(Sfx.flip, volume: 0.7));
    }
    if (after.passed && !after.over) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        flash.show(after.turn == 0 ? '白棋没地方下，跳过！' : '黑棋没地方下，跳过！',
            candy: Candy.grape);
      });
    }
  }

  @override
  void dispose() {
    flash.dispose();
    super.dispose();
  }
}

class ReversiPage extends StatefulWidget {
  const ReversiPage({super.key});

  static Widget create(BuildContext context) => const ReversiPage();

  @override
  State<ReversiPage> createState() => _ReversiPageState();
}

class _ReversiPageState extends State<ReversiPage> {
  final _controller = ReversiController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final s = _controller.state;
        return DuelGameFrame<RvState, int>(
          info: GameCatalog.reversi,
          controller: _controller,
          scenery: Scenery.mint,
          sides: [
            DuelSide('黑棋 ${s.count(0)}', const StoneToken(0),
                candy: Candy.slate),
            DuelSide('白棋 ${s.count(1)}', const StoneToken(1),
                candy: Candy.cream),
          ],
          board: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
            child: AspectRatio(
                aspectRatio: 1, child: _ReversiBoard(controller: _controller)),
          ),
        );
      },
    );
  }
}

class _ReversiBoard extends StatefulWidget {
  const _ReversiBoard({required this.controller});

  final ReversiController controller;

  @override
  State<_ReversiBoard> createState() => _ReversiBoardState();
}

class _ReversiBoardState extends State<_ReversiBoard>
    with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  RvState? _shown;

  ReversiController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onState);
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _flip.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onState() {
    final s = _c.state;
    if (!identical(s, _shown)) {
      if (s.last != null && s.flipped.isNotEmpty) _flip.forward(from: 0);
      _shown = s;
    }
  }

  void _tap(Offset p, double size) {
    if (!_c.canHumanAct) return;
    final x = (p.dx / size * 8).floor();
    final y = (p.dy / size * 8).floor();
    if (x < 0 || x > 7 || y < 0 || y > 7) return;
    final i = y * 8 + x;
    if (_c.state.legalMoves().contains(i)) {
      _c.play(i);
    } else {
      Fx.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return GestureDetector(
          onTapUp: (d) => _tap(d.localPosition, size),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ReversiPainter(
                    state: _c.state,
                    showMoves: _c.canHumanAct,
                    hint: _c.hint,
                    flip: _flip,
                    pulse: _pulse,
                  ),
                ),
              ),
              Positioned.fill(child: FlashBanner(controller: _c.flash)),
            ],
          ),
        );
      },
    );
  }
}

class _ReversiPainter extends CustomPainter {
  _ReversiPainter({
    required this.state,
    required this.showMoves,
    required this.hint,
    required this.flip,
    required this.pulse,
  }) : super(repaint: Listenable.merge([flip, pulse]));

  final RvState state;
  final bool showMoves;
  final int? hint;
  final Animation<double> flip;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 8;
    final board =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(c * 0.5));
    canvas.drawRRect(
        board.shift(Offset(0, c * 0.18)), Paint()..color = Palette.ink);
    canvas.drawRRect(board, Paint()..color = const Color(0xFF2FB98A));
    canvas.save();
    canvas.clipRRect(board);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if ((x + y).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x * c, y * c, c, c),
              Paint()..color = const Color(0xFF29AD80));
        }
      }
    }
    final grid = Paint()
      ..color = const Color(0xFF1B8A63)
      ..strokeWidth = 1.5;
    for (var k = 1; k < 8; k++) {
      canvas.drawLine(Offset(k * c, 0), Offset(k * c, size.height), grid);
      canvas.drawLine(Offset(0, k * c), Offset(size.width, k * c), grid);
    }
    for (final (x, y) in const [(2, 2), (6, 2), (2, 6), (6, 6)]) {
      canvas.drawCircle(Offset(x * c, y * c), c * 0.08,
          Paint()..color = const Color(0xFF1B8A63));
    }
    canvas.restore();
    canvas.drawRRect(board, inkStroke(3));

    final last = state.last;
    final flipped = state.flipped.toSet();
    for (var i = 0; i < 64; i++) {
      final v = state.cells[i];
      if (v < 0) continue;
      final center = Offset((i % 8 + 0.5) * c, (i ~/ 8 + 0.5) * c);
      final r = c * 0.4;
      if (i == last && flip.isAnimating) {
        final t =
            Curves.easeOutBack.transform((flip.value * 4).clamp(0.0, 1.0));
        paintStone(canvas, center, r * (0.4 + 0.6 * t), v);
        continue;
      }
      if (flipped.contains(i) && flip.isAnimating && last != null) {
        final d = math.sqrt(
            math.pow(i % 8 - last % 8, 2) + math.pow(i ~/ 8 - last ~/ 8, 2));
        final start = 0.15 + (d - 1) * 0.12;
        final f = ((flip.value - start) / 0.35).clamp(0.0, 1.0);
        final showNew = f >= 0.5;
        final side = showNew ? v : 1 - v;
        final sx = (math.cos(f * math.pi)).abs().clamp(0.08, 1.0);
        canvas.save();
        canvas.translate(
            center.dx, center.dy - math.sin(f * math.pi) * c * 0.25);
        canvas.scale(sx, 1);
        paintStone(canvas, Offset.zero, r, side);
        canvas.restore();
        continue;
      }
      paintStone(canvas, center, r, v);
    }
    if (last != null && !flip.isAnimating) {
      canvas.drawCircle(Offset((last % 8 + 0.5) * c, (last ~/ 8 + 0.5) * c),
          c * 0.08, Paint()..color = Candy.cherry.face);
    }
    if (showMoves) {
      for (final m in state.legalMoves()) {
        final center = Offset((m % 8 + 0.5) * c, (m ~/ 8 + 0.5) * c);
        final isHint = m == hint;
        final r = c * (isHint ? 0.3 + 0.06 * pulse.value : 0.13);
        canvas.drawCircle(
            center,
            r,
            Paint()
              ..color = (isHint ? Candy.sun.face : Colors.white)
                  .withOpacity(isHint ? 0.95 : 0.55));
        if (isHint) canvas.drawCircle(center, r, inkStroke(2.5));
      }
    }
  }

  @override
  bool shouldRepaint(_ReversiPainter old) =>
      old.state != state || old.showMoves != showMoves || old.hint != hint;
}
