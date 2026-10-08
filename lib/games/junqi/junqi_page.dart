import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
import 'junqi_rules.dart';

const _colors = [Candy.cherry, Candy.ocean];
const _colorNames = ['红方', '蓝方'];

class JunqiController extends DuelController<JqState, JqAction> {
  final flash = FlashController();
  final ValueNotifier<(int, JqEvent)?> eventAt = ValueNotifier(null);

  @override
  JqState initialState() => JqState.deal(math.Random());

  @override
  int sideToMove(JqState state) => state.turn;

  @override
  JqState apply(JqState state, JqAction move) => state.apply(move);

  @override
  DuelOutcome? judge(JqState state) {
    final winner = state.winner;
    if (winner != null) {
      return DuelOutcome.win(
          winner, state.flagTakenBy != null ? '扛走了对方的军旗' : '对方没有能走的棋了');
    }
    if (state.quiet >= JqState.quietLimit) {
      return const DuelOutcome.draw('四十回合没有吃子');
    }
    return null;
  }

  @override
  Future<JqAction?> aiMove(JqState s, AiLevel level) async {
    final code = await compute(
        junqiAiEntry, (s.board, s.ids, s.turn, s.colors, level.index));
    return code < 0 ? null : JqAction.decode(code);
  }

  @override
  Duration get aiPacing => const Duration(milliseconds: 650);

  @override
  void onMovePlayed(JqState before, JqAction move, JqState after) {
    final at = after.eventAt;
    switch (after.event) {
      case JqEvent.flip:
        Fx.play(Sfx.flip, buzz: Buzz.tap);
      case JqEvent.move:
        Fx.play(Sfx.move, buzz: Buzz.light);
      case JqEvent.capture:
        Fx.play(Sfx.capture, buzz: Buzz.medium);
      case JqEvent.trade:
        Fx.play(Sfx.capture, buzz: Buzz.medium);
        flash.show('同归于尽！', candy: Candy.grape);
      case JqEvent.bomb:
        Fx.play(Sfx.bomb, buzz: Buzz.heavy);
        flash.show('轰！', candy: Candy.orange);
      case JqEvent.mine:
        Fx.play(Sfx.bomb, buzz: Buzz.heavy);
        flash.show('踩到地雷！', candy: Candy.orange);
      case JqEvent.dig:
        Fx.play(Sfx.combo, buzz: Buzz.medium);
        flash.show('工兵排雷！', candy: Candy.mint);
      case JqEvent.flag:
        Fx.play(Sfx.clear, buzz: Buzz.heavy);
        flash.show('扛旗！', candy: Candy.sun);
      case JqEvent.none:
        break;
    }
    if (at != null) eventAt.value = (at, after.event);
  }

  @override
  void dispose() {
    flash.dispose();
    eventAt.dispose();
    super.dispose();
  }
}

class JunqiPage extends StatefulWidget {
  const JunqiPage({super.key});

  static Widget create(BuildContext context) => const JunqiPage();

  @override
  State<JunqiPage> createState() => _JunqiPageState();
}

class _JunqiPageState extends State<JunqiPage> {
  final _controller = JunqiController();
  final _particles = ParticleController();

  @override
  void dispose() {
    _controller.dispose();
    _particles.dispose();
    super.dispose();
  }

  DuelSide _side(int player) {
    final color = _controller.state.colors[player];
    if (color < 0) {
      return DuelSide(player == 0 ? '先手' : '后手', const _TileToken(null),
          candy: Candy.wood);
    }
    return DuelSide(_colorNames[color], _TileToken(color),
        candy: _colors[color]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => DuelGameFrame<JqState, JqAction>(
        info: GameCatalog.junqi,
        controller: _controller,
        scenery: Scenery.mint,
        particles: _particles,
        sides: [_side(0), _side(1)],
        board: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
          child: AspectRatio(
            aspectRatio: 5 /
                (12 * _JunqiBoardState.rowRatio + _JunqiBoardState.gapRatio),
            child: _JunqiBoard(controller: _controller, particles: _particles),
          ),
        ),
      ),
    );
  }
}

class _JunqiBoard extends StatefulWidget {
  const _JunqiBoard({required this.controller, required this.particles});

  final JunqiController controller;
  final ParticleController particles;

  @override
  State<_JunqiBoard> createState() => _JunqiBoardState();
}

class _JunqiBoardState extends State<_JunqiBoard> {
  /// Row height and center gap as fractions of the column width.
  static const rowRatio = 0.6;
  static const gapRatio = 0.7;

  int? _selected;
  Set<int> _targets = const {};
  double _cw = 0;

