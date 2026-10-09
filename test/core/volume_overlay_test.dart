import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funme/core/audio/volume_keys.dart';
import 'package:funme/core/storage/app_store.dart';
import 'package:funme/core/widgets/volume_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStore.load();
  });

  test('volume is clamped and persisted', () async {
    final store = AppStore.instance;
    expect(store.volume, 1.0);
    store.volume = 0.4;
    expect(store.volume, 0.4);
    store.volume = 3;
    expect(store.volume, 1.0);
    store.volume = -1;
    expect(store.volume, 0.0);
    store.volume = 0.7;
    expect((await AppStore.load()).volume, 0.7);
  });

  testWidgets('volume keys step the app volume and pop the panel',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: VolumeOverlay(child: SizedBox.expand()),
    ));
    expect(find.text('100'), findsNothing);
    VolumeKeys.instance.nudge(-VolumeKeys.step);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(AppStore.instance.volume, closeTo(0.9, 1e-9));
    expect(find.text('90'), findsOneWidget);
    // Pushing past the end stop keeps the panel on screen at the limit.
    VolumeKeys.instance.nudge(VolumeKeys.step * 3);
    await tester.pump();
    expect(AppStore.instance.volume, 1.0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('100'), findsNothing);
  });
}
