import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/sudoku/sudoku_rules.dart';

void main() {
  test('generated puzzle is unique, consistent with its solution', () {
    for (final entry in Sudoku.clueCounts.entries) {
      final p = Sudoku.generate(clues: entry.value, random: math.Random(7));
      expect(Sudoku.isSolved(p.solution), isTrue);
      expect(Sudoku.countSolutions(p.puzzle), 1);
      for (var i = 0; i < 81; i++) {
        if (p.puzzle[i] != 0) expect(p.puzzle[i], p.solution[i]);
      }
      expect(p.puzzle.where((v) => v != 0).length,
          lessThanOrEqualTo(entry.value + 6));
    }
  });

  test('conflicts flag repeated digits in a row, column or box', () {
    final g = List.filled(81, 0);
    g[0] = 5;
    g[8] = 5; // same row
    g[40] = 5; // different row, column and box: fine
    expect(Sudoku.conflicts(g), {0, 8});
    g[20] = 5; // same box as cell 0
    expect(Sudoku.conflicts(g), {0, 8, 20});
  });

  test('stars drop by one when hints are used but never below one', () {
    expect(Sudoku.starsFor(level: 'hard', hints: 0), 3);
    expect(Sudoku.starsFor(level: 'hard', hints: 2), 2);
    expect(Sudoku.starsFor(level: 'easy', hints: 1), 1);
  });
}
