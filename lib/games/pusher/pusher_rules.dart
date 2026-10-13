import 'dart:math' as math;

enum CoinKind {
  silver(0.5, 1),
  gold(0.56, 3),
  gem(0.65, 5);

  const CoinKind(this.radius, this.value);
  final double radius;
  final int value;
  double get mass => radius * radius;
}

enum PusherMode { arcade, timed }

enum PusherEnd { empty, time, collected }

class Coin {
  Coin(this.kind, this.x, this.y, {this.onPlate = false, double? z})
      : z = z ?? (onPlate ? PusherGame.plateHeight : 0);

  final CoinKind kind;
  double x;
  double y;
  double vx = 0;
  double vy = 0;

  /// Bottom height in world coordinates, shared by physics and rendering.
  double z;
  double vz = 0;
  double angle = 0;
  bool onPlate;
  Coin? support;
  double tipping = 0;
  bool side = false;
  double get r => kind.radius;
}

class Fall {
  Fall(this.kind, this.x, {this.side = false});
  final CoinKind kind;
  final double x;
  final bool side;
  double age = 0;
}

/// Fixed-step, layered-cylinder simulation. Height gates contact; a coin can
/// rest on another coin and loses that support when their centers separate.
/// This intentionally approximates rigid disks without a platform engine.
class PusherGame {
  PusherGame({
    this.startCoins = 30,
    this.speed = 1.7,
    this.mode = PusherMode.arcade,
    math.Random? random,
  })  : assert(startCoins >= 0),
        assert(speed > 0 && speed < 10),
        _random = random ?? math.Random(),
        ammo = startCoins {
    _fillShelf();
  }

  static const width = 10.0;
  static const depth = 9.5;
  static const frontMin = 2.6;
  static const frontMax = 4.6;
  static const plateHeight = 0.65;
  static const thickness = 0.18;
  static const gutter = 0.65;
  static const gutterStart = 5.3;
  static const timeLimit = 90.0;
  static const _step = 1 / 90;
  static const dropInterval = 0.28;

  final int startCoins;
  final double speed;
  final PusherMode mode;
  final math.Random _random;
  final List<Coin> coins = [];
  final List<Fall> falls = [];
  int ammo;
  int score = 0;
  int gems = 0;
  int lost = 0;
  int inserted = 0;
  double front = frontMin;
  double time = 0;
  double _acc = 0;
  double _nextDrop = 0;
  double _quiet = 0;
  double _phase = 0;
  bool _parked = false;
  PusherEnd? _requestedEnd;
  PusherEnd? end;

  /// Transient sound signals, reset once per advance rather than per substep.
  int contacts = 0;
  bool stroke = false;
  bool _forward = true;
  bool get pushing => _forward;
  bool get over => end != null;
  bool get settling => !over && (_requestedEnd != null || ammo == 0);
  bool get canDrop =>
      !over &&
      _requestedEnd == null &&
      ammo > 0 &&
      time + 1e-8 >= _nextDrop &&
      (mode != PusherMode.timed || time < timeLimit);
  double get remaining => math.max(0, timeLimit - time);

  // Keep score units unchanged; thresholds reflect the finite prize bed.
  static int starsFor(int score) =>
      score >= 40 ? 3 : (score >= 25 ? 2 : (score >= 10 ? 1 : 0));

