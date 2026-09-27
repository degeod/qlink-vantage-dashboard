import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_control/src/ui/widgets/glass_panel.dart';
import 'package:vantage_control/src/ui/widgets/neo_icon_well.dart';

/// Renders UIT vs AAN next to each other for visual check.
void main() {
  testWidgets('record neu uit/aan compare', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(800, 280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const key = ValueKey('neu-compare');
    Widget circle(bool on) => NeuCircle(
          size: 96,
          press: on ? 1 : 0,
          child: Icon(
            Icons.power_settings_new,
            size: 40,
            color: on ? Colors.white : const Color(0xFF9AA0A8),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Neo.surface,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  circle(false),
                  const SizedBox(width: 80),
                  circle(true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.runAsync(() async {
      final boundary =
          tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final out = File(
        r'C:\Users\User\Documents\Codex\2026-08-02\referenced-chatgpt-conversation-this-is-an\_crop3\neu_check.png',
      );
      await out.writeAsBytes(data!.buffer.asUint8List());
    });
    debugDisableShadows = true;
  });
}
