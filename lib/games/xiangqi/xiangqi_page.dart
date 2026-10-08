import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/game_icons.dart';
import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/duel.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/duel_frame.dart';
import '../../core/widgets/flash_banner.dart';
import '../../core/widgets/particles.dart';
import '../../core/widgets/piece_layer.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'xiangqi_rules.dart';

class XiangqiController extends DuelController<XqState, XqMove> {
  final flash = FlashController();

  /// Board index of the last capture, for the particle burst.
  final ValueNotifier<int?> captureAt = ValueNotifier(null);

  @override
  XqState initialState() => XqState.initial();

  @override
  int sideToMove(XqState state) => state.turn;

  @override
  XqState apply(XqState state, XqMove move) => state.play(move);

  @override
  DuelOutcome? judge(XqState state) {
    if (state.legalMoves().isEmpty) {
      final mated = state.inCheck(state.turn);
      return DuelOutcome.win(1 - state.turn, mated ? '将死对方' : '对方无棋可走（困毙）');
    }
    if (state.quiet >= XqState.quietLimit) {
      return const DuelOutcome.draw('六十回合没有吃子');
    }
    return null;
  }

  @override
  Future<XqMove?> aiMove(XqState s, AiLevel level) async {
    final code = await compute(xiangqiAiEntry, (s.board, s.turn, level.index));
    return code < 0 ? null : XqMove(code >> 7, code & 127);
  }

  @override
  void onMovePlayed(XqState before, XqMove move, XqState after) {
    if (after.lastCapture != null) {
      Fx.play(Sfx.capture, buzz: Buzz.medium);
      captureAt.value = move.to;
    } else {
      Fx.play(Sfx.place, buzz: Buzz.light);
    }
    if (after.inCheck(after.turn) && after.legalMoves().isNotEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        Fx.play(Sfx.check, buzz: Buzz.heavy);
        flash.show('将军！');
      });
    }
  }

  @override
  void dispose() {
    flash.dispose();
    captureAt.dispose();
    super.dispose();
  }
}

class XiangqiPage extends StatefulWidget {
  const XiangqiPage({super.key});

  static Widget create(BuildContext context) => const XiangqiPage();

  @override
  State<XiangqiPage> createState() => _XiangqiPageState();
}

class _XiangqiPageState extends State<XiangqiPage> {
  final _controller = XiangqiController();
  final _particles = ParticleController();

  @override
  void dispose() {
    _controller.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DuelGameFrame<XqState, XqMove>(
      info: GameCatalog.xiangqi,
      controller: _controller,
      scenery: Scenery.sunset,
      sides: const [
        DuelSide('红方', _PieceToken(true), candy: Candy.cherry),
        DuelSide('黑方', _PieceToken(false), candy: Candy.slate),
      ],
      board: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: AspectRatio(
          aspectRatio: 9.4 / 10.4,
          child: _XiangqiBoard(controller: _controller, particles: _particles),
        ),
      ),
    );
  }
}

class _XiangqiBoard extends StatefulWidget {
  const _XiangqiBoard({required this.controller, required this.particles});

  final XiangqiController controller;
  final ParticleController particles;

  @override
  State<_XiangqiBoard> createState() => _XiangqiBoardState();
}

class _XiangqiBoardState extends State<_XiangqiBoard> {
  int? _selected;
  List<XqMove> _targets = const [];
  double _cell = 0;

  XiangqiController get _c => widget.controller;

