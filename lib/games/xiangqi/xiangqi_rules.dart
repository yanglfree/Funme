import 'dart:math' as math;
import 'dart:typed_data';

/// Chinese chess (象棋). Board index = y * 9 + x, y = 0 is black's back rank.
/// Side 0 = red (moves first, bottom), side 1 = black (top).
/// Cell value 0 = empty, otherwise `type | side << 3`.
abstract final class Xq {
  static const king = 1;
  static const advisor = 2;
  static const elephant = 3;
  static const horse = 4;
  static const rook = 5;
  static const cannon = 6;
  static const pawn = 7;

  static int type(int v) => v & 7;
  static int side(int v) => v >> 3;
  static int make(int type, int side) => type | (side << 3);

  static const redNames = ['', '帅', '仕', '相', '马', '车', '炮', '兵'];
  static const blackNames = ['', '将', '士', '象', '马', '车', '炮', '卒'];

  static String name(int v) =>
      side(v) == 0 ? redNames[type(v)] : blackNames[type(v)];

  static const values = [0, 10000, 200, 200, 420, 900, 450, 100];
}

class XqMove {
  const XqMove(this.from, this.to);

  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      other is XqMove && other.from == from && other.to == to;

  @override
  int get hashCode => from * 90 + to;

  @override
  String toString() => 'XqMove($from→$to)';
}

class XqState {
  const XqState({
    required this.board,
    required this.ids,
    required this.turn,
    this.quiet = 0,
    this.lastCapture,
  });

  factory XqState.initial() {
    final board = List<int>.filled(90, 0);
    const back = [
      Xq.rook,
      Xq.horse,
      Xq.elephant,
      Xq.advisor,
      Xq.king,
      Xq.advisor,
      Xq.elephant,
      Xq.horse,
      Xq.rook
    ];
    for (var x = 0; x < 9; x++) {
      board[x] = Xq.make(back[x], 1);
      board[81 + x] = Xq.make(back[x], 0);
    }
    for (final x in [1, 7]) {
      board[2 * 9 + x] = Xq.make(Xq.cannon, 1);
      board[7 * 9 + x] = Xq.make(Xq.cannon, 0);
    }
    for (final x in [0, 2, 4, 6, 8]) {
      board[3 * 9 + x] = Xq.make(Xq.pawn, 1);
      board[6 * 9 + x] = Xq.make(Xq.pawn, 0);
    }
    var next = 1;
    final ids = [for (final v in board) v == 0 ? 0 : next++];
    return XqState(board: board, ids: ids, turn: 0);
  }

  final List<int> board;

  /// Stable piece ids parallel to [board] (0 = none), for animations.
  final List<int> ids;
  final int turn;

  /// Plies since the last capture (draw after [quietLimit]).
  final int quiet;

  /// Piece captured by the move that produced this state, if any.
  final int? lastCapture;

  static const quietLimit = 120;

  XqState play(XqMove m) {
    final b = List<int>.of(board);
    final i = List<int>.of(ids);
    final captured = b[m.to];
    b[m.to] = b[m.from];
    b[m.from] = 0;
    i[m.to] = i[m.from];
    i[m.from] = 0;
    return XqState(
      board: b,
      ids: i,
      turn: 1 - turn,
      quiet: captured == 0 ? quiet + 1 : 0,
      lastCapture: captured == 0 ? null : captured,
    );
  }

  List<XqMove> legalMoves() {
    final engine = XqEngine(board);
    return [
      for (final code in engine.legalMoves(turn)) XqMove(code >> 7, code & 127),
    ];
  }

  List<XqMove> legalMovesFrom(int from) => [
        for (final m in legalMoves())
          if (m.from == from) m,
      ];

  bool inCheck(int side) => XqEngine(board).inCheck(side);
}

/// Mutable search board with make/unmake, move generation and evaluation.
class XqEngine {
  XqEngine(List<int> cells) : b = Int8List.fromList(cells);

  final Int8List b;
  final _killers = <int, int>{};
  late final Stopwatch _clock = Stopwatch();
  int _deadlineMs = 1 << 30;
  bool _aborted = false;
  int nodes = 0;

  /// Capture-sequence depth at leaves; 0 makes the engine naively greedy.
  int qDepth = 4;

  static bool _inPalace(int x, int y, int side) =>
      x >= 3 && x <= 5 && (side == 0 ? y >= 7 : y <= 2);

  static bool _ownHalf(int y, int side) => side == 0 ? y >= 5 : y <= 4;

