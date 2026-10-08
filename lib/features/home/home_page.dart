import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/fun_route.dart';
import '../../core/art/mascot.dart';
import '../../core/art/shapes.dart';
import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/game/game_info.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/parent_gate.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/sky_background.dart';
import '../../dev/art_gallery_page.dart';
import '../../games/catalog.dart';
import '../parents/parent_center_page.dart';
import 'game_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  GameCategory? _category;
  MascotMood _mood = MascotMood.idle;

  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _idle.dispose();
    _entrance.dispose();
    super.dispose();
  }

  List<GameInfo> get _visible => _category == null
      ? gameCatalog
      : gameCatalog.where((g) => g.category == _category).toList();

  void _selectCategory(GameCategory? category) {
    if (category == _category) return;
    setState(() => _category = category);
    _entrance.forward(from: 0.25);
  }

  Future<void> _pokeMascot() async {
    Fx.play(Sfx.pop, buzz: Buzz.light);
    setState(() => _mood = MascotMood.cheer);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _mood = MascotMood.idle);
  }

  Future<void> _openParents() async {
    final ok = await showParentGate(context);
    if (!ok || !mounted) return;
    await Navigator.of(context)
        .push(FunRoute(builder: (_) => const ParentCenterPage()));
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return '夜深啦，早点睡哦';
    if (h < 11) return '早上好！今天玩什么呀？';
    if (h < 13) return '中午好！记得午休哦';
    if (h < 18) return '下午好！来挑战一下吧';
    if (h < 22) return '晚上好！再玩一局？';
    return '夜深啦，早点睡哦';
  }

  int _columns(double width) {
    if (width < 520) return 2;
    if (width < 820) return 3;
    if (width < 1100) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final games = _visible;
    return Scaffold(
      backgroundColor: Palette.skyBottom,
      body: SkyBackground(
        hills: true,
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = _columns(constraints.maxWidth);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _categories()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    sliver: ListenableBuilder(
                      listenable: AppStore.instance,
                      builder: (context, _) => SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          childCount: games.length,
                          (context, i) => _staggered(
                            i,
                            GameCard(
                              key: ValueKey(games[i].id),
                              info: games[i],
                              idle: _idle,
                              phase: (i * 0.137) % 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.05).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 40),
          child: Transform.scale(scale: 0.85 + 0.15 * anim.value, child: child),
        ),
      ),
      child: child,
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pokeMascot,
            child: Mascot(mood: _mood, size: 88),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: !kReleaseMode
                      ? () => Navigator.of(context).push(
                          FunRoute(builder: (_) => const ArtGalleryPage()))
                      : null,
                  child: const OutlinedText('趣玩岛',
                      size: 34, textAlign: TextAlign.left),
                ),
                const SizedBox(height: 4),
                Text(
                  _greeting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FunText.body(color: Palette.ink, size: 14),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: AppStore.instance,
            builder: (context, _) => Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Palette.ink, width: 2.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StarIcon(size: 26),
                  const SizedBox(width: 4),
                  Text('${AppStore.instance.totalStars}',
                      style: FunText.title(size: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CandyIconButton(
              icon: Icons.settings_rounded, onTap: _openParents, size: 46),
        ],
      ),
    );
  }

  Widget _categories() {
    final items = <(GameCategory?, String, Candy)>[
      (null, '全部', Candy.sun),
      for (final c in GameCategory.values) (c, c.label, c.candy),
    ];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (category, label, candy) = items[i];
          final selected = category == _category;
          return Pressable(
            onTap: () => _selectCategory(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? candy.face : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Palette.ink, width: selected ? 3 : 2),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: candy.shade, offset: const Offset(0, 4))
                      ]
                    : const [],
              ),
              child: Text(
                label,
                style: FunText.title(
                        size: 16, color: selected ? Colors.white : Palette.ink)
                    .copyWith(
                  shadows: selected
                      ? const [
                          Shadow(color: Palette.ink, offset: Offset(0, 1.5))
                        ]
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
