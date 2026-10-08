import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/cartoon_animal.dart';
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
import 'jungle_rules.dart';

const _animals = [
  Animal.mouse, // placeholder for index 0
  Animal.mouse,
  Animal.cat,
  Animal.dog,
  Animal.wolf,
  Animal.leopard,
  Animal.tiger,
  Animal.lion,
  Animal.elephant,
];

const _teams = [Candy.cherry, Candy.ocean];

class JungleController extends DuelController<JgState, JgMove> {
  final flash = FlashController();
  final ValueNotifier<int?> captureAt = ValueNotifier(null);

  @override
  JgState initialState() => JgState.initial();

  @override
  int sideToMove(JgState state) => state.turn;

  @override
  JgState apply(JgState state, JgMove move) => state.play(move);

  @override
  DuelOutcome? judge(JgState state) {
    final winner = state.winner;
    if (winner != null) {
      final denTaken = state.board[Jg.den(1 - winner)] != 0;
      return DuelOutcome.win(winner, denTaken ? '冲进了对方的兽穴' : '对方无路可走');
    }
    if (state.quiet >= JgState.quietLimit) {
      return const DuelOutcome.draw('五十回合没有吃子');
    }
    return null;
  }

  @override
  Future<JgMove?> aiMove(JgState s, AiLevel level) async {
    final code = await compute(jungleAiEntry, (s.board, s.turn, level.index));
    return code < 0 ? null : JgMove(code >> 6, code & 63);
  }

  @override
  void onMovePlayed(JgState before, JgMove move, JgState after) {
    final mover = before.board[move.from];
    final jumped = (move.from % 7 - move.to % 7).abs() > 1 ||
        (move.from ~/ 7 - move.to ~/ 7).abs() > 1;
    if (after.lastCapture != null) {
      Fx.play(Sfx.capture, buzz: Buzz.medium);
      captureAt.value = move.to;
      if (Jg.rank(mover) == Jg.mouse &&
          Jg.rank(after.lastCapture!) == Jg.elephant) {
        flash.show('老鼠吃大象！', candy: Candy.sun);
      }
    } else if (jumped) {
      Fx.play(Sfx.fly, buzz: Buzz.light);
      flash.show(Jg.rank(mover) == Jg.lion ? '狮子跳河！' : '老虎跳河！',
          candy: Candy.ocean);
    } else {
      Fx.play(Jg.isWater(move.to) ? Sfx.slide : Sfx.hop, buzz: Buzz.light);
    }
  }

  @override
  void dispose() {
    flash.dispose();
    captureAt.dispose();
    super.dispose();
  }
}

class JunglePage extends StatefulWidget {
  const JunglePage({super.key});

  static Widget create(BuildContext context) => const JunglePage();

  @override
  State<JunglePage> createState() => _JunglePageState();
}

class _JunglePageState extends State<JunglePage> {
  final _controller = JungleController();
  final _particles = ParticleController();

  @override
  void dispose() {
    _controller.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DuelGameFrame<JgState, JgMove>(
      info: GameCatalog.jungle,
      controller: _controller,
      scenery: Scenery.meadow,
      particles: _particles,
      sides: const [
        DuelSide('红队', _JungleToken(Jg.lion | 0), candy: Candy.cherry),
        DuelSide('蓝队', _JungleToken(Jg.lion | 16), candy: Candy.ocean),
      ],
      board: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: AspectRatio(
          aspectRatio: 7 / 9,
          child: _JungleBoard(controller: _controller, particles: _particles),
        ),
      ),
    );
  }
}

class _JungleBoard extends StatefulWidget {
  const _JungleBoard({required this.controller, required this.particles});

  final JungleController controller;
  final ParticleController particles;

  @override
  State<_JungleBoard> createState() => _JungleBoardState();
}

class _JungleBoardState extends State<_JungleBoard> {
  int? _selected;
  List<JgMove> _targets = const [];
  double _cell = 0;

