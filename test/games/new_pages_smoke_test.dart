import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funme/core/storage/app_store.dart';
import 'package:funme/games/merge2048/merge2048_page.dart';
import 'package:funme/games/pusher/pusher_page.dart';
import 'package:funme/games/sudoku/sudoku_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(780, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(); // post-frame callback pushes the setup sheet
  await tester.pump(const Duration(seconds: 1));
  final start = find.text('开始游戏');
  expect(start, findsOneWidget);
  await tester.tap(start);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStore.load();
  });

  testWidgets('2048 plays moves by keyboard and swipe', (tester) async {
    await _open(tester, const Merge2048Page());
    for (final k in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
    ]) {
      await tester.sendKeyEvent(k);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.drag(find.byType(AspectRatio).first, const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sudoku fills a cell and uses a hint', (tester) async {
    await _open(tester, const SudokuPage());
    // Puzzle generation runs in a real isolate.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('开始游戏'), findsNothing);
    await tester.tap(find.byIcon(Icons.lightbulb_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('提示 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('coin pusher drops coins by tap, drag and keyboard',
      (tester) async {
    await _open(tester, const PusherPage());
    await tester.tap(find.byType(AspectRatio).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(AspectRatio).first, const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('手上'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
