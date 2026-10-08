import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/snake/snake_rules.dart';

void main() {
  test('moves, ignores reversal, and buffers two turns', () {
    final g = SnakeGame(cols: 10, rows: 10, random: math.Random(1));
    final head = g.body.first;
    g.turn(SnakeDir.left); // reversal ignored
    g.step();
    expect(g.body.first, (head.$1 + 1, head.$2));
    g.turn(SnakeDir.up);
    g.turn(SnakeDir.left);
    g.step();
    g.step();
    expect(g.dir, SnakeDir.left);
  });

  test('hitting the wall ends the classic game but wraps in wrap mode', () {
    final classic = SnakeGame(cols: 6, rows: 6, random: math.Random(2));
    var event = SnakeEvent.none;
    for (var i = 0; i < 6 && event != SnakeEvent.crash; i++) {
      event = classic.step();
    }
    expect(classic.dead, isTrue);
    final wrap = SnakeGame(cols: 6, rows: 6, wrap: true, random: math.Random(2));
    for (var i = 0; i < 10; i++) {
      wrap.food = (0, 5); // keep food out of the way
      wrap.step();
    }
    expect(wrap.dead, isFalse);
  });

  test('eating grows the snake and scores', () {
    final g = SnakeGame(cols: 10, rows: 10, random: math.Random(3));
    final (hx, hy) = g.body.first;
    g.food = (hx + 1, hy);
    expect(g.step(), SnakeEvent.eat);
    expect(g.score, 10);
    final length = g.body.length;
    g.food = (0, 0);
    g.step();
    expect(g.body.length, length + 1);
  });

  test('running into itself ends the game', () {
    final g = SnakeGame(cols: 10, rows: 10, random: math.Random(4));
    g.body = [(5, 5), (4, 5), (4, 4), (5, 4), (6, 4), (6, 5), (6, 6)];
    g.food = (0, 0);
    g.dir = SnakeDir.up;
    expect(g.step(), SnakeEvent.crash);
  });
}
