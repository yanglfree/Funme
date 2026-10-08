import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/sound_service.dart';
import '../feedback/fx.dart';

enum PlayMode {
  vsAi('人机对战'),
  duo('双人对战');

  const PlayMode(this.label);

  final String label;
}

enum AiLevel {
  easy('简单', 1),
  normal('普通', 2),
  hard('困难', 3);

  const AiLevel(this.label, this.stars);

  final String label;

  /// Stars awarded for beating the AI at this level.
  final int stars;
}

/// Setup of a two-sided match, persisted per game.
@immutable
class DuelSetup {
  const DuelSetup({
    this.mode = PlayMode.vsAi,
    this.level = AiLevel.easy,
    this.humanFirst = true,
  });

  final PlayMode mode;
  final AiLevel level;

  /// In vs-AI mode, whether the human plays side 0 (moves first).
  final bool humanFirst;

  static DuelSetup fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DuelSetup();
    return DuelSetup(
      mode: PlayMode.values.asNameMap()[map['mode']] ?? PlayMode.vsAi,
      level: AiLevel.values.asNameMap()[map['level']] ?? AiLevel.easy,
      humanFirst: map['first'] != 'ai',
    );
  }

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'level': level.name,
        'first': humanFirst ? 'human' : 'ai',
      };
}

@immutable
class DuelOutcome {
  const DuelOutcome.win(int this.winner, [this.reason = '']);
  const DuelOutcome.draw([this.reason = '']) : winner = null;

  /// Winning side (0 or 1); `null` for a draw.
  final int? winner;
  final String reason;
}

/// Shared turn/AI/undo machinery for two-sided board games.
///
/// Subclasses provide pure rules hooks; the controller handles whose turn it
/// is, schedules AI moves without blocking animations, cancels stale AI
/// results after undo/restart, and keeps an undo history.
abstract class DuelController<S, M> extends ChangeNotifier {
  DuelController() {
    _state = initialState();
  }

  DuelSetup _setup = const DuelSetup();
  late S _state;
  final List<(S, M?)> _history = [];
  M? _lastMove;
  M? _hint;
  DuelOutcome? _outcome;
  bool _thinking = false;
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;

  DuelSetup get setup => _setup;
  S get state => _state;
  M? get lastMove => _lastMove;
  M? get hint => _hint;
  DuelOutcome? get outcome => _outcome;
  bool get thinking => _thinking;
  bool get started => _started;
  bool get vsAi => _setup.mode == PlayMode.vsAi;
  int get humanSide => _setup.humanFirst ? 0 : 1;
  int get turn => sideToMove(_state);
  int get moveCount => _history.length;

  bool isAiSide(int side) => vsAi && side != humanSide;

  /// True when a human may interact with the board right now.
  bool get canHumanAct =>
      _started && _outcome == null && !_thinking && !isAiSide(turn);

  bool get canUndo {
    if (_thinking || _history.isEmpty) return false;
    if (!vsAi) return true;
    // Undo must land on a human turn; an AI-first opening has nothing to undo.
    return _history.any((entry) => !isAiSide(sideToMove(entry.$1)));
  }

  // ---- Rules hooks -------------------------------------------------------

  S initialState();
  int sideToMove(S state);
  S apply(S state, M move);
  DuelOutcome? judge(S state);

  /// Computes an AI move for the side to move. Heavy searches should run in
  /// an isolate (`compute`) so animations stay smooth.
  Future<M?> aiMove(S state, AiLevel level);

  /// Hook for sounds/effects after any move (human or AI).
  void onMovePlayed(S before, M move, S after) {}

  /// Hook after the AI's move when it is the human's turn again.
  void onAiReplied() {
    Fx.play(Sfx.turn);
  }

  /// Minimum time an AI turn takes, so its move reads as a reply.
  Duration get aiPacing => const Duration(milliseconds: 520);

  // ---- Actions ----------------------------------------------------------

  void start(DuelSetup setup) {
    _setup = setup;
    _generation++;
    _state = initialState();
    _history.clear();
    _lastMove = null;
    _hint = null;
    _outcome = null;
    _thinking = false;
    _started = true;
    notifyListeners();
    _scheduleAi();
  }

  /// Plays [move] for the side to move. Callers validate legality.
  void play(M move) {
    if (!_started || _outcome != null) return;
    final before = _state;
    _history.add((before, _lastMove));
    _state = apply(before, move);
    _lastMove = move;
    _hint = null;
    _outcome = judge(_state);
    onMovePlayed(before, move, _state);
    notifyListeners();
    _scheduleAi();
  }

  void undo() {
    if (!canUndo) return;
    _generation++;
    _thinking = false;
    do {
      final (state, last) = _history.removeLast();
      _state = state;
      _lastMove = last;
    } while (vsAi && _history.isNotEmpty && isAiSide(sideToMove(_state)));
    _outcome = null;
    _hint = null;
    notifyListeners();
    _scheduleAi();
  }

  Future<void> requestHint() async {
    if (!canHumanAct) return;
    final generation = _generation;
    final historyLength = _history.length;
    final move = await aiMove(_state, AiLevel.normal);
    if (_disposed ||
        generation != _generation ||
        historyLength != _history.length) {
      return;
    }
    _hint = move;
    notifyListeners();
  }

  Future<void> _scheduleAi() async {
    if (!_started || _outcome != null || !isAiSide(turn)) return;
    final generation = _generation;
    final historyLength = _history.length;
    _thinking = true;
    notifyListeners();
    final watch = Stopwatch()..start();
    M? move;
    try {
      move = await aiMove(_state, _setup.level);
    } catch (error, stack) {
      debugPrint('AI failed: $error\n$stack');
    }
    final remaining = aiPacing - watch.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (_disposed ||
        generation != _generation ||
        historyLength != _history.length) {
      return;
    }
    _thinking = false;
    if (move == null) {
      notifyListeners();
      return;
    }
    play(move);
    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (!_disposed && canHumanAct) onAiReplied();
    });
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
