import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/duel.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/duel_frame.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'tictactoe_rules.dart';

class TicTacToeController extends DuelController<TttState, int> {
  @override
  TttState initialState() => TttState.initial();

  @override
  int sideToMove(TttState state) => state.turn;

  @override
  TttState apply(TttState state, int move) => state.play(move);

  @override
  DuelOutcome? judge(TttState state) {
    final winner = state.winner;
    if (winner != null) return DuelOutcome.win(winner, '三个连成一条线');
    if (state.isFull) return const DuelOutcome.draw('棋盘下满啦');
    return null;
  }

  @override
  Future<int?> aiMove(TttState state, AiLevel level) async =>
      TttAi.choose(state, level.index);

  @override
  void onMovePlayed(TttState before, int move, TttState after) {
    Fx.play(Sfx.place, buzz: Buzz.light);
  }
}

class TicTacToePage extends StatefulWidget {
  const TicTacToePage({super.key});

  static Widget create(BuildContext context) => const TicTacToePage();

  @override
  State<TicTacToePage> createState() => _TicTacToePageState();
}

class _TicTacToePageState extends State<TicTacToePage> {
  final _controller = TicTacToeController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tap(int index) {
    if (!_controller.canHumanAct) return;
    if (_controller.state.cells[index] >= 0) {
      Fx.error();
      return;
    }
    _controller.play(index);
  }

  @override
  Widget build(BuildContext context) {
    return DuelGameFrame<TttState, int>(
      info: GameCatalog.tictactoe,
      controller: _controller,
      scenery: Scenery.candy,
      sides: const [
        DuelSide('叉叉队', _MarkToken(0), candy: Candy.berry),
        DuelSide('圈圈队', _MarkToken(1), candy: Candy.ocean),
      ],
      board: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: AspectRatio(
          aspectRatio: 1,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _Board(
              state: _controller.state,
              hint: _controller.hint,
              onTap: _tap,
            ),
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.state, required this.hint, required this.onTap});

  final TttState state;
  final int? hint;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final line = state.winningLine;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Palette.ink, width: 3),
        boxShadow: [
          BoxShadow(color: Candy.berry.shade, offset: const Offset(0, 8)),
          const BoxShadow(color: Palette.ink, offset: Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / 3;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GridPainter())),
              for (var i = 0; i < 9; i++)
                Positioned(
                  left: (i % 3) * cell,
                  top: (i ~/ 3) * cell,
                  width: cell,
                  height: cell,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: _Cell(
                      value: state.cells[i],
                      hinted: hint == i,
                      highlighted: line?.contains(i) ?? false,
                    ),
                  ),
                ),
              if (line != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(line.join()),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => CustomPaint(
                        painter: _WinLinePainter(line, t, state.cells[line[0]]),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = inkStroke(7, color: Candy.berry.light);
    for (final k in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(size.width * k, 10),
          Offset(size.width * k, size.height - 10), paint);
      canvas.drawLine(Offset(10, size.height * k),
          Offset(size.width - 10, size.height * k), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _Cell extends StatelessWidget {
  const _Cell(
      {required this.value, required this.hinted, required this.highlighted});

  final int value;
  final bool hinted;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (value < 0) {
      return hinted ? const _HintPulse() : const SizedBox.expand();
    }
    return AnimatedScale(
      scale: highlighted ? 1.12 : 1,
      duration: const Duration(milliseconds: 380),
      curve: Curves.elasticOut,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(painter: MarkPainter(value, t)),
      ),
    );
  }
}

class _HintPulse extends StatefulWidget {
  const _HintPulse();

  @override
  State<_HintPulse> createState() => _HintPulseState();
}

class _HintPulseState extends State<_HintPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: Tween(begin: 0.6, end: 0.9).animate(_c),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Candy.sun.face.withOpacity(0.7),
            border: Border.all(color: Palette.ink, width: 2.5),
          ),
          child: const Icon(Icons.lightbulb_rounded, color: Palette.ink),
        ),
      ),
    );
  }
}

/// Draws an X (side 0) or O (side 1) with a hand-drawn reveal at [t].
class MarkPainter extends CustomPainter {
  MarkPainter(this.side, this.t);

  final int side;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.3;
    final width = size.shortestSide * 0.14;
    Path path;
    Color color;
    if (side == 0) {
      path = Path()
        ..moveTo(c.dx - r, c.dy - r)
        ..lineTo(c.dx + r, c.dy + r)
        ..moveTo(c.dx + r, c.dy - r)
        ..lineTo(c.dx - r, c.dy + r);
      color = Candy.berry.face;
    } else {
      path = Path()..addArc(Rect.fromCircle(center: c, radius: r), -1.6, 6.28);
      color = Candy.ocean.face;
    }
    final partial = _extract(path, t);
    canvas.drawPath(partial, inkStroke(width + 6));
    canvas.drawPath(partial, inkStroke(width, color: color));
    canvas.drawPath(partial,
        inkStroke(width * 0.25, color: Colors.white.withOpacity(0.45)));
  }

  Path _extract(Path path, double t) {
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * t;
    final out = Path();
    for (final PathMetric m in metrics) {
      if (remaining <= 0) break;
      final len = remaining.clamp(0.0, m.length);
      out.addPath(m.extractPath(0, len), Offset.zero);
      remaining -= m.length;
    }
    return out;
  }

  @override
  bool shouldRepaint(MarkPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.side != side;
}

class _WinLinePainter extends CustomPainter {
  _WinLinePainter(this.line, this.t, this.side);

  final List<int> line;
  final double t;
  final int side;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    Offset center(int i) => Offset((i % 3 + 0.5) * cell, (i ~/ 3 + 0.5) * cell);
    final a = center(line.first);
    final b = center(line.last);
    final dir = (b - a) / (b - a).distance;
    final start = a - dir * cell * 0.35;
    final end = b + dir * cell * 0.35;
    final p = Offset.lerp(start, end, t)!;
    canvas.drawLine(start, p, inkStroke(18));
    canvas.drawLine(start, p, inkStroke(11, color: Candy.sun.face));
  }

  @override
  bool shouldRepaint(_WinLinePainter oldDelegate) => oldDelegate.t != t;
}

class _MarkToken extends StatelessWidget {
  const _MarkToken(this.side);

  final int side;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: MarkPainter(side, 1));
}
