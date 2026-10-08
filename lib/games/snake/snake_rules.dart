import 'dart:math' as math;

enum SnakeDir {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const SnakeDir(this.dx, this.dy);

  final int dx;
  final int dy;

  bool isOpposite(SnakeDir other) => dx == -other.dx && dy == -other.dy;
}

enum SnakeEvent { none, eat, bonus, crash }

/// Grid snake. Cells are (x, y); the head is `body.first`.
class SnakeGame {
  SnakeGame({
    required this.cols,
    required this.rows,
    this.wrap = false,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    final cx = cols ~/ 2;
    final cy = rows ~/ 2;
    body = [(cx, cy), (cx - 1, cy), (cx - 2, cy)];
    food = _freeCell();
  }

  final int cols;
  final int rows;
  final bool wrap;
  final math.Random _random;

  late List<(int, int)> body;
  SnakeDir dir = SnakeDir.right;
  final List<SnakeDir> _queue = [];
  late (int, int) food;

  /// Kind of fruit to draw (0–3), changes with each new fruit.
  int fruit = 0;
  (int, int)? bonus;
  int bonusSteps = 0;
  int score = 0;
  int eaten = 0;
  bool dead = false;
  int _growth = 0;

  static const bonusLife = 40;

  /// Buffers up to two turns so quick swipes are not lost.
  void turn(SnakeDir next) {
    final last = _queue.isEmpty ? dir : _queue.last;
    if (next == last || next.isOpposite(last) || _queue.length >= 2) return;
    _queue.add(next);
  }

  (int, int) _freeCell() {
    final taken = {...body, if (bonus != null) bonus!};
    while (true) {
      final c = (_random.nextInt(cols), _random.nextInt(rows));
      if (!taken.contains(c)) return c;
    }
  }

  /// Advances one cell and reports what happened.
  SnakeEvent step() {
    if (dead) return SnakeEvent.crash;
    if (_queue.isNotEmpty) dir = _queue.removeAt(0);
    var (x, y) = body.first;
    x += dir.dx;
    y += dir.dy;
    if (wrap) {
      x = (x + cols) % cols;
      y = (y + rows) % rows;
    } else if (x < 0 || y < 0 || x >= cols || y >= rows) {
      dead = true;
      return SnakeEvent.crash;
    }
    final head = (x, y);
    // The tail moves away this step unless the snake is growing.
    final checkLength = _growth > 0 ? body.length : body.length - 1;
    for (var i = 0; i < checkLength; i++) {
      if (body[i] == head) {
        dead = true;
        return SnakeEvent.crash;
      }
    }
    body = [head, ...body];
    if (_growth > 0) {
      _growth--;
    } else {
      body.removeLast();
    }
    var event = SnakeEvent.none;
    if (head == food) {
      score += 10;
      eaten++;
      _growth += 1;
      fruit = _random.nextInt(4);
      food = _freeCell();
      event = SnakeEvent.eat;
      if (bonus == null && eaten % 5 == 0) {
        bonus = _freeCell();
        bonusSteps = bonusLife;
      }
    } else if (head == bonus) {
      score += 50;
      _growth += 2;
      bonus = null;
      event = SnakeEvent.bonus;
    }
    if (bonus != null && --bonusSteps <= 0) bonus = null;
    return event;
  }

  /// Step interval that speeds up as the snake grows.
  Duration interval(int baseMs) {
    final ms = (baseMs - eaten * 4).clamp(baseMs ~/ 2, baseMs);
    return Duration(milliseconds: ms);
  }

  static int starsFor(int score) =>
      score >= 300 ? 3 : (score >= 150 ? 2 : (score >= 50 ? 1 : 0));
}
