import 'dart:math' as math;

/// Chinese checkers on the 121-hole star, in cube coordinates (q, r, s).
/// Camps are numbered clockwise from the bottom:
/// 0 bottom (r > 4), 1 lower-left (q < -4), 2 upper-left (s > 4),
/// 3 top (r < -4), 4 upper-right (q > 4), 5 lower-right (s < -4).
abstract final class Cc {
  static final List<(int, int)> cells = () {
    final out = <(int, int)>[];
    for (var r = -8; r <= 8; r++) {
      for (var q = -8; q <= 8; q++) {
        final s = -q - r;
        final inA = q >= -4 && r >= -4 && s >= -4;
        final inB = q <= 4 && r <= 4 && s <= 4;
        if (inA || inB) out.add((q, r));
      }
    }
    return out;
  }();

  static final Map<int, int> _index = {
    for (var i = 0; i < cells.length; i++) _key(cells[i].$1, cells[i].$2): i,
  };

  static int _key(int q, int r) => (q + 9) * 32 + (r + 9);

  static int? indexOf(int q, int r) => _index[_key(q, r)];

  static const directions = [
    (1, 0),
    (1, -1),
    (0, -1),
    (-1, 0),
    (-1, 1),
    (0, 1)
  ];

  static final List<List<int>> neighbors = [
    for (final (q, r) in cells)
      [for (final (dq, dr) in directions) indexOf(q + dq, r + dr) ?? -1],
  ];

  static int campOf(int i) {
    final (q, r) = cells[i];
    final s = -q - r;
    if (r > 4) return 0;
    if (q < -4) return 1;
    if (s > 4) return 2;
    if (r < -4) return 3;
    if (q > 4) return 4;
    if (s < -4) return 5;
    return -1;
  }

  static final List<List<int>> campCells = [
    for (var c = 0; c < 6; c++)
      [
        for (var i = 0; i < cells.length; i++)
          if (campOf(i) == c) i
      ],
  ];

  static int opposite(int camp) => (camp + 3) % 6;

  /// Distance travelled toward [targetCamp]'s apex (−8 … 8).
  static int progress(int i, int targetCamp) {
    final (q, r) = cells[i];
    final s = -q - r;
    return switch (targetCamp) {
      0 => r,
      1 => -q,
      2 => s,
      3 => -r,
      4 => q,
      _ => -s,
    };
  }

  /// Camps used for each player count, in turn order.
  static List<int> campsFor(int players) => switch (players) {
        2 => const [0, 3],
        3 => const [0, 2, 4],
        4 => const [0, 1, 3, 4],
        _ => const [0, 1, 2, 3, 4, 5],
      };
}

class CcMove {
  const CcMove(this.path);

  /// Holes visited, from the start hole to the destination.
  final List<int> path;

  int get from => path.first;
  int get to => path.last;
  bool get isJump => path.length > 2 || !Cc.neighbors[from].contains(to);

  @override
  bool operator ==(Object other) =>
      other is CcMove && other.from == from && other.to == to;

  @override
  int get hashCode => from * 128 + to;
}

class CcState {
  const CcState({
    required this.cells,
    required this.ids,
    required this.camps,
    required this.turn,
    this.moves = 0,
    this.last,
  });

  factory CcState.initial(int players) {
    final camps = Cc.campsFor(players);
    final cells = List<int>.filled(Cc.cells.length, -1);
    for (var seat = 0; seat < camps.length; seat++) {
      for (final i in Cc.campCells[camps[seat]]) {
        cells[i] = seat;
      }
    }
    var id = 1;
    return CcState(
      cells: cells,
      ids: [for (final v in cells) v < 0 ? 0 : id++],
      camps: camps,
      turn: 0,
    );
  }

  final List<int> cells;
  final List<int> ids;

  /// Home camp of each seat; its target is the opposite camp.
  final List<int> camps;
  final int turn;
  final int moves;
  final CcMove? last;

  static const moveLimit = 900;

  int target(int seat) => Cc.opposite(camps[seat]);

  List<CcMove> movesFrom(int from) {
    final out = <CcMove>[];
    for (final n in Cc.neighbors[from]) {
      if (n >= 0 && cells[n] < 0) out.add(CcMove([from, n]));
    }
    final seen = <int>{from};
    void jump(List<int> path) {
      final cur = path.last;
      for (var d = 0; d < 6; d++) {
        final mid = Cc.neighbors[cur][d];
        if (mid < 0 || mid == from || cells[mid] < 0) continue;
        final land = Cc.neighbors[mid][d];
        if (land < 0 || seen.contains(land)) continue;
        if (cells[land] >= 0 && land != from) continue;
        seen.add(land);
        final next = [...path, land];
        out.add(CcMove(next));
        jump(next);
      }
    }

    jump([from]);
    return out;
  }

