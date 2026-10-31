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

const _captureMs = 750;
const _homeFxMs = 900;

int _legMs(LudoStepKind kind) => switch (kind) {
      LudoStepKind.step => 170,
      LudoStepKind.takeoff => 700,
      LudoStepKind.jump => 430,
      LudoStepKind.fly => 1050,
      LudoStepKind.home => 560,
    };

/// Timing of one move: cumulative leg times plus the capture and arrival
/// tails that play after the route is finished.
class _Timeline {
  _Timeline(this.info) {
    var t = 0;
    for (final leg in info.route) {
      starts.add(t);
      t += _legMs(leg.kind);
      ends.add(t);
    }
    routeMs = t;
  }

  final LudoMoveInfo info;
  final starts = <int>[];
  final ends = <int>[];
  late final int routeMs;

  bool get endsHome =>
      info.route.isNotEmpty && info.route.last.kind == LudoStepKind.home;

  int get totalMs =>
      math.max(routeMs, 1) +
      (info.captured.isEmpty && info.recalled.isEmpty ? 0 : _captureMs) +
      (endsHome ? _homeFxMs : 0);
}

enum LudoFxKind { takeoff, land, fly, crash, home, bomb }

/// A one-shot particle cue at a board position (grid units). Instances are
/// compared by identity so repeated cues at the same spot still notify.
class LudoFx {
  LudoFx(this.kind, this.x, this.y, this.candy);

  final LudoFxKind kind;
  final double x;
  final double y;
  final Candy candy;
}

(double, double) _yardSlot(int position, int plane) {
  final (yx, yy) = Ludo.yards[position];
  final (sx, sy) = Ludo.yardSlots[plane % 4];
  return (yx + sx, yy + sy);
}

class LudoController extends PartyController<LudoState, LudoAction> {
  final flash = FlashController();
  final _random = math.Random();
  final ValueNotifier<LudoFx?> fx = ValueNotifier(null);

  @override
  LudoState initialState(PartySetup setup) => LudoState.initial(
        setup.seats.length,
        planes: int.tryParse(setup.extra['planes'] ?? '') ?? 4,
      );

  @override
  Map<String, dynamic>? saveSession() {
    if (!started || outcome != null) return null;
    return {
      'setup': {
        'players': '${setup.seats.length}',
        'humans': '${setup.humans}',
        'level': setup.level.name,
        ...setup.extra,
      },
      'ludoState': state.toJson(),
    };
  }

