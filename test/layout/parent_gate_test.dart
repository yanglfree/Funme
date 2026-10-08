import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funme/core/widgets/parent_gate.dart';

void main() {
  for (final size in const [Size(1000, 600), Size(800, 360), Size(360, 640)]) {
    testWidgets('parent gate fits ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showParentGate(context),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('请家长回答'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