  /// Human plays from the bottom: flip when the human is black vs the AI.
  bool get _flipped => _c.vsAi && _c.humanSide == 1;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onState);
    _c.captureAt.addListener(_onCapture);
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _c.captureAt.removeListener(_onCapture);
    super.dispose();
  }

  void _onState() {
    if (_selected != null && !_c.canHumanAct) {
      _selected = null;
      _targets = const [];
    }
    setState(() {});
  }

  void _onCapture() {
    final at = _c.captureAt.value;
    if (at == null || _cell == 0) return;
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      widget.particles.burstFrom(
        context,
        _center(at),
        count: 22,
        colors: const [
          Color(0xFFFFC83D),
          Color(0xFFFF8C42),
          Color(0xFFFF5A5F),
          Colors.white
        ],
      );
    });
  }

  Offset _center(int index) {
    var x = index % 9;
    var y = index ~/ 9;
    if (_flipped) {
      x = 8 - x;
      y = 9 - y;
    }
    return Offset((x + 0.7) * _cell, (y + 0.7) * _cell);
  }

  int? _hit(Offset p) {
    var x = (p.dx / _cell - 0.7).round();
    var y = (p.dy / _cell - 0.7).round();
    if (x < 0 || x > 8 || y < 0 || y > 9) return null;
    if (_flipped) {
      x = 8 - x;
      y = 9 - y;
    }
    return y * 9 + x;
  }

  void _tap(Offset p) {
    if (!_c.canHumanAct) return;
    final i = _hit(p);
    if (i == null) return;
    final s = _c.state;
    final move = _targets.where((m) => m.to == i).firstOrNull;
    if (move != null) {
      setState(() {
        _selected = null;
        _targets = const [];
      });
      _c.play(move);
      return;
    }
    final v = s.board[i];
    if (v != 0 && Xq.side(v) == s.turn) {
      Fx.play(Sfx.select, buzz: Buzz.tap);
      setState(() {
        _selected = i;
        _targets = s.legalMovesFrom(i);
      });
      return;
    }
    if (_selected != null) Fx.error();
    setState(() {
      _selected = null;
      _targets = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;
    return LayoutBuilder(
      builder: (context, constraints) {
        _cell = constraints.maxWidth / 9.4;
        final pieceSize = _cell * 0.92;
        final last = _c.lastMove;
        final hint = _c.hint;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Palette.ink, width: 3),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFBDDA6), Color(0xFFF1C483)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0xFFC9955A), offset: Offset(0, 7)),
              BoxShadow(color: Palette.ink, offset: Offset(0, 9)),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _tap(d.localPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _XqBoardPainter(
                      cell: _cell,
                      flipped: _flipped,
                      lastFrom: last == null ? null : _center(last.from),
                      lastTo: last == null ? null : _center(last.to),
                    ),
                  ),
                ),
                AnimatedPieceLayer(
                  size: pieceSize,
                  pieces: [
                    for (var i = 0; i < 90; i++)
                      if (s.board[i] != 0)
                        PieceSpec(
                          id: s.ids[i],
                          center: _center(i),
                          lifted: i == _selected,
                          z: i == _selected || i == last?.to ? 1 : 0,
                          child: _XqPiece(s.board[i]),
                        ),
                  ],
                ),
                for (final m in _targets)
                  Positioned(
                    left: _center(m.to).dx - _cell / 2,
                    top: _center(m.to).dy - _cell / 2,
                    width: _cell,
                    height: _cell,
                    child: IgnorePointer(
                        child: _TargetMarker(capture: s.board[m.to] != 0)),
                  ),
                if (hint != null) ...[
                  for (final i in [hint.from, hint.to])
                    Positioned(
                      left: _center(i).dx - _cell / 2,
                      top: _center(i).dy - _cell / 2,
                      width: _cell,
                      height: _cell,
                      child: const IgnorePointer(child: _HintRing()),
                    ),
                ],
                Positioned.fill(child: FlashBanner(controller: _c.flash)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _XqPiece extends StatelessWidget {
  const _XqPiece(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _XqPiecePainter(value));
  }
}

class _XqPiecePainter extends CustomPainter {
  _XqPiecePainter(this.value);

  final int value;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    GameIcons.paintXiangqiPiece(canvas, size.width * 0.46, Xq.name(value),
        red: Xq.side(value) == 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_XqPiecePainter oldDelegate) => oldDelegate.value != value;
}

class _PieceToken extends StatelessWidget {
  const _PieceToken(this.red);

  final bool red;

  @override
  Widget build(BuildContext context) => _XqPiece(Xq.make(Xq.king, red ? 0 : 1));
}

class _TargetMarker extends StatelessWidget {
  const _TargetMarker({required this.capture});

