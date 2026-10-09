import 'package:flutter/material.dart';

import '../../core/feedback/fx.dart';
import '../../games/catalog.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/candy_panel.dart';
import '../../core/widgets/game_scaffold.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/sky_background.dart';

class ParentCenterPage extends StatelessWidget {
  const ParentCenterPage({super.key});

  static const _limits = [0, 15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return GameScaffold(
      title: '家长中心',
      scenery: Scenery.mint,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _Section(
                  title: '声音与震动',
                  children: [
                    _ToggleRow(
                      icon: Icons.volume_up_rounded,
                      label: '游戏音效',
                      value: store.soundOn,
                      onChanged: (v) => store.soundOn = v,
                    ),
                    _ToggleRow(
                      icon: Icons.music_note_rounded,
                      label: '背景音乐',
                      value: store.musicOn,
                      onChanged: (v) => store.musicOn = v,
                    ),
                    _ToggleRow(
                      icon: Icons.vibration_rounded,
                      label: '触感震动',
                      value: store.hapticsOn,
                      onChanged: (v) => store.hapticsOn = v,
                    ),
                  ],
                ),
                _Section(
                  title: '护眼提醒',
                  children: [
                    Text(
                      '连续游戏到设定时长后，会提醒孩子休息，需要家长解锁才能继续。',
                      style: FunText.caption(),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _limits)
                          _LimitChip(
                            label: m == 0 ? '关闭' : '$m 分钟',
                            selected: store.playLimitMinutes == m,
                            onTap: () => store.playLimitMinutes = m,
                          ),
                      ],
                    ),
                  ],
                ),
                _Section(
                  title: '游戏时长',
                  children: [_PlayTimeSummary(store: store)],
                ),
                _Section(
                  title: '隐私与安全',
                  children: [
                    for (final line in const [
                      '完全离线运行，不联网、不需要账号。',
                      '不收集、不上传任何个人信息或使用数据。',
                      '没有广告，没有内购，没有外部链接。',
                      '游戏记录只保存在本机，可随时清除。',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: Candy.mint.shade),
                            const SizedBox(width: 6),
                            Expanded(
                                child:
                                    Text(line, style: FunText.body(size: 14))),
                          ],
                        ),
                      ),
                  ],
                ),
                _Section(
                  title: '游戏记录',
                  children: [
                    Text('当前共获得 ${store.totalStars} 颗星星。',
                        style: FunText.body(size: 14)),
                    const SizedBox(height: 10),
                    CandyButton(
                      label: '清除全部记录',
                      icon: Icons.delete_outline_rounded,
                      candy: Candy.cherry,
                      foreground: Colors.white,
                      fontSize: 17,
                      onTap: () => _confirmClear(context),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '趣玩岛 Funme v1.0.0',
                    textAlign: TextAlign.center,
                    style: FunText.caption(color: Palette.ink.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.cream,
        title: Text('清除全部记录？', style: FunText.title()),
        content: Text('星星、最佳成绩和游戏时长都会被清空，无法恢复。', style: FunText.body(size: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消', style: FunText.body(color: Palette.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('清除', style: FunText.body(color: Candy.cherry.shade)),
          ),
        ],
      ),
    );
    if (ok == true) await AppStore.instance.clearRecords();
  }
}

String formatPlayTime(int seconds) {
  if (seconds < 60) return seconds == 0 ? '0 分钟' : '不到 1 分钟';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes 分钟';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h 小时' : '$h 小时 $m 分钟';
}

class _PlayTimeSummary extends StatelessWidget {
  const _PlayTimeSummary({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final g in GameCatalog.all)
        (
          info: g,
          today: store.playSeconds(gameId: g.id),
          week: store.playSeconds(gameId: g.id, days: 7),
          total: store.totalPlaySeconds(g.id),
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    final maxTotal = rows.first.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Stat(label: '今天', seconds: store.playSeconds()),
            _Stat(label: '近 7 天', seconds: store.playSeconds(days: 7)),
            _Stat(label: '累计', seconds: store.totalPlaySeconds()),
          ],
        ),
        const SizedBox(height: 12),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.info.name, style: FunText.body(size: 15)),
                    ),
                    Text(
                      '今天 ${formatPlayTime(r.today)} · 累计 ${formatPlayTime(r.total)}',
                      style: FunText.caption(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxTotal == 0 ? 0 : r.total / maxTotal,
                    minHeight: 8,
                    backgroundColor: Palette.ink.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(r.info.candy.face),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text('仅统计游戏页面内的前台时间，只保存在本机。', style: FunText.caption()),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.seconds});

  final String label;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child:
                Text(formatPlayTime(seconds), style: FunText.title(size: 18)),
          ),
          Text(label, style: FunText.caption()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CandyPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: FunText.title(size: 19)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Palette.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: FunText.body())),
          CandySwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Chunky on/off switch with a springy knob.
class CandySwitch extends StatelessWidget {
  const CandySwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Fx.tap();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 62,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? Candy.mint.face : const Color(0xFFDCD6E8),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Palette.ink, width: 2.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 360),
          curve: Curves.elasticOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.ink, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Candy.sun.face : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.ink, width: selected ? 3 : 2),
        ),
        child: Text(label, style: FunText.body(size: 15)),
      ),
    );
  }
}
