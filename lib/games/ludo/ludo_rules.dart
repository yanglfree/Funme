import 'dart:math' as math;

/// 飞行棋 on a 17×17 board with four 4×4 yards in the corners. Board
/// positions (seat positions) 0–3 go clockwise: 0 bottom-left yard, 1 top-left,
/// 2 top-right, 3 bottom-right.
///
/// A plane's progress is -1 in the yard, 0–[lastTrack] on the shared ring
/// (relative to its own start square), 50–54 in its home lane and [goal] when
/// done. Board coordinates are in grid units; ring squares are rectangles
/// (1×2 / 2×1) and corner triangles, so a square is described by its polygon.
abstract final class Ludo {
  static const goal = 55;
  static const yard = -1;

  /// Parked on the arrow pad beside the start square, waiting for a roll.
  static const ready = -2;

  /// Rolls that bring a plane out of the yard onto the arrow pad.
  static const takeoffRolls = {1, 3, 6};

  /// This roll flies a plane straight onto the ring at [directProgress]
  /// (the corner square on the yard's other side).
  static const directRoll = 5;
  static const directProgress = 7;
  static const lastTrack = 49;
  static const laneStart = 50;

  /// Own-colored squares sit at progress % 4 == 1; landing there jumps four.
  static const flyFrom = 17;
  static const flyTo = 29;

  /// The straight flight path crosses the opposite yard's home lane at step 2.
  static const flyCrossStep = 2;
  static const flyCrossProgress = laneStart + flyCrossStep;

  static const size = 17.0;
  static const center = (8.5, 8.5);

  /// The ring squares of position 0's quarter, clockwise from its start
  /// (bottom arm, left outer corner). The other quarters are rotations.
  static const List<List<(double, double)>> _quarter = [
    [(4, 15), (6, 15), (6, 17)],
    [(4, 14), (6, 14), (6, 15), (4, 15)],
    [(4, 13), (6, 13), (6, 14), (4, 14)],
    [(4, 13), (6, 13), (6, 11)],
    [(4, 13), (4, 11), (6, 11)],
    [(3, 11), (4, 11), (4, 13), (3, 13)],
    [(2, 11), (3, 11), (3, 13), (2, 13)],
    [(2, 13), (0, 11), (2, 11)],
    [(0, 10), (2, 10), (2, 11), (0, 11)],
    [(0, 9), (2, 9), (2, 10), (0, 10)],
    [(0, 8), (2, 8), (2, 9), (0, 9)],
    [(0, 7), (2, 7), (2, 8), (0, 8)],
    [(0, 6), (2, 6), (2, 7), (0, 7)],
  ];

  static (double, double) _rotate((double, double) p, int quarters) {
    var (x, y) = p;
    for (var i = 0; i < quarters; i++) {
      (x, y) = (size - y, x);
    }
    return (x, y);
  }

  static (double, double) _centroid(List<(double, double)> poly) {
    var sx = 0.0, sy = 0.0;
    for (final (x, y) in poly) {
      sx += x;
      sy += y;
    }
    return (sx / poly.length, sy / poly.length);
  }

  /// Polygon of each of the 52 ring squares, clockwise from position 0's
  /// start square.
  static final List<List<(double, double)>> trackShapes = [
    for (var q = 0; q < 4; q++)
      for (final shape in _quarter) [for (final p in shape) _rotate(p, q)],
  ];

  /// Token center of every ring square.
  static final List<(double, double)> track = [
    for (final shape in trackShapes) _centroid(shape),
  ];

  static const starts = [0, 13, 26, 39];

  static List<(double, double)> _lane(int x, int y, int dx, int dy) => [
        for (var i = 0; i < 5; i++) (x + i * dx + 0.5, y + i * dy + 0.5),
      ];

  static final List<List<(double, double)>> lanes = [
    _lane(8, 14, 0, -1),
    _lane(2, 8, 1, 0),
    _lane(8, 2, 0, 1),
    _lane(14, 8, -1, 0),
  ];

  /// Top-left cell of each 4×4 yard.
  static const yards = [(0, 13), (0, 0), (13, 0), (13, 13)];

  /// Airfield circles inside a yard, relative to its top-left corner.
  static const yardSlots = [(1.0, 1.0), (3.0, 1.0), (1.0, 3.0), (3.0, 3.0)];

  /// Where a plane waits after takeoff: the empty corner of the start square,
  /// marked with the black arrow badge.
  static (double, double) readySpot(int position) {
    final shape = trackShapes[starts[position]];
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final (x, y) in shape) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    for (final (cx, cy) in [
      (minX, minY),
      (maxX, minY),
      (minX, maxY),
      (maxX, maxY)
    ]) {
      if (!shape.contains((cx, cy))) {
        return (
          cx + (cx == minX ? 0.55 : -0.55),
          cy + (cy == minY ? 0.55 : -0.55)
        );
      }
    }
    return _centroid(shape);
  }

  /// Ring square color = the board position that owns it. Colors cycle along
  /// the ring, so a start square wears the previous seat's color.
  static int trackColor(int trackIndex) => (trackIndex + 3) % 4;

  static int trackIndex(int position, int progress) =>
      (starts[position] + progress) % 52;

  /// Token center of a plane at [progress] (not valid for yard / goal).
  static (double, double) cell(int position, int progress) {
    if (progress <= lastTrack) return track[trackIndex(position, progress)];
    return lanes[position][progress - laneStart];
  }

  /// Positions used for each player count, in turn order.
  static List<int> positionsFor(int players) => switch (players) {
        2 => const [0, 2],
        3 => const [0, 1, 2],
        _ => const [0, 1, 2, 3],
      };
}

