import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funme/core/game/play_time_tracker.dart';
import 'package:funme/core/storage/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('credits only foreground time inside a game route', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    var now = DateTime(2026, 10, 9, 10);
    final tracker = PlayTimeTracker(clock: () => now, store: () => store);
    final observer = PlayTimeObserver(tracker: tracker);
    final home = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final game = MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: RouteSettings(name: PlayTimeTracker.routeName('snake')),
    );

    observer.didPush(home, null);
    now = now.add(const Duration(seconds: 50)); // home: not counted
    observer.didPush(game, home);
    now = now.add(const Duration(seconds: 40));
    tracker.setForeground(false);
    now = now.add(const Duration(seconds: 100)); // backgrounded
    tracker.setForeground(true);
    now = now.add(const Duration(seconds: 20));
    observer.didPop(game, home);
    now = now.add(const Duration(seconds: 30)); // home again

    expect(store.playSeconds(gameId: 'snake', now: now), 60);
    expect(store.totalPlaySeconds(), 60);
  });
}
