import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_control/src/ui/widgets/glass_panel.dart';
import 'package:vantage_control/src/ui/widgets/neo_device_tile.dart';

void main() {
  testWidgets('record dim slider alignment', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1080, 900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    const key = ValueKey('dim-tiles');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: GlassBackdrop(
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    NeoDeviceTile(
                      name: 'Terras',
                      active: true,
                      dimmable: true,
                      level: 40,
                      compact: true,
                      glowColor: const Color(0xFFE0A14A),
                      onToggle: () {},
                      onDimPreview: (_) {},
                      onDimEnd: (_) {},
                    ),
                    const SizedBox(height: 12),
                    NeoDeviceTile(
                      name: 'Nachtverlichting',
                      active: false,
                      dimmable: true,
                      level: 0,
                      compact: true,
                      glowColor: const Color(0xFFE0A14A),
                      onToggle: () {},
                      onDimPreview: (_) {},
                      onDimEnd: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(r'C:\Users\User\Desktop\dim-slider.png')
          .writeAsBytes(data!.buffer.asUint8List());
    });

    debugDisableShadows = true;
    expect(File(r'C:\Users\User\Desktop\dim-slider.png').existsSync(), isTrue);
  });
}