  JunqiController get _c => widget.controller;

  /// Keep the human's color at the bottom once it is known.
  bool get _flipped {
    final mine = _c.state.colors[_c.vsAi ? _c.humanSide : 0];
    return mine == 1;
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_onState);
    _c.eventAt.addListener(_onEvent);
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _c.eventAt.removeListener(_onEvent);
    super.dispose();
  }

  void _onState() {
    if (_selected != null && !_c.canHumanAct) {
      _selected = null;
      _targets = const {};
    }
    setState(() {});
  }

  void _onEvent() {
    final e = _c.eventAt.value;
    if (e == null) return;
    final (at, kind) = e;
    if (kind == JqEvent.move || kind == JqEvent.flip) return;
    final explosive = kind == JqEvent.bomb || kind == JqEvent.mine;
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      widget.particles.burstFrom(
        context,
        _center(at),
        count: explosive ? 34 : 18,
        speed: explosive ? 360 : 240,
        shape: explosive ? ParticleShape.dot : ParticleShape.star,
        colors: explosive
            ? const [
                Color(0xFFFF8C42),
                Color(0xFFFFC83D),
                Color(0xFF6B5E8C),
                Color(0xFFFF5A5F)
              ]
            : ParticleController.defaultColors,
      );
    });
  }

  double get _ch => _cw * rowRatio;

  Offset _center(int i) {
    var x = i % 5;
    var y = i ~/ 5;
    if (_flipped) {
      x = 4 - x;
      y = 11 - y;
    }
    final gap = y >= 6 ? _cw * gapRatio : 0.0;
    return Offset((x + 0.5) * _cw, (y + 0.5) * _ch + gap);
  }

  int? _hit(Offset p) {
    var x = (p.dx / _cw).floor();
    final mid = 6 * _ch;
    double dy = p.dy;
    if (dy > mid + _cw * gapRatio) {
      dy -= _cw * gapRatio;
    } else if (dy > mid) {
      return null;
    }
    var y = (dy / _ch).floor();
    if (x < 0 || x > 4 || y < 0 || y > 11) return null;
    if (_flipped) {
      x = 4 - x;
      y = 11 - y;
    }
    return y * 5 + x;
  }

  void _tap(Offset p) {
    if (!_c.canHumanAct) return;
    final i = _hit(p);
    if (i == null) return;
    final s = _c.state;
    if (_targets.contains(i) && _selected != null) {
      final from = _selected!;
      setState(() {
        _selected = null;
        _targets = const {};
      });
      _c.play(JqAction.move(from, i));
      return;
    }
    final v = s.board[i];
    if (v != 0 && !Jq.revealed(v)) {
      setState(() {
        _selected = null;
        _targets = const {};
      });
      _c.play(JqAction.flip(i));
      return;
    }
    final mine = s.myColor;
    if (v != 0 && mine != null && Jq.color(v) == mine && Jq.movable(v)) {
      final targets = s.destinations(i);
      Fx.play(targets.isEmpty ? Sfx.error : Sfx.select, buzz: Buzz.tap);
      setState(() {
        _selected = i;
        _targets = targets;
      });
      return;
    }
    if (v != 0 && Jq.revealed(v) && mine != null && Jq.color(v) == mine) {
      Fx.error();
    }
    setState(() {
      _selected = null;
      _targets = const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;
    final hint = _c.hint;
    return LayoutBuilder(
      builder: (context, constraints) {
        _cw = constraints.maxWidth / 5;
        final tile = Size(_cw * 0.74, _ch * 0.74);
        final hintSquares = hint == null
            ? const <int>[]
            : (hint.isFlip ? [hint.at!] : [hint.from!, hint.to!]);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Palette.ink, width: 3),
            color: const Color(0xFFE9F7D5),
            boxShadow: const [
              BoxShadow(color: Color(0xFF8CC96B), offset: Offset(0, 7)),
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
                      painter: _JunqiBoardPainter(
                          flipped: _flipped,
                          center: _center,
                          cw: _cw,
                          ch: _ch,
                          gap: _cw * gapRatio),
                    ),
                  ),
                ),
                for (final t in _targets)
                  Positioned(
                    left: _center(t).dx - tile.width / 2 - 3,
                    top: _center(t).dy - tile.height / 2 - 3,
                    width: tile.width + 6,
                    height: tile.height + 6,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: s.board[t] == 0
                              ? Candy.mint.face.withOpacity(0.55)
                              : Colors.transparent,
                          border: Border.all(
                              color: s.board[t] == 0
                                  ? Palette.ink
                                  : Candy.cherry.face,
                              width: 3),
                        ),
                      ),
                    ),
                  ),
                AnimatedPieceLayer(
                  size: tile.width,
                  pieceSize: tile,
                  moveDuration: const Duration(milliseconds: 360),
                  pieces: [
                    for (var i = 0; i < Jq.cells; i++)
                      if (s.board[i] != 0)
                        PieceSpec(
                          id: s.ids[i],
                          center: _center(i),
                          lifted: i == _selected,
                          z: i == _selected || (_c.lastMove?.to == i) ? 1 : 0,
                          child: _JunqiTile(value: s.board[i]),
                        ),
                  ],
                ),
                for (final i in hintSquares)
                  Positioned(
                    left: _center(i).dx - tile.width / 2 - 4,
                    top: _center(i).dy - tile.height / 2 - 4,
                    width: tile.width + 8,
                    height: tile.height + 8,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Candy.sun.face, width: 4),
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

