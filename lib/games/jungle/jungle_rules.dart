import 'dart:math' as math;
import 'dart:typed_data';

/// Jungle / animal chess (斗兽棋) on a 7×9 board. Index = y * 7 + x.
/// Side 0 starts at the bottom (y = 8 den) and moves first.
/// Cell value 0 = empty, otherwise `rank | side << 4` with rank 1 (mouse)
/// … 8 (elephant).
abstract final class Jg {
  static const width = 7;
  static const height = 9;
  static const cells = width * height;

  static const mouse = 1;
  static const cat = 2;
  static const dog = 3;
  static const wolf = 4;
  static const leopard = 5;
  static const tiger = 6;
  static const lion = 7;
  static const elephant = 8;

  static int rank(int v) => v & 15;
  static int side(int v) => v >> 4;
  static int make(int rank, int side) => rank | (side << 4);

  static const names = ['', '鼠', '猫', '狗', '狼', '豹', '虎', '狮', '象'];

  /// Den of [side]: side 0 defends the bottom den.
  static int den(int side) => side == 0 ? 8 * 7 + 3 : 3;

  static bool isWater(int i) {
    final x = i % 7;
    final y = i ~/ 7;
    return y >= 3 && y <= 5 && (x == 1 || x == 2 || x == 4 || x == 5);
  }

  /// Which side owns the trap at [i] (the traps around its den), or -1.
  static int trapOwner(int i) {
    const bottom = [8 * 7 + 2, 8 * 7 + 4, 7 * 7 + 3];
    const top = [2, 4, 7 + 3];
    if (bottom.contains(i)) return 0;
    if (top.contains(i)) return 1;
    return -1;
  }
}

class JgMove {
  const JgMove(this.from, this.to);

  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      other is JgMove && other.from == from && other.to == to;

  @override
  int get hashCode => from * 64 + to;
}

class JgState {
  const JgState({
    required this.board,
    required this.ids,
    required this.turn,
    this.quiet = 0,
    this.lastCapture,
  });

  factory JgState.initial() {
    final board = List<int>.filled(Jg.cells, 0);
    const top = <(int, int, int)>[
      (0, 0, Jg.lion),
      (6, 0, Jg.tiger),
      (1, 1, Jg.dog),
      (5, 1, Jg.cat),
      (0, 2, Jg.mouse),
      (2, 2, Jg.leopard),
      (4, 2, Jg.wolf),
      (6, 2, Jg.elephant),
    ];
    for (final (x, y, r) in top) {
      board[y * 7 + x] = Jg.make(r, 1);
      board[(8 - y) * 7 + (6 - x)] = Jg.make(r, 0);
    }
    var id = 1;
    return JgState(
        board: board, ids: [for (final v in board) v == 0 ? 0 : id++], turn: 0);
  }

  final List<int> board;
  final List<int> ids;
  final int turn;
  final int quiet;
  final int? lastCapture;

  static const quietLimit = 100;

  JgState play(JgMove m) {
    final b = List<int>.of(board);
    final i = List<int>.of(ids);
    final captured = b[m.to];
    b[m.to] = b[m.from];
    b[m.from] = 0;
    i[m.to] = i[m.from];
    i[m.from] = 0;
    return JgState(
      board: b,
      ids: i,
      turn: 1 - turn,
      quiet: captured == 0 ? quiet + 1 : 0,
      lastCapture: captured == 0 ? null : captured,
    );
  }

  List<JgMove> legalMoves() {
    final out = <int>[];
    JgEngine(board).generate(turn, out);
    return [for (final m in out) JgMove(m >> 6, m & 63)];
  }

  List<JgMove> legalMovesFrom(int from) => [
        for (final m in legalMoves())
          if (m.from == from) m,
      ];

  /// Winner if the game is over: den entered, or the side to move is stuck.
  int? get winner {
    for (final side in [0, 1]) {
      final den = Jg.den(1 - side);
      if (board[den] != 0 && Jg.side(board[den]) == side) return side;
    }
    if (legalMoves().isEmpty) return 1 - turn;
    return null;
  }
}

class JgEngine {
  JgEngine(List<int> cells) : b = Int8List.fromList(cells);

  final Int8List b;
  final Stopwatch _clock = Stopwatch();
  int _deadlineMs = 1 << 30;
  bool _aborted = false;
  int nodes = 0;

  static const _value = [0, 350, 200, 280, 380, 480, 800, 900, 1000];

  /// Whether [attacker] standing on [from] may capture [defender] on [to].
  bool canCapture(int attacker, int from, int defender, int to) {
    final ar = Jg.rank(attacker);
    final dr = Jg.rank(defender);
    final fromWater = Jg.isWater(from);
    final toWater = Jg.isWater(to);
    // Water and land don't fight each other.
    if (fromWater != toWater) return false;
    if (Jg.trapOwner(to) == Jg.side(attacker)) return true;
    if (ar == Jg.mouse && dr == Jg.elephant) return true;
    if (ar == Jg.elephant && dr == Jg.mouse) return false;
    return ar >= dr;
  }

