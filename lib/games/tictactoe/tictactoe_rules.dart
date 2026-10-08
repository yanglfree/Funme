import 'dart:math' as math;

/// Tic-tac-toe rules. Cells hold -1 (empty), 0 (X, moves first) or 1 (O).
class TttState {
  const TttState(this.cells, this.turn);

  factory TttState.initial() => TttState(List.filled(9, -1), 0);

  final List<int> cells;
  final int turn;

  static const lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  List<int> get emptyCells => [
        for (var i = 0; i < 9; i++)
          if (cells[i] < 0) i
      ];

  TttState play(int index) {
    assert(cells[index] < 0);
    final next = List<int>.of(cells)..[index] = turn;
    return TttState(next, 1 - turn);
  }

  /// The completed line, if any.
  List<int>? get winningLine {
    for (final line in lines) {
      final v = cells[line[0]];
      if (v >= 0 && v == cells[line[1]] && v == cells[line[2]]) return line;
    }
    return null;
  }

  int? get winner {
    final line = winningLine;
    return line == null ? null : cells[line[0]];
  }

  bool get isFull => cells.every((c) => c >= 0);
}

abstract final class TttAi {
  static final _random = math.Random();

  /// easy: mostly random; normal: wins/blocks then random; hard: perfect.
  static int choose(TttState state, int level) {
    final empty = state.emptyCells;
    if (level == 0) {
      if (_random.nextDouble() < 0.35) return _bestMove(state);
      return empty[_random.nextInt(empty.length)];
    }
    if (level == 1) {
      final tactical = _winOrBlock(state);
      if (tactical != null) return tactical;
      if (state.cells[4] < 0 && _random.nextBool()) return 4;
      return empty[_random.nextInt(empty.length)];
    }
    return _bestMove(state);
  }

  static int? _winOrBlock(TttState state) {
    for (final side in [state.turn, 1 - state.turn]) {
      for (final line in TttState.lines) {
        final values = line.map((i) => state.cells[i]).toList();
        if (values.where((v) => v == side).length == 2 && values.contains(-1)) {
          return line[values.indexOf(-1)];
        }
      }
    }
    return null;
  }

  static int _bestMove(TttState state) {
    var bestScore = -1000;
    final best = <int>[];
    for (final move in state.emptyCells) {
      final score = -_negamax(state.play(move), 1);
      if (score > bestScore) {
        bestScore = score;
        best
          ..clear()
          ..add(move);
      } else if (score == bestScore) {
        best.add(move);
      }
    }
    return best[_random.nextInt(best.length)];
  }

  /// Score from the perspective of the side to move; faster wins score higher.
  static int _negamax(TttState state, int depth) {
    if (state.winner != null) return -(10 - depth);
    if (state.isFull) return 0;
    var best = -1000;
    for (final move in state.emptyCells) {
      final score = -_negamax(state.play(move), depth + 1);
      if (score > best) best = score;
    }
    return best;
  }
}