  List<CcMove> legalMoves() => [
        for (var i = 0; i < cells.length; i++)
          if (cells[i] == turn) ...movesFrom(i),
      ];

  CcState play(CcMove m) {
    final c = List<int>.of(cells);
    final ids = List<int>.of(this.ids);
    c[m.to] = c[m.from];
    c[m.from] = -1;
    ids[m.to] = ids[m.from];
    ids[m.from] = 0;
    return CcState(
      cells: c,
      ids: ids,
      camps: camps,
      turn: (turn + 1) % camps.length,
      moves: moves + 1,
      last: m,
    );
  }

  bool finished(int seat) {
    final target = Cc.campCells[this.target(seat)];
    return target.every((i) => cells[i] >= 0) &&
        target.any((i) => cells[i] == seat);
  }

  int totalProgress(int seat) {
    final t = target(seat);
    var sum = 0;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == seat) sum += Cc.progress(i, t);
    }
    return sum;
  }

  int? get winner {
    for (var seat = 0; seat < camps.length; seat++) {
      if (finished(seat)) return seat;
    }
    if (moves >= moveLimit) {
      var best = 0;
      for (var seat = 1; seat < camps.length; seat++) {
        if (totalProgress(seat) > totalProgress(best)) best = seat;
      }
      return best;
    }
    return null;
  }
}

abstract final class CcAi {
  static double _score(CcState s, CcMove m) {
    final seat = s.turn;
    final t = s.target(seat);
    final from = Cc.progress(m.from, t);
    final to = Cc.progress(m.to, t);
    var v = (to - from) * 10.0;
    final inTargetFrom = Cc.campOf(m.from) == t;
    final inTargetTo = Cc.campOf(m.to) == t;
    if (inTargetFrom && !inTargetTo) v -= 40;
    if (!inTargetFrom && inTargetTo) v += 6;
    if (Cc.campOf(m.from) == s.camps[seat]) v += 3;
    // Pull stragglers along so no piece is left behind.
    var rear = 99;
    for (var i = 0; i < s.cells.length; i++) {
      if (s.cells[i] == seat) rear = math.min(rear, Cc.progress(i, t));
    }
    if (from == rear) v += 4;
    // Prefer the center lane over the far edges.
    final (q, r) = Cc.cells[m.to];
    final lateral = switch (t) {
      0 || 3 => (q + r / 2).abs(),
      1 || 4 => (r + q / 2).abs(),
      _ => (q - r).abs() / 2,
    };
    v -= lateral * 0.6;
    return v;
  }

  static CcMove? choose(CcState s, int level, {math.Random? random}) {
    final rnd = random ?? math.Random();
    final moves = s.legalMoves();
    if (moves.isEmpty) return null;
    final scored = [
      for (final m in moves) (m, _score(s, m) + rnd.nextDouble() * 0.5)
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (level == 0) {
      final pool = scored.take(math.min(4, scored.length)).toList();
      return pool[rnd.nextInt(pool.length)].$1;
    }
    if (level == 1) return scored.first.$1;
    var best = scored.first.$1;
    var bestValue = -double.infinity;
    for (final (m, v) in scored.take(14)) {
      // Pretend it is our turn again to value set-ups for long jump chains.
      final after = s.play(m);
      final again = CcState(
          cells: after.cells,
          ids: after.ids,
          camps: after.camps,
          turn: s.turn,
          moves: after.moves);
      final follow = again.legalMoves();
      var next = 0.0;
      for (final f in follow) {
        next = math.max(next, _score(again, f));
      }
      final value = v + next * 0.7;
      if (value > bestValue) {
        bestValue = value;
        best = m;
      }
    }
    return best;
  }
}

/// Isolate entry: (cells, camps, turn, level) → (from, to) of the chosen move.
List<int> checkersAiEntry((List<int>, List<int>, int, int) args) {
  final (cells, camps, turn, level) = args;
  final s = CcState(
      cells: cells,
      ids: List.filled(cells.length, 0),
      camps: camps,
      turn: turn);
  final m = CcAi.choose(s, level);
  return m == null ? const [] : m.path;
}
