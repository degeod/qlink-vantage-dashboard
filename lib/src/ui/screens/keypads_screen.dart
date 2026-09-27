import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/devices.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/rename_dialog.dart';

class KeypadsScreen extends StatelessWidget {
  const KeypadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final keypads = app.project?.keypads ?? const <KeypadDevice>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Keypads', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'Kort tikken = bedienen via Master (zelfde als geüploade QLK) · lang = hernoemen.\n'
            'Amber = Event/LdA in geladen QLK. Grijs = die knop staat niet in de QLK.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: keypads.isEmpty
                ? const Center(child: Text('No keypads in project'))
                : ListView.separated(
                    itemCount: keypads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _KeypadCard(keypad: keypads[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KeypadCard extends StatelessWidget {
  const _KeypadCard({required this.keypad});
  final KeypadDevice keypad;

  Future<void> _renameKeypad(BuildContext context) async {
    final app = context.read<AppController>();
    final name = await showRenameDialog(
      context,
      title: 'Keypad hernoemen',
      currentName: keypad.name,
      hint: 'bijv. Hal keypad',
      maxLength: 28,
    );
    if (name != null && name.isNotEmpty) {
      await app.renameKeypad(keypad, name);
    }
  }

  Future<void> _renameButton(BuildContext context, KeypadButton button) async {
    final app = context.read<AppController>();
    final name = await showRenameDialog(
      context,
      title: 'Knop ${button.switchNumber} hernoemen',
      currentName: button.name,
      hint: 'Korte naam voor op de knop',
      maxLength: 18,
    );
    if (name != null && name.isNotEmpty) {
      await app.renameKeypadButton(keypad, button, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.charcoalElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onLongPress: () => _renameKeypad(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(keypad.name, style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        [
                          'Station ${keypad.station}',
                          if (keypad.serialNumber != null) 'SN ${keypad.serialNumber}',
                          keypad.room,
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Keypad hernoemen',
                onPressed: () => _renameKeypad(context),
                icon: const Icon(Icons.edit_outlined, color: AppColors.muted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final n = keypad.buttons.length;
              // 8-knops: 2 kolommen zoals fysiek paneel, maar knoppen max ~128px
              // (anders worden ze reuzen op tablet landscape).
              const maxBtn = 128.0;
              const gap = 10.0;
              final crossAxisCount = n == 8
                  ? 2
                  : (constraints.maxWidth < 420 ? 3 : 4);
              final gridW = (maxBtn * crossAxisCount) + (gap * (crossAxisCount - 1));
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: gridW.clamp(0.0, constraints.maxWidth),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: n,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (_, i) {
                      final button = keypad.buttons[i];
                      final programmed = button.hasProgram;
                      return Material(
                        color: const Color(0xFF252C38),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            try {
                              await app.pressKeypadButton(keypad, button);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(app.statusMessage),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Keypad: $e')),
                              );
                            }
                          },
                          onLongPress: () => _renameButton(context, button),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: programmed ? AppColors.amber : Colors.white12,
                                width: programmed ? 1.4 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              child: Column(
                                children: [
                                  Text(
                                    '${button.switchNumber}',
                                    style: TextStyle(
                                      color: programmed ? AppColors.amber : Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Expanded(
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 110),
                                          child: Text(
                                            button.name,
                                            textAlign: TextAlign.center,
                                            maxLines: 3,
                                            softWrap: true,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              height: 1.15,
                                              color: programmed ? Colors.white : Colors.white54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!programmed)
                                    const Text(
                                      'niet in QLK',
                                      style: TextStyle(color: Colors.white24, fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
