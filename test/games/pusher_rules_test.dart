import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/pusher/pusher_rules.dart';

void advance(PusherGame g, double seconds) {
  for (var i = 0; i < (seconds * 90).ceil(); i++) {
    g.advance(1 / 90);
  }
}

PusherGame empty({int ammo = 30, PusherMode mode = PusherMode.arcade}) =>
    PusherGame(startCoins: ammo, mode: mode, random: math.Random(1))
      ..coins.clear();

void main() {
  test('starts with a lower bed and supported prizes', () {
    final g = PusherGame(random: math.Random(1));
    expect(g.ammo, 30);
    expect(g.coins.length, greaterThan(50));
    expect(g.coins.any((c) => c.onPlate), isFalse);
    expect(g.coins.where((c) => c.support != null).length, 9);
  });

  test('drop spends exactly one token and enforces cadence in the engine', () {
    final g = empty(ammo: 2);
    expect(g.drop(5), isTrue);
    expect(g.ammo, 1);
    expect(g.drop(5), isFalse);
    advance(g, 0.3);
    expect(g.drop(5), isTrue);
    expect(g.ammo, 0);
    expect(g.coins.every((c) => c.kind == CoinKind.silver), isTrue);
    expect(g.drop(5), isFalse);
  });

  test('airborne coin does not displace coins below it', () {
    final g = empty();
    final base = Coin(CoinKind.silver, 5, 7);
    final airborne = Coin(CoinKind.silver, 5, 7, z: 3.2);
    g.coins.addAll([base, airborne]);
    advance(g, 0.1);
    expect(base.x, 5);
    expect(base.y, 7);
    expect(airborne.z, greaterThan(2));
    advance(g, 0.5);
    expect(airborne.support, same(base));
    expect(airborne.z, closeTo(PusherGame.thickness, 0.01));
  });

  test('removing support collapses the entire stack under gravity', () {
    final g = empty();
    final base = Coin(CoinKind.silver, 5, 7);
    final middle = Coin(CoinKind.silver, 5, 7, z: PusherGame.thickness)
      ..support = base;
    final top = Coin(CoinKind.gold, 5, 7, z: PusherGame.thickness * 2)
      ..support = middle;
    g.coins.addAll([base, middle, top]);
    g.coins.remove(base);
    advance(g, 0.5);
    expect(middle.z, closeTo(0, 0.001));
    expect(top.z, closeTo(PusherGame.thickness, 0.001));
    expect(top.support, same(middle));
  });

  test('retracting plate releases a rim coin onto the lower shelf', () {
    final g = empty();
    advance(g, 2 / g.speed);
    final coin = Coin(CoinKind.silver, 5, g.front - 0.01, onPlate: true);
    g.coins.add(coin);
    advance(g, 1);
    expect(coin.onPlate, isFalse);
    expect(coin.z, closeTo(0, 0.01));
  });

  test('front overhang tilts before payout, side gutters never pay', () {
    final g = empty();
    final lip = Coin(CoinKind.silver, 5, PusherGame.depth - 0.2);
    g.coins.add(lip);
    advance(g, 0.1);
    expect(lip.angle, greaterThan(0));
    expect(g.score, 0);
    lip.y = PusherGame.depth + 0.1;
    g.coins.add(Coin(CoinKind.gold, 0.4, 8));
    advance(g, 0.15);
    expect(g.score, 0);
    expect(lip.tipping, greaterThan(0));
    advance(g, 0.25);
    expect(g.score, 1);
    expect(g.ammo, 31);
    expect(g.lost, 1);
    expect(g.falls.where((f) => f.side).length, 1);
  });

  test('an idle machine does not generate free winnings or lose prizes', () {
    final g = PusherGame(random: math.Random(3));
    advance(g, 90);
    expect(g.score, 0);
    expect(g.lost, 0);
    expect(g.ammo, 30);
  });

  test('a falling support pulls the prize above it into the tray', () {
    final g = empty();
    final base = Coin(CoinKind.silver, 5, PusherGame.depth + 0.1);
    final top = Coin(CoinKind.gold, 5, base.y, z: PusherGame.thickness)
      ..support = base;
    g.coins.addAll([base, top]);
    advance(g, 1.5);
    expect(g.coins, isEmpty);
    expect(g.score, 4);
    expect(g.ammo, 34);
  });

  test('arcade mode continues beyond ninety seconds', () {
    final g = empty();
    advance(g, 95);
    expect(g.over, isFalse);
    expect(g.canDrop, isTrue);
  });

  test('timed mode stops input but waits for the last falling prize', () {
    final g = empty(mode: PusherMode.timed);
    advance(g, 89.9);
    final prize = Coin(CoinKind.gem, 5, PusherGame.depth + 0.1, z: 2);
    g.coins.add(prize);
    advance(g, 0.2);
    expect(g.settling, isTrue);
    expect(g.drop(5), isFalse);
    expect(g.over, isFalse);
    advance(g, 6);
    expect(g.score, 5);
    expect(g.falls, isEmpty);
    expect(g.end, PusherEnd.time);
  });

  test('an empty hand waits for payout and can resume playing', () {
    final g = empty(ammo: 0);
    g.coins.add(Coin(CoinKind.gold, 5, PusherGame.depth + 0.1, z: 2));
    advance(g, 2);
    expect(g.over, isFalse);
    expect(g.ammo, 3);
    expect(g.canDrop, isTrue);
  });

  test('empty and manual endings park the motor and freeze final state', () {
    for (final manual in [false, true]) {
      final g = empty(ammo: manual ? 10 : 0);
      if (manual) g.collect();
      advance(g, 8);
      expect(g.end, manual ? PusherEnd.collected : PusherEnd.empty);
      expect(g.front, closeTo(PusherGame.frontMin, 0.001));
      expect(g.drop(5), isFalse);
      final time = g.time;
      advance(g, 1);
      expect(g.time, time);
    }
  });

  test('a crowded real session settles after the motor parks', () {
    for (final seed in [3, 16]) {
      final g = PusherGame(mode: PusherMode.timed, random: math.Random(seed));
      for (var frame = 0; frame < 60 * 105 && !g.over; frame++) {
        if (frame % 20 == 0) g.drop(5);
        g.advance(1 / 60);
      }
      expect(g.over, isTrue, reason: 'seed $seed');
      expect(g.falls, isEmpty);
      expect(g.front, closeTo(PusherGame.frontMin, 0.001));
    }
  });

  test('star thresholds match the finite arcade economy', () {
    expect(PusherGame.starsFor(9), 0);
    expect(PusherGame.starsFor(10), 1);
    expect(PusherGame.starsFor(25), 2);
    expect(PusherGame.starsFor(40), 3);
  });

  test('fixed-step results are independent of display frame rate', () {
    final a = PusherGame(random: math.Random(4));
    final b = PusherGame(random: math.Random(4));
    a.drop(5);
    b.drop(5);
    for (var i = 0; i < 600; i++) {
      a.advance(1 / 60);
    }
    for (var i = 0; i < 1200; i++) {
      b.advance(1 / 120);
    }
    expect(a.score, b.score);
    expect(a.coins.length, b.coins.length);
    for (var i = 0; i < a.coins.length; i++) {
      expect(a.coins[i].x, closeTo(b.coins[i].x, 1e-8));
      expect(a.coins[i].z, closeTo(b.coins[i].z, 1e-8));
    }
  });

  test('seeded sessions remain finite and conserve token value', () {
    for (var seed = 0; seed < 5; seed++) {
      final g = PusherGame(random: math.Random(seed));
      final rng = math.Random(seed + 100);
      final initial =
          g.ammo + g.coins.fold<int>(0, (sum, c) => sum + c.kind.value);
      var lostValue = 0;
      for (var frame = 0; frame < 60 * 45 && !g.over; frame++) {
        if (frame % 20 == 0) g.drop(0.6 + rng.nextDouble() * 8.8);
        final falls = g.advance(1 / 60);
        lostValue += falls
            .where((f) => f.side)
            .fold<int>(0, (sum, f) => sum + f.kind.value);
      }
      expect(
          g.ammo +
              g.coins.fold<int>(0, (sum, c) => sum + c.kind.value) +
              lostValue,
          initial);
      for (final c in g.coins) {
        expect(c.x.isFinite && c.y.isFinite && c.z.isFinite, isTrue);
        expect(c.z, lessThan(5));
      }
    }
  });
}
