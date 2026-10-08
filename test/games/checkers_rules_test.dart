import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/checkers/checkers_rules.dart';

void main() {
  test('star has 121 holes and six 10-hole camps', () {
    expect(Cc.cells.length, 121);
    for (var c = 0; c < 6; c++) {
      expect(Cc.campCells[c].length, 10);
    }
  });

  test('initial setups place 10 pieces per seat', () {
    for (final n in [2, 3, 4, 6]) {
      final s = CcState.initial(n);
      expect(s.cells.where((v) => v >= 0).length, 10 * n);
    }
  });

  test('pieces step to neighbors and chain jumps', () {
    final cells = List<int>.filled(121, -1);
    final a = Cc.indexOf(0, 0)!;
    final b = Cc.indexOf(1, 0)!;
    final c = Cc.indexOf(3, 0)!;
    cells[a] = 0;
    cells[b] = 1;
    cells[c] = 1;
    final s = CcState(
        cells: cells, ids: List.filled(121, 0), camps: const [0, 3], turn: 0);
    final moves = s.movesFrom(a);
    final targets = moves.map((m) => m.to).toSet();
    expect(targets, contains(Cc.indexOf(2, 0)));
    expect(targets, contains(Cc.indexOf(4, 0)));
    final chain = moves.firstWhere((m) => m.to == Cc.indexOf(4, 0));
    expect(chain.path, [a, Cc.indexOf(2, 0), Cc.indexOf(4, 0)]);
    expect(targets.contains(b), isFalse);
  });

  test('a seat wins when its target camp is full', () {
    final cells = List<int>.filled(121, -1);
    for (final i in Cc.campCells[3]) {
      cells[i] = 0;
    }
    final s = CcState(
        cells: cells, ids: List.filled(121, 0), camps: const [0, 3], turn: 1);
    expect(s.winner, 0);
  });

  test('AI moves forward from the opening and always finds a move', () {
    var s = CcState.initial(2);
    for (var ply = 0; ply < 40; ply++) {
      final path = checkersAiEntry((s.cells, s.camps, s.turn, 2));
      expect(path, isNotEmpty);
      final before = s.totalProgress(s.turn);
      final mover = s.turn;
      s = s.play(CcMove(path));
      if (ply < 6) expect(s.totalProgress(mover), greaterThan(before));
    }
  });

  test('two hard AIs finish a game', () {
    var s = CcState.initial(2);
    var plies = 0;
    while (s.winner == null && plies < 600) {
      s = s.play(CcMove(checkersAiEntry((s.cells, s.camps, s.turn, 2))));
      plies++;
    }
    expect(s.winner, isNotNull);
    expect(plies, lessThan(CcState.moveLimit));
  });
}
