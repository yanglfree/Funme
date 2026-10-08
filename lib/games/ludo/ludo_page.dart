import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/art/game_icons.dart';
import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/duel.dart';
import '../../core/game/party.dart';
import '../../core/layout/side_panel_scope.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/flash_banner.dart';
import '../../core/widgets/party_frame.dart';
import '../../core/widgets/particles.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/setup_sheet.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'ludo_rules.dart';

const _posCandies = [Candy.cherry, Candy.sun, Candy.ocean, Candy.mint];
const _posNames = ['红色', '黄色', '蓝色', '绿色'];

int _legMs(LudoStepKind kind) => switch (kind) {
      LudoStepKind.step => 170,
      LudoStepKind.takeoff => 420,
      LudoStepKind.jump => 330,
      LudoStepKind.fly => 720,
      LudoStepKind.home => 300,
    };

class LudoController extends PartyController<LudoState, LudoAction> {
  final flash = FlashController();
  final _random = math.Random();

  /// Fires when a plane is captured: (board x, board y) in cells.
  final ValueNotifier<(double, double)?> crashAt = ValueNotifier(null);

  @override
  LudoState initialState(PartySetup setup) => LudoState.initial(
        setup.seats.length,
        planes: int.tryParse(setup.extra['planes'] ?? '') ?? 4,
        takeoff: setup.extra['takeoff'] == '56' ? const {5, 6} : const {6},
      );

  @override
  int seatToMove(LudoState state) => state.turn;

  @override
  LudoState apply(LudoState state, LudoAction move) => state.apply(move);

  @override
  PartyOutcome? judge(LudoState state) {
    final w = state.winner;
    return w == null ? null : PartyOutcome(w, '所有飞机都安全到家');
  }

  @override
  LudoAction? forcedMove(LudoState state) {
    if (state.dice == null) return null;
    final movable = state.movablePlanes();
    if (movable.isEmpty) return const LudoAction.pass();
    if (movable.length == 1) return LudoAction.move(movable.first);
    // Several planes still in the yard and none out: take off the first.
    final planes = state.planes[state.turn];
    if (movable.every((k) => planes[k] == Ludo.yard)) {
      return LudoAction.move(movable.first);
    }
    return null;
  }

  @override
  Future<LudoAction?> aiMove(LudoState state, AiLevel level) async {
    if (state.dice == null) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return LudoAction.roll(1 + _random.nextInt(6));
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final k = LudoAi.choose(state, level.index, random: _random);
    return k == null ? const LudoAction.pass() : LudoAction.move(k);
  }

  void humanRoll() {
    if (!canHumanAct || state.dice != null) return;
    play(LudoAction.roll(1 + _random.nextInt(6)));
  }

  void humanMove(int plane) {
    if (!canHumanAct || !state.movablePlanes().contains(plane)) return;
    play(LudoAction.move(plane));
  }

  @override
  Duration settleTime(LudoState state) {
    if (state.dice != null) return const Duration(milliseconds: 820);
    final route = state.last?.route ?? const [];
    final ms = route.fold<int>(0, (sum, leg) => sum + _legMs(leg.kind));
    return Duration(milliseconds: ms + 380);
  }

  @override
  void onMovePlayed(LudoState before, LudoAction move, LudoState after) {
    if (move.isRoll) {
      Fx.play(Sfx.dice, buzz: Buzz.light);
      return;
    }
    if (move.isPass) {
      Timer(const Duration(milliseconds: 650), () {
        Fx.play(Sfx.error, volume: 0.6);
        flash.show('没有能走的飞机', candy: Candy.slate);
      });
      return;
    }
    final info = after.last!;
    var t = 0;
    for (final leg in info.route) {
      final at = t;
      Timer(Duration(milliseconds: at), () {
        switch (leg.kind) {
          case LudoStepKind.step:
            Fx.play(Sfx.hop, volume: 0.8);
          case LudoStepKind.takeoff:
            Fx.play(Sfx.fly, buzz: Buzz.light);
            flash.show('起飞！', candy: Candy.ocean);
          case LudoStepKind.jump:
            Fx.play(Sfx.select, buzz: Buzz.light);
            flash.show('跳！', candy: Candy.sun);
          case LudoStepKind.fly:
            Fx.play(Sfx.fly, buzz: Buzz.medium);
            flash.show('飞越！', candy: Candy.grape);
          case LudoStepKind.home:
            Fx.play(Sfx.star, buzz: Buzz.medium);
            flash.show('到家啦！', candy: Candy.mint);
        }
      });
      t += _legMs(leg.kind);
    }
    if (info.captured.isNotEmpty) {
      final last = info.route.last;
      Timer(Duration(milliseconds: t), () {
        Fx.play(Sfx.crash, buzz: Buzz.heavy);
        flash.show('撞机！', candy: Candy.cherry);
        crashAt.value = (last.x, last.y);
      });
    }
  }

