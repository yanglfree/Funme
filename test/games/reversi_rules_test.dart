import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/reversi/reversi_rules.dart';

void main() {
  test('opening has four moves and a move flips one disc', () {
    final s = RvState.initial();
    expect(s.legalMoves().toSet(), {19, 26, 37, 44});
    final after = s.play(19);
    expect(after.cells[27], 0);
    expect(after.flipped, [27]);
    expect(after.count(0), 4);
    expect(after.count(1), 1);
    expect(after.turn, 1);
  });

  test('a side with no move passes', () {
    // White has no reply after black takes the last flip.
    final cells = List<int>.filled(64, -1);
    cells[0] = 0;
    cells[1] = 1;
    final s = RvState(cells: cells, turn: 0);
    final after = s.play(2);
    expect(after.over, isTrue);
  });

  test('AI finds the move that wipes out the opponent', () {
    final cells = List<int>.filled(64, -1);
    cells[9] = 1;
    cells[18] = 0;
    cells[10] = 1;
    cells[11] = 0;
    // Corner 0 flips one disc, but 8 flips both white discs and wins.
    expect(RvAi.choose(cells, 0, 1), 8);
  });

  test('two AIs finish a game', () {
    var s = RvState.initial();
    var plies = 0;
    while (!s.over && plies < 70) {
      final m = reversiAiEntry((s.cells, s.turn, s.turn == 0 ? 1 : 0));
      s = s.play(m);
      plies++;
    }
    expect(s.over, isTrue);
  });
}
