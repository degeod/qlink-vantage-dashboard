import 'package:flutter/material.dart';

import '../widgets/neo_icon_well.dart';

/// Losse knop-lab: zelfde painter als de app, geen tegel/slider/glow.
/// [press] 0 = uit (bol), 1 = aan (ingeduwd).
class NeuButtonLab extends StatelessWidget {
  const NeuButtonLab({super.key, required this.press});

  final double press;

  static const bg = Color(0xFF2E3239);

  @override
  Widget build(BuildContext context) {
    final on = press > 0.5;
    const labelStyle = TextStyle(
      fontFamily: 'Segoe UI',
      color: Color(0xFF9AA0A6),
      fontSize: 13,
    );
    return ColoredBox(
      color: bg,
      child: DefaultTextStyle(
        style: labelStyle,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                on ? 'AAN — knop ingeduwd' : 'UIT — knop bol',
                style: const TextStyle(
                  fontFamily: 'Segoe UI',
                  color: Color(0xFFE8EAED),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Slot(
                    label: 'groot',
                    child: NeuCircle(
                      size: 112,
                      press: press,
                      child: Icon(
                        Icons.power_settings_new,
                        size: 44,
                        color: Color.lerp(
                          const Color(0xFF9AA0A6),
                          Colors.white,
                          press,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                  _Slot(
                    label: 'app 40px',
                    child: NeuCircle(
                      size: 40,
                      press: press,
                      child: Icon(
                        Icons.power_settings_new,
                        size: 18,
                        color: Color.lerp(
                          const Color(0xFF9AA0A6),
                          Colors.white,
                          press,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text('auto aan / uit  ·  geen APK'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 12),
        Text(label),
      ],
    );
  }
}
