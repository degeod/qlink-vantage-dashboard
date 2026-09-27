import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Slider-achtige aan/uit: zelfde bol als de dimmer, links Uit / rechts Aan.
class OnOffBallSwitch extends StatelessWidget {
  const OnOffBallSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
    this.compact = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final thumbRadius = compact ? 6.0 : 7.0;
    final trackH = compact ? 2.5 : 3.0;
    final labelSize = compact ? 11.0 : 12.0;
    final muted = accent.withValues(alpha: 0.55);

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 2 : 4, 0, compact ? 2 : 4, 0),
      child: Row(
        children: [
          Text(
            'Uit',
            style: GoogleFonts.sourceSans3(
              color: value ? muted : accent,
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: trackH,
                activeTrackColor: accent,
                thumbColor: accent,
                inactiveTrackColor: accent.withValues(alpha: 0.22),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
                overlayShape: SliderComponentShape.noOverlay,
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: value ? 1 : 0,
                min: 0,
                max: 1,
                onChanged: (v) => onChanged(v >= 0.5),
              ),
            ),
          ),
          Text(
            'Aan',
            style: GoogleFonts.sourceSans3(
              color: value ? accent : muted,
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