  @override
  bool restoreSession(Map<String, dynamic> data) {
    try {
      final setupRaw = data['setup'];
      if (setupRaw is! Map) return false;
      final setupMap = setupRaw.map((k, v) => MapEntry('$k', '$v'));
      final restoredSetup = PartySetup.fromMap(setupMap);
      final ludoRaw = data['ludoState'];
      if (ludoRaw is! Map) return false;
      final restoredState =
          LudoState.fromJson(ludoRaw.cast<String, dynamic>());
      restore(restoredSetup, restoredState);
      flash.show('已恢复上次游戏进度', candy: Candy.mint);
      return true;
    } catch (_) {
      return false;
    }
  }

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
    final last = state.last;
    if (last == null) return const Duration(milliseconds: 380);
    return Duration(milliseconds: _Timeline(last).totalMs + 380);
  }

  @override
  void onMovePlayed(LudoState before, LudoAction move, LudoState after) {
    if (move.isRoll) {
      Fx.play(Sfx.dice, buzz: Buzz.light);
      final penalty = after.last;
      if (after.dice == null &&
          penalty != null &&
          !identical(penalty, before.last)) {
        Timer(const Duration(milliseconds: 800), () {
          Fx.play(Sfx.crash, buzz: Buzz.heavy);
          flash.show('三连六！罚回机库', candy: Candy.cherry);
        });
      }
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
    final tl = _Timeline(info);
    final candy = _posCandies[after.positions[info.seat]];
    void at(int ms, VoidCallback fn) => Timer(Duration(milliseconds: ms), fn);

    var from = _yardSlot(after.positions[info.seat], info.plane);
    for (var i = 0; i < info.route.length; i++) {
      final leg = info.route[i];
      final origin = from;
      from = (leg.x, leg.y);
      at(tl.starts[i], () {
        switch (leg.kind) {
          case LudoStepKind.step:
            Fx.play(Sfx.hop, volume: 0.8);
          case LudoStepKind.takeoff:
            Fx.play(Sfx.fly, buzz: Buzz.light);
            flash.show('起飞！', candy: Candy.ocean);
            fx.value = LudoFx(LudoFxKind.takeoff, origin.$1, origin.$2, candy);
          case LudoStepKind.jump:
            Fx.play(Sfx.select, buzz: Buzz.light);
            flash.show('跳！', candy: Candy.sun);
          case LudoStepKind.fly:
            Fx.play(Sfx.fly, buzz: Buzz.medium);
            flash.show('飞越！', candy: Candy.grape);
          case LudoStepKind.home:
            Fx.play(Sfx.hop, volume: 0.8);
            flash.show('到家啦！', candy: Candy.mint);
        }
      });
      at(tl.ends[i], () {
        switch (leg.kind) {
          case LudoStepKind.jump:
            fx.value = LudoFx(LudoFxKind.land, leg.x, leg.y, candy);
          case LudoStepKind.fly:
            fx.value = LudoFx(LudoFxKind.fly, leg.x, leg.y, candy);
          case LudoStepKind.home:
            Fx.play(Sfx.star, buzz: Buzz.medium);
            fx.value = LudoFx(LudoFxKind.home, leg.x, leg.y, candy);
          case LudoStepKind.step || LudoStepKind.takeoff:
            break;
        }
      });
    }
    final flyLegIdx =
        info.route.indexWhere((leg) => leg.kind == LudoStepKind.fly);
    if (flyLegIdx >= 0 && info.bombSpots.isNotEmpty) {
      final midTime = tl.starts[flyLegIdx] + 520;
      for (final spot in info.bombSpots) {
        at(midTime, () {
          Fx.play(Sfx.crash, buzz: Buzz.heavy);
          flash.show('航线轰炸！把对手炸回家！', candy: Candy.cherry);
          fx.value = LudoFx(LudoFxKind.bomb, spot.$1, spot.$2, Candy.cherry);
        });
      }
    }
    for (final i in info.captureLegs.toSet()) {
      if (i == flyLegIdx && info.bombSpots.isNotEmpty) continue;
      final leg = info.route[i];
      at(tl.ends[i], () {
        Fx.play(Sfx.crash, buzz: Buzz.heavy);
        flash.show('撞机！', candy: Candy.cherry);
        fx.value = LudoFx(LudoFxKind.crash, leg.x, leg.y, Candy.cherry);
      });
    }
  }

  @override
  void dispose() {
    flash.dispose();
    fx.dispose();
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
      prompt = '要掷到 1、3、5 或 6 才能起飞哦';
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
  late final AnimationController _bombController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  LudoMoveInfo? _animating;
  _Timeline? _timeline;
  double _cell = 0;
  Offset? _bombSpot;

  LudoController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onState);
    _c.fx.addListener(_onFx);
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _c.fx.removeListener(_onFx);
    _move.dispose();
    _pulse.dispose();
    _bombController.dispose();
    super.dispose();
  }

  void _onState() {
    final last = _c.state.last;
    if (last != null && !identical(last, _animating)) {
      _animating = last;
      final tl = _Timeline(last);
      _timeline = tl;
      _move.duration = Duration(milliseconds: tl.totalMs);
      _move.forward(from: 0);
    }
    if (last == null) {
      _animating = null;
      _timeline = null;
    }
    setState(() {});
  }

  void _onFx() {
    final e = _c.fx.value;
    if (e == null || _cell == 0) return;
    final at = Offset(e.x * _cell, e.y * _cell);
    final p = widget.particles;
    switch (e.kind) {
      case LudoFxKind.takeoff:
        p.burstFrom(context, at,
            count: 12,
            speed: 150,
            size: 7,
            shape: ParticleShape.dot,
            colors: const [Colors.white, Color(0xFFE5F3FF), Color(0xFFBFE3FF)]);
      case LudoFxKind.land:
        p.burstFrom(context, at,
            count: 12,
            speed: 190,
            size: 7,
            shape: ParticleShape.dot,
            colors: [e.candy.face, e.candy.light, Colors.white]);
      case LudoFxKind.fly:
        p.burstFrom(context, at,
            count: 18,
            speed: 280,
            size: 9,
            colors: [e.candy.face, e.candy.light, const Color(0xFFFFC83D)]);
      case LudoFxKind.crash:
        p.burstFrom(context, at,
            count: 28,
            speed: 320,
            shape: ParticleShape.dot,
            colors: const [
              Color(0xFFFF8C42),
              Color(0xFFFFC83D),
              Color(0xFFFFFFFF),
              Color(0xFF8C9BB5)
            ]);
      case LudoFxKind.home:
        p.burstFrom(context, at, count: 34, speed: 400, size: 10, colors: [
          ...ParticleController.defaultColors,
          e.candy.face,
        ]);
      case LudoFxKind.bomb:
        _bombSpot = at;
        _bombController.forward(from: 0);
        p.burstFrom(context, at,
            count: 46,
            speed: 440,
            size: 13,
            shape: ParticleShape.star,
            colors: const [
              Color(0xFFFF2A2A),
              Color(0xFFFF7A00),
              Color(0xFFFFD600),
              Color(0xFFFFFFFF),
            ]);
        p.burstFrom(context, at,
            count: 26,
            speed: 240,
            size: 9,
            shape: ParticleShape.dot,
            colors: const [
              Color(0xFFFF4D4D),
              Color(0xFFFFAA00),
              Color(0xFF2C2C2C),
            ]);
    }
  }

  Offset _restPos(int seat, int plane, int progress) {
    final pos = _c.state.positions[seat];
    if (progress == Ludo.yard) {
      final (x, y) = _yardSlot(pos, plane);
      return Offset(x * _cell, y * _cell);
    }
    if (progress == Ludo.ready) {
      final (x, y) = Ludo.readySpot(pos);
      return Offset(x * _cell, y * _cell);
    }
    if (progress == Ludo.goal) {
      const dirs = [(0.0, 1.05), (-1.05, 0.0), (0.0, -1.05), (1.05, 0.0)];
      final (dx, dy) = dirs[pos];
      final spread = (plane - 1.5) * 0.4;
      final (cx, cy) = Ludo.center;
      return Offset((cx + dx + (dy != 0 ? spread : 0)) * _cell,
          (cy + dy + (dx != 0 ? spread : 0)) * _cell);
    }
    final (x, y) = Ludo.cell(pos, progress);
    return Offset(x * _cell, y * _cell);
  }

  double _heading(int seat, int progress) {
    final pos = _c.state.positions[seat];
    if (progress == Ludo.ready) {
      final (rx, ry) = Ludo.readySpot(pos);
      final (sx, sy) = Ludo.cell(pos, 0);
      return math.atan2(sy - ry, sx - rx) + math.pi / 2;
    }
    if (progress < 0) return math.pi / 4 + pos * math.pi / 2;
    if (progress >= Ludo.goal) return _parkedHeading(pos);
    final (ax, ay) = Ludo.cell(pos, progress);
    final (bx, by) =
        progress + 1 >= Ludo.goal ? Ludo.center : Ludo.cell(pos, progress + 1);
    return math.atan2(by - ay, bx - ax) + math.pi / 2;
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
    if (best != null && bestD < _cell * 1.7) {
      _c.humanMove(best);
    } else {
      Fx.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cell = constraints.maxWidth / Ludo.size;
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
                    timeline: _timeline,
                    move: _move,
                    pulse: _pulse,
                    highlight: _c.canHumanAct && _c.state.dice != null,
                  ),
                ),
              ),
              if (_bombSpot != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _BombEffectView(
                      position: _bombSpot!,
                      cellSize: _cell,
                      animation: _bombController,
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

class _BombEffectView extends StatelessWidget {
  const _BombEffectView({
    required this.position,
    required this.cellSize,
    required this.animation,
  });

  final Offset position;
  final double cellSize;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (t <= 0 || t >= 1.0) return const SizedBox.shrink();
        return CustomPaint(
          size: Size.infinite,
          painter: _BombEffectPainter(
            center: position,
            cellSize: cellSize,
            progress: t,
          ),
        );
      },
    );
  }
}

