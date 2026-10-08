import 'dart:math' as math;

/// Free-style gomoku: five or more in a row wins, no forbidden moves.
/// Cells hold -1 (empty), 0 (black, moves first) or 1 (white).
class GomokuState {
  const GomokuState({
    required this.size,
    required this.cells,
    required this.turn,
    this.last,
    this.count = 0,
  });

  factory GomokuState.initial(int size) =>
      GomokuState(size: size, cells: List.filled(size * size, -1), turn: 0);

  final int size;
  final List<int> cells;
  final int turn;
  final int? last;
  final int count;

  static const directions = [(1, 0), (0, 1), (1, 1), (1, -1)];

  bool get isFull => count >= size * size;

  int at(int x, int y) => cells[y * size + x];

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;

  GomokuState play(int index) {
    assert(cells[index] < 0);
    final next = List<int>.of(cells)..[index] = turn;
    return GomokuState(
      size: size,
      cells: next,
      turn: 1 - turn,
      last: index,
      count: count + 1,
    );
  }

  /// The winning run through the last move (5+ stones), or `null`.
  List<int>? get winLine {
    final index = last;
    if (index == null) return null;
    final side = cells[index];
    final x0 = index % size;
    final y0 = index ~/ size;
    for (final (dx, dy) in directions) {
      final run = <int>[index];
      for (final sign in [1, -1]) {
        var x = x0 + dx * sign;
        var y = y0 + dy * sign;
        while (inside(x, y) && at(x, y) == side) {
          run.add(y * size + x);
          x += dx * sign;
          y += dy * sign;
        }
      }
      if (run.length >= 5) {
        run.sort();
        return run;
      }
    }
    return null;
  }

  int? get winner {
    final line = winLine;
    return line == null ? null : cells[line.first];
  }
}

/// Shape of a stone line through one cell, strongest first.
enum GomokuShape { five, openFour, four, openThree, three, openTwo, two, one }

abstract final class GomokuAi {
  static const _scores = {
    GomokuShape.five: 1000000,
    GomokuShape.openFour: 50000,
    GomokuShape.four: 6000,
    GomokuShape.openThree: 5000,
    GomokuShape.three: 600,
    GomokuShape.openTwo: 400,
    GomokuShape.two: 50,
    GomokuShape.one: 8,
  };

  static const _patterns = <GomokuShape, List<String>>{
    GomokuShape.five: ['11111'],
    GomokuShape.openFour: ['011110'],
    GomokuShape.four: ['011112', '211110', '11101', '11011', '10111'],
    GomokuShape.openThree: ['001110', '011100', '010110', '011010'],
    GomokuShape.three: [
      '211100', '001112', '211010', '010112', '210110', '011012', //
      '11001', '10011', '10101', '2011102',
    ],
    GomokuShape.openTwo: [
      '001100',
      '011000',
      '000110',
      '001010',
      '010100',
      '010010'
    ],
    GomokuShape.two: [
      '211000',
      '000112',
      '210100',
      '001012',
      '210010',
      '010012',
      '10001'
    ],
  };

  /// Shape formed along (dx, dy) if [side] places a stone at (x, y).
  static GomokuShape shapeAt(
      GomokuState s, int x, int y, int dx, int dy, int side) {
    final buffer = StringBuffer();
    for (var k = -5; k <= 5; k++) {
      final cx = x + dx * k;
      final cy = y + dy * k;
      if (k == 0) {
        buffer.write('1');
      } else if (!s.inside(cx, cy)) {
        buffer.write('2');
      } else {
        final v = s.at(cx, cy);
        buffer.write(v < 0 ? '0' : (v == side ? '1' : '2'));
      }
    }
    final line = buffer.toString();
    const center = 5;
    for (final entry in _patterns.entries) {
      for (final pattern in entry.value) {
        var from = 0;
        while (true) {
          final i = line.indexOf(pattern, from);
          if (i < 0) break;
          if (i <= center && center < i + pattern.length) return entry.key;
          from = i + 1;
        }
      }
    }
    return GomokuShape.one;
  }

