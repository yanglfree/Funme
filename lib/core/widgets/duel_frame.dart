import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../feedback/fx.dart';
import '../game/duel.dart';
import '../layout/side_panel_scope.dart';
import '../game/game_info.dart';
import '../storage/app_store.dart';
import '../theme/palette.dart';
import 'candy_button.dart';
import 'game_scaffold.dart';
import 'particles.dart';
import 'result_overlay.dart';
import 'setup_sheet.dart';
import 'sky_background.dart';

@immutable
class DuelSide {
  const DuelSide(this.name, this.token, {this.candy = Candy.cream});

  /// e.g. 黑棋 / 红方.
  final String name;

  /// Small avatar of the side's piece.
  final Widget token;
  final Candy candy;
}

/// Shared page frame for two-sided board games: setup sheet, player badges,
/// undo / hint controls and the end-of-game result flow.
class DuelGameFrame<S, M> extends StatefulWidget {
  const DuelGameFrame({
    super.key,
    required this.info,
    required this.controller,
    required this.sides,
    required this.board,
    this.scenery = Scenery.sky,
    this.hintEnabled = true,
    this.describe,
    this.particles,
    this.setupGroups,
    this.onSetup,
  });

  final GameInfo info;
  final DuelController<S, M> controller;
  final List<DuelSide> sides;
  final Widget board;
  final Scenery scenery;
  final bool hintEnabled;
  final String? Function(DuelOutcome outcome)? describe;
  final ParticleController? particles;

  /// Defaults to [duelSetupGroups].
  final List<SetupGroup>? setupGroups;

  /// Receives the raw setup map before the match starts (for game-specific
  /// options beyond [DuelSetup]).
  final void Function(Map<String, String> values)? onSetup;

  @override
  State<DuelGameFrame<S, M>> createState() => _DuelGameFrameState<S, M>();
}

class _DuelGameFrameState<S, M> extends State<DuelGameFrame<S, M>> {
  bool _resultPending = false;

  DuelController<S, M> get _c => widget.controller;

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

  Map<String, String> _savedSetup() {
    final raw = AppStore.instance.setup(widget.info.id) ?? const {};
    return {for (final e in raw.entries) e.key: '${e.value}'};
  }

  Future<void> _openSetup() async {
    if (!mounted) return;
    final initial = _savedSetup();
    final result = await showSetupSheet(
      context,
      title: widget.info.name,
      groups: widget.setupGroups ?? duelSetupGroups(),
      initial: initial,
    );
    if (!mounted) return;
    if (result == null && _c.started) return;
    final values = result ?? initial;
    AppStore.instance.saveSetup(widget.info.id, values);
    widget.onSetup?.call(values);
    _c.start(DuelSetup.fromMap(values));
  }

  void _onChange() {
    final outcome = _c.outcome;
    if (outcome == null) {
      _resultPending = false;
      return;
    }
    if (_resultPending) return;
    _resultPending = true;
    Timer(const Duration(milliseconds: 900), () {
      if (mounted && identical(_c.outcome, outcome)) _showResult(outcome);
    });
  }

  Future<void> _showResult(DuelOutcome outcome) async {
    final winner = outcome.winner;
    final vsAi = _c.vsAi;
    final humanWon = vsAi && winner == _c.humanSide;
    final kind = winner == null
        ? ResultKind.draw
        : (!vsAi || humanWon ? ResultKind.win : ResultKind.lose);
    final stars = humanWon ? _c.setup.level.stars : 0;
    if (vsAi) {
      AppStore.instance.submit(widget.info.id, stars: stars, win: humanWon);
    }
    final reason = widget.describe?.call(outcome) ?? outcome.reason;
    final title = switch (kind) {
      ResultKind.draw => '平局！',
      ResultKind.win => vsAi ? '你赢啦！' : '${widget.sides[winner!].name}赢啦！',
      ResultKind.lose => '差一点点！',
    };
    final message = kind == ResultKind.lose
        ? '${reason.isEmpty ? '' : '$reason，'}再试一次吧～'
        : (reason.isEmpty ? null : reason);
    final action = await showResultOverlay(
      context,
      kind: kind,
      title: title,
      message: message,
      stars: stars,
      showStars: vsAi,
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

  /// Shrinks below 128 so two buttons still fit the 300-wide side panel.
  Widget _footerButton({
    required String label,
    required IconData icon,
    required Candy candy,
    required VoidCallback? onTap,
  }) {
    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
        child: CandyButton(
          label: label,
          icon: icon,
          candy: candy,
          width: double.infinity,
          fontSize: 18,
          sound: false,
          onTap: onTap,
        ),
      ),
    );
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
            _PlayersBar(controller: _c, sides: widget.sides),
      ),
      body: Center(child: widget.board),
      footer: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _footerButton(
              label: '悔棋',
              icon: Icons.undo_rounded,
              candy: Candy.ocean,
              onTap: _c.canUndo
                  ? () {
                      Fx.play(Sfx.undo, buzz: Buzz.light);
                      _c.undo();
                    }
                  : null,
            ),
            if (widget.hintEnabled) ...[
              const SizedBox(width: 14),
              _footerButton(
                label: '提示',
                icon: Icons.lightbulb_rounded,
                candy: Candy.sun,
                onTap: _c.canHumanAct
                    ? () {
                        Fx.play(Sfx.hint, buzz: Buzz.light);
                        _c.requestHint();
                      }
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayersBar<S, M> extends StatelessWidget {
  const _PlayersBar({required this.controller, required this.sides});

  final DuelController<S, M> controller;
  final List<DuelSide> sides;

  String _role(int side) {
    if (!controller.vsAi) return '玩家${side + 1}';
    return controller.isAiSide(side) ? '电脑' : '你';
  }

  @override
  Widget build(BuildContext context) {
    final active =
        controller.outcome == null && controller.started ? controller.turn : -1;
    final stacked = SidePanelScope.of(context);
    Widget badge(int i) => _PlayerBadge(
          side: sides[i],
          role: _role(i),
          active: active == i,
          thinking: active == i && controller.thinking,
        );
    final vs = Padding(
      padding: stacked
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 8),
      child: Text('VS',
          textAlign: TextAlign.center,
          style: FunText.title(color: Palette.ink, size: 18).copyWith(
            shadows: const [
              Shadow(color: Colors.white, offset: Offset(0, 2), blurRadius: 0)
            ],
          )),
    );
    if (stacked) {
      return Column(children: [badge(0), vs, badge(1)]);
    }
    return Row(
      children: [
        Expanded(child: badge(0)),
        vs,
        Expanded(child: badge(1)),
      ],
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.side,
    required this.role,
    required this.active,
    required this.thinking,
  });

  final DuelSide side;
  final String role;
  final bool active;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.0 : 0.92,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? side.candy.face : Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Palette.ink, width: active ? 3 : 2),
          boxShadow: active
              ? [BoxShadow(color: side.candy.shade, offset: const Offset(0, 4))]
              : const [],
        ),
        child: Row(
          children: [
            SizedBox(width: 34, height: 34, child: side.token),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(side.name,
                      style: FunText.body(size: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    thinking
                        ? '$role 思考中…'
                        : (active && role != '电脑' ? '$role · 该你啦' : role),
                    style: FunText.caption(
                        size: 12, color: Palette.ink.withOpacity(0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
