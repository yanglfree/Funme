import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/duel.dart';
import '../../core/game/party.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/party_frame.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'checkers_rules.dart';

const _campCandies = [
  Candy.cherry,
  Candy.sun,
  Candy.mint,
  Candy.ocean,
  Candy.grape,
  Candy.orange
];
const _campNames = ['红色', '黄色', '绿色', '蓝色', '紫色', '橙色'];
const _hopMs = 190;

class CheckersController extends PartyController<CcState, CcMove> {
  @override
  CcState initialState(PartySetup setup) => CcState.initial(setup.seats.length);

  @override
  int seatToMove(CcState state) => state.turn;

  @override
  CcState apply(CcState state, CcMove move) => state.play(move);

  @override
  PartyOutcome? judge(CcState state) {
    final w = state.winner;
    if (w == null) return null;
    return PartyOutcome(w, state.finished(w) ? '弹珠全部跳进了对面的营地' : '走得最远');
  }

  @override
  Future<CcMove?> aiMove(CcState s, AiLevel level) async {
    final path =
        await compute(checkersAiEntry, (s.cells, s.camps, s.turn, level.index));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return path.isEmpty ? null : CcMove(path);
  }

  @override
  Duration settleTime(CcState state) {
    final hops = (state.last?.path.length ?? 2) - 1;
    return Duration(milliseconds: hops * _hopMs + 260);
  }

  @override
  void onMovePlayed(CcState before, CcMove move, CcState after) {
    final hops = move.path.length - 1;
    for (var k = 0; k < hops; k++) {
      Future<void>.delayed(Duration(milliseconds: k * _hopMs), () {
        Fx.play(move.isJump ? Sfx.hop : Sfx.place, buzz: Buzz.tap, volume: 0.9);
      });
    }
  }
}

class CheckersPage extends StatefulWidget {
  const CheckersPage({super.key});

  static Widget create(BuildContext context) => const CheckersPage();

  @override
  State<CheckersPage> createState() => _CheckersPageState();
}

class _CheckersPageState extends State<CheckersPage> {
  final _controller = CheckersController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<PartySeat> _seats() {
    final camps = _controller.state.camps;
    return [
      for (final camp in camps)
        PartySeat(
            _campNames[camp], _campCandies[camp], _Marble(_campCandies[camp])),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PartyGameFrame<CcState, CcMove>(
      info: GameCatalog.checkers,
      controller: _controller,
      scenery: Scenery.grape,
      seats: _seats,
      setupGroups: [
        ...partySetupGroups(playerCounts: const [2, 3, 4, 6], maxHumans: 4),
      ],
      toSetup: (values) => PartySetup.fromMap(values),
      board: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 660),
        child: AspectRatio(
          aspectRatio: 13.6 / 15.2,
          child: _CheckersBoard(controller: _controller),
        ),
      ),
    );
  }
}

class _Marble extends StatelessWidget {
  const _Marble(this.candy);

  final Candy candy;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MarblePainter(candy));
}

class _MarblePainter extends CustomPainter {
  _MarblePainter(this.candy);

  final Candy candy;

  @override
  void paint(Canvas canvas, Size size) {
    paintMarble(
        canvas, size.center(Offset.zero), size.shortestSide * 0.42, candy);
  }

  @override
  bool shouldRepaint(_MarblePainter oldDelegate) => oldDelegate.candy != candy;
}

void paintMarble(Canvas canvas, Offset c, double r, Candy candy,
    {double lift = 0}) {
  canvas.drawCircle(c + Offset(0, r * (0.2 + lift)), r * (1 - lift * 0.2),
      Paint()..color = Colors.black.withOpacity(0.22));
  final center = c - Offset(0, r * lift);
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: [candy.light, candy.face, candy.shade],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: center, radius: r)),
  );
  canvas.drawCircle(center + Offset(-r * 0.32, -r * 0.36), r * 0.22,
      Paint()..color = Colors.white.withOpacity(0.8));
  canvas.drawCircle(center, r, inkStroke(r * 0.14));
}

class _CheckersBoard extends StatefulWidget {
  const _CheckersBoard({required this.controller});

