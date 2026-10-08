import 'dart:math' as math;

/// Reversi / Othello on 8×8. Cells: -1 empty, 0 black (first), 1 white.
class RvState {
  const RvState(
      {required this.cells,
      required this.turn,
      this.last,
      this.flipped = const [],
      this.passed = false});

  factory RvState.initial() {
    final c = List<int>.filled(64, -1);
    c[3 * 8 + 3] = 1;
    c[4 * 8 + 4] = 1;
    c[3 * 8 + 4] = 0;
    c[4 * 8 + 3] = 0;
    return RvState(cells: c, turn: 0);
  }

  final List<int> cells;
  final int turn;
  final int? last;

  /// Stones flipped by the last move (for the flip animation).
  final List<int> flipped;

  /// True when the side before [turn] had to pass.
  final bool passed;

  static const _dirs = [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, 1),
    (1, -1),
    (-1, 1),
    (-1, -1)
  ];

  static List<int> flipsFor(List<int> cells, int index, int side) {
    if (cells[index] >= 0) return const [];
    final out = <int>[];
    final x0 = index % 8;
    final y0 = index ~/ 8;
    for (final (dx, dy) in _dirs) {
      final line = <int>[];
      var x = x0 + dx;
      var y = y0 + dy;
      while (x >= 0 && x < 8 && y >= 0 && y < 8) {
        final v = cells[y * 8 + x];
        if (v < 0) break;
        if (v == side) {
          out.addAll(line);
          break;
        }
        line.add(y * 8 + x);
        x += dx;
        y += dy;
      }
    }
    return out;
  }

  static List<int> movesFor(List<int> cells, int side) => [
        for (var i = 0; i < 64; i++)
          if (cells[i] < 0 && flipsFor(cells, i, side).isNotEmpty) i,
      ];

  List<int> legalMoves() => movesFor(cells, turn);

  int count(int side) => cells.where((c) => c == side).length;

  bool get over => movesFor(cells, 0).isEmpty && movesFor(cells, 1).isEmpty;

  RvState play(int index) {
    final flips = flipsFor(cells, index, turn);
    assert(flips.isNotEmpty);
    final next = List<int>.of(cells)..[index] = turn;
    for (final f in flips) {
      next[f] = turn;
    }
    final other = 1 - turn;
    final otherCanMove = movesFor(next, other).isNotEmpty;
    final meCanMove = movesFor(next, turn).isNotEmpty;
    final nextTurn = otherCanMove || !meCanMove ? other : turn;
    return RvState(
      cells: next,
      turn: nextTurn,
      last: index,
      flipped: flips,
      passed: !otherCanMove && meCanMove,
    );
  }
}

abstract final class RvAi {
  static const _weights = [
    120, -20, 20, 5, 5, 20, -20, 120, //
    -20, -40, -5, -5, -5, -5, -40, -20,
    20, -5, 15, 3, 3, 15, -5, 20,
    5, -5, 3, 3, 3, 3, -5, 5,
    5, -5, 3, 3, 3, 3, -5, 5,
    20, -5, 15, 3, 3, 15, -5, 20,
    -20, -40, -5, -5, -5, -5, -40, -20,
    120, -20, 20, 5, 5, 20, -20, 120,
  ];

  static int _eval(List<int> cells, int side) {
    var score = 0;
    var empty = 0;
    for (var i = 0; i < 64; i++) {
      final v = cells[i];
      if (v < 0) {
        empty++;
        continue;
      }
      score += v == side ? _weights[i] : -_weights[i];
    }
    final mobility = RvState.movesFor(cells, side).length -
        RvState.movesFor(cells, 1 - side).length;
    score += mobility * 6;
    if (empty < 12) {
      // Endgame: discs matter most.
      var discs = 0;
      for (final v in cells) {
        if (v == side) discs++;
        if (v == 1 - side) discs--;
      }
      score += discs * 12;
    }
    return score;
  }

  static int _search(List<int> cells, int side, int depth, int alpha, int beta,
      Stopwatch clock, int limitMs) {
    final moves = RvState.movesFor(cells, side);
    if (depth == 0 || clock.elapsedMilliseconds > limitMs) {
      return _eval(cells, side);
    }
    if (moves.isEmpty) {
      if (RvState.movesFor(cells, 1 - side).isEmpty) {
        final diff = cells.where((c) => c == side).length -
            cells.where((c) => c == 1 - side).length;
        return diff * 1000;
      }
      return -_search(
          cells, 1 - side, depth - 1, -beta, -alpha, clock, limitMs);
    }
    moves.sort((a, b) => _weights[b].compareTo(_weights[a]));
    var best = -1 << 30;
    for (final m in moves) {
      final next = List<int>.of(cells)..[m] = side;
      for (final f in RvState.flipsFor(cells, m, side)) {
        next[f] = side;
      }
      final v =
          -_search(next, 1 - side, depth - 1, -beta, -alpha, clock, limitMs);
      if (v > best) best = v;
      if (v > alpha) alpha = v;
      if (alpha >= beta) break;
    }
    return best;
  }

  static int? choose(List<int> cells, int side, int level,
      {math.Random? random}) {
    final rnd = random ?? math.Random();
    final moves = RvState.movesFor(cells, side);
    if (moves.isEmpty) return null;
    final depth = switch (level) { 0 => 1, 1 => 3, _ => 6 };
    final clock = Stopwatch()..start();
    int? best;
    var bestV = -1 << 30;
    for (final m in moves) {
      final next = List<int>.of(cells)..[m] = side;
      for (final f in RvState.flipsFor(cells, m, side)) {
        next[f] = side;
      }
      var v = -_search(next, 1 - side, depth - 1, -(1 << 30), 1 << 30, clock,
          level == 2 ? 1400 : 600);
      if (level == 0) v += rnd.nextInt(80) - 40;
      if (v > bestV) {
        bestV = v;
        best = m;
      }
    }
    return best;
  }
}

int reversiAiEntry((List<int>, int, int) args) {
  final (cells, side, level) = args;
  return RvAi.choose(cells, side, level) ?? -1;
}
