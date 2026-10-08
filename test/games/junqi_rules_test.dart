import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/junqi/junqi_rules.dart';

int sq(int x, int y) => y * 5 + x;

JqState custom(Map<int, int> pieces, {int turn = 0, List<int> colors = const [0, 1]}) {
  final board = List<int>.filled(Jq.cells, 0);
  pieces.forEach((k, v) => board[k] = v);
  var id = 1;
  return JqState(board: board, ids: [for (final v in board) v == 0 ? 0 : id++], turn: turn, colors: colors);
}

int red(int kind) => Jq.make(kind, 0, revealed: true);
int blue(int kind) => Jq.make(kind, 1, revealed: true);

void main() {
  test('deal fills the 50 non-camp posts face down', () {
    final s = JqState.deal(math.Random(1));
    final pieces = s.board.where((v) => v != 0).toList();
    expect(pieces.length, 50);
    expect(pieces.where((v) => Jq.color(v) == 0).length, 25);
    expect(pieces.any(Jq.revealed), isFalse);
    for (final c in Jq.campSet) {
      expect(s.board[c], 0);
    }
    // Before any flip, the only actions are flips.
    expect(s.legalActions().every((a) => a.isFlip), isTrue);
  });

  test('the first flip decides who plays which color', () {
    final s = JqState.deal(math.Random(2));
    final at = s.board.indexWhere((v) => v != 0);
    final after = s.apply(JqAction.flip(at));
    final c = Jq.color(after.board[at]);
    expect(after.colors, [c, 1 - c]);
    expect(after.turn, 1);
  });

  test('pieces slide straight on rails; engineers turn corners', () {
    final s = custom({sq(0, 6): red(0), sq(4, 10): red(Jq.engineer)});
    final general = s.destinations(sq(0, 6));
    expect(general, containsAll([sq(4, 6), sq(0, 10), sq(0, 1)]));
    expect(general.contains(sq(4, 10)), isFalse);
    final engineer = s.destinations(sq(4, 10));
    expect(engineer, containsAll([sq(0, 1), sq(4, 1), sq(2, 5)]));
  });

  test('front line only crosses on columns 0, 2 and 4', () {
    final s = custom({sq(1, 6): red(3), sq(2, 6): red(3)});
    expect(s.destinations(sq(1, 6)).contains(sq(1, 5)), isFalse);
    expect(s.destinations(sq(2, 6)).contains(sq(2, 5)), isTrue);
  });

  test('camps protect their occupant and connect diagonally', () {
    final s = custom({sq(2, 8): blue(7), sq(2, 9): red(0), sq(1, 7): red(5)});
    expect(s.destinations(sq(2, 9)).contains(sq(2, 8)), isFalse);
    expect(s.destinations(sq(1, 7)), contains(sq(0, 6)));
  });

  test('clash rules for bombs, mines, flags and equal ranks', () {
    expect(jqClash(red(Jq.bomb), blue(0)), JqClash.bothDie);
    expect(jqClash(red(0), blue(Jq.mine)), JqClash.defenderWins);
    expect(jqClash(red(Jq.engineer), blue(Jq.mine)), JqClash.attackerWins);
    expect(jqClash(red(Jq.engineer), blue(Jq.flag)), JqClash.flagTaken);
    expect(jqClash(red(4), blue(4)), JqClash.bothDie);
    expect(jqClash(red(Jq.engineer), blue(7)), JqClash.defenderWins);
  });

  test('capturing the flag wins the game', () {
    final s = custom({sq(2, 6): red(5), sq(2, 5): blue(Jq.flag), sq(0, 0): blue(Jq.mine)});
    final after = s.apply(JqAction.move(sq(2, 6), sq(2, 5)));
    expect(after.winner, 0);
  });

  test('AI takes a free flag and avoids a losing attack', () {
    final s = custom({
      sq(2, 6): red(7),
      sq(2, 5): blue(Jq.flag),
      sq(4, 6): blue(0),
    });
    expect(JqAction.decode(junqiAiEntry((s.board, s.ids, 0, s.colors, 1))), JqAction.move(sq(2, 6), sq(2, 5)));
    final t = custom({sq(1, 8): red(7), sq(1, 7): blue(0), sq(4, 0): blue(Jq.mine)});
    final a = JqAction.decode(junqiAiEntry((t.board, t.ids, 0, t.colors, 1)));
    expect(a, isNot(JqAction.move(sq(1, 8), sq(1, 7))));
  });
}