  /// Heuristic value of [side] playing at [index], including combinations.
  static int cellScore(GomokuState s, int index, int side) {
    final x = index % s.size;
    final y = index ~/ s.size;
    var total = 0;
    var fours = 0;
    var openThrees = 0;
    for (final (dx, dy) in GomokuState.directions) {
      final shape = shapeAt(s, x, y, dx, dy, side);
      total += _scores[shape]!;
      if (shape == GomokuShape.four) fours++;
      if (shape == GomokuShape.openThree) openThrees++;
    }
    if (fours >= 2 || (fours >= 1 && openThrees >= 1)) total += 40000;
    if (openThrees >= 2) total += 20000;
    // Slight pull to the center breaks ties toward strong positions.
    final c = (s.size - 1) / 2;
    total += (s.size - ((x - c).abs() + (y - c).abs())).round();
    return total;
  }

  static List<int> candidates(GomokuState s, {int radius = 2}) {
    if (s.count == 0) return [(s.size ~/ 2) * s.size + s.size ~/ 2];
    final out = <int>[];
    for (var i = 0; i < s.cells.length; i++) {
      if (s.cells[i] >= 0) continue;
      final x = i % s.size;
      final y = i ~/ s.size;
      var near = false;
      for (var dy = -radius; dy <= radius && !near; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final nx = x + dx;
          final ny = y + dy;
          if (s.inside(nx, ny) && s.at(nx, ny) >= 0) {
            near = true;
            break;
          }
        }
      }
      if (near) out.add(i);
    }
    return out;
  }

  static List<(int, int)> _ranked(GomokuState s, {double defense = 1.0}) {
    final me = s.turn;
    final ranked = [
      for (final i in candidates(s))
        (
          i,
          (cellScore(s, i, me) * 1.1 + cellScore(s, i, 1 - me) * defense)
              .round()
        ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranked;
  }

  /// Picks a move for the side to move. [level]: 0 easy, 1 normal, 2 hard.
  static int choose(GomokuState s, int level, {math.Random? random}) {
    final rnd = random ?? math.Random();
    if (level == 0) {
      final ranked = _ranked(s, defense: 0.55);
      // Always finish a five; otherwise wander among decent moves.
      if (ranked.first.$2 >= 1000000) return ranked.first.$1;
      final pool = ranked.take(math.min(5, ranked.length)).toList();
      return pool[rnd.nextInt(pool.length)].$1;
    }
    final ranked = _ranked(s);
    if (level == 1 || ranked.length == 1) {
      final best = ranked.first.$2;
      final ties = ranked.where((r) => r.$2 >= best * 0.97).toList();
      return ties[rnd.nextInt(ties.length)].$1;
    }
    // Hard: forced wins/blocks first, then a two-ply look-ahead.
    final me = s.turn;
    for (final (i, _) in ranked) {
      if (cellScore(s, i, me) >= 1000000) return i;
    }
    for (final (i, _) in ranked) {
      if (cellScore(s, i, 1 - me) >= 1000000) return i;
    }
    var bestMove = ranked.first.$1;
    var bestValue = -double.infinity;
    for (final (move, score) in ranked.take(10)) {
      final next = s.play(move);
      final replies = _ranked(next);
      final reply = replies.isEmpty ? 0 : replies.first.$2;
      final value = score - reply * 0.85;
      if (value > bestValue) {
        bestValue = value;
        bestMove = move;
      }
    }
    return bestMove;
  }
}

/// Isolate entry point for [GomokuAi.choose].
int gomokuAiEntry((List<int>, int, int, int, int?, int) args) {
  final (cells, size, turn, level, last, count) = args;
  return GomokuAi.choose(
    GomokuState(size: size, cells: cells, turn: turn, last: last, count: count),
    level,
  );
}
