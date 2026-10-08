import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/art/mascot.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/candy_panel.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/parent_gate.dart';

/// Counts foreground play time and covers the whole app with an eye-rest
/// screen once the parent-configured limit is reached.
class PlayTimeGuard extends StatefulWidget {
  const PlayTimeGuard({super.key, required this.child});

  final Widget child;

  @override
  State<PlayTimeGuard> createState() => _PlayTimeGuardState();
}

class _PlayTimeGuardState extends State<PlayTimeGuard>
    with WidgetsBindingObserver {
  static const _tick = Duration(seconds: 15);

  Timer? _timer;
  Duration _played = Duration.zero;
  bool _resting = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer ??= Timer.periodic(_tick, (_) => _onTick());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onTick() {
    final limit = AppStore.instance.playLimitMinutes;
    if (limit == 0 || _resting) return;
    _played += _tick;
    if (_played >= Duration(minutes: limit)) {
      setState(() => _resting = true);
    }
  }

  void _unlock(bool ok) {
    setState(() {
      _unlocking = false;
      if (ok) {
        _resting = false;
        _played = Duration.zero;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_resting)
          Positioned.fill(
            child: Material(
              color: const Color(0xFF3B3A7A).withOpacity(0.96),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _unlocking
                        ? ParentGatePanel(reason: '继续游戏', onDone: _unlock)
                        : _restCard(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _restCard() {
    final minutes = AppStore.instance.playLimitMinutes;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: CandyPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(mood: MascotMood.sleep, size: 120),
            const SizedBox(height: 8),
            OutlinedText('休息一下眼睛吧', size: 26, color: Candy.sun.face),
            const SizedBox(height: 10),
            Text(
              '已经玩了 $minutes 分钟啦～\n看看远处，喝口水，伸个懒腰！',
              textAlign: TextAlign.center,
              style: FunText.body(),
            ),
            const SizedBox(height: 18),
            CandyButton(
              label: '家长解锁',
              icon: Icons.lock_open_rounded,
              candy: Candy.ocean,
              onTap: () => setState(() => _unlocking = true),
            ),
          ],
        ),
      ),
    );
  }
}
