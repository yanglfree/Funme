import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/connect4/connect4_rules.dart';

C4State playCols(List<int> cols) {
  var s = C4State.initial();
  for (final c in cols) {
    s = s.play(c);
  }
  return s;
}

void main() {
  test('discs stack and four in a row wins', () {
    final s = playCols([0, 1, 0, 1, 0, 1, 0]);
    expect(s.winner, 0);
    expect(s.winLine!.length, 4);
    final diagonal = playCols([0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3]);
    expect(diagonal.winner, 0);
  });

  test('full columns are not legal', () {
    final s = playCols([0, 0, 0, 0, 0, 0]);
    expect(s.legalMoves().contains(0), isFalse);
  });

  test('AI wins when it can and blocks when it must', () {
    final win = playCols([0, 6, 1, 6, 2]); // yellow to move, red threatens 3
    expect(connect4AiEntry((win.cells, win.turn, 1)), 3);
    final take = playCols([0, 6, 1, 6, 2, 6]); // red to move, can win at 3
    expect(connect4AiEntry((take.cells, take.turn, 1)), 3);
  });
}