/// Junqi tile with a 3D flip when it is revealed.
class _JunqiTile extends StatefulWidget {
  const _JunqiTile({required this.value});

  final int value;

  @override
  State<_JunqiTile> createState() => _JunqiTileState();
}

class _JunqiTileState extends State<_JunqiTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: Jq.revealed(widget.value) ? 1 : 0,
  );

  @override
  void didUpdateWidget(_JunqiTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = Jq.revealed(oldWidget.value);
    final now = Jq.revealed(widget.value);
    if (!was && now) _flip.forward(from: 0);
    if (!now) _flip.value = 0;
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_flip.value);
        final showFront = t >= 0.5;
        final angle = showFront ? (1 - t) * math.pi : t * math.pi;
        final lift = math.sin(t * math.pi) * 0.25;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(angle)
            ..scale(1 + lift, 1 + lift),
          child: CustomPaint(
            painter:
                _TilePainter(showFront ? widget.value : (widget.value & ~32)),
          ),
        );
      },
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.value);

  final int value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(size.height * 0.28);
    final body = RRect.fromRectAndRadius(rect, r);
    canvas.drawRRect(body.shift(Offset(0, size.height * 0.1)),
        Paint()..color = Colors.black.withOpacity(0.25));
    if (!Jq.revealed(value)) {
      canvas.drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE2B0), Color(0xFFE7B877)],
          ).createShader(rect),
      );
      canvas.drawRRect(
          body, inkStroke(size.height * 0.07, color: const Color(0xFF8A5A2B)));
      paintStar(
        canvas,
        rect.center,
        size.height * 0.3,
        fill: const Color(0xFFFFF4DC),
        outline: const Color(0xFFB07A4F),
        outlineWidth: size.height * 0.05,
        glossy: false,
      );
      return;
    }
    final candy = _colors[Jq.color(value)];
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [candy.light, candy.face],
        ).createShader(rect),
    );
    canvas.drawRRect(body, inkStroke(size.height * 0.08));
    final kind = Jq.kind(value);
    final label = Jq.names[kind];
    final special = kind >= Jq.mine;
    if (special) {
      final icon = Offset(size.width * 0.22, size.height / 2);
      final ir = size.height * 0.26;
      switch (kind) {
        case Jq.bomb:
          canvas.drawCircle(icon, ir, Paint()..color = Palette.ink);
          canvas.drawLine(
              icon + Offset(ir * 0.5, -ir * 0.6),
              icon + Offset(ir * 0.9, -ir * 1.1),
              inkStroke(ir * 0.25, color: Candy.sun.face));
        case Jq.mine:
          canvas.drawOval(
              Rect.fromCenter(center: icon, width: ir * 2.2, height: ir * 1.3),
              Paint()..color = const Color(0xFF6B5E8C));
          canvas.drawCircle(icon + Offset(0, -ir * 0.5), ir * 0.25,
              Paint()..color = Candy.cherry.face);
        default:
          canvas.drawLine(icon + Offset(-ir * 0.5, ir),
              icon + Offset(-ir * 0.5, -ir), inkStroke(ir * 0.22));
          canvas.drawPath(
            Path()
              ..moveTo(icon.dx - ir * 0.5, icon.dy - ir)
              ..lineTo(icon.dx + ir * 0.9, icon.dy - ir * 0.5)
              ..lineTo(icon.dx - ir * 0.5, icon.dy)
              ..close(),
            Paint()..color = Candy.sun.face,
          );
      }
    }
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: size.height * 0.46,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
          shadows: const [Shadow(color: Palette.ink, offset: Offset(0, 1.5))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final dx = special ? size.width * 0.58 : size.width / 2;
    tp.paint(
        canvas, Offset(dx - tp.width / 2, size.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TilePainter oldDelegate) => oldDelegate.value != value;
}

class _TileToken extends StatelessWidget {
  const _TileToken(this.color);

  final int? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 34,
        height: 24,
        child: CustomPaint(painter: _TokenPainter(color)),
      ),
    );
  }
}

