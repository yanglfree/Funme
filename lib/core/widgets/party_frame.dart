import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_info.dart';
import '../game/party.dart';
import '../storage/app_store.dart';
import '../theme/palette.dart';
import 'game_scaffold.dart';
import 'particles.dart';
import 'result_overlay.dart';
import 'setup_sheet.dart';
import 'sky_background.dart';

@immutable
class PartySeat {
  const PartySeat(this.name, this.candy, this.token);

  final String name;
  final Candy candy;
  final Widget token;
}

/// Page frame for 2–6 seat games: setup sheet, seat chips with the active
/// seat highlighted, and the end-of-game result flow.
class PartyGameFrame<S, M> extends StatefulWidget {
  const PartyGameFrame({
    super.key,
    required this.info,
    required this.controller,
    required this.seats,
    required this.board,
    required this.setupGroups,
    required this.toSetup,
    this.footer,
    this.scenery = Scenery.sky,
    this.particles,
  });

  final GameInfo info;
  final PartyController<S, M> controller;

  /// Seat presentation for the current setup, in turn order.
  final List<PartySeat> Function() seats;
  final Widget board;
  final List<SetupGroup> setupGroups;
  final PartySetup Function(Map<String, String> values) toSetup;
  final Widget? footer;
  final Scenery scenery;
  final ParticleController? particles;

  @override
  State<PartyGameFrame<S, M>> createState() => _PartyGameFrameState<S, M>();
}

class _PartyGameFrameState<S, M> extends State<PartyGameFrame<S, M>> {
  bool _resultPending = false;

  PartyController<S, M> get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSetup());
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _openSetup() async {
    if (!mounted) return;
    final raw = AppStore.instance.setup(widget.info.id) ?? const {};
    final initial = {for (final e in raw.entries) e.key: '${e.value}'};
    final result = await showSetupSheet(
      context,
      title: widget.info.name,
      groups: widget.setupGroups,
      initial: initial,
    );
    if (!mounted) return;
    if (result == null && _c.started) return;
    final values = result ??
        {
          for (final g in widget.setupGroups)
            g.key: initial[g.key] ?? g.choices.first.value,
        };
    AppStore.instance.saveSetup(widget.info.id, values);
    _c.start(widget.toSetup(values));
  }

  void _onChange() {
    final outcome = _c.outcome;
    if (outcome == null) {
      _resultPending = false;
      return;
    }
    if (_resultPending) return;
    _resultPending = true;
    Timer(const Duration(milliseconds: 1100), () {
      if (mounted && identical(_c.outcome, outcome)) _showResult(outcome);
    });
  }

  Future<void> _showResult(PartyOutcome outcome) async {
    final seats = widget.seats();
    final humans = _c.setup.humans;
    final winnerHuman = !_c.isAi(outcome.winner);
    final hasAi = _c.setup.seats.any((s) => s == SeatKind.ai);
    final kind = winnerHuman || !hasAi ? ResultKind.win : ResultKind.lose;
    final stars =
        winnerHuman && hasAi && humans == 1 ? _c.setup.level.stars : 0;
    if (hasAi) {
      AppStore.instance.submit(widget.info.id, stars: stars, win: winnerHuman);
    }
    final name = seats[outcome.winner].name;
    final title = kind == ResultKind.lose
        ? '差一点点！'
        : (humans == 1 && winnerHuman ? '你赢啦！' : '$name赢啦！');
    final message = kind == ResultKind.lose
        ? '$name抢先了一步，再试一次吧～'
        : (outcome.reason.isEmpty ? null : outcome.reason);
    final action = await showResultOverlay(
      context,
      kind: kind,
      title: title,
      message: message,
      stars: stars,
      showStars: hasAi && humans == 1,
    );
    if (!mounted) return;
    switch (action) {
      case ResultAction.again:
      case ResultAction.next:
        _c.start(_c.setup);
      case ResultAction.home:
        Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.info.name,
      scenery: widget.scenery,
      rules: widget.info.rules,
      onRestart: _openSetup,
      particles: widget.particles,
      header: ListenableBuilder(
        listenable: _c,
        builder: (context, _) =>
            _SeatsBar(controller: _c, seats: widget.seats()),
      ),
      body: Center(child: widget.board),
      footer: widget.footer,
    );
  }
}

class _SeatsBar<S, M> extends StatelessWidget {
  const _SeatsBar({required this.controller, required this.seats});

  final PartyController<S, M> controller;
  final List<PartySeat> seats;

  String _role(int seat) {
    if (controller.isAi(seat)) return '电脑';
    if (controller.setup.humans == 1) return '你';
    var n = 0;
    for (var i = 0; i <= seat; i++) {
      if (!controller.isAi(i)) n++;
    }
    return '玩家$n';
  }

  @override
  Widget build(BuildContext context) {
    final active =
        controller.started && controller.outcome == null ? controller.turn : -1;
    final count = seats.length;
    final perRow = count <= 4 ? count : 3;
    final rows = <List<int>>[];
    for (var i = 0; i < count; i += perRow) {
      rows.add([for (var k = i; k < i + perRow && k < count; k++) k]);
    }
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (final i in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _SeatChip(
                        seat: seats[i],
                        role: _role(i),
                        active: i == active,
                        thinking: i == active && controller.thinking,
                        compact: perRow >= 4 || count > 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({
    required this.seat,
    required this.role,
    required this.active,
    required this.thinking,
    required this.compact,
  });

  final PartySeat seat;
  final String role;
  final bool active;
  final bool thinking;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? seat.candy.face : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.ink, width: active ? 3 : 2),
          boxShadow: active
              ? [BoxShadow(color: seat.candy.shade, offset: const Offset(0, 4))]
              : const [],
        ),
        child: Row(
          children: [
            SizedBox(
                width: compact ? 24 : 30,
                height: compact ? 24 : 30,
                child: seat.token),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seat.name,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: FunText.body(size: compact ? 12 : 14),
                  ),
                  Text(
                    thinking ? '思考中…' : role,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: FunText.caption(
                        size: compact ? 10 : 11,
                        color: Palette.ink.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard setup groups for seat games.
List<SetupGroup> partySetupGroups(
    {required List<int> playerCounts, int maxHumans = 4}) {
  return [
    SetupGroup(
      key: 'players',
      title: '几个人玩',
      choices: [
        for (final n in playerCounts)
          SetupChoice('$n', '$n 人', candy: Candy.ocean),
      ],
    ),
    SetupGroup(
      key: 'humans',
      title: '其中真人玩家',
      choices: [
        for (var n = 1; n <= maxHumans; n++)
          SetupChoice('$n', n == 1 ? '只有我' : '$n 位小朋友', candy: Candy.berry),
      ],
    ),
    const SetupGroup(
      key: 'level',
      title: '电脑难度',
      choices: [
        SetupChoice('easy', '简单 ★', candy: Candy.mint),
        SetupChoice('normal', '普通 ★★', candy: Candy.sun),
        SetupChoice('hard', '困难 ★★★', candy: Candy.cherry),
      ],
    ),
  ];
}
