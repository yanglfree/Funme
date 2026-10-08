import 'dart:math' as math;

/// 军棋翻翻棋 (dark Junqi) on the standard 5×12 board. Index = y * 5 + x.
/// Rows 0–5 are the top half, 6–11 the bottom half.
///
/// A piece is encoded as `kind + 1 | color << 4 | revealed << 5`, where
/// `kind` indexes [Jq.names] and `color` 0 = red, 1 = blue.
abstract final class Jq {
  static const width = 5;
  static const height = 12;
  static const cells = width * height;

  static const names = [
    '司令',
    '军长',
    '师长',
    '旅长',
    '团长',
    '营长',
    '连长',
    '排长',
    '工兵',
    '地雷',
    '炸弹',
    '军旗'
  ];
  static const counts = [1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 2, 1];

  static const engineer = 8;
  static const mine = 9;
  static const bomb = 10;
  static const flag = 11;

  static int kind(int v) => (v & 15) - 1;
  static int color(int v) => (v >> 4) & 1;
  static bool revealed(int v) => (v >> 5) & 1 == 1;
  static int make(int kind, int color, {bool revealed = false}) =>
      (kind + 1) | (color << 4) | (revealed ? 32 : 0);
  static int reveal(int v) => v | 32;

  static bool movable(int v) => kind(v) != mine && kind(v) != flag;

  /// Officers compare by rank: 司令 (0) is strongest.
  static int strength(int kind) => kind <= engineer ? 9 - kind : 0;

  static final Set<int> campSet = {
    for (final (x, y) in const [
      (1, 2),
      (3, 2),
      (2, 3),
      (1, 4),
      (3, 4),
      (1, 7),
      (3, 7),
      (2, 8),
      (1, 9),
      (3, 9)
    ])
      y * 5 + x,
  };

  static final Set<int> hqSet = {1, 3, 11 * 5 + 1, 11 * 5 + 3};

  static bool isCamp(int i) => campSet.contains(i);
  static bool isHq(int i) => hqSet.contains(i);

  /// Straight railway lines; pieces slide along one line, engineers may turn.
  static final List<List<int>> railLines = [
    [for (var x = 0; x < 5; x++) 1 * 5 + x],
    [for (var x = 0; x < 5; x++) 5 * 5 + x],
    [for (var x = 0; x < 5; x++) 6 * 5 + x],
    [for (var x = 0; x < 5; x++) 10 * 5 + x],
    [for (var y = 1; y <= 10; y++) y * 5 + 0],
    [for (var y = 1; y <= 10; y++) y * 5 + 4],
    [5 * 5 + 2, 6 * 5 + 2],
  ];

  static final List<Set<int>> _railNeighbors = () {
    final out = List.generate(cells, (_) => <int>{});
    for (final line in railLines) {
      for (var k = 0; k + 1 < line.length; k++) {
        out[line[k]].add(line[k + 1]);
        out[line[k + 1]].add(line[k]);
      }
    }
    return out;
  }();

  static bool onRail(int i) => _railNeighbors[i].isNotEmpty;

  /// One-step road links: orthogonal within a half, the three front-line
  /// crossings, and diagonals into/out of camps.
  static final List<Set<int>> roadNeighbors = () {
    final out = List.generate(cells, (_) => <int>{});
    void link(int a, int b) {
      out[a].add(b);
      out[b].add(a);
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * 5 + x;
        if (x + 1 < width) link(i, i + 1);
        if (y + 1 < height) {
          final crossing = y == 5;
          if (!crossing || x == 0 || x == 2 || x == 4) link(i, i + 5);
        }
      }
    }
    for (final c in campSet) {
      final cx = c % 5;
      final cy = c ~/ 5;
      for (final (dx, dy) in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
        final nx = cx + dx;
        final ny = cy + dy;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if ((cy <= 5) != (ny <= 5)) continue;
        link(c, ny * 5 + nx);
      }
    }
    return out;
  }();

  static const pieceValues = [
    100,
    90,
    80,
    70,
    60,
    50,
    40,
    30,
    45,
    35,
    65,
    1000
  ];
}

enum JqEvent { none, flip, move, capture, trade, bomb, mine, dig, flag }

/// Result of one piece attacking another.
enum JqClash { attackerWins, defenderWins, bothDie, flagTaken }

JqClash jqClash(int attacker, int defender) {
  final a = Jq.kind(attacker);
  final d = Jq.kind(defender);
  if (d == Jq.flag) return JqClash.flagTaken;
  if (a == Jq.bomb || d == Jq.bomb) return JqClash.bothDie;
  if (d == Jq.mine) {
    return a == Jq.engineer ? JqClash.attackerWins : JqClash.defenderWins;
  }
  final sa = Jq.strength(a);
  final sd = Jq.strength(d);
  if (sa == sd) return JqClash.bothDie;
  return sa > sd ? JqClash.attackerWins : JqClash.defenderWins;
}

/// Flip at [at] or move [from] → [to].
class JqAction {
  const JqAction.flip(int this.at)
      : from = null,
        to = null;
  const JqAction.move(int this.from, int this.to) : at = null;