  final bool capture;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, t, _) => Center(
        child: Container(
          width: (capture ? 44 : 18) * t,
          height: (capture ? 44 : 18) * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: capture ? Colors.transparent : Candy.mint.face,
            border: Border.all(
              color: capture ? Candy.cherry.face : Palette.ink,
              width: capture ? 4 : 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _HintRing extends StatefulWidget {
  const _HintRing();

  @override
  State<_HintRing> createState() => _HintRingState();
}

class _HintRingState extends State<_HintRing>
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
    return ScaleTransition(
      scale: Tween(begin: 0.85, end: 1.05).animate(_c),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Candy.sun.face, width: 5),
        ),
      ),
    );
  }
}

class _XqBoardPainter extends CustomPainter {
  _XqBoardPainter({
    required this.cell,
    required this.flipped,
    required this.lastFrom,
    required this.lastTo,
  });

  final double cell;
  final bool flipped;
  final Offset? lastFrom;
  final Offset? lastTo;

  Offset _p(double x, double y) => Offset((x + 0.7) * cell, (y + 0.7) * cell);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..strokeWidth = 1.8;
    for (var y = 0; y < 10; y++) {
      canvas.drawLine(_p(0, y.toDouble()), _p(8, y.toDouble()), line);
    }
    for (var x = 0; x < 9; x++) {
      if (x == 0 || x == 8) {
        canvas.drawLine(_p(x.toDouble(), 0), _p(x.toDouble(), 9), line);
      } else {
        canvas.drawLine(_p(x.toDouble(), 0), _p(x.toDouble(), 4), line);
        canvas.drawLine(_p(x.toDouble(), 5), _p(x.toDouble(), 9), line);
      }
    }
    canvas.drawRect(Rect.fromPoints(_p(0, 0), _p(8, 9)).inflate(4),
        inkStroke(2.5, color: const Color(0xFF8A5A2B)));
    for (final (y0, y1) in const [(0.0, 2.0), (7.0, 9.0)]) {
      canvas.drawLine(_p(3, y0), _p(5, y1), line);
      canvas.drawLine(_p(5, y0), _p(3, y1), line);
    }
    // River band.
    final river = Rect.fromPoints(_p(0, 4), _p(8, 5)).deflate(2);
    canvas.drawRect(
        river, Paint()..color = const Color(0xFF9ED8F5).withOpacity(0.55));
    _text(canvas, flipped ? '汉 界' : '楚 河', _p(2, 4.5));
    _text(canvas, flipped ? '楚 河' : '汉 界', _p(6, 4.5));
    // Position markers for cannons and pawns.
    final marks = <(int, int)>[
      (1, 2),
      (7, 2),
      (1, 7),
      (7, 7),
      for (final x in [0, 2, 4, 6, 8]) ...[(x, 3), (x, 6)],
    ];
    final mark = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final (x, y) in marks) {
      final c = _p(x.toDouble(), y.toDouble());
      final g = cell * 0.08;
      final l = cell * 0.16;
      for (final sx in [-1.0, 1.0]) {
        if ((x == 0 && sx < 0) || (x == 8 && sx > 0)) continue;
        for (final sy in [-1.0, 1.0]) {
          final corner = c + Offset(sx * g, sy * g);
          canvas.drawPath(
            Path()
              ..moveTo(corner.dx + sx * l, corner.dy)
              ..lineTo(corner.dx, corner.dy)
              ..lineTo(corner.dx, corner.dy + sy * l),
            mark,
          );
        }
      }
    }
    if (lastFrom != null) {
      canvas.drawCircle(lastFrom!, cell * 0.2,
          Paint()..color = Candy.ocean.face.withOpacity(0.35));
    }
    if (lastTo != null) {
      canvas.drawCircle(lastTo!, cell * 0.55,
          Paint()..color = Candy.sun.face.withOpacity(0.45));
    }
  }

  void _text(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: cell * 0.48,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF8A5A2B).withOpacity(0.75),
          letterSpacing: cell * 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_XqBoardPainter old) =>
      old.cell != cell ||
      old.flipped != flipped ||
      old.lastFrom != lastFrom ||
      old.lastTo != lastTo;
}