class _TokenPainter extends CustomPainter {
  _TokenPainter(this.color);

  final int? color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final body =
        RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.3));
    final c = color;
    canvas.drawRRect(body,
        Paint()..color = c == null ? const Color(0xFFF4CE93) : _colors[c].face);
    canvas.drawRRect(body, inkStroke(2));
    paintStar(canvas, rect.center, size.height * 0.32,
        fill: Colors.white, outlineWidth: 1.5, glossy: false);
  }

  @override
  bool shouldRepaint(_TokenPainter oldDelegate) => oldDelegate.color != color;
}

class _JunqiBoardPainter extends CustomPainter {
  _JunqiBoardPainter(
      {required this.flipped,
      required this.center,
      required this.cw,
      required this.ch,
      required this.gap});

  final bool flipped;
  final Offset Function(int) center;
  final double cw;
  final double ch;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    // Front line strip with mountains on the blocked columns.
    final mid = Rect.fromLTWH(0, 6 * ch, size.width, gap);
    canvas.drawRect(mid, Paint()..color = const Color(0xFFBFE6F7));
    for (final x in [1, 3]) {
      final c = Offset((x + 0.5) * cw, mid.center.dy);
      final m = Path()
        ..moveTo(c.dx - cw * 0.38, mid.bottom - gap * 0.18)
        ..lineTo(c.dx - cw * 0.08, mid.top + gap * 0.18)
        ..lineTo(c.dx + cw * 0.06, mid.top + gap * 0.4)
        ..lineTo(c.dx + cw * 0.18, mid.top + gap * 0.28)
        ..lineTo(c.dx + cw * 0.38, mid.bottom - gap * 0.18)
        ..close();
      canvas.drawPath(m, Paint()..color = const Color(0xFF9C7A63));
      canvas.drawPath(m, inkStroke(2));
    }

    // Roads (thin) then railways (thick, striped).
    final road = Paint()
      ..color = const Color(0xFFB9A57E)
      ..strokeWidth = 2;
    for (var i = 0; i < Jq.cells; i++) {
      for (final n in Jq.roadNeighbors[i]) {
        if (n < i) continue;
        canvas.drawLine(center(i), center(n), road);
      }
    }
    final railBase = inkStroke(6, color: const Color(0xFF4F4466));
    final railTie = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2;
    for (final line in Jq.railLines) {
      for (var k = 0; k + 1 < line.length; k++) {
        final a = center(line[k]);
        final b = center(line[k + 1]);
        canvas.drawLine(a, b, railBase);
        final len = (b - a).distance;
        final dir = (b - a) / len;
        for (var d = 6.0; d < len; d += 12) {
          final p = a + dir * d;
          final q = a + dir * math.min(d + 5, len);
          canvas.drawLine(p, q, railTie);
        }
      }
    }

    // Posts, camps and headquarters.
    for (var i = 0; i < Jq.cells; i++) {
      final c = center(i);
      if (Jq.isCamp(i)) {
        canvas.drawCircle(
            c, ch * 0.5, Paint()..color = const Color(0xFFFFF4DC));
        canvas.drawCircle(
            c, ch * 0.5, inkStroke(2.2, color: const Color(0xFFB07A4F)));
      } else if (Jq.isHq(i)) {
        final r = RRect.fromRectAndCorners(
          Rect.fromCenter(center: c, width: cw * 0.9, height: ch * 0.95),
          topLeft: Radius.circular(ch * 0.45),
          topRight: Radius.circular(ch * 0.45),
          bottomLeft: Radius.circular(ch * 0.15),
          bottomRight: Radius.circular(ch * 0.15),
        );
        canvas.drawRRect(r, Paint()..color = const Color(0xFFFFE9A8));
        canvas.drawRRect(r, inkStroke(2.2, color: const Color(0xFFB07A4F)));
      } else {
        final r = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: cw * 0.8, height: ch * 0.78),
            Radius.circular(ch * 0.2));
        canvas.drawRRect(r, Paint()..color = Colors.white.withOpacity(0.8));
        canvas.drawRRect(r, inkStroke(1.6, color: const Color(0xFFB9A57E)));
      }
    }
  }

  @override
  bool shouldRepaint(_JunqiBoardPainter old) =>
      old.cw != cw || old.ch != ch || old.flipped != flipped;
}