  @override
  void dispose() {
    flash.dispose();
    crashAt.dispose();
    super.dispose();
  }
}

class LudoPage extends StatefulWidget {
  const LudoPage({super.key});

  static Widget create(BuildContext context) => const LudoPage();

  @override
  State<LudoPage> createState() => _LudoPageState();
}

class _LudoPageState extends State<LudoPage> {
  final _controller = LudoController();
  final _particles = ParticleController();

  @override
  void dispose() {
    _controller.dispose();
    _particles.dispose();
    super.dispose();
  }

  List<PartySeat> _seats() => [
        for (final pos in _controller.state.positions)
          PartySeat(
              _posNames[pos], _posCandies[pos], _PlaneToken(_posCandies[pos])),
      ];

  @override
  Widget build(BuildContext context) {
    return PartyGameFrame<LudoState, LudoAction>(
      info: GameCatalog.ludo,
      controller: _controller,
      scenery: Scenery.sky,
      particles: _particles,
      seats: _seats,
      setupGroups: [
        ...partySetupGroups(playerCounts: const [2, 3, 4], maxHumans: 4),
        const SetupGroup(
          key: 'planes',
          title: '每人几架飞机',
          choices: [
            SetupChoice('2', '2 架（快速）', candy: Candy.mint),
            SetupChoice('4', '4 架（标准）', candy: Candy.orange),
          ],
        ),
        const SetupGroup(
          key: 'takeoff',
          title: '起飞规则',
          choices: [
            SetupChoice('56', '掷 5 或 6 起飞', candy: Candy.sun),
            SetupChoice('6', '只有 6 起飞', candy: Candy.grape),
          ],
        ),
      ],
      toSetup: (values) => PartySetup.fromMap(values),
      board: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: AspectRatio(
          aspectRatio: 1,
          child: _LudoBoard(controller: _controller, particles: _particles),
        ),
      ),
      footer: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _DiceBar(controller: _controller),
      ),
    );
  }
}

class _PlaneToken extends StatelessWidget {
  const _PlaneToken(this.candy);

  final Candy candy;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PlaneTokenPainter(candy));
}

class _PlaneTokenPainter extends CustomPainter {
  _PlaneTokenPainter(this.candy);

  final Candy candy;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 4);
    GameIcons.paintPlane(canvas, size.width * 0.9, candy);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlaneTokenPainter oldDelegate) =>
      oldDelegate.candy != candy;
}

class _DiceBar extends StatelessWidget {
  const _DiceBar({required this.controller});

  final LudoController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final seatPos = s.positions[s.turn];
    final human = controller.started &&
        !controller.isAi(s.turn) &&
        controller.outcome == null;
    final canRoll = controller.canHumanAct && s.dice == null;
    final String prompt;
    if (!controller.started || controller.outcome != null) {
      prompt = '';
    } else if (!human) {
      prompt = s.dice == null
          ? '${_posNames[seatPos]}电脑掷骰子…'
          : '${_posNames[seatPos]}电脑在想…';
    } else if (s.dice == null) {
      prompt = '点一下骰子！';
    } else if (s.movablePlanes().isEmpty) {
      prompt = s.takeoff.contains(5) ? '要掷到 5 或 6 才能起飞哦' : '要掷到 6 才能起飞哦';
    } else {
      prompt = '点一架发光的飞机';
    }
    final stacked = SidePanelScope.of(context);
    final promptText = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Text(
        prompt,
        key: ValueKey(prompt),
        style: FunText.title(size: 18, color: Palette.ink),
        textAlign: stacked ? TextAlign.center : TextAlign.right,
      ),
    );
    final dice = _Dice(
      value: s.lastRoll ?? 6,
      rolling: s.dice != null,
      rollKey: controller.state,
      candy: _posCandies[seatPos],
      enabled: canRoll,
      onTap: controller.humanRoll,
    );
    if (stacked) {
      return Column(
        children: [
          dice,
          const SizedBox(height: 10),
          SizedBox(height: 48, child: Center(child: promptText)),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: promptText),
        const SizedBox(width: 14),
        dice,
      ],
    );
  }
}

