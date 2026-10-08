import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/ludo/ludo_rules.dart';

LudoState withPlanes(List<List<int>> planes,
        {int turn = 0, int? dice, List<int>? positions}) =>
    LudoState(
      positions: positions ?? Ludo.positionsFor(planes.length),
      planes: planes,
      turn: turn,
      dice: dice,
    );

void main() {
  test('track is a closed 52-square loop of touching cells', () {
    expect(Ludo.track.length, 52);
    expect(Ludo.track.toSet().length, 52);
    for (var i = 0; i < 52; i++) {
      final (ax, ay) = Ludo.track[i];
      final (bx, by) = Ludo.track[(i + 1) % 52];
      // Inner corners step diagonally, like a real board.
      expect(math.max((ax - bx).abs(), (ay - by).abs()), 1,
          reason: 'gap after $i');
    }
    for (var pos = 0; pos < 4; pos++) {
      // Each player's start square carries its own color.
      expect(Ludo.trackColor(Ludo.starts[pos]), pos);
      // The lane starts next to the last track square.
      final (lx, ly) = Ludo.lanes[pos].first;
      final (tx, ty) = Ludo.cell(pos, 50);
      expect((lx - tx).abs() + (ly - ty).abs(), 1);
    }
  });

  test('planes leave the yard only on takeoff rolls', () {
    final s = LudoState.initial(2);
    expect(s.apply(const LudoAction.roll(3)).movablePlanes(), isEmpty);
    expect(s.apply(const LudoAction.roll(6)).movablePlanes().length, 4);
    final easy = LudoState.initial(2, takeoff: const {5, 6});
    expect(easy.apply(const LudoAction.roll(5)).movablePlanes().length, 4);
  });

  test('rolling a six grants another turn', () {
    final s = LudoState.initial(2)
        .apply(const LudoAction.roll(6))
        .apply(const LudoAction.move(0));
    expect(s.turn, 0);
    expect(s.planes[0][0], 0);
    final t = withPlanes([
      [3, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 2)
        .apply(const LudoAction.move(0));
    expect(t.turn, 1);
  });

  test('landing on own color jumps four, the fly square crosses the board', () {
    final jump = withPlanes([
      [5, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(jump.planes[0][0], 12);
    expect(jump.last!.bonus, LudoStepKind.jump);
    final fly = withPlanes([
      [17, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(fly.planes[0][0], Ludo.flyTo);
    expect(fly.last!.bonus, LudoStepKind.fly);
    final jumpThenFly = withPlanes([
      [14, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 2)
        .apply(const LudoAction.move(0));
    expect(jumpThenFly.planes[0][0], Ludo.flyTo);
  });

  test('landing on an opponent sends it home', () {
    // Seat 1 sits at position 2; find its progress on track index 10.
    final opponentProgress = (10 - Ludo.starts[2]) % 52;
    final s = withPlanes([
      [7, -1, -1, -1],
      [opponentProgress, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(s.planes[1][0], Ludo.yard);
    expect(s.last!.captured, [(1, 0, opponentProgress)]);
  });

  test('the goal needs an exact roll and overshoot bounces back', () {
    final exact = withPlanes([
      [53, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(exact.planes[0][0], Ludo.goal);
    final bounce = withPlanes([
      [54, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 5)
        .apply(const LudoAction.move(0));
    expect(bounce.planes[0][0], 53);
  });

  test('random AI games always end with a winner', () {
    final rnd = math.Random(7);
    for (final players in [2, 3, 4]) {
      var s = LudoState.initial(players, planes: 2);
      var plies = 0;
      while (s.winner == null && plies < 4000) {
        if (s.dice == null) {
          s = s.apply(LudoAction.roll(1 + rnd.nextInt(6)));
        } else {
          final k = LudoAi.choose(s, 1, random: rnd);
          s = s.apply(k == null ? const LudoAction.pass() : LudoAction.move(k));
        }
        plies++;
      }
      expect(s.winner, isNotNull, reason: '$players players');
    }
  });
}
