import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';

/// Gedeeld soft-UI materiaal. Achtergrond én kaarten zijn uit hetzelfde
/// graphiet gebeeldhouwd, zodat alles naadloos versmelt. Diepte komt van
/// zachte dubbele schaduwen — geen glas, geen harde randen.
class Neo {
  const Neo._();

  static const bg = Color(0xFF26292E);
  static const bgTop = Color(0xFF2B2F35);

  static const surface = Color(0xFF2E3239);

  static const highlight = Color(0xFF3B4048);
  static const shadow = Color(0xFF15171A);

  static const accent = Color(0xFF2EE8E0);

  static const text = Color(0xFFE7E8EB);
  static const textDim = Color(0xFF9AA0A8);

  static const radius = 18.0;

  static Color shade(Color c, double amt) => amt >= 0
      ? Color.lerp(c, const Color(0xFFFFFFFF), amt)!
      : Color.lerp(c, const Color(0xFF000000), -amt)!;

  /// Zachte dubbele schaduw die van verheven (p=0) naar ingedrukt (p=1)
  /// interpoleert; bij p>=0.5 keert het paar om naar inset.
  static List<BoxShadow> depth({
    required double p,
    required double distRaised,
    required double distPressed,
    required double blurRaised,
    required double blurPressed,
    double spread = 0,
    Color light = highlight,
    Color dark = shadow,
  }) {
    final t = p.clamp(0.0, 1.0);
    final dist = lerpDouble(distRaised, distPressed, t)!;
    final blur = lerpDouble(blurRaised, blurPressed, t)!;
    final inset = t >= 0.5;
    return [
      BoxShadow(
        color: light,
        offset: Offset(-dist, -dist),
        blurRadius: blur,
        spreadRadius: spread,
        inset: inset,
      ),
      BoxShadow(
        color: dark,
        offset: Offset(dist, dist),
        blurRadius: blur,
        spreadRadius: spread,
        inset: inset,
      ),
    ];
  }

  /// Subtiele topverlichting op een oppervlak; keert om bij indrukken.
  static Gradient faceGradient(Color base, {bool pressed = false}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: pressed
          ? [shade(base, -0.03), shade(base, 0.03)]
          : [shade(base, 0.05), shade(base, -0.035)],
    );
  }
}

/// Gecarveerde soft-UI kaart. Gebruikt voor weer/kalender/memo én als basis
/// voor de tegels. Zelfde materiaal overal, dus alles blendt. Geen glas.
///
/// Visual only — no device or calendar logic.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = Neo.radius,
    this.padding,
    this.fillColor,
    this.frosted = true,
    this.glowIntensity = 1.0,
    this.pressed = false,
    this.dimFill = 0,
    this.dimFillColor,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? fillColor;

  /// Bewaard voor bestaande call-sites; het materiaal is nu altijd opaak.
  final bool frosted;

  /// Bewaard voor bestaande call-sites.
  final double glowIntensity;

  /// Inset-look: verdiept in het oppervlak.
  final bool pressed;

  /// 0–1 accentvulling vanaf links (dimbare lichten).
  final double dimFill;

  /// Tint voor [dimFill].
  final Color? dimFillColor;

  static const neonCyan = Color(0xFF4DEEEA);
  static const surface = Neo.surface;

  /// Vlak paneel voor weer/kalender/to do list — géén effect (geen schaduw,
  /// geen glans). Effen kleur, subtiel afgerond.
  static const flat = Color(0xFF2A2D33);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final fill = dimFill.clamp(0.0, 1.0);
    final base = fillColor ?? flat;
    final wash = dimFillColor ?? Colors.white;

    final content =
        padding == null ? child : Padding(padding: padding!, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: base,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (fill > 0.004)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fill,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            wash.withValues(alpha: 0.16),
                            wash.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            content,
          ],
        ),
      ),
    );
  }
}

/// Dashboard- en Remote-achtergrond: één graphiet-materiaal met een zachte
/// bovenverlichting, zodat kaarten er organisch uit lijken te groeien.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({
    super.key,
    required this.child,
    this.tintAlpha = 0.72,
    this.patternScale = 2.2,
  });

  final Widget child;

  /// Ongebruikt; bewaard voor bestaande call-sites.
  final double tintAlpha;

  /// Ongebruikt; bewaard voor bestaande call-sites.
  final double patternScale;

  static const base = Neo.bg;

  @override
  Widget build(BuildContext context) {
    assert(tintAlpha >= 0 && patternScale > 0);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.55, -0.95),
          radius: 1.5,
          colors: [Neo.bgTop, Neo.bg],
        ),
      ),
      child: child,
    );
  }
}

SliderThemeData glassSliderTheme(
  BuildContext context, {
  Color activeColor = Neo.accent,
}) {
  return SliderTheme.of(context).copyWith(
    trackHeight: 8,
    activeTrackColor: activeColor,
    inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
    thumbColor: Colors.white,
    overlayColor: activeColor.withValues(alpha: 0.20),
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    trackShape: const RoundedRectSliderTrackShape(),
    showValueIndicator: ShowValueIndicator.never,
  );
}
