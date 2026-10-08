import 'package:flutter/widgets.dart';

import '../theme/palette.dart';

enum GameCategory {
  board('棋类对战', Candy.ocean),
  puzzle('益智烧脑', Candy.grape),
  arcade('手速反应', Candy.orange);

  const GameCategory(this.label, this.candy);

  final String label;
  final Candy candy;
}

/// Paints a game's card icon. [t] runs 0→1 repeatedly for idle animation.
typedef GameIconPainter = void Function(Canvas canvas, Size size, double t);

/// Static description of one game in the catalog.
@immutable
class GameInfo {
  const GameInfo({
    required this.id,
    required this.name,
    required this.tagline,
    required this.category,
    required this.candy,
    required this.icon,
    required this.builder,
    required this.rules,
    this.players = '1-2人',
    this.age = '5岁+',
  });

  final String id;
  final String name;
  final String tagline;
  final GameCategory category;
  final Candy candy;
  final GameIconPainter icon;
  final WidgetBuilder builder;

  /// Rule bullets shown in the rules sheet, simplest first.
  final List<String> rules;
  final String players;
  final String age;
}