class _BombEffectPainter extends CustomPainter {
  _BombEffectPainter({
    required this.center,
    required this.cellSize,
    required this.progress,
  });

  final Offset center;
  final double cellSize;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.38) {
      // Phase 1: Cartoon Bomb lands and ticks frantically
      final phaseT = progress / 0.38;
      final bounce = math.sin(phaseT * math.pi) * (cellSize * 0.4);
      final at = center - Offset(0, cellSize * (1 - phaseT) * 1.5 - bounce);
      final r = cellSize * 0.65 * (1.0 + phaseT * 0.3);

      // Shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(0, cellSize * 0.5),
          width: r * 1.8 * (0.8 + 0.2 * phaseT),
          height: r * 0.6 * (0.8 + 0.2 * phaseT),
        ),
        Paint()..color = Palette.ink.withOpacity(0.28),
      );

      // Bomb Body (turns from dark ink to cherry red warning)
      final bodyColor = Color.lerp(
        Palette.ink,
        const Color(0xFFFF2222),
        (phaseT * 2 - 0.7).clamp(0.0, 1.0),
      )!;

      // Bomb Cap & Fuse
      final capRect = Rect.fromCenter(
        center: at - Offset(0, r * 0.88),
        width: r * 0.55,
        height: r * 0.3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(capRect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF6B7280),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(capRect, const Radius.circular(3)),
        inkStroke(2),
      );

      // Curved fuse line
      final fusePath = Path()
        ..moveTo(at.dx, at.dy - r * 0.95)
        ..quadraticBezierTo(
          at.dx + r * 0.5,
          at.dy - r * 1.5,
          at.dx + r * 0.3,
          at.dy - r * 1.7,
        );
      canvas.drawPath(
        fusePath,
        Paint()
          ..color = const Color(0xFFD4A373)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );

      // Spark on fuse tip
      final sparkCenter = Offset(at.dx + r * 0.3, at.dy - r * 1.7);
      final sparkR = (cellSize * 0.3) * (0.8 + 0.4 * math.sin(phaseT * 30));
      canvas.drawCircle(
        sparkCenter,
        sparkR,
        Paint()..color = const Color(0xFFFFD600).withOpacity(0.9),
      );
      canvas.drawCircle(
        sparkCenter,
        sparkR * 0.5,
        Paint()..color = Colors.white,
      );

      // Draw Bomb Sphere
      canvas.drawCircle(at, r, Paint()..color = bodyColor);
      canvas.drawCircle(at, r, inkStroke(3));

      // Specular highlight
      canvas.drawOval(
        Rect.fromCenter(
          center: at - Offset(r * 0.35, r * 0.35),
          width: r * 0.45,
          height: r * 0.28,
        ),
        Paint()..color = Colors.white.withOpacity(0.65),
      );
    } else {
      // Phase 2: Massive Cartoon Explosion Cloud & Shockwave
      final p = ((progress - 0.38) / 0.62).clamp(0.0, 1.0);
      final fade = (1.0 - p).clamp(0.0, 1.0);

      // Expanding Shockwave Ring
      final ringR = cellSize * (0.8 + p * 2.8);
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..color = const Color(0xFFFFD600).withOpacity(fade * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, (1.0 - p) * 8),
      );

      // Fiery explosion cloud puffs
      final cloudR = cellSize * (0.9 + p * 1.1);
      const angles = [
        0.0,
        math.pi / 3,
        2 * math.pi / 3,
        math.pi,
        4 * math.pi / 3,
        5 * math.pi / 3,
      ];

      // Outer Red Fire
      for (var i = 0; i < angles.length; i++) {
        final ang = angles[i] + p * 0.5;
        final dist = cloudR * 0.65;
        final c = center + Offset(math.cos(ang) * dist, math.sin(ang) * dist);
        canvas.drawCircle(
          c,
          cloudR * 0.6,
          Paint()..color = const Color(0xFFFF2A2A).withOpacity(fade * 0.95),
        );
        canvas.drawCircle(
          c,
          cloudR * 0.6,
          inkStroke(2.5, color: Palette.ink.withOpacity(fade)),
        );
      }

      // Middle Orange/Yellow Fire
      canvas.drawCircle(
        center,
        cloudR * 0.8,
        Paint()..color = const Color(0xFFFF9500).withOpacity(fade),
      );

      // Core Intense White/Yellow Flash
      canvas.drawCircle(
        center,
        cloudR * 0.5,
        Paint()..color = Colors.white.withOpacity(fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BombEffectPainter old) =>
      old.progress != progress || old.center != center;
}

