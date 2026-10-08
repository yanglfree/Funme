import 'dart:math' as math;

/// 飞行棋 on a 15×15 cross board. Board positions (seat positions) 0–3 go
/// clockwise: 0 bottom-left yard, 1 top-left, 2 top-right, 3 bottom-right.
///
/// A plane's progress is -1 in the yard, 0–50 on the shared track (relative
/// to its own start square), 51–55 in its home lane and [goal] when done.
abstract final class Ludo {
  static const goal = 56;
  static const yard = -1;
  static const jumpFrom = 16;
  static const flyFrom = 20;
  static const flyTo = 32;

  /// The 52-square loop, clockwise, starting at position 0's start square.
  static final List<(int, int)> track = [
    for (var y = 13; y >= 9; y--) (6, y),
    for (var x = 5; x >= 0; x--) (x, 8),
    (0, 7),
    for (var x = 0; x <= 5; x++) (x, 6),
    for (var y = 5; y >= 0; y--) (6, y),
    (7, 0),
    for (var y = 0; y <= 5; y++) (8, y),
    for (var x = 9; x <= 14; x++) (x, 6),
    (14, 7),
    for (var x = 14; x >= 9; x--) (x, 8),
    for (var y = 9; y <= 14; y++) (8, y),
    (7, 14),
    (6, 14),
  ];

  static const starts = [0, 13, 26, 39];