  void generate(int side, List<int> out) {
    for (var from = 0; from < Jg.cells; from++) {
      final v = b[from];
      if (v == 0 || Jg.side(v) != side) continue;
      final r = Jg.rank(v);
      final x = from % 7;
      final y = from ~/ 7;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        var tx = x + dx;
        var ty = y + dy;
        if (tx < 0 || tx > 6 || ty < 0 || ty > 8) continue;
        var to = ty * 7 + tx;
        if (Jg.isWater(to)) {
          if (r == Jg.mouse) {
            // Mouse swims.
          } else if (r == Jg.lion || r == Jg.tiger) {
            var blocked = false;
            while (Jg.isWater(to)) {
              if (b[to] != 0) blocked = true;
              tx += dx;
              ty += dy;
              to = ty * 7 + tx;
            }
            if (blocked) continue;
          } else {
            continue;
          }
        }
        if (to == Jg.den(side)) continue;
        final t = b[to];
        if (t != 0) {
          if (Jg.side(t) == side) continue;
          if (!canCapture(v, from, t, to)) continue;
        }
        out.add(from << 6 | to);
      }
    }
  }

  int evaluate(int side) {
    var score = 0;
    for (var i = 0; i < Jg.cells; i++) {
      final v = b[i];
      if (v == 0) continue;
      final s = Jg.side(v);
      final r = Jg.rank(v);
      final enemyDen = Jg.den(1 - s);
      final dx = (i % 7 - enemyDen % 7).abs();
      final dy = (i ~/ 7 - enemyDen ~/ 7).abs();
      final dist = dx + dy;
      var value = _value[r] + (12 - dist) * (r >= Jg.leopard ? 10 : 6);
      if (dist == 1) value += 300;
      if (Jg.trapOwner(i) == 1 - s) value -= _value[r] ~/ 2;
      score += s == side ? value : -value;
    }
    return score;
  }

  static const _win = 100000;

  bool _wonBy(int side) {
    final den = Jg.den(1 - side);
    return b[den] != 0 && Jg.side(b[den]) == side;
  }

  int _search(int side, int depth, int alpha, int beta, int ply) {
    if ((nodes & 1023) == 0 && _clock.elapsedMilliseconds > _deadlineMs) {
      _aborted = true;
    }
    if (_aborted) return 0;
    nodes++;
    if (_wonBy(1 - side)) return -_win + ply;
    if (depth <= 0) return evaluate(side);
    final moves = <int>[];
    generate(side, moves);
    if (moves.isEmpty) return -_win + ply;
    moves.sort((a, c) => _order(c).compareTo(_order(a)));
    var best = -_win;
    for (final m in moves) {
      final from = m >> 6;
      final to = m & 63;
      final captured = b[to];
      b[to] = b[from];
      b[from] = 0;
      final score = -_search(1 - side, depth - 1, -beta, -alpha, ply + 1);
      b[from] = b[to];
      b[to] = captured;
      if (_aborted) return 0;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _order(int m) {
    final to = m & 63;
    final mover = b[m >> 6];
    var s = 0;
    if (to == Jg.den(1 - Jg.side(mover))) s += 100000;
    if (b[to] != 0) s += 1000 + _value[Jg.rank(b[to])];
    return s;
  }

  int? bestMove(int side,
      {required int maxDepth, int timeMs = 1200, int noise = 0}) {
    final rnd = math.Random();
    final root = <int>[];
    generate(side, root);
    if (root.isEmpty) return null;
    _clock
      ..reset()
      ..start();
    _deadlineMs = timeMs;
    _aborted = false;
    var ordered = List<int>.of(root)
      ..sort((a, c) => _order(c).compareTo(_order(a)));
    var best = ordered.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      final scored = <(int, int)>[];
      var alpha = -_win - 1;
      for (final m in ordered) {
        final from = m >> 6;
        final to = m & 63;
        final captured = b[to];
        b[to] = b[from];
        b[from] = 0;
        var score = _wonBy(side)
            ? _win
            : -_search(1 - side, depth - 1, -_win - 1, -alpha + noise, 1);
        b[from] = b[to];
        b[to] = captured;
        if (_aborted) break;
        if (noise > 0) score += rnd.nextInt(noise * 2 + 1) - noise;
        scored.add((m, score));
        if (score > alpha) alpha = score;
      }
      if (scored.isEmpty) break;
      scored.sort((a, c) => c.$2.compareTo(a.$2));
      best = scored.first.$1;
      if (_aborted || scored.first.$2 >= _win - 100) break;
      ordered = [for (final s in scored) s.$1];
    }
    return best;
  }
}

/// Isolate entry: (board, side, level) → encoded move or -1.
int jungleAiEntry((List<int>, int, int) args) {
  final (board, side, level) = args;
  final engine = JgEngine(board);
  final move = switch (level) {
    0 => engine.bestMove(side, maxDepth: 2, noise: 220),
    1 => engine.bestMove(side, maxDepth: 4, timeMs: 900, noise: 20),
    _ => engine.bestMove(side, maxDepth: 8, timeMs: 1500),
  };
  return move ?? -1;
}
