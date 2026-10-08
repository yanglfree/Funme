import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/gomoku/gomoku_rules.dart';

GomokuState _play(int size, List<(int, int)> moves) {
  var s = GomokuState.initial(size);
  for (final (x, y) in moves) {
    s = s.play(y * size + x);
  }
  return s;
}

void main() {
  test('five in a row wins in every direction', () {
    final horizontal = _play(9, [
      (0, 0),
      (0, 1),
      (1, 0),
      (1, 1),
      (2, 0),
      (2, 1),
      (3, 0),
      (3, 1),
      (4, 0)
    ]);
    expect(horizontal.winner, 0);
    expect(horizontal.winLine, [0, 1, 2, 3, 4]);
    final diagonal = _play(9, [
      (0, 0),
      (8, 0),
      (1, 1),
      (8, 1),
      (2, 2),
      (8, 2),
      (3, 3),
      (8, 3),
      (4, 4)
    ]);
    expect(diagonal.winner, 0);
    final four =
        _play(9, [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1), (3, 0)]);
    expect(four.winner, isNull);
  });

  test('every AI level completes an open four', () {
    // Black has four in a row on row 4 with both ends open; black to move.
    final s = _play(
        13, [(3, 4), (3, 6), (4, 4), (4, 6), (5, 4), (5, 6), (6, 4), (10, 10)]);
    for (final level in [0, 1, 2]) {
      final move = GomokuAi.choose(s, level);
      expect([4 * 13 + 2, 4 * 13 + 7], contains(move), reason: 'level $level');
    }
  });

  test('normal and hard AI block an opponent four', () {
    // White to move; black threatens (2..5, 0) + (6, 0) with (1, 0) blocked.
    final s =
        _play(13, [(2, 0), (1, 0), (3, 0), (10, 10), (4, 0), (10, 11), (5, 0)]);
    for (final level in [1, 2]) {
      expect(GomokuAi.choose(s, level), 6, reason: 'level $level');
    }
  });

  test('shape detection recognises open three and four', () {
    final s = _play(13, [(4, 6), (0, 0), (5, 6), (0, 1)]);
    expect(GomokuAi.shapeAt(s, 6, 6, 1, 0, 0), GomokuShape.openThree);
    final t = _play(13, [(4, 6), (0, 0), (5, 6), (0, 1), (6, 6), (0, 2)]);
    expect(GomokuAi.shapeAt(t, 7, 6, 1, 0, 0), GomokuShape.openFour);
  });
}
