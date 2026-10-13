import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funme/core/storage/app_store.dart';
import 'package:funme/core/widgets/candy_button.dart';
import 'package:funme/core/theme/fun_theme.dart';
import 'package:funme/games/pusher/pusher_page.dart';
import 'package:funme/games/pusher/pusher_painter.dart';
import 'package:funme/games/pusher/pusher_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

PusherPainter painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<PusherPainter>()
    .single;

Future<void> open(WidgetTester tester,
    {Size size = const Size(390, 844)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await AppStore.load();
  await tester.pumpWidget(
      MaterialApp(theme: buildFunTheme(), home: const PusherPage()));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('开始游戏'));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 17));
  }
}

void main() {
  test('chute projection and touch inverse agree across the rail', () {
    for (final x in [0.6, 2.0, 5.0, 8.0, 9.4]) {
      expect(PusherProjection.aimFromX(PusherProjection.point(x, 0.85).dx),
          closeTo(x, 1e-10));
    }
  });

  testWidgets('pause, rules and app background preserve game time and coins',
      (tester) async {
    await open(tester);
    final game = painter(tester).game();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await frames(tester, 5);
    final ammo = game.ammo;
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    final time = game.time;
    await frames(tester, 10);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(game.time, time);
    expect(game.ammo, ammo);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await frames(tester, 5);
    expect(game.time, greaterThan(time));
    await tester.tap(find.byIcon(Icons.question_mark_rounded));
    await tester.pump(const Duration(seconds: 1));
    final rulesTime = game.time;
    await frames(tester, 10);
    expect(game.time, rulesTime);
    await tester.tap(find.text('知道啦'));
    await tester.pump(const Duration(seconds: 1));
    await frames(tester, 5);
    final foregroundTime = game.time;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await frames(tester, 20);
    expect(game.time, foregroundTime);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 2);
    expect(game.time - foregroundTime, lessThan(0.06));
    expect(game.time, greaterThan(foregroundTime));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('canceling restart keeps the same round and collect submits once',
      (tester) async {
    await open(tester);
    final game = painter(tester).game();
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).game(), same(game));
    game.coins.clear();
    await tester.tap(find.text('收币结算'));
    await frames(tester, 240);
    expect(game.end, PusherEnd.collected);
    expect(find.text('本次收获'), findsNWidgets(2));
    expect(AppStore.instance.record('pusher').plays, 1);
    await frames(tester, 60);
    expect(AppStore.instance.record('pusher').plays, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('landscape result keeps both actions visible with a new record',
      (tester) async {
    await open(tester, size: const Size(844, 390));
    final game = painter(tester).game();
    game.coins.clear();
    game.score = 40;
    await tester.tap(find.text('收币结算'));
    await frames(tester, 240);
    expect(find.text('星星  3/3'), findsOneWidget);
    for (final label in ['回首页', '再来一局']) {
      final button = tester.getRect(find.ancestor(
          of: find.text(label), matching: find.byType(CandyButton)));
      expect(button.top, greaterThanOrEqualTo(0));
      expect(button.bottom, lessThanOrEqualTo(390));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(360, 640),
    const Size(844, 390),
    const Size(1180, 820)
  ]) {
    testWidgets('cabinet and controls fit $size', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      final board = tester.getRect(find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PusherPainter));
      expect(board.width, greaterThan(100));
      expect(board.left, greaterThanOrEqualTo(0));
      expect(board.right, lessThanOrEqualTo(size.width));
      expect(board.bottom, lessThanOrEqualTo(size.height));
      for (final label in ['投币！', '收币结算']) {
        final button = tester.getRect(find.ancestor(
            of: find.text(label), matching: find.byType(CandyButton)));
        expect(button.top, greaterThanOrEqualTo(0));
        expect(button.bottom, lessThanOrEqualTo(size.height));
      }
      await tester.ensureVisible(find.text('投币！'));
      final game = painter(tester).game();
      final before = game.ammo;
      await tester.tap(find.text('投币！'));
      await tester.pump();
      expect(game.ammo, before - 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
