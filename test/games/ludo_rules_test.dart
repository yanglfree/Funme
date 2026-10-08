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
  test('track is a closed 52-square loop of touching squares', () {
    expect(Ludo.track.length, 52);
    expect(Ludo.track.toSet().length, 52);
    for (var i = 0; i < 52; i++) {
      final (ax, ay) = Ludo.track[i];
      final (bx, by) = Ludo.track[(i + 1) % 52];
      expect(math.max((ax - bx).abs(), (ay - by).abs()), lessThan(2.3),
          reason: 'gap after $i');
    }
    for (var pos = 0; pos < 4; pos++) {
      // Start squares wear the previous seat's color; own squares are p % 4 == 1.
      expect(Ludo.trackColor(Ludo.starts[pos]), (pos + 3) % 4);
      expect(Ludo.trackColor(Ludo.trackIndex(pos, 1)), pos);
      expect(Ludo.trackColor(Ludo.trackIndex(pos, Ludo.flyFrom)), pos);
      // The lane starts next to the last ring square.
      final (lx, ly) = Ludo.lanes[pos].first;
      final (tx, ty) = Ludo.cell(pos, Ludo.lastTrack);
      expect((lx - tx).abs() + (ly - ty).abs(), lessThan(2.1));
    }
  });

  test('flight squares sit across the board along a straight line', () {
    for (var pos = 0; pos < 4; pos++) {
      final (ax, ay) = Ludo.cell(pos, Ludo.flyFrom);
      final (bx, by) = Ludo.cell(pos, Ludo.flyTo);
      expect(math.min((ax - bx).abs(), (ay - by).abs()), lessThan(0.01));
    }
  });

  test('planes leave the yard on 1, 3, 5 and 6 only', () {
    final s = LudoState.initial(2);
    for (final d in [2, 4]) {
      expect(s.apply(LudoAction.roll(d)).movablePlanes(), isEmpty);
    }
    for (final d in [1, 3, 5, 6]) {
      expect(s.apply(LudoAction.roll(d)).movablePlanes().length, 4);
    }
  });

  test('takeoff parks on the arrow pad; a six still rolls again', () {
    final six = LudoState.initial(2)
        .apply(const LudoAction.roll(6))
        .apply(const LudoAction.move(0));
    expect(six.planes[0][0], Ludo.ready);
    expect(six.turn, 0);
    expect(six.sixes, 1);
    expect(six.last!.route.single.kind, LudoStepKind.takeoff);
    final s = LudoState.initial(2)
        .apply(const LudoAction.roll(3))
        .apply(const LudoAction.move(0));
    expect(s.turn, 1);
    // The next roll walks off the pad: a 1 reaches the start square.
    final t = withPlanes([
      [Ludo.ready, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(t.planes[0][0], 2);
    expect(t.last!.route.length, 3);
  });

  test('a five flies straight onto the ring', () {
    final s = withPlanes([
      [-1, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 5)
        .apply(const LudoAction.move(0));
    expect(s.planes[0][0], Ludo.directProgress);
    expect(s.turn, 1);
  });

  test('rolling a six grants another turn', () {
    final s = withPlanes([
      [3, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 6)
        .apply(const LudoAction.move(0));
    expect(s.turn, 0);
    expect(s.sixes, 1);
    final t = withPlanes([
      [3, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 2)
        .apply(const LudoAction.move(0));
    expect(t.turn, 1);
  });

  test('three sixes in a row send the furthest plane home and pass the turn',
      () {
    var s = withPlanes([
      [10, 30, Ludo.goal, -1],
      [-1, -1, -1, -1]
    ]);
    for (var i = 0; i < 2; i++) {
      s = s.apply(const LudoAction.roll(6)).apply(const LudoAction.move(0));
    }
    expect(s.turn, 0);
    expect(s.sixes, 2);
    s = s.apply(const LudoAction.roll(6));
    expect(s.dice, isNull);
    expect(s.turn, 1);
    expect(s.sixes, 0);
    expect(s.planes[0][1], Ludo.yard);
    expect(s.planes[0][2], Ludo.goal);
    expect(s.last!.recalled, [(0, 1, 30)]);
  });

  test('landing on own color jumps four, the fly square crosses the board', () {
    final jump = withPlanes([
      [2, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(jump.planes[0][0], 9);
    expect(jump.last!.bonus, LudoStepKind.jump);
    final fly = withPlanes([
      [14, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(fly.planes[0][0], Ludo.flyTo);
    expect(fly.last!.bonus, LudoStepKind.fly);
    final jumpThenFly = withPlanes([
      [11, -1, -1, -1],
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
    expect(s.last!.captureLegs, [2]);
  });

  test('the goal needs an exact roll and overshoot bounces back', () {
    final exact = withPlanes([
      [52, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 3)
        .apply(const LudoAction.move(0));
    expect(exact.planes[0][0], Ludo.goal);
    final bounce = withPlanes([
      [53, -1, -1, -1],
      [-1, -1, -1, -1]
    ], dice: 5)
        .apply(const LudoAction.move(0));
    expect(bounce.planes[0][0], 52);
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
