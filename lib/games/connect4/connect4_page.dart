import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/duel.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/duel_frame.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'connect4_rules.dart';

const _discs = [Candy.cherry, Candy.sun];

class Connect4Controller extends DuelController<C4State, int> {
  @override
  C4State initialState() => C4State.initial();

  @override
  int sideToMove(C4State state) => state.turn;

  @override
  C4State apply(C4State state, int move) => state.play(move);

  @override
  DuelOutcome? judge(C4State state) {
    final w = state.winner;
    if (w != null) return DuelOutcome.win(w, '四颗连成一条线');
    if (state.isFull) return const DuelOutcome.draw('格子都放满啦');
    return null;
  }

  @override
  Future<int?> aiMove(C4State s, AiLevel level) async {
    final m = await compute(connect4AiEntry, (s.cells, s.turn, level.index));
    return m < 0 ? null : m;
  }

  @override
  void onMovePlayed(C4State before, int move, C4State after) {
    final row = after.last! ~/ C4State.cols;
    Future<void>.delayed(Duration(milliseconds: 120 + row * 45),
        () => Fx.play(Sfx.place, buzz: Buzz.light));
  }
}

class Connect4Page extends StatefulWidget {
  const Connect4Page({super.key});

  static Widget create(BuildContext context) => const Connect4Page();

  @override
  State<Connect4Page> createState() => _Connect4PageState();
}

class _Connect4PageState extends State<Connect4Page> {
  final _controller = Connect4Controller();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DuelGameFrame<C4State, int>(
      info: GameCatalog.connect4,
      controller: _controller,
      scenery: Scenery.sky,
      sides: const [
        DuelSide('红色', _DiscToken(0), candy: Candy.cherry),
        DuelSide('黄色', _DiscToken(1), candy: Candy.sun),
      ],
      board: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: AspectRatio(
            aspectRatio: 7 / 7.2,
            child: _Connect4Board(controller: _controller)),
      ),
    );
  }
}

class _DiscToken extends StatelessWidget {
  const _DiscToken(this.side);

  final int side;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DiscPainter(side));
}

class _DiscPainter extends CustomPainter {
  _DiscPainter(this.side);

  final int side;

  @override
  void paint(Canvas canvas, Size size) => paintDisc(
      canvas, size.center(Offset.zero), size.shortestSide * 0.42, side);

  @override
  bool shouldRepaint(_DiscPainter old) => old.side != side;
}

void paintDisc(Canvas canvas, Offset c, double r, int side,
    {double opacity = 1}) {
  final candy = _discs[side];
  canvas.drawCircle(c, r, Paint()..color = candy.shade.withOpacity(opacity));
  canvas.drawCircle(c - Offset(0, r * 0.08), r * 0.92,
      Paint()..color = candy.face.withOpacity(opacity));
  canvas.drawCircle(c - Offset(0, r * 0.08), r * 0.6,
      inkStroke(r * 0.1, color: candy.shade.withOpacity(0.6 * opacity)));
  canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.42), r * 0.16,
      Paint()..color = Colors.white.withOpacity(0.7 * opacity));
  canvas.drawCircle(
      c, r, inkStroke(r * 0.12, color: Palette.ink.withOpacity(opacity)));
}

class _Connect4Board extends StatefulWidget {
  const _Connect4Board({required this.controller});

  final Connect4Controller controller;

  @override
  State<_Connect4Board> createState() => _Connect4BoardState();
}

class _Connect4BoardState extends State<_Connect4Board>
    with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);
  int? _hover;
  int? _animatedFor;

  Connect4Controller get _c => widget.controller;

  @override
  void dispose() {
    _drop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int _col(Offset p, double width) => (p.dx / width * 7).floor().clamp(0, 6);

  void _release() {
    final col = _hover;
    setState(() => _hover = null);
    if (col == null || !_c.canHumanAct) return;
    if (!_c.state.legalMoves().contains(col)) {
      Fx.error();
      return;
    }
    _c.play(col);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final last = _c.state.last;
        if (last != _animatedFor) {
          _animatedFor = last;
          if (last != null) _drop.forward(from: 0);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return Listener(
              onPointerDown: (e) {
                if (_c.canHumanAct) {
                  setState(() => _hover = _col(e.localPosition, w));
                }
              },
              onPointerMove: (e) {
                if (_c.canHumanAct) {
                  setState(() => _hover = _col(e.localPosition, w));
                }
              },
              onPointerUp: (_) => _release(),
              onPointerCancel: (_) => setState(() => _hover = null),
              child: CustomPaint(
                size: Size(w, constraints.maxHeight),
                painter: _Connect4Painter(
                  state: _c.state,
                  hover: _hover,
                  hint: _c.hint,
                  drop: _drop,
                  pulse: _pulse,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Connect4Painter extends CustomPainter {
  _Connect4Painter({
    required this.state,
    required this.hover,
    required this.hint,
    required this.drop,
    required this.pulse,
  }) : super(repaint: Listenable.merge([drop, pulse]));

  final C4State state;
  final int? hover;
  final int? hint;
  final Animation<double> drop;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 7;
    final top = size.height - c * 6;
    final frame = Rect.fromLTWH(0, top, size.width, c * 6);
    Offset center(int i) => Offset((i % 7 + 0.5) * c, top + (i ~/ 7 + 0.5) * c);
    final r = c * 0.4;

    // Preview disc over the hovered column.
    final h = hover ?? hint;
    if (h != null) {
      final row = C4State.dropRow(state.cells, h);
      if (row >= 0) {
        paintDisc(
            canvas,
            Offset((h + 0.5) * c, top - c * 0.1 - pulse.value * 4),
            r * 0.9,
            state.turn,
            opacity: 0.85);
        paintDisc(canvas, center(row * 7 + h), r, state.turn, opacity: 0.3);
      }
    }

    final last = state.last;
    final win = state.winLine?.toSet() ?? const <int>{};
    for (var i = 0; i < 42; i++) {
      final v = state.cells[i];
      if (v < 0) continue;
      var p = center(i);
      if (i == last && drop.isAnimating) {
        final t = Curves.bounceOut.transform(drop.value);
        p = Offset(p.dx, (top - c * 0.6) + (p.dy - (top - c * 0.6)) * t);
      }
      final scale = win.contains(i) ? 1 + 0.08 * pulse.value : 1.0;
      paintDisc(canvas, p, r * scale, v);
    }

    // Blue frame with holes, drawn over the discs.
    final holes = Path()
      ..addRRect(RRect.fromRectAndRadius(frame, Radius.circular(c * 0.35)));
    for (var i = 0; i < 42; i++) {
      holes.addOval(Rect.fromCircle(center: center(i), radius: r * 1.04));
    }
    holes.fillType = PathFillType.evenOdd;
    canvas.drawPath(
        holes.shift(Offset(0, c * 0.12)), Paint()..color = Palette.ink);
    canvas.drawPath(holes, Paint()..color = Candy.ocean.face);
    for (var i = 0; i < 42; i++) {
      canvas.drawCircle(
          center(i), r * 1.04, inkStroke(2.5, color: Candy.ocean.shade));
    }
    canvas.drawRRect(RRect.fromRectAndRadius(frame, Radius.circular(c * 0.35)),
        inkStroke(3));
    if (win.isNotEmpty) {
      final pts = win.toList()..sort();
      canvas.drawLine(center(pts.first), center(pts.last),
          inkStroke(c * 0.16, color: Colors.white.withOpacity(0.85)));
    }
  }

  @override
  bool shouldRepaint(_Connect4Painter old) =>
      old.state != state || old.hover != hover || old.hint != hint;
}
