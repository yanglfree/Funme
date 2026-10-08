import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:funme/games/merge2048/merge2048_rules.dart';

Merge2048 board(List<List<int>> rows) {
  final g = Merge2048(size: rows.length, random: math.Random(1));
  g.tiles.clear();
  var id = 100;
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows.length; c++) {
      if (rows[r][c] != 0) g.tiles.add(MergeTile(id++, rows[r][c], r, c));
    }
  }
  return g;
}

int at(Merge2048 g, int r, int c) =>
    g.tiles.where((t) => t.row == r && t.col == c).fold(0, (_, t) => t.value);

void main() {
  test('starts with two tiles', () {
    expect(Merge2048(random: math.Random(3)).tiles.length, 2);
  });

  test('merges each pair once per move: 2 2 2 2 -> 4 4', () {
    final g = board([
      [2, 2, 2, 2],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(g.move(MergeDir.left), isTrue);
    expect(at(g, 0, 0), 4);
    expect(at(g, 0, 1), 4);
    expect(g.score, 8);
    expect(g.ghosts.length, 2);
  });

  test('2 2 4 slides right to _ _ 4 4 and never chain-merges', () {
    final g = board([
      [2, 2, 4, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    g.move(MergeDir.right);
    expect(at(g, 0, 2), 4);
    expect(at(g, 0, 3), 4);
    expect(g.score, 4);
  });

  test('a move that changes nothing is rejected and spawns nothing', () {
    final g = board([
      [2, 4, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(g.move(MergeDir.left), isFalse);
    expect(g.tiles.length, 2);
  });

  test('vertical moves and game over detection', () {
    final g = board([
      [2, 4, 2, 4],
      [4, 2, 4, 2],
      [2, 4, 2, 4],
      [4, 2, 4, 2],
    ]);
    expect(g.canMove, isFalse);
    final h = board([
      [0, 0, 0, 2],
      [0, 0, 0, 0],
      [0, 0, 0, 2],
      [0, 0, 0, 0],
    ]);
    h.move(MergeDir.up);
    expect(at(h, 0, 3), 4);
  });

  test('clone is independent', () {
    final g = Merge2048(random: math.Random(5));
    final copy = g.clone();
    g.move(MergeDir.left);
    g.move(MergeDir.up);
    expect(copy.tiles.length, 2);
    expect(copy.score, 0);
  });
}