  int kingSquare(int side) {
    final k = Xq.make(Xq.king, side);
    for (var i = 0; i < 90; i++) {
      if (b[i] == k) return i;
    }
    return -1;
  }

  /// Pseudo-legal moves encoded as `from << 7 | to`.
  void generate(int side, List<int> out, {bool capturesOnly = false}) {
    for (var from = 0; from < 90; from++) {
      final v = b[from];
      if (v == 0 || Xq.side(v) != side) continue;
      final x = from % 9;
      final y = from ~/ 9;
      void add(int tx, int ty) {
        if (tx < 0 || tx > 8 || ty < 0 || ty > 9) return;
        final to = ty * 9 + tx;
        final t = b[to];
        if (t != 0 && Xq.side(t) == side) return;
        if (capturesOnly && t == 0) return;
        out.add(from << 7 | to);
      }

      switch (Xq.type(v)) {
        case Xq.king:
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            if (_inPalace(x + dx, y + dy, side)) add(x + dx, y + dy);
          }
        case Xq.advisor:
          for (final (dx, dy) in const [(1, 1), (-1, 1), (1, -1), (-1, -1)]) {
            if (_inPalace(x + dx, y + dy, side)) add(x + dx, y + dy);
          }
        case Xq.elephant:
          for (final (dx, dy) in const [(2, 2), (-2, 2), (2, -2), (-2, -2)]) {
            final tx = x + dx;
            final ty = y + dy;
            if (tx < 0 || tx > 8 || ty < 0 || ty > 9 || !_ownHalf(ty, side)) {
              continue;
            }
            if (b[(y + dy ~/ 2) * 9 + x + dx ~/ 2] != 0) continue;
            add(tx, ty);
          }
        case Xq.horse:
          for (final (dx, dy) in const [
            (1, 2),
            (-1, 2),
            (1, -2),
            (-1, -2),
            (2, 1),
            (2, -1),
            (-2, 1),
            (-2, -1)
          ]) {
            final lx = dx.abs() == 2 ? x + dx ~/ 2 : x;
            final ly = dy.abs() == 2 ? y + dy ~/ 2 : y;
            final tx = x + dx;
            final ty = y + dy;
            if (tx < 0 || tx > 8 || ty < 0 || ty > 9) continue;
            if (b[ly * 9 + lx] != 0) continue;
            add(tx, ty);
          }
        case Xq.rook:
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            var tx = x + dx;
            var ty = y + dy;
            while (tx >= 0 && tx <= 8 && ty >= 0 && ty <= 9) {
              final t = b[ty * 9 + tx];
              if (t == 0) {
                if (!capturesOnly) out.add(from << 7 | (ty * 9 + tx));
              } else {
                if (Xq.side(t) != side) out.add(from << 7 | (ty * 9 + tx));
                break;
              }
              tx += dx;
              ty += dy;
            }
          }
        case Xq.cannon:
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            var tx = x + dx;
            var ty = y + dy;
            var screened = false;
            while (tx >= 0 && tx <= 8 && ty >= 0 && ty <= 9) {
              final t = b[ty * 9 + tx];
              if (!screened) {
                if (t == 0) {
                  if (!capturesOnly) out.add(from << 7 | (ty * 9 + tx));
                } else {
                  screened = true;
                }
              } else if (t != 0) {
                if (Xq.side(t) != side) out.add(from << 7 | (ty * 9 + tx));
                break;
              }
              tx += dx;
              ty += dy;
            }
          }
        case Xq.pawn:
          final forward = side == 0 ? -1 : 1;
          add(x, y + forward);
          if (!_ownHalf(y, side)) {
            add(x - 1, y);
            add(x + 1, y);
          }
      }
    }
  }

  /// True when [side]'s king is attacked (including facing kings).
  bool inCheck(int side) {
    final k = kingSquare(side);
    if (k < 0) return true;
    final kx = k % 9;
    final ky = k ~/ 9;
    final enemy = 1 - side;
    // Lines: rooks, cannons and the facing king.
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      var x = kx + dx;
      var y = ky + dy;
      var screens = 0;
      while (x >= 0 && x <= 8 && y >= 0 && y <= 9) {
        final t = b[y * 9 + x];
        if (t != 0) {
          if (screens == 0) {
            if (Xq.side(t) == enemy) {
              final tt = Xq.type(t);
              if (tt == Xq.rook) return true;
              if (tt == Xq.king && dx == 0) return true;
            }
            screens = 1;
          } else {
            if (Xq.side(t) == enemy && Xq.type(t) == Xq.cannon) return true;
            break;
          }
        }
        x += dx;
        y += dy;
      }
    }
    // Horses: a horse at h hits the king unless its leg is blocked.
    for (final (dx, dy) in const [
      (1, 2),
      (-1, 2),
      (1, -2),
      (-1, -2),
      (2, 1),
      (2, -1),
      (-2, 1),
      (-2, -1)
    ]) {
      final hx = kx + dx;
      final hy = ky + dy;
      if (hx < 0 || hx > 8 || hy < 0 || hy > 9) continue;
      final h = b[hy * 9 + hx];
      if (h == 0 || Xq.side(h) != enemy || Xq.type(h) != Xq.horse) continue;
      final lx = dx.abs() == 2 ? hx - dx ~/ 2 : hx;
      final ly = dy.abs() == 2 ? hy - dy ~/ 2 : hy;
      if (b[ly * 9 + lx] == 0) return true;
    }
    // Pawns: the enemy pawn steps toward us, so it sits "behind" from its view.
    final pawn = Xq.make(Xq.pawn, enemy);
    final pawnForward = enemy == 0 ? -1 : 1;
    final py = ky - pawnForward;
    if (py >= 0 && py <= 9 && b[py * 9 + kx] == pawn) return true;
    for (final px in [kx - 1, kx + 1]) {
      if (px >= 0 &&
          px <= 8 &&
          b[ky * 9 + px] == pawn &&
          !_ownHalf(ky, enemy)) {
        return true;
      }
    }
    return false;
  }

  List<int> legalMoves(int side) {
    final pseudo = <int>[];
    generate(side, pseudo);
    final legal = <int>[];
    for (final m in pseudo) {
      final from = m >> 7;
      final to = m & 127;
      final captured = b[to];
      b[to] = b[from];
      b[from] = 0;
      if (!inCheck(side)) legal.add(m);
      b[from] = b[to];
      b[to] = captured;
    }
    return legal;
  }

  // ---- Evaluation -------------------------------------------------------

  static int _positional(int type, int side, int x, int y) {
    // Distance travelled toward the enemy, 0 at own back rank.
    final adv = side == 0 ? 9 - y : y;
    final center = 4 - (x - 4).abs();
    switch (type) {
      case Xq.pawn:
        if (adv <= 4) return adv >= 3 ? 10 : 0;
        // Crossed the river: worth double, more near the palace.
        return 90 +
            center * 8 +
            (adv >= 6 && adv <= 8 ? 30 : 0) -
            (adv == 9 ? 40 : 0);
      case Xq.horse:
        return center * 8 + math.min(adv, 7) * 6 - (x == 0 || x == 8 ? 20 : 0);
      case Xq.rook:
        return center * 4 + math.min(adv, 6) * 5;
      case Xq.cannon:
        return (x == 4 ? 20 : center * 3) + (adv <= 2 ? 10 : 0);
      default:
        return 0;
    }
  }

  /// Whether [evaluate] rewards pieces for pressing on the enemy king.
  bool kingPressure = true;

  /// Static score from [side]'s point of view.
  int evaluate(int side) {
    var score = 0;
    final kings = [kingSquare(0), kingSquare(1)];
    for (var i = 0; i < 90; i++) {
      final v = b[i];
      if (v == 0) continue;
      final t = Xq.type(v);
      final s = Xq.side(v);
      final x = i % 9;
      final y = i ~/ 9;
      var value = Xq.values[t] + _positional(t, s, x, y);
      if (kingPressure) {
        final k = kings[1 - s];
        if (k >= 0) {
          final dist = (x - k % 9).abs() + (y - k ~/ 9).abs();
          final weight = switch (t) {
            Xq.rook => 3,
            Xq.horse => 4,
            Xq.cannon => 3,
            Xq.pawn => 2,
            _ => 0,
          };
          value += weight * (14 - dist);
        }
      }
      score += s == side ? value : -value;
    }
    return score;
  }

  // ---- Search -------------------------------------------------------------

  static const mate = 100000;

  int _orderScore(int m, int ply) {
    final victim = b[m & 127];
    if (victim != 0) {
      return 1000000 +
          Xq.values[Xq.type(victim)] * 10 -
          Xq.values[Xq.type(b[m >> 7])] ~/ 10;
    }
    return _killers[ply] == m ? 900000 : 0;
  }

  void _sort(List<int> moves, int ply) {
    final scored = [for (final m in moves) (m, _orderScore(m, ply))]
      ..sort((a, c) => c.$2.compareTo(a.$2));
    for (var i = 0; i < moves.length; i++) {
      moves[i] = scored[i].$1;
    }
  }

  int _quiesce(int side, int alpha, int beta, int depth) {
    nodes++;
    final stand = evaluate(side);
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    if (depth <= 0) return stand;
    final moves = <int>[];
    generate(side, moves, capturesOnly: true);
    _sort(moves, 99);
    for (final m in moves) {
      final from = m >> 7;
      final to = m & 127;
      final captured = b[to];
      if (Xq.type(captured) == Xq.king) return mate;
      b[to] = b[from];
      b[from] = 0;
      if (!inCheck(side)) {
        final score = -_quiesce(1 - side, -beta, -alpha, depth - 1);
        b[from] = b[to];
        b[to] = captured;
        if (score >= beta) return score;
        if (score > alpha) alpha = score;
      } else {
        b[from] = b[to];
        b[to] = captured;
      }
    }
    return alpha;
  }

  int _search(int side, int depth, int alpha, int beta, int ply) {
    if ((nodes & 1023) == 0 && _clock.elapsedMilliseconds > _deadlineMs) {
      _aborted = true;
    }
    if (_aborted) return 0;
    nodes++;
    // Extend while in check (bounded by ply) so forced lines are not cut off.
    if (depth <= 0 && ply < 24 && inCheck(side)) depth = 1;
    if (depth <= 0) return _quiesce(side, alpha, beta, qDepth);
    final moves = <int>[];
    generate(side, moves);
    _sort(moves, ply);
    var legal = 0;
    var best = -mate;
    for (final m in moves) {
      final from = m >> 7;
      final to = m & 127;
      final captured = b[to];
      b[to] = b[from];
      b[from] = 0;
      if (inCheck(side)) {
        b[from] = b[to];
        b[to] = captured;
        continue;
      }
      legal++;
      final score = -_search(1 - side, depth - 1, -beta, -alpha, ply + 1);
      b[from] = b[to];
      b[to] = captured;
      if (_aborted) return 0;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) {
        if (captured == 0) _killers[ply] = m;
        break;
      }
    }
    // No legal move: checkmate or stalemate — both lose in xiangqi.
    if (legal == 0) return -mate + ply;
    return best;
  }

  /// Best move for [side] using iterative deepening within [timeMs].
  int? bestMove(int side,
      {required int maxDepth,
      int timeMs = 1500,
      int noise = 0,
      math.Random? random}) {
    final rnd = random ?? math.Random();
    final root = legalMoves(side);
    if (root.isEmpty) return null;
    if (root.length == 1) return root.first;
    _clock
      ..reset()
      ..start();
    _deadlineMs = timeMs;
    _aborted = false;
    var ordered = List<int>.of(root);
    _sort(ordered, 0);
    int? best = ordered.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      final scored = <(int, int)>[];
      var alpha = -mate - 1;
      for (final m in ordered) {
        final from = m >> 7;
        final to = m & 127;
        final captured = b[to];
        b[to] = b[from];
        b[from] = 0;
        var score = -_search(1 - side, depth - 1, -mate - 1,
            -alpha + (noise > 0 ? noise : 0), 1);
        b[from] = b[to];
        b[to] = captured;
        if (_aborted) break;
        if (noise > 0) score += rnd.nextInt(noise * 2 + 1) - noise;
        scored.add((m, score));
        if (score > alpha) alpha = score;
      }
      if (_aborted && scored.isEmpty) break;
      scored.sort((a, c) => c.$2.compareTo(a.$2));
      best = scored.first.$1;
      if (_aborted) break;
      ordered = [for (final s in scored) s.$1];
      if (scored.first.$2 > mate - 100) break;
    }
    return best;
  }
}

/// Isolate entry: (board, side, level) → encoded move or -1.
int xiangqiAiEntry((List<int>, int, int) args) {
  final (board, side, level) = args;
  final engine = XqEngine(board)..qDepth = 6;
  final move = switch (level) {
    0 => engine.bestMove(side, maxDepth: 2, timeMs: 800, noise: 45),
    1 => engine.bestMove(side, maxDepth: 4, timeMs: 2200, noise: 6),
    _ => engine.bestMove(side, maxDepth: 10, timeMs: 3000),
  };
  return move ?? -1;
}