  final CheckersController controller;

  @override
  State<_CheckersBoard> createState() => _CheckersBoardState();
}

class _CheckersBoardState extends State<_CheckersBoard>
    with TickerProviderStateMixin {
  int? _selected;
  Map<int, CcMove> _targets = const {};
  CcMove? _animating;
  late final AnimationController _hop = AnimationController(vsync: this);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  double _unit = 0;
  Offset _origin = Offset.zero;

  CheckersController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onState);
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _hop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onState() {
    final last = _c.state.last;
    if (last != null && !identical(last, _animating)) {
      _animating = last;
      _hop.duration = Duration(milliseconds: (last.path.length - 1) * _hopMs);
      _hop.forward(from: 0);
    }
    if (last == null) _animating = null;
    if (!_c.canHumanAct) {
      _selected = null;
      _targets = const {};
    }
    setState(() {});
  }

  Offset _pos(int i) {
    final (q, r) = Cc.cells[i];
    return _origin + Offset((q + r / 2) * _unit, r * math.sqrt(3) / 2 * _unit);
  }

  int? _hit(Offset p) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < Cc.cells.length; i++) {
      final d = (_pos(i) - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return bestD < _unit * _unit * 0.36 ? best : null;
  }

  void _tap(Offset p) {
    if (!_c.canHumanAct) return;
    final i = _hit(p);
    if (i == null) return;
    final s = _c.state;
    final move = _targets[i];
    if (move != null) {
      setState(() {
        _selected = null;
        _targets = const {};
      });
      _c.play(move);
      return;
    }
    if (s.cells[i] == s.turn) {
      final moves = s.movesFrom(i);
      Fx.play(moves.isEmpty ? Sfx.error : Sfx.select, buzz: Buzz.tap);
      setState(() {
        _selected = i;
        // Prefer the shortest path to each destination.
        final map = <int, CcMove>{};
        for (final m in moves) {
          final old = map[m.to];
          if (old == null || m.path.length < old.path.length) map[m.to] = m;
        }
        _targets = map;
      });
      return;
    }
    setState(() {
      _selected = null;
      _targets = const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _unit = constraints.maxWidth / 13.6;
        _origin = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(d.localPosition),
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _CheckersPainter(
              state: _c.state,
              pos: _pos,
              unit: _unit,
              selected: _selected,
              targets: _targets.keys.toSet(),
              moving: _animating,
              hop: _hop,
              pulse: _pulse,
            ),
          ),
        );
      },
    );
  }
}

class _CheckersPainter extends CustomPainter {
  _CheckersPainter({
    required this.state,
    required this.pos,
    required this.unit,
    required this.selected,
    required this.targets,
    required this.moving,
    required this.hop,
    required this.pulse,
  }) : super(repaint: Listenable.merge([hop, pulse]));

  final CcState state;
  final Offset Function(int) pos;
  final double unit;
  final int? selected;
  final Set<int> targets;
  final CcMove? moving;
  final Animation<double> hop;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final plate = _roundedHexagon(center, unit * 7.55, unit * 1.1);
    canvas.drawPath(
        plate.shift(const Offset(0, 8)), Paint()..color = Palette.ink);
    canvas.drawPath(
      plate,
      Paint()
        ..shader = const RadialGradient(
                colors: [Color(0xFFFFFDF7), Color(0xFFF3E7D3)])
            .createShader(Rect.fromCircle(center: center, radius: unit * 7.5)),
    );
    canvas.drawPath(plate, inkStroke(3));

    // Camp triangles tinted with the color of the seat that lives there.
    final active = {
      for (var seat = 0; seat < state.camps.length; seat++) state.camps[seat]
    };
    for (var camp = 0; camp < 6; camp++) {
      final tint = active.contains(camp)
          ? _campCandies[camp].light
          : const Color(0xFFEDE4D3);
      final cells = Cc.campCells[camp];
      final pts = cells.map(pos).toList();
      final hull = _triangleHull(pts, center);
      canvas.drawPath(hull, Paint()..color = tint);
      canvas.drawPath(hull, inkStroke(2, color: Palette.ink.withOpacity(0.25)));
    }

