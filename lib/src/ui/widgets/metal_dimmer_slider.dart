import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Skeuomorphic metal dimmer: recessed track, cyan fill, brushed-metal knob, ticks.
class MetalDimmerSlider extends StatefulWidget {
  const MetalDimmerSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
    this.min = 0,
    this.max = 100,
    this.height = 44,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool enabled;
  final double min;
  final double max;
  final double height;

  @override
  State<MetalDimmerSlider> createState() => _MetalDimmerSliderState();
}

class _MetalDimmerSliderState extends State<MetalDimmerSlider> {
  static const _thumbR = 11.0;
  static const _hPad = 14.0;

  double _clamp(double v) => v.clamp(widget.min, widget.max);

  double _valueFromLocalDx(double dx, double width) {
    final track = (width - _hPad * 2).clamp(1.0, double.infinity);
    final t = ((dx - _hPad) / track).clamp(0.0, 1.0);
    return _clamp(widget.min + t * (widget.max - widget.min));
  }

  void _setFromDx(Offset local, double width, {required bool end}) {
    if (!widget.enabled) return;
    final v = _valueFromLocalDx(local.dx, width);
    widget.onChanged(v);
    if (end) widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.enabled
                ? (d) => _setFromDx(d.localPosition, c.maxWidth, end: true)
                : null,
            onHorizontalDragUpdate: widget.enabled
                ? (d) => _setFromDx(d.localPosition, c.maxWidth, end: false)
                : null,
            onHorizontalDragEnd: widget.enabled
                ? (_) => widget.onChangeEnd?.call(_clamp(widget.value))
                : null,
            child: CustomPaint(
              painter: _MetalDimmerPainter(
                t: t,
                enabled: widget.enabled,
                thumbR: _thumbR,
                hPad: _hPad,
              ),
              size: Size(c.maxWidth, widget.height),
            ),
          );
        },
      ),
    );
  }
}

class _MetalDimmerPainter extends CustomPainter {
  _MetalDimmerPainter({
    required this.t,
    required this.enabled,
    required this.thumbR,
    required this.hPad,
  });

  final double t;
  final bool enabled;
  final double thumbR;
  final double hPad;

  static const _panel = Color(0xFFD8D8D8);
  static const _panelEdge = Color(0xFFB8B8B8);
  static const _trackDark = Color(0xFF3A3A3A);
  static const _trackDeep = Color(0xFF2A2A2A);
  static const _cyan = Color(0xFF2EC4C6);
  static const _cyanDeep = Color(0xFF1A9FA1);
  static const _tick = Color(0xFF8A8A8A);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 2, size.width, size.height - 4),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, size.height),
          const [Color(0xFFE8E8E8), _panel, _panelEdge],
          const [0.0, 0.45, 1.0],
        ),
    );

    const trackH = 10.0;
    final trackTop = size.height / 2 - trackH / 2;
    final trackLeft = hPad;
    final trackRight = size.width - hPad;
    final trackW = trackRight - trackLeft;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(trackLeft, trackTop, trackW, trackH),
      const Radius.circular(5),
    );

    // Tick marks above & below track
    const majors = 10;
    for (var i = 0; i <= majors; i++) {
      final x = trackLeft + trackW * (i / majors);
      if (i < majors) {
        for (var m = 1; m <= 3; m++) {
          final mx = trackLeft + trackW * ((i + m / 4) / majors);
          _tickLine(canvas, mx, trackTop - 5, 4);
          _tickLine(canvas, mx, trackTop + trackH + 1, 4);
        }
      }
      _tickLine(canvas, x, trackTop - 7, 6, thick: true);
      _tickLine(canvas, x, trackTop + trackH + 1, 6, thick: true);
    }

    // Recessed dark track
    canvas.drawRRect(
      trackRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(trackLeft, trackTop),
          Offset(trackLeft, trackTop + trackH),
          const [_trackDeep, _trackDark, Color(0xFF4A4A4A)],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Inner shadow top
    canvas.drawRRect(
      trackRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x66000000),
    );

    // Cyan fill
    if (t > 0.001) {
      final fillW = math.max(trackH, trackW * t);
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(trackLeft, trackTop, fillW.clamp(0, trackW), trackH),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        fillRect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(trackLeft, trackTop),
            Offset(trackLeft, trackTop + trackH),
            enabled
                ? const [_cyan, _cyanDeep]
                : const [Color(0xFF7A9A9A), Color(0xFF5A7A7A)],
            const [0.0, 1.0],
          ),
      );
    }

    // Thumb
    final cx = trackLeft + trackW * t;
    final cy = size.height / 2;
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(cx, cy + 1.5), thumbR, shadow);

    final metal = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - thumbR * 0.25, cy - thumbR * 0.3),
        thumbR * 1.35,
        const [
          Color(0xFFF4F4F4),
          Color(0xFFC8C8C8),
          Color(0xFF9A9A9A),
          Color(0xFFBEBEBE),
        ],
        const [0.0, 0.35, 0.75, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), thumbR, metal);

    // Brushed rings
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0x55FFFFFF);
    canvas.drawCircle(Offset(cx, cy), thumbR * 0.72, ring);
    canvas.drawCircle(
      Offset(cx, cy),
      thumbR * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0x44888888),
    );

    // Rim
    canvas.drawCircle(
      Offset(cx, cy),
      thumbR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF6E6E6E),
    );
  }

  void _tickLine(Canvas canvas, double x, double y, double h, {bool thick = false}) {
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + h),
      Paint()
        ..color = _tick
        ..strokeWidth = thick ? 1.2 : 0.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MetalDimmerPainter old) =>
      old.t != t || old.enabled != enabled;
}
