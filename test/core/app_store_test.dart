import 'package:flutter_test/flutter_test.dart';
import 'package:funme/core/storage/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps best stars and best score per game', () async {
    final store = await AppStore.load();
    store.submit('g', stars: 2, win: true, score: 30, lowerIsBetter: true);
    final second =
        store.submit('g', stars: 1, win: true, score: 20, lowerIsBetter: true);
    expect(second.newBestScore, isTrue);
    expect(second.newStars, isFalse);
    final record = store.record('g');
    expect(record.stars, 2);
    expect(record.bestScore, 20);
    expect(record.plays, 2);
    expect(record.wins, 2);
    expect(store.totalStars, 2);
  });

  test('records survive a reload and can be cleared', () async {
    final store = await AppStore.load();
    store.submit('a', stars: 3, win: true, score: 100);
    store.saveSetup('a', {'mode': 'duo'});
    final reloaded = await AppStore.load();
    expect(reloaded.record('a').stars, 3);
    expect(reloaded.setup('a'), {'mode': 'duo'});
    await reloaded.clearRecords();
    expect(reloaded.totalStars, 0);
    expect(reloaded.setup('a'), isNull);
  });

  test('accumulates play time per day and game, prunes old days', () async {
    final store = await AppStore.load();
    final today = DateTime(2026, 10, 9, 12);
    store.addPlaySeconds('a', 120,
        now: today.subtract(const Duration(days: 3)));
    store.addPlaySeconds('a', 60, now: today);
    store.addPlaySeconds('b', 30, now: today);
    expect(store.playSeconds(gameId: 'a', now: today), 60);
    expect(store.playSeconds(gameId: 'a', days: 7, now: today), 180);
    expect(store.playSeconds(days: 7, now: today), 210);
    expect(store.totalPlaySeconds('a'), 180);
    store.addPlaySeconds('a', 10, now: today.add(const Duration(days: 30)));
    expect(store.playSeconds(gameId: 'a', days: 14, now: today), 0);
    expect(store.totalPlaySeconds('a'), 190);
    final reloaded = await AppStore.load();
    expect(reloaded.totalPlaySeconds(), 220);
    await reloaded.clearRecords();
    expect(reloaded.totalPlaySeconds(), 0);
  });
}
