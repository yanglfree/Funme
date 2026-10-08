import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/jungle/jungle_rules.dart';

int sq(int x, int y) => y * 7 + x;

JgState custom(Map<int, int> pieces, {int turn = 0}) {
  final board = List<int>.filled(Jg.cells, 0);
  pieces.forEach((k, v) => board[k] = v);
  var id = 1;
  return JgState(
      board: board,
      ids: [for (final v in board) v == 0 ? 0 : id++],
      turn: turn);
}

Set<int> targets(JgState s, int from) =>
    s.legalMovesFrom(from).map((m) => m.to).toSet();

void main() {
  test('initial setup is mirrored and both sides can move', () {
    final s = JgState.initial();
    expect(s.board[sq(0, 0)], Jg.make(Jg.lion, 1));
    expect(s.board[sq(6, 8)], Jg.make(Jg.lion, 0));
    expect(s.board[sq(0, 6)], Jg.make(Jg.elephant, 0));
    expect(s.legalMoves().length, 24);
  });

  test('only the mouse swims; lion and tiger jump unless a mouse blocks', () {
    final s = custom({
      sq(0, 4): Jg.make(Jg.lion, 0),
      sq(3, 5): Jg.make(Jg.dog, 0),
      sq(1, 6): Jg.make(Jg.mouse, 0),
    });
    expect(targets(s, sq(0, 4)), contains(sq(3, 4)));
    expect(targets(s, sq(3, 5)).contains(sq(2, 5)), isFalse);
    expect(targets(s, sq(1, 6)), contains(sq(1, 5)));

    final blocked = custom({
      sq(0, 4): Jg.make(Jg.lion, 0),
      sq(2, 4): Jg.make(Jg.mouse, 1),
    });
    expect(targets(blocked, sq(0, 4)).contains(sq(3, 4)), isFalse);
  });

  test('mouse beats elephant but not from the water', () {
    final land = custom(
        {sq(3, 2): Jg.make(Jg.mouse, 0), sq(3, 1): Jg.make(Jg.elephant, 1)});
    expect(targets(land, sq(3, 2)), contains(sq(3, 1)));
    final swim = custom(
        {sq(1, 3): Jg.make(Jg.mouse, 0), sq(1, 2): Jg.make(Jg.elephant, 1)});
    expect(targets(swim, sq(1, 3)).contains(sq(1, 2)), isFalse);
    final stomp = custom(
        {sq(3, 2): Jg.make(Jg.elephant, 0), sq(3, 1): Jg.make(Jg.mouse, 1)});
    expect(targets(stomp, sq(3, 2)).contains(sq(3, 1)), isFalse);
  });

  test('a piece in the enemy trap can be taken by anyone', () {
    // Black elephant sits in red's trap next to red's den.
    final s = custom(
        {sq(2, 7): Jg.make(Jg.cat, 0), sq(2, 8): Jg.make(Jg.elephant, 1)});
    expect(targets(s, sq(2, 7)), contains(sq(2, 8)));
  });

  test('entering the enemy den wins and own den is off limits', () {
    final s = custom({
      sq(3, 1): Jg.make(Jg.dog, 0),
      sq(3, 7): Jg.make(Jg.cat, 0),
      sq(0, 0): Jg.make(Jg.mouse, 1)
    });
    expect(targets(s, sq(3, 7)).contains(sq(3, 8)), isFalse);
    final after = s.play(JgMove(sq(3, 1), sq(3, 0)));
    expect(after.winner, 0);
  });

  test('AI walks into an open den', () {
    final s = custom({
      sq(3, 1): Jg.make(Jg.wolf, 0),
      sq(6, 8): Jg.make(Jg.lion, 1),
      sq(0, 8): Jg.make(Jg.mouse, 0)
    });
    for (final level in [1, 2]) {
      expect(jungleAiEntry((s.board, 0, level)), sq(3, 1) << 6 | sq(3, 0));
    }
  });
}
