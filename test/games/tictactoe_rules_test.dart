import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/tictactoe/tictactoe_rules.dart';

TttState _board(String rows) {
  final cells = [
    for (final ch in rows.replaceAll(RegExp(r'\s'), '').split(''))
      ch == 'X' ? 0 : (ch == 'O' ? 1 : -1),
  ];
  final xs = cells.where((c) => c == 0).length;
  final os = cells.where((c) => c == 1).length;
  return TttState(cells, xs > os ? 1 : 0);
}

void main() {
  test('detects rows, columns and diagonals', () {
    expect(_board('XXX ... ...').winner, 0);
    expect(_board('O.. O.. O..').winner, 1);
    expect(_board('X.. .X. ..X').winningLine, [0, 4, 8]);
    expect(_board('XO. OX. ...').winner, isNull);
  });

  test('hard AI never loses from the empty board', () {
    // Exhaustively try every human reply against the perfect AI.
    int? worst(TttState s, int aiSide) {
      if (s.winner != null) return s.winner == aiSide ? 1 : -1;
      if (s.isFull) return 0;
      if (s.turn == aiSide) return worst(s.play(TttAi.choose(s, 2)), aiSide);
      var result = 1;
      for (final m in s.emptyCells) {
        final r = worst(s.play(m), aiSide)!;
        if (r < result) result = r;
      }
      return result;
    }

    expect(worst(TttState.initial(), 1)! >= 0, isTrue);
    expect(worst(TttState.initial(), 0)! >= 0, isTrue);
  });

  test('normal AI takes a win and blocks a threat', () {
    // O to move can win at 5.
    expect(TttAi.choose(_board('XX. OO. X..'), 1), 5);
    // O to move must block X at 2.
    expect(TttAi.choose(_board('XX. .O. ...'), 1), 2);
  });
}
