import 'dart:async';

import 'package:flutter/material.dart';

import '../art/mascot.dart';
import '../art/shapes.dart';
import '../audio/sound_service.dart';
import '../feedback/fx.dart';
import '../theme/palette.dart';
import 'candy_button.dart';
import 'candy_panel.dart';
import 'outlined_text.dart';
import 'particles.dart';

enum ResultKind { win, lose, draw }

enum ResultAction { again, next, home }

/// Celebration (or encouragement) card shown when a round ends.
Future<ResultAction> showResultOverlay(
  BuildContext context, {
  required ResultKind kind,
  required String title,
  String? message,
  int stars = 0,
  bool showStars = true,
  List<(String, String)> stats = const [],
  bool newRecord = false,
  String? nextLabel,
}) async {
  Fx.play(
    switch (kind) {
      ResultKind.win => Sfx.win,
      ResultKind.lose => Sfx.lose,
      ResultKind.draw => Sfx.combo,
    },
    buzz: Buzz.heavy,
  );
  final action = await showGeneralDialog<ResultAction>(
    context: context,
    barrierDismissible: false,
    barrierLabel: title,
    barrierColor: Palette.ink.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (context, _, __) => _ResultView(
      kind: kind,
      title: title,
      message: message,
      stars: stars,
      showStars: showStars,
      stats: stats,
      newRecord: newRecord,
      nextLabel: nextLabel,
    ),
    transitionBuilder: (context, animation, _, child) {
      final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity:
            CurvedAnimation(parent: animation, curve: const Interval(0, 0.4)),
        child: ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(scale), child: child),
      );
    },
  );
  return action ?? ResultAction.home;
}

class _ResultView extends StatefulWidget {
  const _ResultView({
    required this.kind,
    required this.title,
    required this.message,
    required this.stars,
    required this.showStars,
    required this.stats,
    required this.newRecord,
    required this.nextLabel,
  });

  final ResultKind kind;
  final String title;
  final String? message;
  final int stars;
  final bool showStars;
  final List<(String, String)> stats;
  final bool newRecord;
  final String? nextLabel;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView>
    with SingleTickerProviderStateMixin {
  final _particles = ParticleController();
  late final AnimationController _stars = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.kind == ResultKind.win) {
        _particles.rain(MediaQuery.sizeOf(context).width);
      }
      _stars.forward();
      for (var i = 0; i < widget.stars; i++) {
        _timers.add(Timer(Duration(milliseconds: 420 + i * 260), () {
          Fx.play(Sfx.star, buzz: Buzz.light);
        }));
      }
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _stars.dispose();
    _particles.dispose();
    super.dispose();
  }

  Candy get _accent => switch (widget.kind) {
        ResultKind.win => Candy.sun,
        ResultKind.lose => Candy.ocean,
        ResultKind.draw => Candy.mint,
      };

  MascotMood get _mood => switch (widget.kind) {
        ResultKind.win => MascotMood.cheer,
        ResultKind.lose => MascotMood.sad,
        ResultKind.draw => MascotMood.happy,
      };

  Widget _star(int index) {
    final start = 0.25 + index * 0.17;
    final anim = CurvedAnimation(
      parent: _stars,
      curve:
          Interval(start, (start + 0.35).clamp(0, 1), curve: Curves.elasticOut),
    );
    final filled = index < widget.stars;
    final big = index == 1;
    return ScaleTransition(
      scale: filled ? anim : const AlwaysStoppedAnimation(1.0),
      child: Padding(
        padding: EdgeInsets.only(bottom: big ? 12 : 0),
        child: StarIcon(size: big ? 58 : 46, filled: filled),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParticleLayer(
      controller: _particles,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 58),
                    child: CandyPanel(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedText(widget.title,
                              size: 30, color: _accent.face),
                          if (widget.showStars) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [for (var i = 0; i < 3; i++) _star(i)],
                            ),
                          ],
                          if (widget.newRecord) ...[
                            const SizedBox(height: 10),
                            const CandyChip(
                                label: '新纪录！',
                                candy: Candy.berry,
                                fontSize: 15),
                          ],
                          if (widget.message != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              widget.message!,
                              textAlign: TextAlign.center,
                              style: FunText.body(color: Palette.inkSoft),
                            ),
                          ],
                          if (widget.stats.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final (label, value) in widget.stats)
                                  CandyChip(
                                      label: '$label  $value',
                                      candy: Candy.sun,
                                      fontSize: 14),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (widget.nextLabel != null) ...[
                            CandyButton(
                              label: widget.nextLabel,
                              icon: Icons.arrow_forward_rounded,
                              candy: Candy.mint,
                              onTap: () =>
                                  Navigator.of(context).pop(ResultAction.next),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: CandyButton(
                                  label: '回首页',
                                  icon: Icons.home_rounded,
                                  candy: Candy.cream,
                                  fontSize: 17,
                                  onTap: () => Navigator.of(context)
                                      .pop(ResultAction.home),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CandyButton(
                                  label: '再来一局',
                                  icon: Icons.replay_rounded,
                                  candy: widget.nextLabel == null
                                      ? Candy.sun
                                      : Candy.cream,
                                  fontSize: 17,
                                  onTap: () => Navigator.of(context)
                                      .pop(ResultAction.again),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Mascot(mood: _mood, size: 112),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