/// Direction a plane faces once parked in its goal triangle (pointing in).
double _parkedHeading(int position) => const [
      0.0,
      math.pi / 2,
      math.pi,
      -math.pi / 2,
    ][position];

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter(this.active);

  final List<int> active;

  static const _goalTriangles = <List<(double, double)>>[
    [(7, 10), (10, 10), (8.5, 8.5)],
    [(7, 7), (7, 10), (8.5, 8.5)],
    [(7, 7), (10, 7), (8.5, 8.5)],
    [(10, 7), (10, 10), (8.5, 8.5)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / Ludo.size;
    Offset pt((double, double) p) => Offset(p.$1 * u, p.$2 * u);

    final board =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * 0.9));
    canvas.drawRRect(
        board.shift(Offset(0, u * 0.22)), Paint()..color = Palette.ink);
    canvas.drawRRect(board, Paint()..color = const Color(0xFFFFFBF2));
    canvas.drawRRect(board, inkStroke(3));

    // Yards: a 4×4 pad with four airfield circles.
    for (var pos = 0; pos < 4; pos++) {
      final (yx, yy) = Ludo.yards[pos];
      final candy = _posCandies[pos];
      final on = active.contains(pos);
      final rect = Rect.fromLTWH(yx * u, yy * u, 4 * u, 4 * u);
      final outer = RRect.fromRectAndRadius(
          rect.deflate(u * 0.12), Radius.circular(u * 0.9));
      canvas.drawRRect(
          outer, Paint()..color = on ? candy.face : const Color(0xFFE5DED0));
      canvas.drawRRect(outer, inkStroke(2.5));
      final inner = RRect.fromRectAndRadius(
          rect.deflate(u * 0.32), Radius.circular(u * 0.65));
      canvas.drawRRect(inner, Paint()..color = Colors.white.withOpacity(0.92));
      for (final (sx, sy) in Ludo.yardSlots) {
        final center = Offset((yx + sx) * u, (yy + sy) * u);
        canvas.drawCircle(center, u * 0.66,
            Paint()..color = on ? candy.light : const Color(0xFFF1ECE2));
        canvas.drawCircle(center, u * 0.66,
            inkStroke(2, color: on ? candy.shade : const Color(0xFFD5CCBA)));
      }
    }

    // Ring squares.
    for (var i = 0; i < Ludo.trackShapes.length; i++) {
      final candy = _posCandies[Ludo.trackColor(i)];
      final path = _squarePath(Ludo.trackShapes[i], u);
      canvas.drawPath(path, Paint()..color = candy.face);
      canvas.drawPath(path, inkStroke(1.6)..strokeJoin = StrokeJoin.round);
      canvas.drawCircle(pt(Ludo.track[i]), u * 0.26,
          Paint()..color = Colors.white.withOpacity(0.7));
    }

    // Home lanes.
    for (var pos = 0; pos < 4; pos++) {
      final candy = _posCandies[pos];
      for (final (x, y) in Ludo.lanes[pos]) {
        final r = RRect.fromRectAndRadius(
            Rect.fromCenter(center: pt((x, y)), width: u, height: u)
                .deflate(u * 0.07),
            Radius.circular(u * 0.22));
        canvas.drawRRect(r, Paint()..color = candy.light);
        canvas.drawRRect(r, inkStroke(1.6, color: candy.shade));
        canvas.drawCircle(pt((x, y)), u * 0.2,
            Paint()..color = Colors.white.withOpacity(0.8));
      }
    }

    // Airports: four triangles meeting at the center.
    for (var pos = 0; pos < 4; pos++) {
      final tri = Path()
        ..addPolygon([for (final p in _goalTriangles[pos]) pt(p)], true);
      canvas.drawPath(tri, Paint()..color = _posCandies[pos].face);
      canvas.drawPath(tri, inkStroke(2)..strokeJoin = StrokeJoin.round);
    }
    paintStar(canvas, pt(Ludo.center), u * 0.5, outlineWidth: 2);

    for (var pos = 0; pos < 4; pos++) {
      _paintStartMarker(canvas, u, pos);
      _paintFlight(canvas, u, pos);
    }
  }

  /// A ring square inset a little so neighbours show a gap.
  static Path _squarePath(List<(double, double)> shape, double u) {
    if (shape.length == 4) {
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final (x, y) in shape) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTRB(minX * u, minY * u, maxX * u, maxY * u)
                .deflate(u * 0.07),
            Radius.circular(u * 0.22)));
    }
    var cx = 0.0, cy = 0.0;
    for (final (x, y) in shape) {
      cx += x / shape.length;
      cy += y / shape.length;
    }
    return Path()
      ..addPolygon([
        for (final (x, y) in shape)
          Offset((cx + (x - cx) * 0.9) * u, (cy + (y - cy) * 0.9) * u),
      ], true);
  }

  /// The black arrow badge tucked into the empty corner of a start square.
  void _paintStartMarker(Canvas canvas, double u, int pos) {
    final (rx, ry) = Ludo.readySpot(pos);
    final center = Offset(rx * u, ry * u);
    final (ax, ay) = Ludo.cell(pos, 0);
    final (bx, by) = Ludo.cell(pos, 1);
    final dir = (bx - ax).abs() > (by - ay).abs()
        ? Offset((bx - ax).sign, 0)
        : Offset(0, (by - ay).sign);
    canvas.drawCircle(center, u * 0.44, Paint()..color = Palette.ink);
    _arrow(canvas, center, dir, u * 0.3, _posCandies[pos].face);
  }

  void _arrow(Canvas canvas, Offset at, Offset dir, double r, Color color) {
    final side = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo(at.dx + dir.dx * r, at.dy + dir.dy * r)
        ..lineTo(at.dx - dir.dx * r * 0.6 + side.dx * r * 0.9,
            at.dy - dir.dy * r * 0.6 + side.dy * r * 0.9)
        ..lineTo(at.dx - dir.dx * r * 0.6 - side.dx * r * 0.9,
            at.dy - dir.dy * r * 0.6 - side.dy * r * 0.9)
        ..close(),
      Paint()..color = color,
    );
  }

  /// Dashed shortcut across the board, with arrow badges on both ends.
  void _paintFlight(Canvas canvas, double u, int pos) {
    final (fx, fy) = Ludo.cell(pos, Ludo.flyFrom);
    final (tx, ty) = Ludo.cell(pos, Ludo.flyTo);
    final a = Offset(fx * u, fy * u);
    final b = Offset(tx * u, ty * u);
    final dir = (b - a) / (b - a).distance;
    final candy = _posCandies[pos];
    final dash = Paint()
      ..color = candy.shade
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.13
      ..strokeCap = StrokeCap.round;
    final start = a + dir * u * 0.55;
    final end = b - dir * u * 0.9;
    final len = (end - start).distance;
    for (var d = 0.0; d < len; d += u * 0.5) {
      canvas.drawLine(
          start + dir * d, start + dir * math.min(d + u * 0.3, len), dash);
    }
    _arrow(canvas, b - dir * u * 0.75, dir, u * 0.34, candy.shade);
    for (final at in [a, b]) {
      canvas.drawCircle(at, u * 0.3, Paint()..color = Colors.white);
      canvas.drawCircle(at, u * 0.3, inkStroke(1.4, color: candy.shade));
      _arrow(canvas, at, dir, u * 0.2, candy.shade);
    }
  }

  @override
  bool shouldRepaint(_LudoBoardPainter old) =>
      old.active.join() != active.join();
}