  JungleController get _c => widget.controller;
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
    if (at == null) return;
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) widget.particles.burstFrom(context, _center(at), count: 20);
    });
  }

  Offset _center(int i) {
    var x = i % 7;
    var y = i ~/ 7;
    if (_flipped) {
      x = 6 - x;
      y = 8 - y;
    }
    return Offset((x + 0.5) * _cell, (y + 0.5) * _cell);
  }

  int? _hit(Offset p) {
    var x = (p.dx / _cell).floor();
    var y = (p.dy / _cell).floor();
    if (x < 0 || x > 6 || y < 0 || y > 8) return null;
    if (_flipped) {
      x = 6 - x;
      y = 8 - y;
    }
    return y * 7 + x;
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
    if (v != 0 && Jg.side(v) == s.turn) {
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
    final hint = _c.hint;
    return LayoutBuilder(
      builder: (context, constraints) {
        _cell = constraints.maxWidth / 7;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Palette.ink, width: 3),
            boxShadow: const [
              BoxShadow(color: Palette.grassDark, offset: Offset(0, 7)),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: CustomPaint(
                      painter: _JungleBoardPainter(
                          cell: _cell, flipped: _flipped, last: _c.lastMove),
                    ),
                  ),
                ),
                AnimatedPieceLayer(
                  size: _cell * 0.88,
                  moveDuration: const Duration(milliseconds: 340),
                  pieces: [
                    for (var i = 0; i < Jg.cells; i++)
                      if (s.board[i] != 0)
                        PieceSpec(
                          id: s.ids[i],
                          center: _center(i),
                          lifted: i == _selected,
                          z: i == _selected || i == _c.lastMove?.to ? 1 : 0,
                          child:
                              _JungleToken(s.board[i], swimming: Jg.isWater(i)),
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
                        child: _Target(capture: s.board[m.to] != 0)),
                  ),
                if (hint != null)
                  for (final i in [hint.from, hint.to])
                    Positioned(
                      left: _center(i).dx - _cell / 2,
                      top: _center(i).dy - _cell / 2,
                      width: _cell,
                      height: _cell,
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Candy.sun.face, width: 5),
                          ),
                        ),
                      ),
                    ),
                Positioned.fill(child: FlashBanner(controller: _c.flash)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Target extends StatelessWidget {
  const _Target({required this.capture});

  final bool capture;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.elasticOut,
      builder: (context, t, _) => Center(
        child: Container(
          width: (capture ? 50 : 20) * t,
          height: (capture ? 50 : 20) * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: capture ? Candy.cherry.face.withOpacity(0.25) : Colors.white,
            border: Border.all(
                color: capture ? Candy.cherry.face : Palette.ink,
                width: capture ? 4 : 2.5),
          ),
        ),
      ),
    );
  }
}

class _JungleToken extends StatelessWidget {
  const _JungleToken(this.value, {this.swimming = false});

  final int value;
  final bool swimming;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _TokenPainter(value, swimming));
}

class _TokenPainter extends CustomPainter {
  _TokenPainter(this.value, this.swimming);

  final int value;
  final bool swimming;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = size.center(Offset.zero);
    final team = _teams[Jg.side(value)];
    final r = s * 0.47;
    canvas.drawCircle(c + Offset(0, s * 0.05), r,
        Paint()..color = Colors.black.withOpacity(0.22));
    canvas.drawCircle(c, r, Paint()..color = team.face);
    canvas.drawCircle(c, r * 0.82, Paint()..color = Colors.white);
    canvas.drawCircle(c, r, inkStroke(s * 0.05));
    paintAnimal(
        canvas,
        Rect.fromCircle(center: c + Offset(0, s * 0.02), radius: r * 0.82),
        _animals[Jg.rank(value)],
        outline: true);
    // Rank badge so kids can compare strength at a glance.
    final badge = c + Offset(r * 0.62, r * 0.6);
    canvas.drawCircle(badge, s * 0.15, Paint()..color = team.face);
    canvas.drawCircle(badge, s * 0.15, inkStroke(s * 0.035));
    final tp = TextPainter(
      text: TextSpan(
        text: '${Jg.rank(value)}',
        style: TextStyle(
            fontSize: s * 0.19,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, badge - Offset(tp.width / 2, tp.height / 2));
    if (swimming) {
      final wave = Path();
      for (var i = 0; i <= 12; i++) {
        final x = c.dx - r + 2 * r * i / 12;
        final y = c.dy + r * 0.92 + math.sin(i * 1.4) * s * 0.025;
        i == 0 ? wave.moveTo(x, y) : wave.lineTo(x, y);
      }
      canvas.drawPath(
          wave, inkStroke(s * 0.05, color: Colors.white.withOpacity(0.9)));
    }
  }

  @override
  bool shouldRepaint(_TokenPainter old) =>
      old.value != value || old.swimming != swimming;
}

class _JungleBoardPainter extends CustomPainter {
  _JungleBoardPainter(
      {required this.cell, required this.flipped, required this.last});

