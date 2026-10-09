import 'dart:math' as math;

enum CoinKind {
  silver(0.5, 1),
  gold(0.56, 3),
  gem(0.78, 5);

  const CoinKind(this.radius, this.value);

  final double radius;

  /// Coins credited to the player when this falls into the tray.
  final int value;

  double get mass => radius * radius;
}

class Offset2 {
  const Offset2(this.x, this.y);

  final double x;
  final double y;
}

class Coin {
  Coin(this.kind, this.x, this.y, {this.onPlate = false, this.z = 0})
      : angle = 0;

  final CoinKind kind;
  double x;
  double y;
  double vx = 0;
  double vy = 0;

  /// Visual height above the surface; only the landing animation uses it.
  double z;
  double vz = 0;
  double angle;

  /// True while resting on top of the pusher plate (behind its front face).
  bool onPlate;

  double get r => kind.radius;
}

/// A coin that just tipped over the front edge.
class Fall {
  Fall(this.kind, this.x);

  final CoinKind kind;
  final double x;
  double age = 0;
}

/// Top-down coin pusher. The back wall is y = 0, the open front edge is
/// y = [depth]; a plate slides back and forth along y and shoves the shelf coins
/// toward the edge.
class PusherGame {
  PusherGame({
    this.startCoins = 25,
    this.speed = 1.7,
    math.Random? random,
  })  : _random = random ?? math.Random(),
        ammo = startCoins {
    _fillShelf();
  }

  static const width = 10.0;
  static const depth = 9.5;
  static const frontMin = 2.6;
  static const frontMax = 4.6;
  static const _friction = 5.0;
  static const _step = 1 / 90;

  /// Seconds the player may stay broke with an empty plate before it ends.
  static const _endDelay = 5.0;

  /// A round lasts at most this long, so coin-rich players still finish.
  static const timeLimit = 90.0;

  final int startCoins;
  final double speed;
  final math.Random _random;

  final List<Coin> coins = [];
  final List<Fall> falls = [];

  int ammo;
  int score = 0;
  int gems = 0;
  double front = frontMin;
  double time = 0;
  double _dir = 1;
  double _broke = 0;
  double _acc = 0;

  bool get over => _broke >= _endDelay || time >= timeLimit;

  /// Seconds left in the round.
  double get remaining => math.max(0, timeLimit - time);

  static int starsFor(int score) =>
      score >= 260 ? 3 : (score >= 160 ? 2 : (score >= 80 ? 1 : 0));

  /// Packs the shelf with a jittered hex grid so the pile transmits the
  /// pusher's force right from the first stroke.
  void _fillShelf() {
    const top = frontMax + 0.6;
    final spots = <Offset2>[];
    var row = 0;
    for (var y = top; y <= depth - 0.7; y += 0.9, row++) {
      final shift = row.isEven ? 0.0 : 0.5;
      for (var x = 0.6 + shift; x <= width - 0.6; x += 1.1) {
        if (_random.nextInt(100) < 12) continue;
        spots.add(Offset2(x + (_random.nextDouble() - 0.5) * 0.15,
            y + (_random.nextDouble() - 0.5) * 0.15));
      }
    }
    spots.shuffle(_random);
    for (var i = 0; i < spots.length; i++) {
      final kind =
          i < 3 ? CoinKind.gem : (i < 6 ? CoinKind.gold : CoinKind.silver);
      coins.add(Coin(kind, spots[i].x, spots[i].y));
    }
  }

  /// Drops one coin from the chute at [x]. Returns false when out of coins.
  bool drop(double x) {
    if (ammo <= 0) return false;
    ammo--;
    final kind = _random.nextInt(14) == 0 ? CoinKind.gold : CoinKind.silver;
    final r = kind.radius;
    coins.add(Coin(kind, x.clamp(r + 0.1, width - r - 0.1), 0.9,
        onPlate: true, z: 3.2));
    return true;
  }

  bool get _plateBusy => coins.any((c) => c.onPlate);

