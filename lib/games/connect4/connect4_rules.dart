import 'dart:math' as math;

/// Connect four on 7 columns × 6 rows. Index = row * 7 + col, row 0 = top.
/// Cells: -1 empty, 0 red (first), 1 yellow.
class C4State {
  const C4State({required this.cells, required this.turn, this.last});

  factory C4State.initial() => C4State(cells: List.filled(42, -1), turn: 0);

  static const cols = 7;
  static const rows = 6;

  final List<int> cells;
  final int turn;
  final int? last;

  /// Landing row in [col], or -1 when full.
  static int dropRow(List<int> cells, int col) {
    for (var r = rows - 1; r >= 0; r--) {
      if (cells[r * cols + col] < 0) return r;
    }
    return -1;
  }

  List<int> legalMoves() => [
        for (var c = 0; c < cols; c++)
          if (cells[c] < 0) c
      ];

  C4State play(int col) {
    final r = dropRow(cells, col);
    assert(r >= 0);
    final next = List<int>.of(cells)..[r * cols + col] = turn;
    return C4State(cells: next, turn: 1 - turn, last: r * cols + col);
  }

  static const _dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];

  static List<int>? lineThrough(List<int> cells, int index) {
    final side = cells[index];
    if (side < 0) return null;
    final c0 = index % cols;
    final r0 = index ~/ cols;
    for (final (dc, dr) in _dirs) {
      final line = [index];
      for (final s in [1, -1]) {
        var c = c0 + dc * s;
        var r = r0 + dr * s;
        while (c >= 0 &&
            c < cols &&
            r >= 0 &&
            r < rows &&
            cells[r * cols + c] == side) {
          line.add(r * cols + c);
          c += dc * s;
          r += dr * s;
        }
      }
      if (line.length >= 4) return line..sort();
    }
    return null;
  }

  List<int>? get winLine => last == null ? null : lineThrough(cells, last!);

  int? get winner => winLine == null ? null : cells[last!];

  bool get isFull => cells.every((c) => c >= 0);
}

abstract final class C4Ai {
  static const _order = [3, 2, 4, 1, 5, 0, 6];
  static const _win = 1000000;

  static int _window(int mine, int theirs, int empty) {
    if (mine == 4) return 10000;
    if (mine == 3 && empty == 1) return 50;
    if (mine == 2 && empty == 2) return 8;
    if (theirs == 3 && empty == 1) return -60;
    if (theirs == 2 && empty == 2) return -6;
    return 0;
  }

  static int _eval(List<int> cells, int side) {
    var score = 0;
    for (var r = 0; r < C4State.rows; r++) {
      if (cells[r * 7 + 3] == side) score += 6;
    }
    for (var r = 0; r < C4State.rows; r++) {
      for (var c = 0; c < C4State.cols; c++) {
        for (final (dc, dr) in C4State._dirs) {
          final ec = c + dc * 3;
          final er = r + dr * 3;
          if (ec < 0 || ec >= 7 || er < 0 || er >= 6) continue;
          var mine = 0, theirs = 0, empty = 0;
          for (var k = 0; k < 4; k++) {
            final v = cells[(r + dr * k) * 7 + c + dc * k];
            if (v == side) {
              mine++;
            } else if (v < 0) {
              empty++;
            } else {
              theirs++;
            }
          }
          score += _window(mine, theirs, empty);
        }
      }
    }
    return score;
  }

  static int _negamax(List<int> cells, int side, int depth, int alpha, int beta,
      int ply, Stopwatch clock, int limitMs) {
    if (depth == 0 || clock.elapsedMilliseconds > limitMs) {
      return _eval(cells, side);
    }
    var any = false;
    var best = -_win * 2;
    for (final col in _order) {
      final r = C4State.dropRow(cells, col);
      if (r < 0) continue;
      any = true;
      final i = r * 7 + col;
      cells[i] = side;
      final int v;
      if (C4State.lineThrough(cells, i) != null) {
        v = _win - ply;
      } else {
        v = -_negamax(
            cells, 1 - side, depth - 1, -beta, -alpha, ply + 1, clock, limitMs);
      }
      cells[i] = -1;
      if (v > best) best = v;
      if (v > alpha) alpha = v;
      if (alpha >= beta) break;
    }
    return any ? best : 0;
  }

  static int? choose(List<int> cells, int side, int level,
      {math.Random? random}) {
    final rnd = random ?? math.Random();
    final depth = switch (level) { 0 => 2, 1 => 5, _ => 8 };
    final work = List<int>.of(cells);
    final clock = Stopwatch()..start();
    final scored = <(int, int)>[];
    for (final col in _order) {
      final r = C4State.dropRow(work, col);
      if (r < 0) continue;
      final i = r * 7 + col;
      work[i] = side;
      final v = C4State.lineThrough(work, i) != null
          ? _win
          : -_negamax(work, 1 - side, depth - 1, -_win * 2, _win * 2, 1, clock,
              level == 2 ? 1500 : 700);
      work[i] = -1;
      scored.add((col, v + (level == 0 ? rnd.nextInt(60) - 30 : 0)));
    }
    if (scored.isEmpty) return null;
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.first.$1;
  }
}

int connect4AiEntry((List<int>, int, int) args) {
  final (cells, side, level) = args;
  return C4Ai.choose(cells, side, level) ?? -1;
}
