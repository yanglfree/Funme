import 'dart:math' as math;

/// A 9×9 grid is a flat list of 81 digits, 0 meaning empty.
class SudokuPuzzle {
  const SudokuPuzzle(this.puzzle, this.solution);

  final List<int> puzzle;
  final List<int> solution;
}

abstract final class Sudoku {
  static const clueCounts = {'easy': 46, 'normal': 36, 'hard': 30};

  static int row(int i) => i ~/ 9;
  static int col(int i) => i % 9;
  static int box(int i) => (i ~/ 27) * 3 + (i % 9) ~/ 3;

  static bool sees(int a, int b) =>
      a != b && (row(a) == row(b) || col(a) == col(b) || box(a) == box(b));

  /// Builds a puzzle with a unique solution and (at most) [clues] givens.
  static SudokuPuzzle generate({required int clues, math.Random? random}) {
    final rnd = random ?? math.Random();
    final solution = _Solver(List.filled(81, 0)).solve(rnd)!;
    final puzzle = List.of(solution);
    final order = List.generate(81, (i) => i)..shuffle(rnd);
    var left = 81;
    for (final i in order) {
      if (left <= clues) break;
      final keep = puzzle[i];
      puzzle[i] = 0;
      if (countSolutions(puzzle) == 1) {
        left--;
      } else {
        puzzle[i] = keep;
      }
    }
    return SudokuPuzzle(puzzle, solution);
  }

  /// Isolate-friendly wrapper: returns puzzle followed by solution.
  static List<int> generateEntry((int, int) args) {
    final p = generate(clues: args.$2, random: math.Random(args.$1));
    return [...p.puzzle, ...p.solution];
  }

  static int countSolutions(List<int> grid, {int limit = 2}) =>
      _Solver(grid).count(limit);

  /// Indices of filled cells that repeat a digit within a row, column or box.
  static Set<int> conflicts(List<int> grid) {
    final bad = <int>{};
    for (var i = 0; i < 81; i++) {
      if (grid[i] == 0) continue;
      for (var j = i + 1; j < 81; j++) {
        if (grid[j] == grid[i] && sees(i, j)) {
          bad
            ..add(i)
            ..add(j);
        }
      }
    }
    return bad;
  }

  static bool isSolved(List<int> grid) =>
      !grid.contains(0) && conflicts(grid).isEmpty;

  static int starsFor({required String level, required int hints}) {
    final base = switch (level) {
      'easy' => 1,
      'normal' => 2,
      _ => 3,
    };
    return hints > 0 ? math.max(1, base - 1) : base;
  }
}

class _Solver {
  _Solver(List<int> start) : grid = List.of(start) {
    for (var i = 0; i < 81; i++) {
      final v = grid[i];
      if (v == 0) continue;
      final bit = 1 << v;
      if ((_used(i) & bit) != 0) _valid = false;
      _mark(i, bit);
    }
  }

  final List<int> grid;
  final _rows = List.filled(9, 0);
  final _cols = List.filled(9, 0);
  final _boxes = List.filled(9, 0);
  bool _valid = true;
  int _found = 0;
  List<int>? _first;

  int _used(int i) =>
      _rows[Sudoku.row(i)] | _cols[Sudoku.col(i)] | _boxes[Sudoku.box(i)];

  void _mark(int i, int bit) {
    _rows[Sudoku.row(i)] |= bit;
    _cols[Sudoku.col(i)] |= bit;
    _boxes[Sudoku.box(i)] |= bit;
  }

  void _unmark(int i, int bit) {
    _rows[Sudoku.row(i)] &= ~bit;
    _cols[Sudoku.col(i)] &= ~bit;
    _boxes[Sudoku.box(i)] &= ~bit;
  }

  int count(int limit) {
    if (!_valid) return 0;
    _search(limit, null);
    return _found;
  }

  List<int>? solve(math.Random rnd) {
    if (!_valid) return null;
    _search(1, rnd);
    return _first;
  }

  void _search(int limit, math.Random? rnd) {
    var best = -1;
    var bestFree = 10;
    for (var i = 0; i < 81; i++) {
      if (grid[i] != 0) continue;
      final free = 9 - _popcount(_used(i) >> 1 & 0x1FF);
      if (free < bestFree) {
        best = i;
        bestFree = free;
        if (free <= 1) break;
      }
    }
    if (best < 0) {
      _found++;
      _first ??= List.of(grid);
      return;
    }
    if (bestFree == 0) return;
    final used = _used(best);
    final digits = [
      for (var d = 1; d <= 9; d++)
        if ((used & (1 << d)) == 0) d
    ];
    if (rnd != null) digits.shuffle(rnd);
    for (final d in digits) {
      grid[best] = d;
      _mark(best, 1 << d);
      _search(limit, rnd);
      _unmark(best, 1 << d);
      grid[best] = 0;
      if (_found >= limit) return;
    }
  }

  static int _popcount(int v) {
    var n = 0;
    while (v != 0) {
      v &= v - 1;
      n++;
    }
    return n;
  }
}