/// Where a flying plane is at one instant of a leg.
class _Pose {
  const _Pose(this.ground, this.height, this.scale, this.angle);

  final Offset ground;
  final double height;
  final double scale;
  final double angle;
}

double _lerpAngle(double a, double b, double t) {
  var d = (b - a) % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  return a + d * t;
}

class _PlanesPainter extends CustomPainter {
  _PlanesPainter({
    required this.state,
    required this.cell,
    required this.restPos,
    required this.heading,
    required this.moving,
    required this.timeline,
    required this.move,
    required this.pulse,
    required this.highlight,
  }) : super(repaint: Listenable.merge([move, pulse]));

  final LudoState state;
  final double cell;
  final Offset Function(int seat, int plane, int progress) restPos;
  final double Function(int seat, int progress) heading;
  final LudoMoveInfo? moving;
  final _Timeline? timeline;
  final AnimationController move;
  final Animation<double> pulse;
  final bool highlight;

  Candy _candy(int seat) => _posCandies[state.positions[seat]];

  @override
  void paint(Canvas canvas, Size size) {
    final m = moving;
    final tl = timeline;
    final active = m != null && tl != null && move.value < 1;
    final movable = highlight ? state.movablePlanes().toSet() : const <int>{};
    final elapsed = active ? move.value * tl.totalMs : double.infinity;
    final inAir = active && elapsed < tl.routeMs;

    // Captured planes stay put until the attacker lands, then fly home.
    final hitAt = <int, int>{};
    final hitFrom = <int, int>{};
    if (active) {
      for (var i = 0; i < m.captured.length; i++) {
        final (s, k, p) = m.captured[i];
        hitAt[s * 10 + k] = tl.ends[m.captureLegs[i]];
        hitFrom[s * 10 + k] = p;
      }
      for (final (s, k, p) in m.recalled) {
        hitAt[s * 10 + k] = 0;
        hitFrom[s * 10 + k] = p;
      }
    }

    // Count planes per spot to fan out stacks.
    final spots = <String, int>{};
    for (var seat = 0; seat < state.planes.length; seat++) {
      for (var k = 0; k < state.planes[seat].length; k++) {
        final p = state.planes[seat][k];
        if (inAir && seat == m.seat && k == m.plane) continue;
        var at = restPos(seat, k, p);
        var angle = heading(seat, p);
        var scale = p == Ludo.goal ? 0.62 : 1.0;
        final te = hitAt[seat * 10 + k];
        if (te != null) {
          if (elapsed >= te + _captureMs) {
            // Landed back in the yard: handled as a resting plane.
          } else if (elapsed >= te) {
            continue;
          } else {
            final from = hitFrom[seat * 10 + k]!;
            at = restPos(seat, k, from);
            angle = heading(seat, from);
            // Brace for impact: a nervous wobble just before the hit.
            if (elapsed > te - 260) {
              angle += math.sin(elapsed * 0.05) * 0.35;
            }
          }
        }
        final key = '${(at.dx / 4).round()},${(at.dy / 4).round()}';
        final n = spots.update(key, (v) => v + 1, ifAbsent: () => 0);
        final offset = p == Ludo.goal || p == Ludo.yard
            ? Offset.zero
            : Offset(n * cell * 0.16, -n * cell * 0.16);
        if (seat == state.turn && movable.contains(k)) {
          final r = cell * (0.66 + 0.12 * pulse.value);
          canvas.drawCircle(
              at + offset, r, Paint()..color = Colors.white.withOpacity(0.85));
          canvas.drawCircle(
              at + offset, r, inkStroke(3, color: _candy(seat).shade));
        }
        _plane(canvas, at + offset, angle, _candy(seat), scale);
      }
    }

    if (!active) return;
    _effects(canvas, m, tl, elapsed);
    if (inAir) _mover(canvas, m, tl, elapsed);
    for (var i = 0; i < m.captured.length; i++) {
      final (seat, k, from) = m.captured[i];
      _knockedHome(canvas, seat, k, from, elapsed - tl.ends[m.captureLegs[i]]);
    }
    for (final (seat, k, from) in m.recalled) {
      _knockedHome(canvas, seat, k, from, elapsed);
    }
  }