  final double cell;
  final bool flipped;
  final JgMove? last;

  Rect _rect(int i) {
    var x = i % 7;
    var y = i ~/ 7;
    if (flipped) {
      x = 6 - x;
      y = 8 - y;
    }
    return Rect.fromLTWH(x * cell, y * cell, cell, cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < Jg.cells; i++) {
      final r = _rect(i);
      final light = ((i % 7) + (i ~/ 7)).isEven;
      canvas.drawRect(
          r,
          Paint()
            ..color =
                light ? const Color(0xFFA6E87F) : const Color(0xFF93DB6C));
    }
    // Rivers.
    for (final x0 in [1, 4]) {
      final a = _rect(3 * 7 + x0);
      final b = _rect(5 * 7 + x0 + 1);
      final pool = RRect.fromRectAndRadius(
          a.expandToInclude(b).deflate(cell * 0.06),
          Radius.circular(cell * 0.35));
      canvas.drawRRect(pool, Paint()..color = const Color(0xFF5CC3F2));
      canvas.drawRRect(pool, inkStroke(2.5, color: const Color(0xFF2A83D8)));
      final wave = inkStroke(2.2, color: Colors.white.withOpacity(0.7));
      for (var k = 0; k < 4; k++) {
        final y = pool.top + pool.height * (0.2 + k * 0.2);
        final path = Path()..moveTo(pool.left + cell * 0.25, y);
        for (var t = 1; t <= 6; t++) {
          path.relativeQuadraticBezierTo(
              cell * 0.12, (t.isEven ? 1 : -1) * cell * 0.08, cell * 0.24, 0);
        }
        canvas.drawPath(path, wave);
      }
    }
    // Traps.
    for (var i = 0; i < Jg.cells; i++) {
      final owner = Jg.trapOwner(i);
      if (owner < 0) continue;
      final r = _rect(i).deflate(cell * 0.12);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cell * 0.12)),
          Paint()..color = const Color(0xFFC9955A));
      final net = inkStroke(1.6, color: const Color(0xFF7A4E25));
      for (var k = 1; k < 4; k++) {
        canvas.drawLine(Offset(r.left + r.width * k / 4, r.top),
            Offset(r.left + r.width * k / 4, r.bottom), net);
        canvas.drawLine(Offset(r.left, r.top + r.height * k / 4),
            Offset(r.right, r.top + r.height * k / 4), net);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cell * 0.12)),
          inkStroke(2, color: _teams[owner].shade));
    }
    // Dens.
    for (final side in [0, 1]) {
      final r = _rect(Jg.den(side)).deflate(cell * 0.1);
      final house = Path()
        ..moveTo(r.left, r.top + r.height * 0.45)
        ..lineTo(r.center.dx, r.top)
        ..lineTo(r.right, r.top + r.height * 0.45)
        ..lineTo(r.right - r.width * 0.1, r.top + r.height * 0.45)
        ..lineTo(r.right - r.width * 0.1, r.bottom)
        ..lineTo(r.left + r.width * 0.1, r.bottom)
        ..lineTo(r.left + r.width * 0.1, r.top + r.height * 0.45)
        ..close();
      canvas.drawPath(house, Paint()..color = _teams[side].light);
      canvas.drawPath(house, inkStroke(2.5));
      final door = RRect.fromRectAndCorners(
        Rect.fromLTWH(r.center.dx - r.width * 0.15, r.top + r.height * 0.6,
            r.width * 0.3, r.height * 0.4),
        topLeft: Radius.circular(r.width * 0.15),
        topRight: Radius.circular(r.width * 0.15),
      );
      canvas.drawRRect(door, Paint()..color = _teams[side].shade);
    }
    final m = last;
    if (m != null) {
      canvas.drawRect(_rect(m.from).deflate(3),
          inkStroke(3, color: Colors.white.withOpacity(0.7)));
      canvas.drawRect(
          _rect(m.to).deflate(3), inkStroke(3, color: Candy.sun.face));
    }
  }

  @override
  bool shouldRepaint(_JungleBoardPainter old) =>
      old.cell != cell || old.flipped != flipped || old.last != last;
}
