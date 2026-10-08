import '../core/art/game_icons.dart';
import '../core/game/game_info.dart';
import '../core/theme/palette.dart';
import 'gomoku/gomoku_page.dart';
import 'tictactoe/tictactoe_page.dart';

/// Every game in the app, in home-screen order.
abstract final class GameCatalog {
  static const tictactoe = GameInfo(
    id: 'tictactoe',
    name: '井字棋',
    tagline: '三个连一线就赢',
    category: GameCategory.board,
    candy: Candy.berry,
    icon: GameIcons.tictactoe,
    builder: TicTacToePage.create,
    players: '1-2人',
    age: '4岁+',
    rules: [
      '两人轮流在 3×3 的格子里画上自己的记号：叉叉或圈圈。',
      '谁先把三个记号连成一条线（横、竖、斜都可以）就赢啦！',
      '格子下满还没人连成线，就是平局。',
      '小窍门：先占中间的格子，更容易赢哦。',
    ],
  );

  static const gomoku = GameInfo(
    id: 'gomoku',
    name: '五子棋',
    tagline: '五颗连一线',
    category: GameCategory.board,
    candy: Candy.wood,
    icon: GameIcons.gomoku,
    builder: GomokuPage.create,
    players: '1-2人',
    age: '5岁+',
    rules: [
      '黑棋先下，两人轮流把棋子放在线的交叉点上。',
      '谁先把五颗自己的棋子连成一条线（横、竖、斜）就赢啦！',
      '按住棋盘可以预览位置，松开手指才会落子。',
      '要一边连自己的棋，一边堵住对方快连成的线哦。',
      '小朋友可以先选 9×9 的小棋盘练习。',
    ],
  );

  static const all = <GameInfo>[
    gomoku,
    tictactoe,
  ];
}

List<GameInfo> get gameCatalog => GameCatalog.all;