  /// Ground target of leg [i]; the final home leg parks in the plane's slot.
  Offset _legTarget(LudoMoveInfo m, int i) {
    final leg = m.route[i];
    if (leg.kind == LudoStepKind.home) {
      return restPos(m.seat, m.plane, Ludo.goal);
    }
    return Offset(leg.x * cell, leg.y * cell);
  }

  _Pose _pose(LudoStepKind kind, Offset from, Offset to, double f,
      double fromAngle, double toAngle) {
    final dir = math.atan2(to.dy - from.dy, to.dx - from.dx) + math.pi / 2;
    switch (kind) {
      case LudoStepKind.step:
        final h = math.sin(f * math.pi) * cell * 0.35;
        return _Pose(Offset.lerp(from, to, Curves.easeInOut.transform(f))!, h,
            1 + h / cell * 0.25, dir);
      case LudoStepKind.jump:
        final h = math.sin(f * math.pi) * cell * 1.3;
        return _Pose(Offset.lerp(from, to, Curves.easeInOut.transform(f))!, h,
            1 + h / cell * 0.22, dir);
      case LudoStepKind.fly:
        final h = math.sin(f * math.pi) * cell * 2.6;
        return _Pose(Offset.lerp(from, to, Curves.easeInOutCubic.transform(f))!,
            h, 1 + h / cell * 0.2, dir);
      case LudoStepKind.takeoff:
        const rev = 0.3;
        if (f < rev) {
          // Spool up on the pad: shake and swell before rolling out.
          final r = f / rev;
          final shake = math.sin(r * math.pi * 9) * cell * 0.04 * r;
          return _Pose(from + Offset(shake, 0), 0,
              1 + 0.14 * math.sin(r * math.pi), fromAngle);
        }
        final g = (f - rev) / (1 - rev);
        final h = math.sin(g * math.pi) * cell * 1.6;
        return _Pose(
            Offset.lerp(from, to, Curves.easeInOut.transform(g))!,
            h,
            1 + h / cell * 0.25,
            _lerpAngle(fromAngle, dir, Curves.easeOut.transform(g)));
      case LudoStepKind.home:
        final e = Curves.easeOut.transform(f);
        return _Pose(Offset.lerp(from, to, e)!, (1 - e) * cell * 0.7,
            1.15 + (0.62 - 1.15) * e, _lerpAngle(dir, toAngle, e));
    }
  }

