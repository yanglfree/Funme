import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/shapes.dart';
import '../../core/art/stones.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/duel.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/duel_frame.dart';
import '../../core/widgets/setup_sheet.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'gomoku_rules.dart';

class GomokuController extends DuelController<GomokuState, int> {
  int boardSize = 13;

  @override
  GomokuState initialState() => GomokuState.initial(boardSize);

  @override
  int sideToMove(GomokuState state) => state.turn;

  @override
  GomokuState apply(GomokuState state, int move) => state.play(move);

  @override
  DuelOutcome? judge(GomokuState state) {
    final winner = state.winner;
    if (winner != null) return DuelOutcome.win(winner, '五子连珠');
    if (state.isFull) return const DuelOutcome.draw('棋盘下满啦');
    return null;
  }

  @override
  Future<int?> aiMove(GomokuState s, AiLevel level) => compute(
        gomokuAiEntry,
        (s.cells, s.size, s.turn, level.index, s.last, s.count),
      );

  @override
  void onMovePlayed(GomokuState before, int move, GomokuState after) {
    Fx.play(Sfx.place, buzz: Buzz.light);
  }
}

class GomokuPage extends StatefulWidget {
  const GomokuPage({super.key});

  static Widget create(BuildContext context) => const GomokuPage();

  @override
  State<GomokuPage> createState() => _GomokuPageState();
}

class _GomokuPageState extends State<GomokuPage> {
  final _controller = GomokuController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DuelGameFrame<GomokuState, int>(
      info: GameCatalog.gomoku,
      controller: _controller,
      scenery: Scenery.meadow,
      sides: const [
        DuelSide('黑棋', StoneToken(0), candy: Candy.slate),
        DuelSide('白棋', StoneToken(1), candy: Candy.cream),
      ],
      setupGroups: [
        ...duelSetupGroups(),
        const SetupGroup(
          key: 'size',
          title: '棋盘大小',
          choices: [
            SetupChoice('9', '小 9×9', candy: Candy.mint),
            SetupChoice('13', '中 13×13', candy: Candy.sun),
            SetupChoice('15', '大 15×15', candy: Candy.orange),
          ],
        ),
      ],
      onSetup: (values) =>
          _controller.boardSize = int.tryParse(values['size'] ?? '') ?? 13,
      board: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: AspectRatio(
          aspectRatio: 1,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _GomokuBoard(controller: _controller),
          ),
        ),
      ),
    );
  }
}

class _GomokuBoard extends StatefulWidget {
  const _GomokuBoard({required this.controller});

  final GomokuController controller;

  @override
  State<_GomokuBoard> createState() => _GomokuBoardState();
}

