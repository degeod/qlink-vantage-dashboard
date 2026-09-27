import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_control/src/ui/widgets/glass_panel.dart';
import 'package:vantage_control/src/ui/widgets/neo_device_tile.dart';

/// Echte app-tegels (glas + achtergrond), geen losse lab-knop.
///   flutter test test/record_in_app_tiles_test.dart
void main() {
  testWidgets('record in-app Evening / All Off / Fan / haard', (tester) async {
    await tester.runAsync(_loadPreviewFonts);
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    const key = ValueKey('in-app-tiles');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: GlassBackdrop(
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                child: Column(
                  children: [
                    NeoDeviceTile(
                      name: 'Evening',
                      status: '',
                      iconType: 'Light',
                      active: false,
                      compact: true,
                      glowColor: const Color(0xFFE07A45),
                      iconTint: const Color(0xFFE07A45),
                      onToggle: () {},
                    ),
                    const SizedBox(height: 10),
                    NeoDeviceTile(
                      name: 'All Off',
                      status: '',
                      iconType: 'Light',
                      active: false,
                      compact: true,
                      glowColor: const Color(0xFF6FBF8B),
                      iconTint: const Color(0xFF6FBF8B),
                      onToggle: () {},
                    ),
                    const SizedBox(height: 10),
                    NeoDeviceTile(
                      name: 'Ventilator',
                      iconType: 'Fan',
                      active: true,
                      compact: true,
                      glowColor: const Color(0xFFE07A5F),
                      onToggle: () {},
                    ),
                    const SizedBox(height: 10),
                    NeoDeviceTile(
                      name: 'Open haard',
                      iconType: 'Fireplace',
                      active: false,
                      compact: true,
                      glowColor: const Color(0xFFE07A45),
                      onToggle: () {},
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

    late File out;
    await tester.runAsync(() async {
      final boundary =
          tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      out = File(r'C:\Users\User\Desktop\in-app-tegels.png');
      await out.writeAsBytes(data!.buffer.asUint8List());
    });

    debugDisableShadows = true;
    expect(out.existsSync(), isTrue);
  });
}

Future<void> _loadPreviewFonts() async {
  Future<ByteData> fromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return ByteData.sublistView(bytes);
  }

  final segoe = FontLoader('Segoe UI')
    ..addFont(fromFile(r'C:\Windows\Fonts\segoeui.ttf'));
  await segoe.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      fromFile(
        r'D:\dev\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      ),
    );
  await icons.load();
}