class _Dice extends StatefulWidget {
  const _Dice({
    required this.value,
    required this.rolling,
    required this.rollKey,
    required this.candy,
    required this.enabled,
    required this.onTap,
  });

  final int value;
  final bool rolling;
  final Object rollKey;
  final Candy candy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_Dice> createState() => _DiceState();
}

class _DiceState extends State<_Dice> with TickerProviderStateMixin {
  late final AnimationController _tumble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  late final AnimationController _invite = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  final _random = math.Random();

  @override
  void didUpdateWidget(_Dice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling && !oldWidget.rolling) _tumble.forward(from: 0);
  }

  @override
  void dispose() {
    _tumble.dispose();
    _invite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: widget.enabled,
      sound: false,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_tumble, _invite]),
        builder: (context, _) {
          final t = _tumble.value;
          final tumbling = _tumble.isAnimating;
          final face =
              tumbling && t < 0.85 ? 1 + _random.nextInt(6) : widget.value;
          final bounce = tumbling
              ? -math.sin(t * math.pi) * 26
              : (widget.enabled ? -_invite.value * 6 : 0.0);
          final angle = tumbling ? (1 - t) * math.pi * 3 : 0.0;
          return Transform.translate(
            offset: Offset(0, bounce),
            child: Transform.rotate(
              angle: angle,
              child: CustomPaint(
                size: const Size.square(66),
                painter: _DicePainter(face, widget.candy, glow: widget.enabled),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DicePainter extends CustomPainter {
  _DicePainter(this.value, this.candy, {required this.glow});

  final int value;
  final Candy candy;
  final bool glow;

  static const _pips = {
    1: [(0.5, 0.5)],
    2: [(0.28, 0.28), (0.72, 0.72)],
    3: [(0.28, 0.28), (0.5, 0.5), (0.72, 0.72)],
    4: [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)],
    5: [(0.28, 0.28), (0.72, 0.28), (0.5, 0.5), (0.28, 0.72), (0.72, 0.72)],
    6: [
      (0.28, 0.25),
      (0.72, 0.25),
      (0.28, 0.5),
      (0.72, 0.5),
      (0.28, 0.75),
      (0.72, 0.75)
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final body = RRect.fromRectAndRadius(
        rect.deflate(3), Radius.circular(size.width * 0.22));
    if (glow) {
      canvas.drawRRect(
          body.inflate(6), Paint()..color = candy.face.withOpacity(0.45));
    }
    canvas.drawRRect(
        body.shift(const Offset(0, 5)), Paint()..color = candy.shade);
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.drawRRect(body, inkStroke(3));
    for (final (x, y) in _pips[value]!) {
      final c = Offset(size.width * x, size.height * y);
      canvas.drawCircle(
          c,
          size.width * 0.085,
          Paint()
            ..color =
                value == 1 || value == 4 ? Candy.cherry.face : Palette.ink);
    }
  }

  @override
  bool shouldRepaint(_DicePainter old) =>
      old.value != value || old.candy != candy || old.glow != glow;
}

class _LudoBoard extends StatefulWidget {
  const _LudoBoard({required this.controller, required this.particles});

  final LudoController controller;
  final ParticleController particles;

  @override
  State<_LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends State<_LudoBoard> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);
  LudoMoveInfo? _animating;
  double _cell = 0;

  LudoController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onState);
    _c.crashAt.addListener(_onCrash);
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _c.crashAt.removeListener(_onCrash);
    _move.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onState() {
    final last = _c.state.last;
    if (last != null && !identical(last, _animating)) {
      _animating = last;
      final ms = last.route.fold<int>(0, (sum, leg) => sum + _legMs(leg.kind));
      _move.duration = Duration(milliseconds: math.max(ms, 1));
      _move.forward(from: 0);
    }
    if (last == null) _animating = null;
    setState(() {});
  }

  void _onCrash() {
    final at = _c.crashAt.value;
    if (at == null || _cell == 0) return;
    widget.particles.burstFrom(
      context,
      Offset((at.$1 + 0.5) * _cell, (at.$2 + 0.5) * _cell),
      count: 28,
      speed: 320,
      shape: ParticleShape.dot,
      colors: const [
        Color(0xFFFF8C42),
        Color(0xFFFFC83D),
        Color(0xFFFFFFFF),
        Color(0xFF8C9BB5)
      ],
    );
  }

  Offset _restPos(int seat, int plane, int progress) {
    final pos = _c.state.positions[seat];
    if (progress == Ludo.yard) {
      final (yx, yy) = Ludo.yards[pos];
      const slots = [(1.75, 1.75), (4.25, 1.75), (1.75, 4.25), (4.25, 4.25)];
      final (sx, sy) = slots[plane % 4];
      return Offset((yx + sx) * _cell, (yy + sy) * _cell);
    }
    if (progress == Ludo.goal) {
      const dirs = [(0.0, 0.55), (-0.55, 0.0), (0.0, -0.55), (0.55, 0.0)];
      final (dx, dy) = dirs[pos];
      final spread = (plane - 1.5) * 0.18;
      return Offset((7.5 + dx + (dy != 0 ? spread : 0)) * _cell,
          (7.5 + dy + (dx != 0 ? spread : 0)) * _cell);
    }
    final (x, y) = Ludo.cell(pos, progress);
    return Offset((x + 0.5) * _cell, (y + 0.5) * _cell);
  }

  double _heading(int seat, int progress) {
    final pos = _c.state.positions[seat];
    if (progress < 0) return -math.pi / 4 + pos * math.pi / 2;
    if (progress >= Ludo.goal) return 0;
    final (ax, ay) = Ludo.cell(pos, progress);
    final (bx, by) =
        progress + 1 >= Ludo.goal ? (7, 7) : Ludo.cell(pos, progress + 1);
    return math.atan2((by - ay).toDouble(), (bx - ax).toDouble()) + math.pi / 2;
  }

  void _tap(Offset p) {
    if (!_c.canHumanAct) return;
    final s = _c.state;
    if (s.dice == null) {
      _c.humanRoll();
      return;
    }
    final movable = s.movablePlanes();
    int? best;
    var bestD = double.infinity;
    for (final k in movable) {
      final d = (_restPos(s.turn, k, s.planes[s.turn][k]) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    }
    if (best != null && bestD < _cell * 1.4) {
      _c.humanMove(best);
    } else {
      Fx.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cell = constraints.maxWidth / 15;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(d.localPosition),
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                      painter: _LudoBoardPainter(_c.state.positions)),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _PlanesPainter(
                    state: _c.state,
                    cell: _cell,
                    restPos: _restPos,
                    heading: _heading,
                    moving: _animating,
                    move: _move,
                    pulse: _pulse,
                    highlight: _c.canHumanAct && _c.state.dice != null,
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

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter(this.active);

  final List<int> active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 15;
    Rect cellRect(int x, int y) => Rect.fromLTWH(x * c, y * c, c, c);
    final board =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(c * 0.8));
    canvas.drawRRect(
        board.shift(Offset(0, c * 0.2)), Paint()..color = Palette.ink);
    canvas.drawRRect(board, Paint()..color = const Color(0xFFFFFBF2));
    canvas.drawRRect(board, inkStroke(3));

    // Yards.
    for (var pos = 0; pos < 4; pos++) {
      final (yx, yy) = Ludo.yards[pos];
      final candy = _posCandies[pos];
      final on = active.contains(pos);
      final outer = RRect.fromRectAndRadius(
          Rect.fromLTWH(yx * c, yy * c, 6 * c, 6 * c).deflate(c * 0.2),
          Radius.circular(c * 0.9));
      canvas.drawRRect(
          outer, Paint()..color = on ? candy.face : const Color(0xFFE5DED0));
      canvas.drawRRect(outer, inkStroke(2.5));
      final inner = RRect.fromRectAndRadius(
          Rect.fromLTWH(yx * c, yy * c, 6 * c, 6 * c).deflate(c * 0.75),
          Radius.circular(c * 0.6));
      canvas.drawRRect(inner, Paint()..color = Colors.white.withOpacity(0.92));
      for (final (sx, sy) in const [
        (1.75, 1.75),
        (4.25, 1.75),
        (1.75, 4.25),
        (4.25, 4.25)
      ]) {
        final center = Offset((yx + sx) * c, (yy + sy) * c);
        canvas.drawCircle(center, c * 0.72,
            Paint()..color = on ? candy.light : const Color(0xFFF1ECE2));
        canvas.drawCircle(center, c * 0.72,
            inkStroke(2, color: on ? candy.shade : const Color(0xFFD5CCBA)));
      }
    }

    // Track.
    for (var i = 0; i < Ludo.track.length; i++) {
      final (x, y) = Ludo.track[i];
      final candy = _posCandies[Ludo.trackColor(i)];
      final r = RRect.fromRectAndRadius(
          cellRect(x, y).deflate(c * 0.06), Radius.circular(c * 0.22));
      canvas.drawRRect(r, Paint()..color = candy.face);
      canvas.drawRRect(r, inkStroke(1.6));
      canvas.drawCircle(cellRect(x, y).center, c * 0.14,
          Paint()..color = Colors.white.withOpacity(0.55));
    }

    // Lanes and the home center.
    for (var pos = 0; pos < 4; pos++) {
      final candy = _posCandies[pos];
      for (final (x, y) in Ludo.lanes[pos]) {
        final r = RRect.fromRectAndRadius(
            cellRect(x, y).deflate(c * 0.06), Radius.circular(c * 0.22));
        canvas.drawRRect(r, Paint()..color = candy.light);
        canvas.drawRRect(r, inkStroke(1.6, color: candy.shade));
      }
    }
    final center = Offset(7.5 * c, 7.5 * c);
    final corners = [
      Offset(6 * c, 9 * c),
      Offset(6 * c, 6 * c),
      Offset(9 * c, 6 * c),
      Offset(9 * c, 9 * c)
    ];
    for (var pos = 0; pos < 4; pos++) {
      final a = corners[pos];
      final b = corners[(pos + 3) % 4];
      final tri = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(center.dx, center.dy)
        ..close();
      canvas.drawPath(tri, Paint()..color = _posCandies[pos].face);
      canvas.drawPath(tri, inkStroke(2));
    }
    paintStar(canvas, center, c * 0.55, outlineWidth: 2);

    // Start arrows and fly routes.
    for (var pos = 0; pos < 4; pos++) {
      final (sx, sy) = Ludo.cell(pos, 0);
      final (nx, ny) = Ludo.cell(pos, 1);
      final from = cellRect(sx, sy).center;
      final dir = Offset((nx - sx).toDouble(), (ny - sy).toDouble());
      final tip = from + dir * c * 0.28;
      final back = from - dir * c * 0.22;
      final side = Offset(-dir.dy, dir.dx) * c * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(back.dx + side.dx, back.dy + side.dy)
          ..lineTo(back.dx - side.dx, back.dy - side.dy)
          ..close(),
        Paint()..color = Colors.white,
      );
      final (fx, fy) = Ludo.cell(pos, Ludo.flyFrom);
      final (tx, ty) = Ludo.cell(pos, Ludo.flyTo);
      final a = cellRect(fx, fy).center;
      final b = cellRect(tx, ty).center;
      final mid =
          Offset.lerp(a, b, 0.5)! + (center - Offset.lerp(a, b, 0.5)!) * 0.35;
      final route = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      final dash = inkStroke(2.4, color: _posCandies[pos].shade);
      for (final metric in route.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 12) {
          canvas.drawPath(
              metric.extractPath(d, math.min(d + 6, metric.length)), dash);
        }
      }
      canvas.save();
      canvas.translate(a.dx, a.dy);
      canvas.rotate(math.atan2(b.dy - a.dy, b.dx - a.dx) + math.pi / 2);
      GameIcons.paintPlane(canvas, c * 0.6, Candy.cream, outline: 0.08);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LudoBoardPainter old) =>
      old.active.join() != active.join();
}

class _PlanesPainter extends CustomPainter {
  _PlanesPainter({
    required this.state,
    required this.cell,
    required this.restPos,
    required this.heading,
    required this.moving,
    required this.move,
    required this.pulse,
    required this.highlight,
  }) : super(repaint: Listenable.merge([move, pulse]));

  final LudoState state;
  final double cell;
  final Offset Function(int seat, int plane, int progress) restPos;
  final double Function(int seat, int progress) heading;
  final LudoMoveInfo? moving;
  final AnimationController move;
  final Animation<double> pulse;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final m = moving;
    final animating = m != null && move.value < 1;
    final movable = highlight ? state.movablePlanes().toSet() : const <int>{};
    final elapsed = animating
        ? move.value * (move.duration?.inMilliseconds ?? 1)
        : double.infinity;
    final captureTime = m == null
        ? 0
        : m.route.fold<int>(0, (sum, leg) => sum + _legMs(leg.kind));

    // Count planes per spot to fan out stacks.
    final spots = <String, int>{};
    for (var seat = 0; seat < state.planes.length; seat++) {
      for (var k = 0; k < state.planes[seat].length; k++) {
        final p = state.planes[seat][k];
        if (animating && seat == m.seat && k == m.plane) continue;
        Offset at = restPos(seat, k, p);
        var angle = heading(seat, p);
        // Captured planes stay on the board until the attacker lands.
        if (animating && elapsed < captureTime) {
          for (final (cs, ck, cp) in m.captured) {
            if (cs == seat && ck == k) {
              at = restPos(seat, k, cp);
              angle = heading(seat, cp);
            }
          }
        }
        final key = '${(at.dx / 4).round()},${(at.dy / 4).round()}';
        final n = spots.update(key, (v) => v + 1, ifAbsent: () => 0);
        final offset = Offset(n * cell * 0.16, -n * cell * 0.16);
        if (seat == state.turn && movable.contains(k)) {
          final r = cell * (0.62 + 0.12 * pulse.value);
          canvas.drawCircle(
              at + offset, r, Paint()..color = Colors.white.withOpacity(0.85));
          canvas.drawCircle(at + offset, r,
              inkStroke(3, color: _posCandies[state.positions[seat]].shade));
        }
        _plane(canvas, at + offset, angle, _posCandies[state.positions[seat]],
            1.0);
      }
    }

    if (animating) {
      final pos = state.positions[m.seat];
      var t = elapsed;
      var from = restPos(m.seat, m.plane, m.fromProgress);
      for (final leg in m.route) {
        final ms = _legMs(leg.kind).toDouble();
        final to = Offset((leg.x + 0.5) * cell, (leg.y + 0.5) * cell);
        if (t <= ms) {
          final f = Curves.easeInOut.transform((t / ms).clamp(0.0, 1.0));
          final p = Offset.lerp(from, to, f)!;
          final lift = switch (leg.kind) {
            LudoStepKind.fly => 1.8,
            LudoStepKind.jump || LudoStepKind.takeoff => 0.9,
            _ => 0.35,
          };
          final h = math.sin(f * math.pi) * cell * lift;
          final angle =
              math.atan2(to.dy - from.dy, to.dx - from.dx) + math.pi / 2;
          canvas.drawOval(
              Rect.fromCenter(center: p, width: cell * 0.7, height: cell * 0.3),
              Paint()..color = Colors.black.withOpacity(0.18));
          _plane(canvas, p - Offset(0, h), angle, _posCandies[pos],
              1 + h / cell * 0.25);
          return;
        }
        t -= ms;
        from = to;
      }
    }
  }

  void _plane(
      Canvas canvas, Offset at, double angle, Candy candy, double scale) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    GameIcons.paintPlane(canvas, cell * 0.92, candy);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanesPainter old) => true;
}
