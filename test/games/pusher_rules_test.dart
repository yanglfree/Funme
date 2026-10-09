import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/pusher/pusher_rules.dart';

void main() {
  test('starts with a populated shelf and the full hand', () {
    final g = PusherGame(startCoins: 25, random: math.Random(1));
    expect(g.ammo, 25);
    expect(g.coins.length, greaterThan(35));
    expect(g.coins.every((c) => !c.onPlate), isTrue);
  });

  test('drop spends a coin and lands it on the plate', () {
    final g = PusherGame(startCoins: 1, random: math.Random(1));
    expect(g.drop(5), isTrue);
    expect(g.ammo, 0);
    expect(g.coins.where((c) => c.onPlate).length, 1);
    expect(g.drop(5), isFalse);
  });

  test('steady dropping pushes coins into the tray and stays finite', () {
    final g = PusherGame(startCoins: 25, random: math.Random(7));
    final rng = math.Random(3);
    var won = 0;
    for (var t = 0.0; t < 90; t += 1 / 60) {
      if ((t * 60).round() % 20 == 0) {
        g.drop(0.5 + rng.nextDouble() * 9);
      }
      won += g.advance(1 / 60).length;
    }
    expect(won, greaterThan(0));
    expect(g.score, greaterThan(0));
    for (final c in g.coins) {
      expect(c.x.isFinite && c.y.isFinite, isTrue);
      expect(c.x, inInclusiveRange(0, PusherGame.width));
      expect(c.y, greaterThanOrEqualTo(0));
    }
  });

  test('ends once the hand is empty and the plate is clear', () {
    final g = PusherGame(startCoins: 0, random: math.Random(2));
    expect(g.over, isFalse);
    for (var i = 0; i < 60 * 8; i++) {
      g.advance(1 / 60);
    }
    expect(g.over, isTrue);
  });

  test('a round is capped by the clock', () {
    final g = PusherGame(startCoins: 25, random: math.Random(2));
    for (var i = 0; i < 60 * 91; i++) {
      g.advance(1 / 60);
    }
    expect(g.over, isTrue);
    expect(g.remaining, 0);
  });

  test('stars thresholds', () {
    expect(PusherGame.starsFor(10), 0);
    expect(PusherGame.starsFor(80), 1);
    expect(PusherGame.starsFor(160), 2);
    expect(PusherGame.starsFor(260), 3);
  });
}
