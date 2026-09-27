import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Vaste kleurenpalet voor Dashboard- en Remote-tegels.
const kTileColorPalette = <Color>[
  Color(0xFFE0A14A), // amber
  Color(0xFF5DADE2), // blue
  Color(0xFF58D68D), // green
  Color(0xFFE59866), // peach
  Color(0xFF48C9B0), // teal
  Color(0xFFF5B041), // gold
  Color(0xFF85C1E9), // light blue
  Color(0xFFDC7633), // orange
  Color(0xFFE07A5F), // coral
  Color(0xFF7BC8A4), // mint
  Color(0xFF6C8EBF), // steel
  Color(0xFFAF7AC5), // purple
];

/// Sentinel: tegel zonder accentkleur (neutraal).
const kTileColorNone = 0x00FFFFFF;

bool isTileColorNone(int? argb) => argb == kTileColorNone;

Future<int?> showTileColorPicker(
  BuildContext context, {
  required String title,
  int? currentArgb,
}) {
  return showModalBottomSheet<int?>(
    context: context,
    backgroundColor: AppColors.charcoalElevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tegelkleur · $title',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Icoon-gloed op Remote en Dashboard. Kies een kleur of geen kleur.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _NoneSwatch(
                    selected: currentArgb == kTileColorNone,
                    onTap: () => Navigator.pop(ctx, kTileColorNone),
                  ),
                  for (final c in kTileColorPalette)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, c.toARGB32()),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentArgb == c.toARGB32()
                                ? Colors.white
                                : Colors.white24,
                            width: currentArgb == c.toARGB32() ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx, -1),
                child: const Text('Automatisch (type/naam)'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NoneSwatch extends StatelessWidget {
  const _NoneSwatch({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Tooltip(
        message: 'Geen kleur',
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A313A),
            border: Border.all(
              color: selected ? Colors.white : Colors.white38,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: const Icon(Icons.block, size: 18, color: Colors.white54),
        ),
      ),
    );
  }
}