  static const lanes = <List<(int, int)>>[
    [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
    [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
    [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
  ];

  /// Top-left cell of each 6×6 yard.
  static const yards = [(0, 9), (0, 0), (9, 0), (9, 9)];

  /// Track square color = the board position that owns it.
  static int trackColor(int trackIndex) => trackIndex % 4;

  static int trackIndex(int position, int progress) =>
      (starts[position] + progress) % 52;

  /// Board cell of a plane at [progress] (not valid for yard / goal).
  static (int, int) cell(int position, int progress) {
    if (progress <= 50) return track[trackIndex(position, progress)];
    return lanes[position][progress - 51];
  }

  /// Positions used for each player count, in turn order.
  static List<int> positionsFor(int players) => switch (players) {
        2 => const [0, 2],
        3 => const [0, 1, 2],
        _ => const [0, 1, 2, 3],
      };
}

enum LudoStepKind { step, takeoff, jump, fly, home }

/// One leg of a plane's animated route, in board cells (doubles allow yard
/// slots and the goal to sit between cells).
class LudoStep {
  const LudoStep(this.x, this.y, this.kind);

  final double x;
  final double y;
  final LudoStepKind kind;
}

class LudoMoveInfo {
  const LudoMoveInfo({
    required this.seat,
    required this.plane,
    required this.fromProgress,
    required this.route,
    required this.captured,
    required this.bonus,
  });

  final int seat;
  final int plane;

  /// Progress before the move (the route's starting point).
  final int fromProgress;
  final List<LudoStep> route;

  /// (seat, plane, progress before capture) sent back to the yard.
  final List<(int, int, int)> captured;

  /// Jump / fly that happened during the move (for sounds and banners).
  final LudoStepKind? bonus;
}

class LudoAction {
  const LudoAction.roll(int this.value) : plane = null;
  const LudoAction.move(int this.plane) : value = null;
  const LudoAction.pass()
      : value = null,
        plane = null;

  final int? value;
  final int? plane;

  bool get isRoll => value != null;
  bool get isMove => plane != null;
  bool get isPass => value == null && plane == null;
}

class LudoState {
  const LudoState({
    required this.positions,
    required this.planes,
    required this.turn,
    this.dice,
    this.lastRoll,
    this.takeoff = const {6},
    this.last,
  });

  factory LudoState.initial(int players,
      {int planes = 4, Set<int> takeoff = const {6}}) {
    final positions = Ludo.positionsFor(players);
    return LudoState(
      positions: positions,
      planes: [for (final _ in positions) List.filled(planes, Ludo.yard)],
      turn: 0,
      takeoff: takeoff,
    );
  }

  /// Board position of each seat.
  final List<int> positions;

  /// Progress of every plane, per seat.
  final List<List<int>> planes;
  final int turn;

  /// Rolled value waiting to be used; `null` means the seat must roll.
  final int? dice;

  /// The most recent roll (kept after use so the die keeps showing it).
  final int? lastRoll;

  /// Rolls that let a plane leave the yard.
  final Set<int> takeoff;
  final LudoMoveInfo? last;

  List<int> movablePlanes() {
    final d = dice;
    if (d == null) return const [];
    final out = <int>[];
    final mine = planes[turn];
    for (var k = 0; k < mine.length; k++) {
      final p = mine[k];
      if (p == Ludo.goal) continue;
      if (p == Ludo.yard && !takeoff.contains(d)) continue;
      out.add(k);
    }
    return out;
  }

  int? get winner {
    for (var seat = 0; seat < planes.length; seat++) {
      if (planes[seat].every((p) => p == Ludo.goal)) return seat;
    }
    return null;
  }

  LudoState apply(LudoAction a) {
    if (a.isRoll) {
      return LudoState(
        positions: positions,
        planes: planes,
        turn: turn,
        dice: a.value,
        lastRoll: a.value,
        takeoff: takeoff,
        last: last,
      );
    }
    if (a.isPass) {
      return LudoState(
        positions: positions,
        planes: planes,
        turn: (turn + 1) % positions.length,
        lastRoll: lastRoll,
        takeoff: takeoff,
      );
    }
    final d = dice!;
    final k = a.plane!;
    final pos = positions[turn];
    final next = [for (final p in planes) List<int>.of(p)];
    final route = <LudoStep>[];
    final captured = <(int, int, int)>[];
    LudoStepKind? bonus;

    void add(int progress, LudoStepKind kind) {
      if (progress == Ludo.goal) {
        route.add(const LudoStep(7, 7, LudoStepKind.home));
        return;
      }
      final (x, y) = Ludo.cell(pos, progress);
      route.add(LudoStep(x.toDouble(), y.toDouble(), kind));
    }

    void captureAt(int progress) {
      if (progress > 50) return;
      final at = Ludo.trackIndex(pos, progress);
      for (var seat = 0; seat < next.length; seat++) {
        if (seat == turn) continue;
        for (var j = 0; j < next[seat].length; j++) {
          final q = next[seat][j];
          if (q >= 0 && q <= 50 && Ludo.trackIndex(positions[seat], q) == at) {
            next[seat][j] = Ludo.yard;
            captured.add((seat, j, q));
          }
        }
      }
    }

    var p = next[turn][k];
    final fromProgress = p;
    if (p == Ludo.yard) {
      p = 0;
      add(p, LudoStepKind.takeoff);
      captureAt(p);
    } else {
      final target = p + d;
      if (target <= Ludo.goal) {
        for (var s = p + 1; s <= target; s++) {
          add(s, LudoStepKind.step);
        }
        p = target;
      } else {
        // Overshoot: walk to the goal and bounce back.
        for (var s = p + 1; s <= Ludo.goal; s++) {
          add(s, LudoStepKind.step);
        }
        final back = Ludo.goal - (target - Ludo.goal);
        for (var s = Ludo.goal - 1; s >= back; s--) {
          add(s, LudoStepKind.step);
        }
        p = back;
      }
      captureAt(p);
      // Landing on an own-colored track square: jump, maybe fly.
      if (p <= 50 && p % 4 == 0) {
        if (p == Ludo.flyFrom) {
          p = Ludo.flyTo;
          add(p, LudoStepKind.fly);
          bonus = LudoStepKind.fly;
          captureAt(p);
        } else if (p + 4 <= 50) {
          p += 4;
          add(p, LudoStepKind.jump);
          bonus = LudoStepKind.jump;
          captureAt(p);
          if (p == Ludo.flyFrom) {
            p = Ludo.flyTo;
            add(p, LudoStepKind.fly);
            bonus = LudoStepKind.fly;
            captureAt(p);
          }
        }
      }
    }
    next[turn][k] = p;
    final again = d == 6 && winnerOf(next) == null;
    return LudoState(
      positions: positions,
      planes: next,
      turn: again ? turn : (turn + 1) % positions.length,
      lastRoll: d,
      takeoff: takeoff,
      last: LudoMoveInfo(
        seat: turn,
        plane: k,
        fromProgress: fromProgress,
        route: route,
        captured: captured,
        bonus: bonus,
      ),
    );
  }

  static int? winnerOf(List<List<int>> planes) {
    for (var seat = 0; seat < planes.length; seat++) {
      if (planes[seat].every((p) => p == Ludo.goal)) return seat;
    }
    return null;
  }
}

abstract final class LudoAi {
  /// How many opponent planes could land on our track square next turn.
  static int _threats(LudoState s, int seat, int progress) {
    if (progress < 0 || progress > 50) return 0;
    final at = Ludo.trackIndex(s.positions[seat], progress);
    var n = 0;
    for (var o = 0; o < s.planes.length; o++) {
      if (o == seat) continue;
      for (final q in s.planes[o]) {
        if (q < 0 || q > 50) continue;
        final from = Ludo.trackIndex(s.positions[o], q);
        final gap = (at - from) % 52;
        if (gap >= 1 && gap <= 6 && q + gap <= 50) n++;
      }
    }
    return n;
  }

  static double score(LudoState s, int plane) {
    final seat = s.turn;
    final before = s.planes[seat][plane];
    final after = s.apply(LudoAction.move(plane));
    final p = after.planes[seat][plane];
    var v = 0.0;
    if (before == Ludo.yard) {
      v += 45;
    } else {
      v += (p - before).toDouble();
    }
    if (p == Ludo.goal) v += 100;
    if (p > 50 && before <= 50) v += 25;
    for (final (_, _, progress) in after.last!.captured) {
      v += 55 + progress * 0.6;
    }
    final danger = _threats(after, seat, p);
    v -= danger * (12 + p * 0.4);
    if (before >= 0 && _threats(s, seat, before) > 0 && danger == 0) {
      v += 10 + before * 0.3;
    }
    return v;
  }

  static int? choose(LudoState s, int level, {math.Random? random}) {
    final rnd = random ?? math.Random();
    final movable = s.movablePlanes();
    if (movable.isEmpty) return null;
    if (level == 0 && rnd.nextDouble() < 0.6) {
      return movable[rnd.nextInt(movable.length)];
    }
    var best = movable.first;
    var bestScore = -double.infinity;
    for (final k in movable) {
      final v = score(s, k) + rnd.nextDouble() * (level == 2 ? 0.5 : 6);
      if (v > bestScore) {
        bestScore = v;
        best = k;
      }
    }
    return best;
  }
}