class _GomokuBoardState extends State<_GomokuBoard>
    with TickerProviderStateMixin {
  int? _ghost;
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  int? _animatedFor;

  @override
  void dispose() {
    _drop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  GomokuState get _state => widget.controller.state;

  ({double margin, double cell}) _metrics(double side) {
    final n = _state.size;
    final cell = side / (n - 1 + 1.3);
    return (margin: (side - cell * (n - 1)) / 2, cell: cell);
  }

  int? _hit(Offset local, double side) {
    final m = _metrics(side);
    final x = ((local.dx - m.margin) / m.cell).round();
    final y = ((local.dy - m.margin) / m.cell).round();
    if (!_state.inside(x, y)) return null;
    return y * _state.size + x;
  }

  void _down(Offset local, double side) {
    if (!widget.controller.canHumanAct) return;
    final i = _hit(local, side);
    if (i != _ghost) setState(() => _ghost = i);
  }

  void _up() {
    final i = _ghost;
    setState(() => _ghost = null);
    if (i == null || !widget.controller.canHumanAct) return;
    if (_state.cells[i] >= 0) {
      Fx.error();
      return;
    }
    widget.controller.play(i);
  }

  @override
  Widget build(BuildContext context) {
    final last = _state.last;
    if (last != _animatedFor) {
      _animatedFor = last;
      if (last != null) _drop.forward(from: 0);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Palette.ink, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBDDA6), Color(0xFFEFC27E)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFFC9955A), offset: Offset(0, 7)),
          BoxShadow(color: Palette.ink, offset: Offset(0, 9)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          return Listener(
            onPointerDown: (e) => _down(e.localPosition, side),
            onPointerMove: (e) => _down(e.localPosition, side),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => setState(() => _ghost = null),
            child: CustomPaint(
              size: Size.square(side),
              painter: _GomokuPainter(
                state: _state,
                ghost: _ghost,
                ghostSide: _state.turn,
                hint: widget.controller.hint,
                winLine: _state.winLine,
                drop: _drop,
                pulse: _pulse,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GomokuPainter extends CustomPainter {
  _GomokuPainter({
    required this.state,
    required this.ghost,
    required this.ghostSide,
    required this.hint,
    required this.winLine,
    required this.drop,
    required this.pulse,
  }) : super(repaint: Listenable.merge([drop, pulse]));

  final GomokuState state;
  final int? ghost;
  final int ghostSide;
  final int? hint;
  final List<int>? winLine;
  final Animation<double> drop;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final n = state.size;
    final cell = size.width / (n - 1 + 1.3);
    final margin = (size.width - cell * (n - 1)) / 2;
    Offset at(int i) =>
        Offset(margin + (i % n) * cell, margin + (i ~/ n) * cell);

    final grid = Paint()
      ..color = const Color(0xFFA8743F)
      ..strokeWidth = n > 13 ? 1.4 : 2;
    for (var k = 0; k < n; k++) {
      final d = margin + k * cell;
      canvas.drawLine(Offset(margin, d), Offset(size.width - margin, d), grid);
      canvas.drawLine(Offset(d, margin), Offset(d, size.height - margin), grid);
    }
    canvas.drawRect(
      Rect.fromLTRB(margin, margin, size.width - margin, size.height - margin),
      inkStroke(2.5, color: const Color(0xFF8A5A2B)),
    );
    final mid = n ~/ 2;
    final edge = n >= 13 ? 3 : 2;
    for (final (x, y) in [
      (mid, mid),
      (edge, edge),
      (n - 1 - edge, edge),
      (edge, n - 1 - edge),
      (n - 1 - edge, n - 1 - edge)
    ]) {
      canvas.drawCircle(
          at(y * n + x), cell * 0.12, Paint()..color = const Color(0xFF8A5A2B));
    }

    final r = cell * 0.44;
    final win = winLine?.toSet() ?? const <int>{};
    for (var i = 0; i < state.cells.length; i++) {
      final v = state.cells[i];
      if (v < 0) continue;
      var c = at(i);
      var radius = r;
      if (i == state.last) {
        final t = Curves.easeOutBack.transform(drop.value.clamp(0.0, 1.0));
        radius = r * (1.5 - 0.5 * t);
        c = c.translate(0, -cell * 0.4 * (1 - t));
      }
      if (win.contains(i)) radius *= 1 + 0.08 * pulse.value;
      paintStone(canvas, c, radius, v);
      if (i == state.last && winLine == null) {
        canvas.drawCircle(c, r * 0.22, Paint()..color = Candy.cherry.face);
      }
    }

    if (winLine != null && winLine!.length >= 2) {
      final a = at(winLine!.first);
      final b = at(winLine!.last);
      canvas.drawLine(
          a, b, inkStroke(cell * 0.32, color: Palette.ink.withOpacity(0.5)));
      canvas.drawLine(
          a,
          b,
          inkStroke(cell * 0.2,
              color: Candy.sun.face.withOpacity(0.85 + 0.15 * pulse.value)));
    }

    final h = hint;
    if (h != null && state.cells[h] < 0) {
      final c = at(h);
      canvas.drawCircle(c, r * (0.8 + 0.25 * pulse.value),
          Paint()..color = Candy.sun.face.withOpacity(0.55));
      canvas.drawCircle(c, r * (0.8 + 0.25 * pulse.value), inkStroke(2.5));
    }

    final g = ghost;
    if (g != null) {
      final c = at(g);
      final guide = Paint()
        ..color = Candy.ocean.face.withOpacity(0.5)
        ..strokeWidth = 3;
      canvas.drawLine(
          Offset(margin, c.dy), Offset(size.width - margin, c.dy), guide);
      canvas.drawLine(
          Offset(c.dx, margin), Offset(c.dx, size.height - margin), guide);
      if (state.cells[g] < 0) {
        paintStone(canvas, c, r, ghostSide, opacity: 0.55);
      }
    }
  }

  @override
  bool shouldRepaint(_GomokuPainter old) =>
      old.state != state || old.ghost != ghost || old.hint != hint;
}