  void _mover(Canvas canvas, LudoMoveInfo m, _Timeline tl, double elapsed) {
    final candy = _candy(m.seat);
    final pos = state.positions[m.seat];
    var from = restPos(m.seat, m.plane, m.fromProgress);
    var fromAngle = heading(m.seat, m.fromProgress);
    for (var i = 0; i < m.route.length; i++) {
      final leg = m.route[i];
      final to = _legTarget(m, i);
      if (elapsed < tl.ends[i]) {
        final f = ((elapsed - tl.starts[i]) / _legMs(leg.kind)).clamp(0.0, 1.0);
        final toAngle = _parkedHeading(pos);
        final pose = _pose(leg.kind, from, to, f, fromAngle, toAngle);
        _trail(canvas, leg.kind, from, to, f, fromAngle, toAngle, candy);
        final lift = 1 / (1 + pose.height / cell * 0.35);
        canvas.drawOval(
            Rect.fromCenter(
                center: pose.ground,
                width: cell * 0.7 * lift,
                height: cell * 0.3 * lift),
            Paint()..color = Colors.black.withOpacity(0.18 * lift));
        _plane(canvas, pose.ground - Offset(0, pose.height), pose.angle, candy,
            pose.scale);
        return;
      }
      fromAngle = math.atan2(to.dy - from.dy, to.dx - from.dx) + math.pi / 2;
      from = to;
    }
  }

  /// Puffs of vapour left behind by takeoffs, jumps and flights.
  void _trail(Canvas canvas, LudoStepKind kind, Offset from, Offset to,
      double f, double fromAngle, double toAngle, Candy candy) {
    if (kind == LudoStepKind.step || kind == LudoStepKind.home) return;
    final fly = kind == LudoStepKind.fly;
    final n = fly ? 10 : 5;
    for (var i = 1; i <= n; i++) {
      final ff = f - i * (fly ? 0.035 : 0.05);
      if (ff <= 0) break;
      final pose = _pose(kind, from, to, ff, fromAngle, toAngle);
      final fade = 1 - i / (n + 1);
      canvas.drawCircle(
          pose.ground - Offset(0, pose.height),
          cell * (fly ? 0.26 : 0.18) * fade,
          Paint()
            ..color =
                (fly ? candy.light : Colors.white).withOpacity(0.6 * fade));
    }
  }

  void _ripple(Canvas canvas, Offset at, double t, Color color, double maxR,
      {double width = 3}) {
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOut.transform(t);
    canvas.drawCircle(
        at,
        maxR * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * (1 - t) + 0.5
          ..color = color.withOpacity(1 - t));
  }