    // Holes.
    final hole = Paint()..color = const Color(0xFFD8CBB3);
    for (var i = 0; i < Cc.cells.length; i++) {
      canvas.drawCircle(pos(i), unit * 0.2, hole);
    }

    // Move targets.
    for (final t in targets) {
      final r = unit * (0.28 + 0.06 * pulse.value);
      canvas.drawCircle(pos(t), r, Paint()..color = Candy.mint.face);
      canvas.drawCircle(pos(t), r, inkStroke(2));
    }

    final m = moving;
    final movingTo =
        hop.isAnimating || (hop.value < 1 && m != null) ? m?.to : null;
    final r = unit * 0.4;
    for (var i = 0; i < state.cells.length; i++) {
      final seat = state.cells[i];
      if (seat < 0 || i == movingTo) continue;
      final lift = i == selected ? 0.35 : 0.0;
      paintMarble(canvas, pos(i), r, _campCandies[state.camps[seat]],
          lift: lift);
      if (i == selected) {
        canvas.drawCircle(pos(i) - Offset(0, r * 0.35), r * 1.25,
            inkStroke(3, color: Colors.white));
      }
    }
    if (m != null && movingTo != null) {
      final segments = m.path.length - 1;
      final t = hop.value * segments;
      final k = math.min(t.floor(), segments - 1);
      final f = t - k;
      final a = pos(m.path[k]);
      final b = pos(m.path[k + 1]);
      final p = Offset.lerp(a, b, Curves.easeInOut.transform(f))!;
      final arc = math.sin(f * math.pi) * unit * (m.isJump ? 0.9 : 0.35);
      final seat = state.cells[m.to];
      paintMarble(canvas, p, r, _campCandies[state.camps[seat < 0 ? 0 : seat]],
          lift: arc / r * 0.35);
    }
    final last = state.last;
    if (last != null && !hop.isAnimating) {
      canvas.drawCircle(
          pos(last.from), unit * 0.2, inkStroke(2.5, color: Candy.sun.shade));
    }
  }

  /// Pointy-top hexagon whose corners sit just outside the star's tips.
  Path _roundedHexagon(Offset c, double radius, double corner) {
    final pts = [
      for (var k = 0; k < 6; k++)
        c +
            Offset(math.cos(-math.pi / 2 + k * math.pi / 3),
                    math.sin(-math.pi / 2 + k * math.pi / 3)) *
                radius,
    ];
    final path = Path();
    for (var k = 0; k < 6; k++) {
      final prev = pts[(k + 5) % 6];
      final cur = pts[k];
      final next = pts[(k + 1) % 6];
      final a = cur + (prev - cur) / (prev - cur).distance * corner;
      final b = cur + (next - cur) / (next - cur).distance * corner;
      if (k == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return path..close();
  }

  /// Triangle around a camp's ten holes, slightly inflated.
  Path _triangleHull(List<Offset> pts, Offset center) {
    // The three farthest-apart holes are the triangle's corners.
    Offset far(Offset from) => pts.reduce((a, b) =>
        (a - from).distanceSquared > (b - from).distanceSquared ? a : b);
    final apex = far(center);
    final c1 = far(apex);
    final c2 = pts.reduce((a, b) {
      double score(Offset p) => (p - apex).distance + (p - c1).distance;
      return score(a) > score(b) ? a : b;
    });
    final centroid = (apex + c1 + c2) / 3;
    Offset grow(Offset p) =>
        centroid +
        (p - centroid) * 1.0 +
        (p - centroid) / (p - centroid).distance * unit * 0.55;
    return Path()
      ..moveTo(grow(apex).dx, grow(apex).dy)
      ..lineTo(grow(c1).dx, grow(c1).dy)
      ..lineTo(grow(c2).dx, grow(c2).dy)
      ..close();
  }

  @override
  bool shouldRepaint(_CheckersPainter old) =>
      old.state != state ||
      old.selected != selected ||
      old.targets.length != targets.length ||
      old.unit != unit;
}
