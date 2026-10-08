import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../layout/side_panel_scope.dart';
import 'candy_button.dart';
import 'candy_panel.dart';
import 'outlined_text.dart';
import 'particles.dart';
import 'rules_sheet.dart';
import 'sky_background.dart';

/// Standard game page frame: animated background, top bar with back /
/// rules / restart, an optional header, the play area and a footer.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.body,
    this.scenery = Scenery.sky,
    this.rules,
    this.onRestart,
    this.actions = const [],
    this.header,
    this.footer,
    this.particles,
    this.hills = false,
  });

  final String title;
  final Widget body;
  final Scenery scenery;
  final List<String>? rules;
  final VoidCallback? onRestart;
  final List<Widget> actions;
  final Widget? header;
  final Widget? footer;
  final ParticleController? particles;
  final bool hills;

  /// Wide landscape: the board takes the full height on the left, and one
  /// side panel holds navigation, status and controls.
  Widget _wideBody(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Row(
          children: [
            Expanded(child: body),
            const SizedBox(width: 16),
            SizedBox(
              width: 300,
              child: Center(
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  child: SidePanelScope(
                    child: CandyPanel(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CandyIconButton(
                                icon: Icons.arrow_back_rounded,
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedText(title, size: 26),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _actionButtons(
                              context,
                              title: title,
                              rules: rules,
                              onRestart: onRestart,
                              actions: actions,
                            ),
                          ),
                          if (header != null) ...[
                            const SizedBox(height: 14),
                            header!,
                          ],
                          if (footer != null) ...[
                            const SizedBox(height: 14),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isWideLandscape(constraints.biggest)) return _wideBody(context);
            return Column(
              children: [
                _TopBar(
                  title: title,
                  rules: rules,
                  onRestart: onRestart,
                  actions: actions,
                ),
                if (header != null) ...[const SizedBox(height: 8), header!],
                const SizedBox(height: 8),
                Expanded(child: body),
                if (footer != null) ...[const SizedBox(height: 8), footer!],
              ],
            );
          },
        ),
      ),
    );
    if (particles != null) {
      content = ParticleLayer(controller: particles!, child: content);
    }
    return Scaffold(
      backgroundColor: scenery.gradient.last,
      body: SkyBackground(scenery: scenery, hills: hills, child: content),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.rules,
    required this.onRestart,
    required this.actions,
  });

  final String title;
  final List<String>? rules;
  final VoidCallback? onRestart;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CandyIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: OutlinedText(title, size: 26),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ..._actionButtons(context,
            title: title, rules: rules, onRestart: onRestart, actions: actions),
      ],
    );
  }
}

/// Action buttons shared by the top bar and the wide-layout side panel:
/// game-specific actions, rules and restart, separated by 8px.
List<Widget> _actionButtons(
  BuildContext context, {
  required String title,
  required List<String>? rules,
  required VoidCallback? onRestart,
  required List<Widget> actions,
}) {
  final buttons = <Widget>[
    ...actions,
    if (rules != null)
      CandyIconButton(
        icon: Icons.question_mark_rounded,
        candy: Candy.sun,
        onTap: () => showRulesSheet(context, title: title, rules: rules),
      ),
    if (onRestart != null)
      CandyIconButton(
        icon: Icons.refresh_rounded,
        candy: Candy.mint,
        onTap: onRestart,
      ),
  ];
  return [
    for (var i = 0; i < buttons.length; i++) ...[
      if (i > 0) const SizedBox(width: 8),
      buttons[i],
    ],
  ];
}
