import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Skeuomorphic metal on/off toggle: recessed capsule, cyan when on, brushed knob.
class MetalToggleSwitch extends StatelessWidget {
  const MetalToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 56,
    this.height = 30,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _MetalTogglePainter(on: value, enabled: enabled),
          ),
        ),
      ),
    );
  }
}

class _MetalTogglePainter extends CustomPainter {
  _MetalTogglePainter({required this.on, required this.enabled});

  final bool on;
  final bool enabled;

  static const _frameTop = Color(0xFFECECEC);
  static const _frameBot = Color(0xFFC8C8C8);
  static const _offTrack = Color(0xFF3A3A3A);
  static const _offTrackDeep = Color(0xFF2A2A2A);
  static const _cyan = Color(0xFF2EC4C6);
  static const _cyanDeep = Color(0xFF1A9FA1);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 1.5;
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [_frameTop, _frameBot],
        ),
    );

    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2),
      Radius.circular((size.height - pad * 2) / 2),
    );

    if (on) {
      canvas.drawRRect(
        inner,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(pad, pad),
            Offset(pad, size.height - pad),
            enabled
                ? const [_cyan, _cyanDeep]
                : const [Color(0xFF7A9A9A), Color(0xFF5A7A7A)],
          ),
      );
    } else {
      canvas.drawRRect(
        inner,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(pad, pad),
            Offset(pad, size.height - pad),
            const [_offTrackDeep, _offTrack, Color(0xFF4A4A4A)],
            const [0.0, 0.55, 1.0],
          ),
      );
    }

    // Inner recess shadow
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x55000000),
    );

    final thumbR = (size.height - pad * 2) / 2 - 1.5;
    final cy = size.height / 2;
    final cx = on
        ? size.width - pad - 1.5 - thumbR
        : pad + 1.5 + thumbR;

    canvas.drawCircle(
      Offset(cx, cy + 1.2),
      thumbR,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      thumbR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - thumbR * 0.28, cy - thumbR * 0.32),
          thumbR * 1.4,
          const [
            Color(0xFFF5F5F5),
            Color(0xFFC9C9C9),
            Color(0xFF959595),
            Color(0xFFC0C0C0),
          ],
          const [0.0, 0.35, 0.78, 1.0],
        ),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      thumbR * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0x55FFFFFF),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      thumbR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF6E6E6E),
    );
  }

  @override
  bool shouldRepaint(covariant _MetalTogglePainter old) =>
      old.on != on || old.enabled != enabled;
}
