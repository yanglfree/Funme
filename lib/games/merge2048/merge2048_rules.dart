import 'dart:math' as math;

enum MergeDir { up, down, left, right }

class MergeTile {
  MergeTile(this.id, this.value, this.row, this.col, {this.fresh = false});

  final int id;
  int value;
  int row;
  int col;

  /// Doubled by a merge during the last move.
  bool merged = false;

  /// Spawned by the last move.
  bool fresh;
}

/// Sliding-merge puzzle on a square grid.
class Merge2048 {
  Merge2048({this.size = 4, math.Random? random})
      : _random = random ?? math.Random() {
    _spawn();
    _spawn();
  }

  Merge2048._clone(Merge2048 o)
      : size = o.size,
        _random = o._random,
        _nextId = o._nextId,
        score = o.score,
        tiles = [
          for (final t in o.tiles) MergeTile(t.id, t.value, t.row, t.col)
        ];

  static const target = 2048;

  final int size;
  final math.Random _random;
  int _nextId = 0;
  int score = 0;
  List<MergeTile> tiles = [];

  /// Tiles absorbed by a merge in the last move, at their destination, so the
  /// view can slide them under the survivor before they vanish.
  final List<MergeTile> ghosts = [];

  Merge2048 clone() => Merge2048._clone(this);

  int get maxTile => tiles.fold(0, (m, t) => math.max(m, t.value));

  bool get canMove {
    if (tiles.length < size * size) return true;
    final grid = _grid();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = grid[r][c];
        if (c + 1 < size && grid[r][c + 1] == v) return true;
        if (r + 1 < size && grid[r + 1][c] == v) return true;
      }
    }
    return false;
  }

  List<List<int>> _grid() {
    final g = List.generate(size, (_) => List.filled(size, 0));
    for (final t in tiles) {
      g[t.row][t.col] = t.value;
    }
    return g;
  }

  void _spawn() {
    final taken = {for (final t in tiles) t.row * size + t.col};
    final free = [
      for (var i = 0; i < size * size; i++)
        if (!taken.contains(i)) i
    ];
    if (free.isEmpty) return;
    final cell = free[_random.nextInt(free.length)];
    tiles.add(MergeTile(
        _nextId++, _random.nextInt(10) == 0 ? 4 : 2, cell ~/ size, cell % size,
        fresh: true));
  }

  int _line(MergeTile t, MergeDir d) =>
      (d == MergeDir.left || d == MergeDir.right) ? t.row : t.col;

  /// Distance from the edge the tiles slide toward.
  int _depth(MergeTile t, MergeDir d) => switch (d) {
        MergeDir.left => t.col,
        MergeDir.right => size - 1 - t.col,
        MergeDir.up => t.row,
        MergeDir.down => size - 1 - t.row,
      };

  (int, int) _cell(int line, int depth, MergeDir d) => switch (d) {
        MergeDir.left => (line, depth),
        MergeDir.right => (line, size - 1 - depth),
        MergeDir.up => (depth, line),
        MergeDir.down => (size - 1 - depth, line),
      };

  /// Slides everything toward [d]. Returns false (and changes nothing) when no
  /// tile can move.
  bool move(MergeDir d) {
    for (final t in tiles) {
      t.merged = false;
      t.fresh = false;
    }
    ghosts.clear();
    var moved = false;
    final absorbed = <MergeTile>[];
    for (var line = 0; line < size; line++) {
      final row = tiles.where((t) => _line(t, d) == line).toList()
        ..sort((a, b) => _depth(a, d).compareTo(_depth(b, d)));
      var slot = 0;
      MergeTile? prev;
      for (final t in row) {
        final p = prev;
        if (p != null && !p.merged && p.value == t.value) {
          p.value *= 2;
          p.merged = true;
          score += p.value;
          ghosts.add(MergeTile(t.id, t.value, p.row, p.col));
          absorbed.add(t);
          moved = true;
          continue;
        }
        final (r, c) = _cell(line, slot++, d);
        if (r != t.row || c != t.col) moved = true;
        t.row = r;
        t.col = c;
        prev = t;
      }
    }
    tiles.removeWhere(absorbed.contains);
    if (moved) _spawn();
    return moved;
  }

  static int starsFor(int maxTile) {
    if (maxTile >= 1024) return 3;
    if (maxTile >= 512) return 2;
    if (maxTile >= 256) return 1;
    return 0;
  }
}
