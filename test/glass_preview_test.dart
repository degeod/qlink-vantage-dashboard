// Rendert de glas-styling naar PNG's zodat het uiterlijk visueel te
// beoordelen is zonder een APK te installeren:
//   flutter test --update-goldens test/glass_preview_test.dart
// De PNG's komen in test/goldens/. Puur een styling-preview: geen app-logica.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_control/src/ui/widgets/glass_panel.dart';
import 'package:vantage_control/src/ui/widgets/neo_device_tile.dart';

void main() {
  testWidgets('dashboard band preview', (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Preview(child: _DashboardBandMock()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(_Preview),
      matchesGoldenFile('goldens/dashboard_band.png'),
    );
  });

  testWidgets('remote list preview', (tester) async {
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Preview(patternScale: 4.5, child: _RemoteListMock()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(_Preview),
      matchesGoldenFile('goldens/remote_list.png'),
    );
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.child, this.patternScale = 2.2});

  final Widget child;
  final double patternScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GlassBackdrop(
        patternScale: patternScale,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _DashboardBandMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: GlassPanel(child: _WeatherMock())),
            const SizedBox(width: 8),
            Expanded(flex: 5, child: GlassPanel(child: _CalendarMock())),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: GlassPanel(child: _MemoMock())),
          ],
        ),
      ),
    );
  }
}

class _WeatherMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: Colors.white70, size: 26),
              SizedBox(width: 8),
              Text('21°', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              SizedBox(width: 10),
              Text('Rain 20%', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Sint-Niklaas · 06:32 / 21:14',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const Spacer(),
          Row(
            children: [
              for (final d in const ['di', 'wo', 'do', 'vr', 'za', 'zo'])
                Expanded(
                  child: Column(
                    children: [
                      Text(d, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      const Icon(Icons.water_drop_outlined, color: Colors.white70, size: 15),
                      const Text('19°', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Text('augustus 2026',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.count(
              crossAxisCount: 7,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var d = 1; d <= 28; d++)
                  Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: d == 25
                          ? const BoxDecoration(color: Color(0x662E6FFF), shape: BoxShape.circle)
                          : d == 12
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.55), width: 1.2),
                                )
                              : null,
                      child: Text('$d',
                          style: TextStyle(
                              color: d == 25 ? Colors.white : Colors.white70, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Memo', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('• brood\n• melk\n• koffie',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RemoteListMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        children: [
          _MacroMock(label: 'All Off'),
          SizedBox(height: 10),
          _DeviceMock(name: 'Living sfeer', on: true, level: 45),
          SizedBox(height: 10),
          _DeviceMock(name: 'Hanglamp living', on: true, level: 70),
          SizedBox(height: 10),
          _DeviceMock(name: 'Garage', on: false, level: null),
          SizedBox(height: 10),
          _DeviceMock(name: 'Nachtverlichting', on: false, level: 0),
        ],
      ),
    );
  }
}

class _MacroMock extends StatelessWidget {
  const _MacroMock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return NeoDeviceTile(
      name: label,
      status: '',
      active: false,
      compact: true,
      glowColor: const Color(0xFF6FBF8B),
      iconTint: const Color(0xFF6FBF8B),
      glowWhenOff: false,
      icon: const Icon(Icons.power_settings_new, color: Colors.white70, size: 18),
      onToggle: () {},
    );
  }
}

class _DeviceMock extends StatelessWidget {
  const _DeviceMock({required this.name, required this.on, required this.level});

  final String name;
  final bool on;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final dimmable = level != null;
    return NeoDeviceTile(
      name: name,
      active: on,
      dimmable: dimmable,
      level: level ?? 0,
      compact: true,
      glowColor: on ? const Color(0xFFE0A14A) : null,
      icon: Icon(
        on ? Icons.lightbulb : Icons.lightbulb_outline,
        size: 18,
        color: Colors.white.withValues(alpha: on ? 1 : 0.58),
      ),
      onToggle: () {},
      onDimPreview: dimmable ? (_) {} : null,
      onDimEnd: dimmable ? (_) {} : null,
    );
  }
}
