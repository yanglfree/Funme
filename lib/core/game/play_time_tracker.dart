import 'package:flutter/widgets.dart';

import '../storage/app_store.dart';

/// Credits foreground time spent inside a game page to [AppStore].
///
/// Time accrues only while a game route is on top of the home page and the
/// app is in the foreground. [flush] banks the running interval without
/// stopping it.
class PlayTimeTracker {
  PlayTimeTracker({DateTime Function()? clock, AppStore Function()? store})
      : _clock = clock ?? DateTime.now,
        _store = store ?? (() => AppStore.instance);

  static final PlayTimeTracker instance = PlayTimeTracker();

  static const _routePrefix = 'game:';

  static String routeName(String gameId) => '$_routePrefix$gameId';

  final DateTime Function() _clock;
  final AppStore Function() _store;

  String? _game;
  bool _foreground = true;
  DateTime? _since;

  void setGame(String? gameId) {
    if (gameId == _game) return;
    flush();
    _game = gameId;
    _restart();
  }

  void setForeground(bool value) {
    if (value == _foreground) return;
    flush();
    _foreground = value;
    _restart();
  }

  void flush() {
    final since = _since;
    final game = _game;
    if (since == null || game == null) return;
    final now = _clock();
    final seconds = now.difference(since).inSeconds;
    if (seconds <= 0) return;
    // Keep the sub-second remainder for the next interval.
    _since = since.add(Duration(seconds: seconds));
    _store().addPlaySeconds(game, seconds, now: now);
  }

  void _restart() {
    _since = (_game != null && _foreground) ? _clock() : null;
  }
}

/// Reports the topmost game route (see [PlayTimeTracker.routeName]) to the
/// tracker.
class PlayTimeObserver extends NavigatorObserver {
  PlayTimeObserver({PlayTimeTracker? tracker})
      : _tracker = tracker ?? PlayTimeTracker.instance;

  final PlayTimeTracker _tracker;
  final List<Route<dynamic>> _stack = [];

  void _report() {
    String? game;
    for (final route in _stack.reversed) {
      final name = route.settings.name;
      if (name != null && name.startsWith(PlayTimeTracker._routePrefix)) {
        game = name.substring(PlayTimeTracker._routePrefix.length);
        break;
      }
    }
    _tracker.setGame(game);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _report();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _report();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _report();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _stack.remove(oldRoute);
    if (newRoute != null) _stack.add(newRoute);
    _report();
  }
}
