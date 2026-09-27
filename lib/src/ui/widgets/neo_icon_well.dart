import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';

/// LOCK 2026-09-06 — grootte en schaduw nooit meer wijzigen.
/// Layout [size] 40. AAN: OverflowBox × 21.5/18.5 (anders kneep Flutter
/// de put terug naar 40 px → 18,5 mm). UIT-schaduw ongewijzigd.
class NeuCircle extends StatelessWidget {
  const NeuCircle({
    super.key,
    required this.size,
    required this.press,
    this.child,
  });

  final double size;
  final double press;
  final Widget? child;

  static const face = Color(0xFF32373E);
  static const _light = Color(0xFF4A515A);
  static const _dark = Color(0xFF0B0D10);

  /// LOCK: gemeten Remote AAN 18,5 mm / UIT 21,5 mm. Niet herschalen.
  static const _aanGrow = 21.5 / 18.5;

  @override
  Widget build(BuildContext context) {
    final t = press.clamp(0.0, 1.0);
    final k = size / 40.0;
    final inset = t >= 0.5;
    final diskSize = inset ? size * _aanGrow : size;

    // GEBLOKKEERD — schaduw niet wijzigen.
    final lightDist = 2.8 * k;
    final lightBlur = 1.0 * k;
    final darkDist = 3.4 * k;
    final darkBlur = 6.0 * k;

    final shadows = [
      BoxShadow(
        color: _light,
        offset: Offset(-lightDist, -lightDist),
        blurRadius: lightBlur,
        inset: inset,
      ),
      BoxShadow(
        color: _dark,
        offset: Offset(darkDist, darkDist),
        blurRadius: darkBlur,
        inset: inset,
      ),
    ];

    final disk = Container(
      width: diskSize,
      height: diskSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: face,
        boxShadow: inset ? shadows : null,
      ),
      child: child,
    );

    // Stack in 40×40 kneep AAN terug naar 40 — daarom bleef 18,5 mm.
    // OverflowBox laat AAN echt 21,5/18,5 groter tekenen.
    return SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: diskSize,
        minHeight: diskSize,
        maxWidth: diskSize,
        maxHeight: diskSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (!inset)
              IgnorePointer(
                child: Container(
                  width: diskSize,
                  height: diskSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: face,
                    boxShadow: shadows,
                  ),
                ),
              ),
            disk,
            IgnorePointer(
              child: CustomPaint(
                size: Size.square(diskSize),
                painter: const _FaceRing(color: face, width: 2),
              ),
            ),
            // UIT: 1 px haarlijn,zelfde kleur als de schijf — snijdt de
            // schaduw scherp af zonder zichtbare tweede-kleur-rand.
            // Binnen de omtrek; SIZE LOCK onaangeroerd.
            if (!inset)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.square(diskSize),
                  painter: const _FaceRing(color: face, width: 1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FaceRing extends CustomPainter {
  const _FaceRing({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true;
    final inset = width / 2;
    canvas.drawOval(
      Rect.fromLTWH(inset, inset, size.width - width, size.height - width),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceRing old) =>
      old.color != color || old.width != width;
}

class NeoIconWell extends StatelessWidget {
  const NeoIconWell({
    super.key,
    required this.child,
    this.size = 40,
    this.pressed = false,
  });

  final Widget child;
  final double size;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      tween: Tween<double>(end: pressed ? 1.0 : 0.0),
      builder: (context, t, child) => NeuCircle(
        size: size,
        press: t,
        child: child,
      ),
      child: child,
    );
  }
}

double neuPressCycle(double t) {
  final x = t % 1.0;
  if (x < 0.38) return 0;
  if (x < 0.50) return Curves.easeInOut.transform((x - 0.38) / 0.12);
  if (x < 0.88) return 1;
  return 1 - Curves.easeInOut.transform((x - 0.88) / 0.12);
}