  void _sparkles(Canvas canvas, Offset at, double t, int count, double reach,
      Color color) {
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOut.transform(t);
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + t * 1.4;
      paintStar(canvas, at + Offset(math.cos(a), math.sin(a)) * reach * e,
          cell * 0.26 * (1 - t),
          fill: color, outlineWidth: 1.4, glossy: false);
    }
  }

  void _effects(Canvas canvas, LudoMoveInfo m, _Timeline tl, double elapsed) {
    final candy = _candy(m.seat);
    var from = restPos(m.seat, m.plane, m.fromProgress);
    for (var i = 0; i < m.route.length; i++) {
      final leg = m.route[i];
      final to = _legTarget(m, i);
      final since = elapsed - tl.ends[i];
      switch (leg.kind) {
        case LudoStepKind.takeoff:
          _ripple(canvas, from, (elapsed - tl.starts[i]) / 320, candy.light,
              cell * 1.4,
              width: 5);
          _ripple(canvas, to, since / 420, candy.face, cell * 1.1);
        case LudoStepKind.jump:
          _ripple(canvas, to, since / 450, candy.face, cell * 1.2, width: 4);
          _sparkles(canvas, to, since / 450, 5, cell * 1.0, candy.light);
        case LudoStepKind.fly:
          _ripple(canvas, to, since / 650, candy.face, cell * 2.2, width: 6);
          _ripple(canvas, to, (since - 120) / 650, Colors.white, cell * 1.6);
          _sparkles(
              canvas, to, since / 650, 8, cell * 2.0, const Color(0xFFFFC83D));
        case LudoStepKind.home:
          final t = since / _homeFxMs;
          final c = Offset(Ludo.center.$1 * cell, Ludo.center.$2 * cell);
          if (t > 0 && t < 1) {
            canvas.drawCircle(c, cell * 2.4 * Curves.easeOut.transform(t),
                Paint()..color = candy.light.withOpacity(0.55 * (1 - t)));
          }
          _ripple(canvas, c, t, candy.face, cell * 2.6, width: 6);
          _ripple(canvas, c, (t - 0.18) / 0.82, Colors.white, cell * 2.0);
          _sparkles(canvas, c, t, 10, cell * 2.6, const Color(0xFFFFC83D));
        case LudoStepKind.step:
          break;
      }
      from = to;
    }
    for (final i in m.captureLegs.toSet()) {
      final at = _legTarget(m, i);
      final since = elapsed - tl.ends[i];
      _ripple(canvas, at, since / 480, const Color(0xFFFF8C42), cell * 1.7,
          width: 6);
      _ripple(canvas, at, (since - 80) / 480, Colors.white, cell * 1.1);
      if (since > 0 && since < 220) {
        // Impact flash.
        canvas.drawCircle(at, cell * 0.8 * (1 - since / 220),
            Paint()..color = Colors.white.withOpacity(0.9));
      }
    }
  }

  /// The captured plane is knocked out of the sky, tumbling back to its yard.
  void _knockedHome(
      Canvas canvas, int seat, int k, int fromProgress, double since) {
    if (since < 0 || since >= _captureMs) return;
    final f = since / _captureMs;
    final from = restPos(seat, k, fromProgress);
    final to = restPos(seat, k, Ludo.yard);
    final g = f < 0.15 ? 0.0 : (f - 0.15) / 0.85;
    final ground = Offset.lerp(from, to, Curves.easeInOutCubic.transform(g))!;
    final h = math.sin(g * math.pi) * cell * 2.4;
    final candy = _candy(seat);
    for (var i = 1; i <= 6; i++) {
      final gg = g - i * 0.04;
      if (gg <= 0) break;
      final p = Offset.lerp(from, to, Curves.easeInOutCubic.transform(gg))!;
      final hh = math.sin(gg * math.pi) * cell * 2.4;
      canvas.drawCircle(
          p - Offset(0, hh),
          cell * 0.2 * (1 - i / 7),
          Paint()
            ..color = const Color(0xFFFF8C42).withOpacity(0.6 * (1 - i / 7)));
    }
    final lift = 1 / (1 + h / cell * 0.35);
    canvas.drawOval(
        Rect.fromCenter(
            center: ground,
            width: cell * 0.7 * lift,
            height: cell * 0.3 * lift),
        Paint()..color = Colors.black.withOpacity(0.18 * lift));
    // Dust ring where it lands back in the yard.
    _ripple(canvas, to, (g - 0.85) / 0.15, candy.light, cell * 1.1);
    final squash =
        g > 0.9 ? 1 + 0.18 * math.sin((g - 0.9) / 0.1 * math.pi) : 1.0;
    _plane(
        canvas,
        ground - Offset(0, h),
        heading(seat, fromProgress) + g * math.pi * 4,
        candy,
        (1 + h / cell * 0.2) * squash);
    if (f < 0.15) {
      // Dizzy stars right after the hit.
      for (var i = 0; i < 3; i++) {
        final a = since * 0.02 + i * math.pi * 2 / 3;
        paintStar(
            canvas,
            from +
                Offset(math.cos(a) * cell * 0.5,
                    -cell * 0.7 + math.sin(a) * cell * 0.15),
            cell * 0.16,
            fill: const Color(0xFFFFC83D),
            outlineWidth: 1,
            glossy: false);
      }
    }
  }

  void _plane(
      Canvas canvas, Offset at, double angle, Candy candy, double scale) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    GameIcons.paintPlane(canvas, cell * 0.98, candy);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanesPainter old) => true;
}