enum LudoStepKind { step, takeoff, jump, fly, home }

/// One leg of a plane's animated route: the target's center in board units.
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
    required this.captureLegs,
    required this.bonus,
    this.recalled = const [],
    this.bombSpots = const [],
  });

  final int seat;
  final int plane;

  /// Progress before the move (the route's starting point).
  final int fromProgress;
  final List<LudoStep> route;

  /// (seat, plane, progress before capture) sent back to the yard.
  final List<(int, int, int)> captured;

  /// For each [captured] entry, the route leg whose landing caused it.
  final List<int> captureLegs;

  /// Planes sent back to the yard as a penalty (three sixes in a row):
  /// (seat, plane, progress before).
  final List<(int, int, int)> recalled;

  /// Jump / fly that happened during the move (for sounds and banners).
  final LudoStepKind? bonus;

  /// Board coordinates of mid-flight or flight-landing bomb explosions caused
  /// by flying across the board.
  final List<(double, double)> bombSpots;
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
    this.sixes = 0,
    this.last,
  });

  factory LudoState.initial(int players, {int planes = 4}) {
    final positions = Ludo.positionsFor(players);
    return LudoState(
      positions: positions,
      planes: [for (final _ in positions) List.filled(planes, Ludo.yard)],
      turn: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'positions': positions,
        'planes': planes,
        'turn': turn,
        'dice': dice,
        'lastRoll': lastRoll,
        'sixes': sixes,
      };

  factory LudoState.fromJson(Map<String, dynamic> json) => LudoState(
        positions: (json['positions'] as List).cast<int>(),
        planes: (json['planes'] as List)
            .map((e) => (e as List).cast<int>())
            .toList(),
        turn: json['turn'] as int,
        dice: json['dice'] as int?,
        lastRoll: json['lastRoll'] as int?,
        sixes: (json['sixes'] as int?) ?? 0,
      );

  /// Board position of each seat.
  final List<int> positions;

  /// Progress of every plane, per seat.
  final List<List<int>> planes;
  final int turn;

  /// Rolled value waiting to be used; `null` means the seat must roll.
  final int? dice;

  /// The most recent roll (kept after use so the die keeps showing it).
  final int? lastRoll;

  /// Sixes this seat has already used in a row; the third one is a penalty.
  final int sixes;
  final LudoMoveInfo? last;

  List<int> movablePlanes() {
    final d = dice;
    if (d == null) return const [];
    final out = <int>[];
    final mine = planes[turn];
    for (var k = 0; k < mine.length; k++) {
      final p = mine[k];
      if (p == Ludo.goal) continue;
      if (p == Ludo.yard &&
          !Ludo.takeoffRolls.contains(d) &&
          d != Ludo.directRoll) {
        continue;
      }
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
      if (a.value == 6 && sixes >= 2) return _threeSixes();
      return LudoState(
        positions: positions,
        planes: planes,
        turn: turn,
        dice: a.value,
        lastRoll: a.value,
        sixes: sixes,
        last: last,
      );
    }
    if (a.isPass) {
      return LudoState(
        positions: positions,
        planes: planes,
        turn: (turn + 1) % positions.length,
        lastRoll: lastRoll,
      );
    }
    final d = dice!;
    final k = a.plane!;
    final pos = positions[turn];
    final next = [for (final p in planes) List<int>.of(p)];
    final route = <LudoStep>[];
    final captured = <(int, int, int)>[];
    final captureLegs = <int>[];
    final bombSpots = <(double, double)>[];
    LudoStepKind? bonus;

    void add(int progress, LudoStepKind kind) {
      if (progress == Ludo.goal) {
        final (cx, cy) = Ludo.center;
        route.add(LudoStep(cx, cy, kind));
        return;
      }
      final (x, y) = Ludo.cell(pos, progress);
      route.add(LudoStep(x, y, kind));
    }

    void captureAt(int progress) {
      if (progress > Ludo.lastTrack) return;
      final at = Ludo.trackIndex(pos, progress);
      for (var seat = 0; seat < next.length; seat++) {
        if (seat == turn) continue;
        for (var j = 0; j < next[seat].length; j++) {
          final q = next[seat][j];
          if (q >= 0 &&
              q <= Ludo.lastTrack &&
              Ludo.trackIndex(positions[seat], q) == at) {
            next[seat][j] = Ludo.yard;
            captured.add((seat, j, q));
            captureLegs.add(route.length - 1);
          }
        }
      }
    }

    var p = next[turn][k];
    final fromProgress = p;
    if (p == Ludo.yard) {
      if (d == Ludo.directRoll) {
        p = Ludo.directProgress;
        add(p, LudoStepKind.takeoff);
        captureAt(p);
      } else {
        p = Ludo.ready;
        final (rx, ry) = Ludo.readySpot(pos);
        route.add(LudoStep(rx, ry, LudoStepKind.takeoff));
      }
    } else {
      // The arrow pad sits one step before the start square.
      if (p == Ludo.ready) p = -1;
      final target = p + d;
      if (target <= Ludo.goal) {
        for (var s = p + 1; s <= target; s++) {
          add(s, s == Ludo.goal ? LudoStepKind.home : LudoStepKind.step);
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
      // Landing on an own-colored square jumps four; the flight square then
      // flies. A move jumps once at most, so a flight that lands on an own
      // color still owes the jump if none happened before it.
      var jumped = false;
      bool ownSquare() => p <= Ludo.lastTrack && p % 4 == 1;
      void jump() {
        p += 4;
        add(p, LudoStepKind.jump);
        bonus = LudoStepKind.jump;
        jumped = true;
        captureAt(p);
      }

      void fly() {
        p = Ludo.flyTo;
        add(p, LudoStepKind.fly);
        bonus = LudoStepKind.fly;
        final flyLegIndex = route.length - 1;

        // Check the shortcut cross intersection with the opposite yard's home lane.
        final oppPos = (pos + 2) % 4;
        final oppSeat = positions.indexOf(oppPos);
        if (oppSeat >= 0 && oppSeat != turn) {
          for (var j = 0; j < next[oppSeat].length; j++) {
            if (next[oppSeat][j] == Ludo.flyCrossProgress) {
              next[oppSeat][j] = Ludo.yard;
              captured.add((oppSeat, j, Ludo.flyCrossProgress));
              captureLegs.add(flyLegIndex);
              final spot = Ludo.lanes[oppPos][Ludo.flyCrossStep];
              bombSpots.add(spot);
            }
          }
        }

        final countBeforeLand = captured.length;
        captureAt(p);
        if (captured.length > countBeforeLand) {
          bombSpots.add(Ludo.cell(pos, p));
        }
      }

      if (ownSquare()) {
        if (p == Ludo.flyFrom) {
          fly();
        } else if (p + 4 <= Ludo.lastTrack) {
          jump();
          if (p == Ludo.flyFrom) fly();
        }
        if (!jumped && ownSquare() && p + 4 <= Ludo.lastTrack) jump();
      }
    }
    next[turn][k] = p;
    final again = d == 6 && winnerOf(next) == null;
    return LudoState(
      positions: positions,
      planes: next,
      turn: again ? turn : (turn + 1) % positions.length,
      lastRoll: d,
      sixes: again ? sixes + 1 : 0,
      last: LudoMoveInfo(
        seat: turn,
        plane: k,
        fromProgress: fromProgress,
        route: route,
        captured: captured,
        captureLegs: captureLegs,
        bonus: bonus,
        bombSpots: bombSpots,
      ),
    );
  }

  /// Third six in a row: the roll is void, the seat's furthest plane goes back
  /// to the yard and the turn passes.
  LudoState _threeSixes() {
    final next = [for (final p in planes) List<int>.of(p)];
    final recalled = <(int, int, int)>[];
    var best = -1;
    var bestProgress = Ludo.yard;
    for (var k = 0; k < next[turn].length; k++) {
      final p = next[turn][k];
      if (p > bestProgress && p != Ludo.goal) {
        best = k;
        bestProgress = p;
      }
    }
    if (best >= 0) {
      next[turn][best] = Ludo.yard;
      recalled.add((turn, best, bestProgress));
    }
    return LudoState(
      positions: positions,
      planes: next,
      turn: (turn + 1) % positions.length,
      lastRoll: 6,
      last: LudoMoveInfo(
        seat: turn,
        plane: best < 0 ? 0 : best,
        fromProgress: bestProgress,
        route: const [],
        captured: const [],
        captureLegs: const [],
        bonus: null,
        recalled: recalled,
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
    if (progress < 0 || progress > Ludo.lastTrack) return 0;
    final at = Ludo.trackIndex(s.positions[seat], progress);
    var n = 0;
    for (var o = 0; o < s.planes.length; o++) {
      if (o == seat) continue;
      for (final q in s.planes[o]) {
        if (q < 0 || q > Ludo.lastTrack) continue;
        final from = Ludo.trackIndex(s.positions[o], q);
        final gap = (at - from) % 52;
        if (gap >= 1 && gap <= 6 && q + gap <= Ludo.lastTrack) n++;
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
      v += (p - (before == Ludo.ready ? -1 : before)).toDouble();
    }
    if (p == Ludo.goal) v += 100;
    if (p > Ludo.lastTrack && before <= Ludo.lastTrack) v += 25;
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
