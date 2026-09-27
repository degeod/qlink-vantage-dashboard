import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vierkante analoge standby-klok (12/3/6/9, oranje secondewijzer).
/// Alleen visueel — geen protocol of kalenderlogica.
class StandbyAnalogClock extends StatefulWidget {
  const StandbyAnalogClock({super.key});

  /// Ruim midden: ~40% van de korte zijde, begrensd.
  static const scale = 0.40;
  static const minSide = 220.0;
  static const maxSide = 360.0;

  static const _mark = Color(0xFFD0D0D0);
  static const minuteColor = Color(0x6BD0D0D0);

  @override
  State<StandbyAnalogClock> createState() => _StandbyAnalogClockState();
}

class _StandbyAnalogClockState extends State<StandbyAnalogClock> {
  static const _days = [
    'maandag',
    'dinsdag',
    'woensdag',
    'donderdag',
    'vrijdag',
    'zaterdag',
    'zondag',
  ];
  static const _months = [
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ];

  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    final untilNext = Duration(milliseconds: 1000 - _now.millisecond);
    _timer = Timer(untilNext, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _date {
    final wd = _days[_now.weekday - 1];
    final mo = _months[_now.month - 1];
    return '$wd ${_now.day} $mo';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.biggest.shortestSide;
        final side = (short * StandbyAnalogClock.scale)
            .clamp(StandbyAnalogClock.minSide, StandbyAnalogClock.maxSide);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size.square(side),
              painter: _StandbyClockPainter(_now),
            ),
            SizedBox(height: side * 0.08),
            Text(
              _date,
              style: TextStyle(
                color: StandbyAnalogClock.minuteColor,
                fontSize: side * 0.072,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StandbyClockPainter extends CustomPainter {
  const _StandbyClockPainter(this.now);

  final DateTime now;

  static const _mark = StandbyAnalogClock._mark;
  static const _hand = Color(0xFFE4E4E4);
  static const _accent = Color(0xFFE08A32);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    _paintHourTicks(canvas, c, r);
    _paintMinuteTicks(canvas, c, r);
    _paintNumerals(canvas, c, r);
    _paintHands(canvas, c, r);
  }

  /// Uurstreepjes aan de rand — niet doorgetrokken naar het midden.
  /// Dubbele dikte van de minutenverdeling, kleur van de oude uurlijnen.
  void _paintHourTicks(Canvas canvas, Offset c, double r) {
    final minuteW = math.max(0.8, r * 0.007);
    final paint = Paint()
      ..color = _mark.withValues(alpha: 0.72)
      ..strokeWidth = minuteW * 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2 - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r * 0.88), c + dir * (r * 0.98), paint);
    }
  }

  void _paintMinuteTicks(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..color = _mark.withValues(alpha: 0.42)
      ..strokeWidth = math.max(0.8, r * 0.007)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 60; i++) {
      if (i % 5 == 0) continue;
      final a = (i / 60) * math.pi * 2 - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r * 0.93), c + dir * (r * 0.98), paint);
    }
  }

  void _paintNumerals(Canvas canvas, Offset c, double r) {
    const labels = {0: '12', 3: '3', 6: '6', 9: '9'};
    final fontSize = r * 0.20;
    for (final e in labels.entries) {
      final a = (e.key / 12) * math.pi * 2 - math.pi / 2;
      final pos = c + Offset(math.cos(a), math.sin(a)) * (r * 0.57);
      final tp = TextPainter(
        text: TextSpan(
          text: e.value,
          style: TextStyle(
            color: _mark,
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            fontFamily: 'Roboto',
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintHands(Canvas canvas, Offset c, double r) {
    final hour = now.hour % 12 + now.minute / 60 + now.second / 3600;
    final minute = now.minute + now.second / 60;
    final second = now.second.toDouble();

    final hourA = (hour / 12) * math.pi * 2 - math.pi / 2;
    final minA = (minute / 60) * math.pi * 2 - math.pi / 2;
    final secA = (second / 60) * math.pi * 2 - math.pi / 2;

    final hourPaint = Paint()
      ..color = _hand
      ..strokeWidth = r * 0.072
      ..strokeCap = StrokeCap.round;
    final minPaint = Paint()
      ..color = _hand
      ..strokeWidth = r * 0.062
      ..strokeCap = StrokeCap.round;
    final secPaint = Paint()
      ..color = _accent
      ..strokeWidth = math.max(1.4, r * 0.016)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(c, c + Offset(math.cos(hourA), math.sin(hourA)) * (r * 0.42), hourPaint);
    canvas.drawLine(c, c + Offset(math.cos(minA), math.sin(minA)) * (r * 0.68), minPaint);
    canvas.drawLine(
      c - Offset(math.cos(secA), math.sin(secA)) * (r * 0.16),
      c + Offset(math.cos(secA), math.sin(secA)) * (r * 0.78),
      secPaint,
    );

    canvas.drawCircle(c, r * 0.038, Paint()..color = _accent);
  }

  @override
  bool shouldRepaint(covariant _StandbyClockPainter oldDelegate) =>
      oldDelegate.now.second != now.second ||
      oldDelegate.now.minute != now.minute ||
      oldDelegate.now.hour != now.hour;
}