  final int? at;
  final int? from;
  final int? to;

  bool get isFlip => at != null;

  int encode() => isFlip ? 1000 + at! : from! * 64 + to!;

  static JqAction decode(int code) => code >= 1000
      ? JqAction.flip(code - 1000)
      : JqAction.move(code ~/ 64, code % 64);

  @override
  bool operator ==(Object other) =>
      other is JqAction && other.encode() == encode();

  @override
  int get hashCode => encode();
}

class JqState {
  const JqState({
    required this.board,
    required this.ids,
    required this.turn,
    required this.colors,
    this.quiet = 0,
    this.event = JqEvent.none,
    this.eventAt,
    this.flagTakenBy,
  });

  factory JqState.deal(math.Random random) {
    final pieces = <int>[
      for (var color = 0; color < 2; color++)
        for (var kind = 0; kind < Jq.names.length; kind++)
          for (var n = 0; n < Jq.counts[kind]; n++) Jq.make(kind, color),
    ]..shuffle(random);
    final board = List<int>.filled(Jq.cells, 0);
    var k = 0;
    for (var i = 0; i < Jq.cells; i++) {
      if (!Jq.isCamp(i)) board[i] = pieces[k++];
    }
    var id = 1;
    return JqState(
      board: board,
      ids: [for (final v in board) v == 0 ? 0 : id++],
      turn: 0,
      colors: const [-1, -1],
    );
  }

  final List<int> board;
  final List<int> ids;

  /// Player to act (0 moves first).
  final int turn;

  /// Piece color each player controls; -1 until the first flip.
  final List<int> colors;

  /// Plies since the last flip or capture.
  final int quiet;
  final JqEvent event;
  final int? eventAt;

  /// Player who captured a flag, ending the game.
  final int? flagTakenBy;

  static const quietLimit = 80;

  int? get myColor => colors[turn] < 0 ? null : colors[turn];

  bool get hasHidden => board.any((v) => v != 0 && !Jq.revealed(v));

  List<JqAction> legalActions() {
    final out = <JqAction>[];
    for (var i = 0; i < Jq.cells; i++) {
      final v = board[i];
      if (v != 0 && !Jq.revealed(v)) out.add(JqAction.flip(i));
    }
    final color = myColor;
    if (color == null) return out;
    for (var i = 0; i < Jq.cells; i++) {
      final v = board[i];
      if (v == 0 || !Jq.revealed(v) || Jq.color(v) != color || !Jq.movable(v)) {
        continue;
      }
      for (final to in destinations(i)) {
        out.add(JqAction.move(i, to));
      }
    }
    return out;
  }

  bool _canEnter(int mover, int to) {
    final t = board[to];
    if (t == 0) return true;
    if (!Jq.revealed(t) || Jq.color(t) == Jq.color(mover)) return false;
    return !Jq.isCamp(to);
  }

  /// Squares the revealed piece at [from] may move to or attack.
  Set<int> destinations(int from) {
    final mover = board[from];
    final out = <int>{};
    for (final n in Jq.roadNeighbors[from]) {
      if (_canEnter(mover, n)) out.add(n);
    }
    if (!Jq.onRail(from)) return out;
    if (Jq.kind(mover) == Jq.engineer) {
      final seen = {from};
      final queue = [from];
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        for (final n in Jq._railNeighbors[cur]) {
          if (!seen.add(n)) continue;
          if (board[n] == 0) {
            out.add(n);
            queue.add(n);
          } else if (_canEnter(mover, n)) {
            out.add(n);
          }
        }
      }
    } else {
      for (final line in Jq.railLines) {
        final k = line.indexOf(from);
        if (k < 0) continue;
        for (final step in [1, -1]) {
          for (var j = k + step; j >= 0 && j < line.length; j += step) {
            final n = line[j];
            if (board[n] == 0) {
              out.add(n);
              continue;
            }
            if (_canEnter(mover, n)) out.add(n);
            break;
          }
        }
      }
    }
    return out;
  }

  JqState apply(JqAction action) {
    final b = List<int>.of(board);
    final ids = List<int>.of(this.ids);
    var colors = this.colors;
    if (action.isFlip) {
      final at = action.at!;
      b[at] = Jq.reveal(b[at]);
      if (colors[turn] < 0) {
        final c = Jq.color(b[at]);
        colors = turn == 0 ? [c, 1 - c] : [1 - c, c];
      }
      return JqState(
          board: b,
          ids: ids,
          turn: 1 - turn,
          colors: colors,
          event: JqEvent.flip,
          eventAt: at);
    }
    final from = action.from!;
    final to = action.to!;
    final mover = b[from];
    final target = b[to];
    var event = JqEvent.move;
    int? flagBy;
    if (target == 0) {
      b[to] = mover;
      ids[to] = ids[from];
    } else {
      switch (jqClash(mover, target)) {
        case JqClash.flagTaken:
          b[to] = mover;
          ids[to] = ids[from];
          event = JqEvent.flag;
          flagBy = turn;
        case JqClash.attackerWins:
          b[to] = mover;
          ids[to] = ids[from];
          event = Jq.kind(target) == Jq.mine ? JqEvent.dig : JqEvent.capture;
        case JqClash.defenderWins:
          event = Jq.kind(target) == Jq.mine ? JqEvent.mine : JqEvent.capture;
        case JqClash.bothDie:
          b[to] = 0;
          ids[to] = 0;
          event = Jq.kind(mover) == Jq.bomb || Jq.kind(target) == Jq.bomb
              ? JqEvent.bomb
              : JqEvent.trade;
      }
    }
    b[from] = 0;
    ids[from] = 0;
    return JqState(
      board: b,
      ids: ids,
      turn: 1 - turn,
      colors: colors,
      quiet: target == 0 ? quiet + 1 : 0,
      event: event,
      eventAt: to,
      flagTakenBy: flagBy,
    );
  }

  /// Winner (player index), or null while the game goes on.
  int? get winner {
    if (flagTakenBy != null) return flagTakenBy;
    if (colors[turn] >= 0 && legalActions().isEmpty) return 1 - turn;
    return null;
  }
}

