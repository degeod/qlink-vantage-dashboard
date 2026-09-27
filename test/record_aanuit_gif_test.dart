import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_control/src/ui/widgets/device_icon_view.dart';
import 'package:vantage_control/src/ui/widgets/glass_panel.dart';
import 'package:vantage_control/src/ui/widgets/neo_icon_well.dart';

/// Scherpe PNG-frames van de cirkel UIT → AAN. Wordt tot aanuit.gif geplakt.
///   flutter test test/record_aanuit_gif_test.dart
void main() {
  testWidgets('record aan/uit knop frames', (tester) async {
    await tester.runAsync(_loadPreviewFonts);
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(960, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const key = ValueKey('aanuit');
    final dir = Directory(r'C:\Users\User\Desktop\aanuit_frames');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    const steps = 10;
    try {
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Neo.bg,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Neo.surface,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Row(
                          children: [
                            NeuCircle(
                              size: 168,
                              press: t,
                              child: DeviceIconView(
                                typeId: 'Fan',
                                isOn: t >= 0.5,
                                size: 78,
                                inset: 0.04,
                                whiteAsset: true,
                                color: Colors.white.withValues(
                                  alpha: t >= 0.5 ? 1 : 0.72,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _Led(on: t >= 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));

        await tester.runAsync(() async {
          final boundary =
              tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File(
            '${dir.path}/frame_${i.toString().padLeft(2, '0')}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
        });
      }
    } finally {
      debugDisableShadows = true;
    }

    expect(dir.listSync().length, steps + 1);
  });
}

class _Led extends StatelessWidget {
  const _Led({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    const accent = Neo.accent;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? accent : const Color(0xFF454A52),
        boxShadow: on
            ? [BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 16)]
            : null,
      ),
    );
  }
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
