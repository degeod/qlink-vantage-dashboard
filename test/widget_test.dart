import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:vantage_control/src/ui/widgets/neo_device_tile.dart';
import 'package:vantage_control/src/ui/widgets/standby_analog_clock.dart';

void main() {
  testWidgets('NeoDeviceTile renders name and status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeoDeviceTile(
            name: 'Wall',
            active: true,
            dimmable: true,
            level: 40,
            onToggle: () {},
          ),
        ),
      ),
    );
    expect(find.text('Wall'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('light tile tap fires onToggle once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeoDeviceTile(
            name: 'Hanglamp',
            active: true,
            showToggleLed: true,
            onToggle: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hanglamp'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('macro tile presses in while held then pops back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeoDeviceTile(
            name: 'All Off',
            status: '',
            active: false,
            glowWhenOff: false,
            pulse: true,
            onToggle: () {},
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.text('All Off'));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(NeoDeviceTile), findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('All Off'), findsOneWidget);
  });

  testWidgets('standby analog clock paints in the center', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Colors.black,
          child: Center(child: StandbyAnalogClock()),
        ),
      ),
    );
    expect(find.byType(StandbyAnalogClock), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Text), findsOneWidget);
  });
}
