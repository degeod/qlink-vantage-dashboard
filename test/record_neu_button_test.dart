import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_control/src/ui/preview/neu_button_lab.dart';
import 'package:vantage_control/src/ui/widgets/neo_icon_well.dart';

/// Schrijft PNG-frames van de losse knop (geen APK).
///   flutter test test/record_neu_button_test.dart
void main() {
  testWidgets('record neu button aan/uit loop', (tester) async {
    await tester.runAsync(_loadPreviewFonts);
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const frames = 48;
    const key = ValueKey('neu-lab');
    final dir = Directory('test/goldens/neu_frames');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    try {
      for (var i = 0; i < frames; i++) {
        final press = neuPressCycle(i / frames);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Segoe UI',
              useMaterial3: true,
            ),
            home: RepaintBoundary(
              key: key,
              child: NeuButtonLab(press: press),
            ),
          ),
        );
        await tester.pump();

        await tester.runAsync(() async {
          final boundary =
              tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File(
            '${dir.path}/frame_${i.toString().padLeft(3, '0')}.png',
          );
          await file.writeAsBytes(data!.buffer.asUint8List());
        });
      }
    } finally {
      debugDisableShadows = true;
    }

    expect(dir.listSync().length, frames);
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