  /// Advances the world by [dt] seconds; returns the coins that fell this call.
  List<Fall> advance(double dt) {
    final fell = <Fall>[];
    _acc += dt;
    while (_acc >= _step) {
      _acc -= _step;
      _sub(_step, fell);
    }
    for (final f in falls) {
      f.age += dt;
    }
    falls.removeWhere((f) => f.age > 0.7);
    falls.addAll(fell);
    for (final f in fell) {
      f.age = 0;
    }
    if (ammo <= 0 && !_plateBusy) {
      _broke += dt;
    } else {
      _broke = 0;
    }
    return fell;
  }

  void _sub(double h, List<Fall> fell) {
    time += h;
    final prev = front;
    front += _dir * speed * h;
    if (front >= frontMax) {
      front = frontMax;
      _dir = -1;
    } else if (front <= frontMin) {
      front = frontMin;
      _dir = 1;
    }
    final dFront = front - prev;
    final pusherV = dFront / h;

    final damp = math.exp(-_friction * h);
    for (final c in coins) {
      if (c.z > 0 || c.vz != 0) {
        c.z += c.vz * h;
        c.vz -= 30 * h;
        if (c.z <= 0) {
          c.z = 0;
          c.vz = 0;
        }
      }
      if (c.onPlate) {
        if (dFront > 0) c.y += dFront;
        if (c.y > front) {
          // The plate pulled back from under it: it tips onto the shelf.
          c.onPlate = false;
          c.y = math.max(c.y, front + c.r);
          c.vy = 0.5;
          c.z = 0.4;
        }
      } else {
        c.x += c.vx * h;
        c.y += c.vy * h;
        c.vx *= damp;
        c.vy *= damp;
        if (c.vx.abs() < 0.01) c.vx = 0;
        if (c.vy.abs() < 0.01) c.vy = 0;
      }
    }

    for (var it = 0; it < 6; it++) {
      _separate();
      for (final c in coins) {
        final r = c.r;
        if (c.x < r) {
          c.x = r;
          c.vx = c.vx.abs() * 0.3;
        } else if (c.x > width - r) {
          c.x = width - r;
          c.vx = -c.vx.abs() * 0.3;
        }
        if (c.onPlate) {
          if (c.y < r) c.y = r;
        } else if (c.y - r < front) {
          c.y = front + r;
          if (pusherV > c.vy) c.vy = pusherV;
        }
      }
    }

    coins.removeWhere((c) {
      if (c.onPlate || c.y < depth) return false;
      score += c.kind.value;
      ammo += c.kind.value;
      if (c.kind == CoinKind.gem) gems++;
      fell.add(Fall(c.kind, c.x));
      return true;
    });
  }

  void _separate() {
    final n = coins.length;
    for (var i = 0; i < n; i++) {
      final a = coins[i];
      for (var j = i + 1; j < n; j++) {
        final b = coins[j];
        if (a.onPlate != b.onPlate) continue;
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final min = a.r + b.r;
        final d2 = dx * dx + dy * dy;
        if (d2 >= min * min) continue;
        final d = math.sqrt(d2);
        double nx, ny;
        if (d < 1e-6) {
          final ang = _random.nextDouble() * math.pi * 2;
          nx = math.cos(ang);
          ny = math.sin(ang);
        } else {
          nx = dx / d;
          ny = dy / d;
        }
        final overlap = min - d;
        final total = a.kind.mass + b.kind.mass;
        final wa = b.kind.mass / total;
        final wb = a.kind.mass / total;
        a.x -= nx * overlap * wa;
        a.y -= ny * overlap * wa;
        b.x += nx * overlap * wb;
        b.y += ny * overlap * wb;
        final rel = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (rel < 0) {
          final j = -(1 + 0.15) * rel / (1 / a.kind.mass + 1 / b.kind.mass);
          a.vx -= j * nx / a.kind.mass;
          a.vy -= j * ny / a.kind.mass;
          b.vx += j * nx / b.kind.mass;
          b.vy += j * ny / b.kind.mass;
        }
      }
    }
  }
}
