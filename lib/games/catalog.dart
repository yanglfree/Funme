import '../core/art/game_icons.dart';
import '../core/game/game_info.dart';
import '../core/theme/palette.dart';
import 'checkers/checkers_page.dart';
import 'connect4/connect4_page.dart';
import 'gomoku/gomoku_page.dart';
import 'jungle/jungle_page.dart';
import 'junqi/junqi_page.dart';
import 'ludo/ludo_page.dart';
import 'merge2048/merge2048_page.dart';
import 'reversi/reversi_page.dart';
import 'snake/snake_page.dart';
import 'sudoku/sudoku_page.dart';
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

  static const checkers = GameInfo(
    id: 'checkers',
    name: '跳棋',
    tagline: '弹珠连连跳回家',
    category: GameCategory.board,
    candy: Candy.grape,
    icon: GameIcons.checkers,
    builder: CheckersPage.create,
    players: '2-6人',
    age: '5岁+',
    rules: [
      '每个人有 10 颗弹珠，目标是把它们全部搬到正对面的三角营地。',
      '弹珠可以走到旁边的空洞里，一次走一步。',
      '如果旁边有任何颜色的弹珠，并且它后面是空洞，就可以跳过去！',
      '跳过去以后还能接着跳，一口气连跳好多次。',
      '谁先把对面营地填满就赢啦！',
    ],
  );

  static const ludo = GameInfo(
    id: 'ludo',
    name: '飞行棋',
    tagline: '掷骰子 起飞啦',
    category: GameCategory.board,
    candy: Candy.ocean,
    icon: GameIcons.ludo,
    builder: LudoPage.create,
    players: '2-4人',
    age: '4岁+',
    rules: [
      '点骰子掷出点数，掷到 1、3、6 飞机停到起飞区，掷到 5 直接飞上跑道；起飞后要等下一次掷骰才能走。连掷三个 6 会被罚，最远的飞机回机库。',
      '掷到 6（包括起飞时）还能再掷一次，但连掷三个 6 就不算啦！',
      '飞机按点数一格一格往前飞；停在和自己同色的格子上，会再往前跳 4 格。',
      '停在带小飞机图案的格子上，可以沿着虚线一下子飞过去！',
      '停在别人飞机的格子上，会把它撞回机场。',
      '飞进自己颜色的跑道，点数刚好才能到达中心，多出来的会往回退。',
      '所有飞机都到家就赢啦！',
    ],
  );

  static const snake = GameInfo(
    id: 'snake',
    name: '贪吃蛇',
    tagline: '吃水果 长长长',
    category: GameCategory.arcade,
    candy: Candy.mint,
    icon: GameIcons.snake,
    builder: SnakePage.create,
    players: '1人',
    age: '5岁+',
    rules: [
      '在棋盘上滑动手指，或者按方向键，告诉小蛇往哪里走。',
      '吃到水果小蛇会变长，还能得 10 分。',
      '每吃 5 个水果会出现金色星星，赶快去吃能得 50 分！',
      '小心别撞到墙（选了“可以穿墙”就不怕）和自己的身体。',
      '小蛇越长跑得越快，加油冲高分！',
    ],
  );

  static const reversi = GameInfo(
    id: 'reversi',
    name: '黑白棋',
    tagline: '夹住就翻面',
    category: GameCategory.board,
    candy: Candy.slate,
    icon: GameIcons.reversi,
    builder: ReversiPage.create,
    players: '1-2人',
    age: '6岁+',
    rules: [
      '黑棋先下。下的棋子要和自己的另一颗棋子把对方的棋子“夹”在中间。',
      '被夹住的对方棋子会全部翻面，变成你的颜色！',
      '横、竖、斜都可以夹，一次能翻好多颗。',
      '棋盘上的小白点就是可以下的地方；没地方下时会自动跳过。',
      '下满或者都没地方下时，谁的棋子多谁就赢。四个角最珍贵哦！',
    ],
  );

  static const connect4 = GameInfo(
    id: 'connect4',
    name: '四子棋',
    tagline: '投币连四颗',
    category: GameCategory.board,
    candy: Candy.sun,
    icon: GameIcons.connect4,
    builder: Connect4Page.create,
    players: '1-2人',
    age: '4岁+',
    rules: [
      '两人轮流把棋子投进一列，棋子会掉到最下面。',
      '先把四颗自己的棋子连成一条线（横、竖、斜）就赢啦！',
      '手指按住可以先看看棋子会掉到哪里，松手才投下去。',
      '别忘了堵住对方快要连成的线！',
    ],
  );

  static const merge2048 = GameInfo(
    id: 'merge2048',
    name: '2048',
    tagline: '滑动合并 冲向 2048',
    category: GameCategory.puzzle,
    candy: Candy.orange,
    icon: GameIcons.merge2048,
    builder: Merge2048Page.create,
    players: '1人',
    age: '6岁+',
    rules: [
      '上下左右滑动屏幕，所有数字方块会一起往那个方向滑。',
      '两个相同的数字撞在一起，会合成一个更大的数字（2+2=4，4+4=8……）。',
      '每次滑动之后，空地上会冒出一个新的 2 或 4。',
      '合成出 2048 就赢啦！之后还可以继续冲更高的分数。',
      '方块把格子占满、又没有能合并的时候，游戏就结束了。',
      '滑错了不要紧，点右上角的撤销按钮可以退回上一步。',
    ],
  );

  static const sudoku = GameInfo(
    id: 'sudoku',
    name: '数独',
    tagline: '1到9 不重复',
    category: GameCategory.puzzle,
    candy: Candy.grape,
    icon: GameIcons.sudoku,
    builder: SudokuPage.create,
    players: '1人',
    age: '7岁+',
    rules: [
      '把 1 到 9 填进空格，让每一行、每一列、每个粗线框起来的 3×3 小宫里，数字都不重复。',
      '先点一个空格，再点下面的数字键填进去；再点一次同样的数字可以擦掉。',
      '填错重复的数字会变红，提醒你检查一下。',
      '点铅笔按钮可以切换成“记笔记”，在格子里写下可能的小数字。',
      '实在想不出来，就点灯泡按钮要一个提示，但是星星会少一颗哦。',
    ],
  );

  static const all = <GameInfo>[
    ludo,
    checkers,
    xiangqi,
    junqi,
    jungle,
    gomoku,
    reversi,
    connect4,
    tictactoe,
    merge2048,
    sudoku,
    snake,
  ];
}

List<GameInfo> get gameCatalog => GameCatalog.all;