  void _fillShelf() {
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < (row.isOdd ? 8 : 9); col++) {
        final x = 0.8 + col * 1.04 + (row.isOdd ? 0.52 : 0);
        final y = 5.15 + row * 0.9;
        coins.add(Coin(CoinKind.silver, x, y));
      }
    }
    // Prizes are supported by the lower bed, so removing that bed matters.
    final bases = List<Coin>.of(coins)..shuffle(_random);
    for (var i = 0; i < 9; i++) {
      final base = bases[i];
      final kind = i < 3 ? CoinKind.gem : CoinKind.gold;
      coins.add(Coin(kind, base.x + 0.1, base.y, z: thickness)..support = base);
    }
  }

  bool drop(double x) {
    if (!x.isFinite || !canDrop) return false;
    ammo--;
    inserted++;
    _nextDrop = time + dropInterval;
    // A spent token always creates one token: no random currency inflation.
    coins.add(Coin(CoinKind.silver, x.clamp(0.6, width - 0.6), 0.85,
        onPlate: true, z: 1.7)
      ..vy = 2.4);
    return true;
  }

  /// Stop accepting coins, finish the current stroke, then allow gravity and
  /// payouts to settle. Used by the collect button and the timed challenge.
  void collect() {
    if (!over) _requestedEnd ??= PusherEnd.collected;
  }

  List<Fall> advance(double dt) {
    contacts = 0;
    stroke = false;
    if (over || !dt.isFinite || dt <= 0) return [];
    final fell = <Fall>[];
    // Bound catch-up after a stalled frame; callers pause on lifecycle changes.
    _acc += math.min(dt, 0.1);
    while (_acc + 1e-10 >= _step && !over) {
      _acc -= _step;
      for (final f in falls) {
        f.age += _step;
      }
      falls.removeWhere((f) => f.age >= 0.7);
      _sub(_step, fell);
    }
    return fell;
  }

  void _sub(double h, List<Fall> fell) {
    time += h;
    if (mode == PusherMode.timed && time >= timeLimit) {
      _requestedEnd ??= PusherEnd.time;
    }
    final draining = _requestedEnd != null || ammo == 0;
    final prev = front;
    if (!draining) _parked = false;
    if (!_parked) {
      _phase += h;
      final period = 4 / speed;
      if (_phase >= period) {
        _phase -= period;
        if (draining) {
          _phase = 0;
          _parked = true;
        }
      }
      // Park at the retracted end, after completing the current cycle.
      front = frontMin +
          (frontMax - frontMin) *
              (1 - math.cos(_phase * speed * math.pi / 2)) /
              2;
    }
    final delta = front - prev;
    if (delta.abs() > 1e-8) {
      final forward = delta > 0;
      if (forward != _forward) stroke = true;
      _forward = forward;
    }
    final sorted = List<Coin>.of(coins)..sort((a, b) => a.z.compareTo(b.z));
    final movement = <Coin, (double, double)>{};
    var moving = false;
    for (final c in sorted) {
      final oldX = c.x;
      final oldY = c.y;
      if (c.tipping > 0) {
        c.tipping += h;
        c.angle = math.min(math.pi / 2, c.tipping * 5);
        c.z -= h * 2;
        moving = true;
        continue;
      }
      final support = c.support;
      if (support != null && support.tipping == 0) {
        final shift = movement[support];
        if (shift != null) {
          c.x += shift.$1 * 0.85;
          c.y += shift.$2 * 0.85;
        }
      } else if (c.onPlate && (c.z - plateHeight).abs() < 0.015) {
        // Forward static grip exceeds the sliding return friction.
        c.y += delta * (delta > 0 ? 0.92 : 0.12);
      }
      c.x += c.vx * h;
      c.y += c.vy * h;
      c.vx *= math.exp(-6 * h);
      c.vy *= math.exp(-6 * h);
      c.onPlate = c.y <= front && c.z >= plateHeight - 0.015;
      var floor = c.onPlate ? plateHeight : 0.0;
      Coin? nextSupport;
      for (final other in sorted) {
        if (identical(c, other) || other.tipping > 0 || other.vz != 0) continue;
        final top = other.z + thickness;
        if (top > c.z + 0.025 || top <= floor) continue;
        final dx = c.x - other.x;
        final dy = c.y - other.y;
        // Central overlap is required for stability, not merely touching rims.
        if (dx * dx + dy * dy < math.pow((c.r + other.r) * 0.58, 2)) {
          floor = top;
          nextSupport = other;
        }
      }
      c.vz -= 24 * h;
      c.z += c.vz * h;
      if (c.z <= floor) {
        if (c.vz < -1.5) contacts++;
        c.z = floor;
        c.vz = 0;
        c.support = nextSupport;
        if (nextSupport != null && !_parked) {
          // Motor vibration lets off-center stacks creep toward a free rim.
          // Parking removes this drive; gravity and existing momentum remain.
          final dx = c.x - nextSupport.x;
          final dy = c.y - nextSupport.y;
          final shift = movement[nextSupport];
          final agitation = shift == null
              ? 0.0
              : ((shift.$1.abs() + shift.$2.abs()) / h).clamp(0.0, 1.0);
          final slip = (1 + math.max(0, c.z - plateHeight) * 3) * agitation;
          c.vx += dx * slip * h;
          c.vy += (dy + 0.12) * slip * h;
        }
      } else {
        c.support = null;
      }
      movement[c] = (c.x - oldX, c.y - oldY);
    }

    // Contact resolution only considers overlapping vertical intervals.
    for (var iteration = 0; iteration < 5; iteration++) {
      _separate();
      for (final c in coins) {
        if (c.tipping > 0) continue;
        c.x = c.x.clamp(c.r * 0.35, width - c.r * 0.35);
        c.y = math.max(c.r, c.y);
        if (c.z < plateHeight - 0.02 && c.y - c.r < front) {
          c.y = front + c.r;
          c.vy = math.max(c.vy, math.max(0, delta / h) * 0.6);
        }
      }
    }
    for (final c in coins) {
      if (c.tipping > 0) continue;
      final side = c.y > gutterStart && (c.x < gutter || c.x > width - gutter);
      final edge = c.y > depth;
      if ((side || edge) && c.support == null && c.z < 0.04) {
        c.tipping = h;
        c.side = side;
        moving = true;
      }
      // Overhang tilts before the center of mass leaves the shelf.
      c.angle = c.support == null && c.z < 0.04
          ? ((c.y + c.r - depth) / c.r).clamp(0.0, 1.0) * 0.35
          : 0;
      if (c.vz.abs() > 0.05 || c.vx.abs() + c.vy.abs() > 0.08) moving = true;
    }
    coins.removeWhere((c) {
      if (c.tipping < 0.32) return false;
      if (c.side) {
        lost++;
      } else {
        score += c.kind.value;
        ammo += c.kind.value;
        if (c.kind == CoinKind.gem) gems++;
      }
      final f = Fall(c.kind, c.x, side: c.side);
      fell.add(f);
      falls.add(f);
      return true;
    });
    if (_requestedEnd != null || ammo == 0) {
      if (_parked && !moving && falls.isEmpty) {
        _quiet += h;
      } else {
        _quiet = 0;
      }
      if (_quiet >= 0.8) end = _requestedEnd ?? PusherEnd.empty;
    } else {
      _quiet = 0;
    }
  }

  void _separate() {
    for (var i = 0; i < coins.length; i++) {
      final a = coins[i];
      if (a.tipping > 0) continue;
      for (var j = i + 1; j < coins.length; j++) {
        final b = coins[j];
        if (b.tipping > 0 || (a.z - b.z).abs() >= thickness - 0.025) continue;
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final min = a.r + b.r;
        final d2 = dx * dx + dy * dy;
        if (d2 >= min * min) continue;
        final d = math.sqrt(d2);
        final nx = d < 1e-6 ? 1.0 : dx / d;
        final ny = d < 1e-6 ? 0.0 : dy / d;
        final overlap = min - d;
        final total = a.kind.mass + b.kind.mass;
        a.x -= nx * overlap * b.kind.mass / total;
        a.y -= ny * overlap * b.kind.mass / total;
        b.x += nx * overlap * a.kind.mass / total;
        b.y += ny * overlap * a.kind.mass / total;
        final rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (rel < -0.25) contacts++;
        if (rel < 0) {
          final impulse = -1.08 * rel / (1 / a.kind.mass + 1 / b.kind.mass);
          a.vx -= impulse * nx / a.kind.mass;
          a.vy -= impulse * ny / a.kind.mass;
          b.vx += impulse * nx / b.kind.mass;
          b.vy += impulse * ny / b.kind.mass;
        }
      }
    }
  }
}
