import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/xiangqi/xiangqi_rules.dart';

int sq(int x, int y) => y * 9 + x;

XqState custom(Map<int, int> pieces, {int turn = 0}) {
  final board = List<int>.filled(90, 0);
  pieces.forEach((k, v) => board[k] = v);
  var id = 1;
  return XqState(
      board: board,
      ids: [for (final v in board) v == 0 ? 0 : id++],
      turn: turn);
}

void main() {
  test('initial position has 44 legal moves for both sides', () {
    final s = XqState.initial();
    expect(s.legalMoves().length, 44);
    final black = XqState(board: s.board, ids: s.ids, turn: 1);
    expect(black.legalMoves().length, 44);
  });

  test('kings may not face each other on an open file', () {
    final s = custom({
      sq(4, 9): Xq.make(Xq.king, 0),
      sq(3, 0): Xq.make(Xq.king, 1),
      sq(4, 5): Xq.make(Xq.rook, 0),
    });
    // Moving the rook off the e-file is fine, but the king may not step to d-file.
    final kingMoves = s.legalMovesFrom(sq(4, 9)).map((m) => m.to).toSet();
    expect(kingMoves.contains(sq(3, 9)), isFalse);
    expect(kingMoves.contains(sq(4, 8)), isTrue);
  });

  test('horse leg and elephant eye block movement', () {
    final s = custom({
      sq(4, 9): Xq.make(Xq.king, 0),
      sq(4, 0): Xq.make(Xq.king, 1),
      sq(1, 9): Xq.make(Xq.horse, 0),
      sq(1, 8): Xq.make(Xq.pawn, 0),
      sq(2, 9): Xq.make(Xq.elephant, 0),
      sq(3, 8): Xq.make(Xq.advisor, 0),
    });
    final horse = s.legalMovesFrom(sq(1, 9)).map((m) => m.to).toSet();
    expect(horse.contains(sq(0, 7)), isFalse);
    expect(horse.contains(sq(2, 7)), isFalse);
    expect(horse.contains(sq(3, 8)), isFalse);
    // Both elephant eyes are occupied (pawn at b8, advisor at d8).
    expect(s.legalMovesFrom(sq(2, 9)), isEmpty);
    expect(horse, isEmpty);
  });

  test('cannon needs exactly one screen to capture', () {
    final s = custom({
      sq(4, 9): Xq.make(Xq.king, 0),
      sq(3, 0): Xq.make(Xq.king, 1),
      sq(0, 9): Xq.make(Xq.cannon, 0),
      sq(0, 5): Xq.make(Xq.pawn, 1),
      sq(0, 2): Xq.make(Xq.rook, 1),
    });
    final targets = s.legalMovesFrom(sq(0, 9)).map((m) => m.to).toSet();
    expect(targets.contains(sq(0, 2)), isTrue);
    expect(targets.contains(sq(0, 5)), isFalse);
  });

  test('checkmate leaves no legal moves', () {
    // Black king boxed in by two red rooks.
    final s = custom({
      sq(4, 9): Xq.make(Xq.king, 0),
      sq(3, 0): Xq.make(Xq.king, 1),
      sq(0, 0): Xq.make(Xq.rook, 0),
      sq(8, 1): Xq.make(Xq.rook, 0),
    }, turn: 1);
    expect(s.inCheck(1), isTrue);
    expect(s.legalMoves(), isEmpty);
  });

  test('AI finds mate in one and grabs a free rook', () {
    final mateIn1 = custom({
      sq(4, 9): Xq.make(Xq.king, 0),
      sq(3, 0): Xq.make(Xq.king, 1),
      sq(0, 5): Xq.make(Xq.rook, 0),
      sq(8, 1): Xq.make(Xq.rook, 0),
    });
    final m = xiangqiAiEntry((mateIn1.board, 0, 1));
    final after = mateIn1.play(XqMove(m >> 7, m & 127));
    expect(after.legalMoves(), isEmpty);

    final free = custom({
      sq(4, 9): Xq.make(Xq.king, 0),
      sq(3, 0): Xq.make(Xq.king, 1),
      sq(4, 5): Xq.make(Xq.rook, 0),
      sq(7, 5): Xq.make(Xq.rook, 1),
    });
    final c = xiangqiAiEntry((free.board, 0, 1));
    expect(c, sq(4, 5) << 7 | sq(7, 5));
  });

  test('hard AI answers the opening within the time budget', () {
    final watch = Stopwatch()..start();
    final m = xiangqiAiEntry((XqState.initial().board, 0, 2));
    expect(m, isNot(-1));
    expect(watch.elapsedMilliseconds, lessThan(2500));
  });
}
