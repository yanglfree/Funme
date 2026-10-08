import '../core/art/game_icons.dart';
import '../core/game/game_info.dart';
import '../core/theme/palette.dart';
import 'gomoku/gomoku_page.dart';
import 'jungle/jungle_page.dart';
import 'junqi/junqi_page.dart';
import 'tictactoe/tictactoe_page.dart';
import 'xiangqi/xiangqi_page.dart';

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

  static const xiangqi = GameInfo(
    id: 'xiangqi',
    name: '象棋',
    tagline: '楚河汉界大作战',
    category: GameCategory.board,
    candy: Candy.cherry,
    icon: GameIcons.xiangqi,
    builder: XiangqiPage.create,
    players: '1-2人',
    age: '6岁+',
    rules: [
      '红方先走，双方轮流走一步，把对方的“将/帅”逼得无路可走就赢了。',
      '车走直线，不限格数；马走“日”字，前面有子挡住（蹩马腿）就不能走。',
      '相/象走“田”字，田字中心有子不能走，而且不能过河。',
      '仕/士只能在九宫里斜走一步；将/帅只能在九宫里直走一步，两个老将不能面对面。',
      '炮平时和车一样走，吃子时必须隔着一个棋子“翻山”去吃。',
      '兵/卒只能向前，过了河以后还能左右走，但永远不能后退。',
      '点一下自己的棋子，绿点就是能走的地方，红圈表示可以吃掉对方。',
    ],
  );

  static const jungle = GameInfo(
    id: 'jungle',
    name: '斗兽棋',
    tagline: '大象老鼠谁厉害',
    category: GameCategory.board,
    candy: Candy.lime,
    icon: GameIcons.jungle,
    builder: JunglePage.create,
    players: '1-2人',
    age: '5岁+',
    rules: [
      '每只动物都有战斗力数字：象8 > 狮7 > 虎6 > 豹5 > 狼4 > 狗3 > 猫2 > 鼠1。',
      '每次走一格（上下左右），数字大的可以吃掉数字一样或更小的动物。',
      '小老鼠能钻进象鼻子吃掉大象，但大象吃不了老鼠！',
      '只有老鼠会游泳；狮子和老虎能直接跳过河，但河里有老鼠挡着就跳不过去。',
      '对方家门口的陷阱里，谁都能把掉进去的动物吃掉。',
      '先冲进对方的兽穴（小房子）就赢啦！',
    ],
  );

  static const junqi = GameInfo(
    id: 'junqi',
    name: '军棋',
    tagline: '翻翻棋 · 扛军旗',
    category: GameCategory.board,
    candy: Candy.mint,
    icon: GameIcons.junqi,
    builder: JunqiPage.create,
    players: '1-2人',
    age: '7岁+',
    rules: [
      '开局所有棋子都背面朝上。第一个翻开的棋子是什么颜色，你就是那一方。',
      '每回合可以翻开一个棋子，或者走一步自己的棋子。',
      '官大的吃官小的：司令 > 军长 > 师长 > 旅长 > 团长 > 营长 > 连长 > 排长 > 工兵，一样大就同归于尽。',
      '炸弹碰到谁都会一起消失；地雷和军旗不能移动，碰到地雷的棋子会被炸掉，只有工兵能排雷。',
      '黑白条纹的是铁路，可以一口气走很远；工兵在铁路上还能拐弯。',
      '圆圈是行营，躲在里面不会被吃。扛走对方的军旗就赢啦！',
    ],
  );

  static const all = <GameInfo>[
    xiangqi,
    junqi,
    jungle,
    gomoku,
    tictactoe,
  ];
}

List<GameInfo> get gameCatalog => GameCatalog.all;