/// Heuristic AI that only looks at revealed pieces (no peeking).
abstract final class JqAi {
  static int _value(int v) => Jq.pieceValues[Jq.kind(v)];

  /// Largest loss [piece] on [square] can suffer from a revealed enemy
  /// reply next turn (0 when safe).
  static double _danger(JqState s, int square, int piece) {
    if (Jq.isCamp(square)) return 0;
    final color = Jq.color(piece);
    final probe =
        JqState(board: s.board, ids: s.ids, turn: s.turn, colors: s.colors);
    var worst = 0.0;
    for (var i = 0; i < Jq.cells; i++) {
      final v = s.board[i];
      if (v == 0 || !Jq.revealed(v) || Jq.color(v) == color || !Jq.movable(v)) {
        continue;
      }
      if (!probe.destinations(i).contains(square)) continue;
      final loss = switch (jqClash(v, piece)) {
        JqClash.attackerWins || JqClash.flagTaken => _value(piece).toDouble(),
        JqClash.bothDie => (_value(piece) - _value(v)).toDouble(),
        JqClash.defenderWins => 0.0,
      };
      worst = math.max(worst, loss);
    }
    return worst;
  }

  static double score(JqState s, JqAction a, int level, math.Random rnd) {
    final me = s.myColor;
    if (a.isFlip) {
      var v = 25.0 + rnd.nextDouble() * 30;
      if (me == null) return v;
      // Flipping next to my strong piece may expose a target for it.
      for (final n in Jq.roadNeighbors[a.at!]) {
        final p = s.board[n];
        if (p != 0 &&
            Jq.revealed(p) &&
            Jq.color(p) == me &&
            Jq.strength(Jq.kind(p)) >= 7) {
          v += 8;
        }
      }
      return v;
    }
    final mover = s.board[a.from!];
    final target = s.board[a.to!];
    var v = rnd.nextDouble() * (level == 0 ? 60 : 6);
    if (target != 0) {
      switch (jqClash(mover, target)) {
        case JqClash.flagTaken:
          return 100000;
        case JqClash.attackerWins:
          v += _value(target) + 20;
        case JqClash.defenderWins:
          v -= _value(mover);
        case JqClash.bothDie:
          v += _value(target) - _value(mover) + 5;
      }
    }
    if (level == 0) return v;
    final after = s.apply(a);
    if (after.board[a.to!] == mover) v -= _danger(after, a.to!, mover) * 0.85;
    v += _danger(s, a.from!, mover) * 0.6;
    if (Jq.isCamp(a.to!)) v += 6;
    if (level >= 2) {
      // Look one reply ahead at known captures the opponent gets.
      var reply = 0.0;
      final opp = JqState(
          board: after.board,
          ids: after.ids,
          turn: after.turn,
          colors: after.colors);
      for (final r in opp.legalActions()) {
        if (r.isFlip) continue;
        final t = opp.board[r.to!];
        if (t == 0) continue;
        final clash = jqClash(opp.board[r.from!], t);
        if (clash == JqClash.flagTaken) reply = math.max(reply, 50000);
        if (clash == JqClash.attackerWins) {
          reply = math.max(reply, _value(t).toDouble());
        }
      }
      v -= reply * 0.8;
    }
    return v;
  }

  static JqAction? choose(JqState s, int level, {math.Random? random}) {
    final rnd = random ?? math.Random();
    final actions = s.legalActions();
    if (actions.isEmpty) return null;
    JqAction? best;
    var bestScore = -double.infinity;
    for (final a in actions) {
      final v = score(s, a, level, rnd);
      if (v > bestScore) {
        bestScore = v;
        best = a;
      }
    }
    return best;
  }
}

/// Isolate entry: returns an encoded [JqAction] or -1.
int junqiAiEntry((List<int>, List<int>, int, List<int>, int) args) {
  final (board, ids, turn, colors, level) = args;
  final s = JqState(board: board, ids: ids, turn: turn, colors: colors);
  return JqAi.choose(s, level)?.encode() ?? -1;
}
