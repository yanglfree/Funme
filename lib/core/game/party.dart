import 'dart:async';

import 'package:flutter/foundation.dart';

import 'duel.dart';

enum SeatKind { human, ai }

/// Setup of a multi-seat match (2–6 seats, any mix of humans and AI).
@immutable
class PartySetup {
  const PartySetup({
    required this.seats,
    this.level = AiLevel.normal,
    this.extra = const {},
  });

  /// Seat kinds in turn order.
  final List<SeatKind> seats;
  final AiLevel level;

  /// Game-specific options from the setup sheet.
  final Map<String, String> extra;

  int get humans => seats.where((s) => s == SeatKind.human).length;

  /// Builds a setup from the standard `players` / `humans` / `level` keys.
  static PartySetup fromMap(Map<String, String> map, {int defaultPlayers = 2}) {
    final players = int.tryParse(map['players'] ?? '') ?? defaultPlayers;
    final humans = (int.tryParse(map['humans'] ?? '') ?? 1).clamp(1, players);
    return PartySetup(
      seats: [
        for (var i = 0; i < players; i++)
          i < humans ? SeatKind.human : SeatKind.ai
      ],
      level: AiLevel.values.asNameMap()[map['level']] ?? AiLevel.normal,
      extra: map,
    );
  }
}

@immutable
class PartyOutcome {
  const PartyOutcome(this.winner, [this.reason = '']);

  /// Winning seat index.
  final int winner;
  final String reason;
}

/// Turn/AI machinery for games with 2–6 seats. Unlike [DuelController] there
/// is no undo (dice and multiple players make it confusing for kids).
abstract class PartyController<S, M> extends ChangeNotifier {
  PartySetup _setup = const PartySetup(seats: [SeatKind.human, SeatKind.ai]);
  late S _state = initialState(_setup);
  PartyOutcome? _outcome;
  bool _thinking = false;
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _autoTimer;

  PartySetup get setup => _setup;
  S get state => _state;
  PartyOutcome? get outcome => _outcome;
  bool get thinking => _thinking;
  bool get started => _started;
  int get seatCount => _setup.seats.length;
  int get turn => seatToMove(_state);

  bool isAi(int seat) => _setup.seats[seat] == SeatKind.ai;

  bool get canHumanAct =>
      _started && _outcome == null && !_thinking && !isAi(turn);

  // ---- Rules hooks -------------------------------------------------------

  S initialState(PartySetup setup);
  int seatToMove(S state);
  S apply(S state, M move);
  PartyOutcome? judge(S state);
  Future<M?> aiMove(S state, AiLevel level);

  /// A move the controller plays on its own for any seat (e.g. "pass" when
  /// nothing can move, or the only legal move). `null` waits for input.
  M? forcedMove(S state) => null;

  /// How long to wait after a move before the next automatic action, so
  /// the move's animation can finish.
  Duration settleTime(S state) => const Duration(milliseconds: 450);

  void onMovePlayed(S before, M move, S after) {}

  // ---- Actions ----------------------------------------------------------

  void start(PartySetup setup) {
    _setup = setup;
    _generation++;
    _autoTimer?.cancel();
    _state = initialState(setup);
    _outcome = null;
    _thinking = false;
    _started = true;
    notifyListeners();
    _scheduleNext(const Duration(milliseconds: 500));
  }

  void play(M move) {
    if (!_started || _outcome != null) return;
    final before = _state;
    _state = apply(before, move);
    _outcome = judge(_state);
    onMovePlayed(before, move, _state);
    notifyListeners();
    _scheduleNext(settleTime(_state));
  }

  void _scheduleNext(Duration delay) {
    _autoTimer?.cancel();
    if (_outcome != null) return;
    final generation = _generation;
    _autoTimer = Timer(delay, () {
      if (_disposed || generation != _generation || _outcome != null) return;
      final forced = forcedMove(_state);
      if (forced != null) {
        play(forced);
        return;
      }
      if (isAi(turn)) _runAi(generation);
    });
  }

  Future<void> _runAi(int generation) async {
    _thinking = true;
    notifyListeners();
    M? move;
    try {
      move = await aiMove(_state, _setup.level);
    } catch (error, stack) {
      debugPrint('AI failed: $error\n$stack');
    }
    if (_disposed || generation != _generation) return;
    _thinking = false;
    if (move == null) {
      notifyListeners();
      return;
    }
    play(move);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _autoTimer?.cancel();
    super.dispose();
  }
}
