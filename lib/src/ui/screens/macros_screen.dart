import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/devices.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/device_icon_view.dart';
import '../widgets/icon_type_picker.dart';
import '../widgets/tile_color_picker.dart';

/// Phone-side scenes (WebPoint-style): pick loads from the QLK/project + levels,
/// run them with sequential VLB — not controller VMA.
class MacrosScreen extends StatelessWidget {
  const MacrosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final macros = app.project?.macros ?? [];
    final lightCount = app.project?.lights.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Macros', style: Theme.of(context).textTheme.headlineMedium),
              ),
              TextButton.icon(
                onPressed: () async {
                  await app.addMacro();
                  final created = app.project?.macros.last;
                  if (created != null && context.mounted) {
                    await _openEditor(context, created);
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nieuw'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lightCount == 0
                ? 'Geen lampen in project — laad eerst een QLK in Settings.'
                : 'Vink aan voor Dashboard. Afspelen / bewerken: lampen + dimniveau. '
                    'Icoon + kleur voor Dashboard/Remote. '
                    '$lightCount load(s) beschikbaar.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: macros.isEmpty
                ? Center(
                    child: TextButton(
                      onPressed: () => app.addMacro(name: 'All Off'),
                      child: const Text('Eerste scene aanmaken'),
                    ),
                  )
                : ListView.separated(
                    itemCount: macros.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final macro = macros[i];
                      final n = macro.actions.length;
                      final subtitle = macro.isConfigured
                          ? '$n load${n == 1 ? '' : 's'} · ${macro.room}'
                          : 'Leeg — tik bewerken om lampen te kiezen';
                      final pinned = app.dashboard.isMacroPinned(macro.key);
                      final tileArgb = app.dashboard.tileColors['macro:${macro.key}'];
                      final tileColor = (tileArgb != null && !isTileColorNone(tileArgb))
                          ? Color(tileArgb)
                          : null;
                      return Material(
                        color: AppColors.charcoalElevated,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: pinned,
                                activeColor: AppColors.amber,
                                side: const BorderSide(color: AppColors.muted),
                                onChanged: (v) => app.setMacroPinned(macro.key, v ?? false),
                              ),
                              IconButton(
                                tooltip: 'Type / icoon',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                icon: DeviceIconView(
                                  typeId: macro.iconType,
                                  isOn: true,
                                  size: 22,
                                ),
                                onPressed: () async {
                                  final chosen = await showIconTypePicker(
                                    context,
                                    currentType: macro.iconType,
                                  );
                                  if (chosen != null) {
                                    await app.setMacroIcon(macro, chosen);
                                  }
                                },
                              ),
                            ],
                          ),
                          title: Text(macro.name),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(
                              color: macro.isConfigured ? AppColors.muted : AppColors.amber,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Tegelkleur Dashboard / Remote',
                                icon: Icon(
                                  Icons.palette_outlined,
                                  color: tileColor ?? AppColors.muted,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final chosen = await showTileColorPicker(
                                    context,
                                    title: macro.name,
                                    currentArgb: tileArgb,
                                  );
                                  if (chosen == null) return;
                                  await app.setMacroTileColor(
                                    macro.key,
                                    chosen == -1 ? null : chosen,
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Bewerken',
                                icon: const Icon(Icons.edit_outlined, color: AppColors.ink),
                                onPressed: () => _openEditor(context, macro),
                              ),
                              IconButton(
                                tooltip: 'Afspelen',
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  color: macro.isConfigured ? AppColors.amber : AppColors.muted,
                                ),
                                onPressed: () => app.runMacro(macro),
                              ),
                            ],
                          ),
                          onTap: () => app.runMacro(macro),
                          onLongPress: () => _openEditor(context, macro),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, MacroDevice macro) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MacroEditorScreen(macroKey: macro.key),
      ),
    );
  }
}

class MacroEditorScreen extends StatefulWidget {
  const MacroEditorScreen({super.key, required this.macroKey});

  final String macroKey;

  @override
  State<MacroEditorScreen> createState() => _MacroEditorScreenState();
}

class _MacroEditorScreenState extends State<MacroEditorScreen> {
  late final TextEditingController _nameCtrl;
  /// lightKey -> level (only selected lights)
  late Map<String, int> _levels;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _levels = {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppController>();
      final macro = _find(app);
      _nameCtrl.text = macro?.name ?? 'Scene';
      setState(() {
        _levels = {
          for (final a in macro?.actions ?? const <MacroAction>[])
            a.lightKey: a.level.clamp(0, 100),
        };
        _ready = true;
      });
    });
  }

  MacroDevice? _find(AppController app) {
    final macros = app.project?.macros ?? const <MacroDevice>[];
    for (final m in macros) {
      if (m.key == widget.macroKey) return m;
    }
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppController app) async {
    final macro = _find(app);
    if (macro == null) return;
    macro.name = _nameCtrl.text.trim().isEmpty ? macro.name : _nameCtrl.text.trim();
    macro.actions = [
      for (final e in _levels.entries) MacroAction(lightKey: e.key, level: e.value.clamp(0, 100)),
    ];
    await app.saveMacroConfig(macro);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scene "${macro.name}" opgeslagen')),
      );
      Navigator.of(context).pop();
    }
  }

  void _selectAll(List<LightDevice> lights, int level) {
    setState(() {
      _levels = {for (final l in lights) l.key: level.clamp(0, 100)};
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final macro = _find(app);
    final lights = app.project?.lights ?? const <LightDevice>[];

    if (!_ready || macro == null) {
      return Scaffold(
        backgroundColor: AppColors.charcoal,
        appBar: AppBar(title: const Text('Scene')),
        body: const Center(child: Text('Scene niet gevonden')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        title: const Text('Scene bewerken'),
        actions: [
          IconButton(
            tooltip: 'Verwijderen',
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Scene verwijderen?'),
                  content: Text('"${macro.name}" wordt van deze telefoon verwijderd.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verwijderen')),
                  ],
                ),
              );
              if (ok == true) {
                await app.deleteMacro(macro);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
          TextButton(onPressed: () => _save(app), child: const Text('Opslaan')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Naam',
              hintText: 'bijv. All Off, Evening, Film',
            ),
          ),
          const SizedBox(height: 16),
          Text('Snelkeuze', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('All Off (0%)'),
                onPressed: lights.isEmpty ? null : () {
                  _nameCtrl.text = 'All Off';
                  _selectAll(lights, 0);
                },
              ),
              ActionChip(
                label: const Text('Evening (35%)'),
                onPressed: lights.isEmpty ? null : () {
                  _nameCtrl.text = 'Evening';
                  _selectAll(lights, 35);
                },
              ),
              ActionChip(
                label: const Text('All On (100%)'),
                onPressed: lights.isEmpty ? null : () => _selectAll(lights, 100),
              ),
              ActionChip(
                label: const Text('Leegmaken'),
                onPressed: () => setState(() => _levels.clear()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Lampen uit project / QLK', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Vink loads aan en stel het dimniveau in. Dit zijn dezelfde objecten als na QLK-upload in WebPoint.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          if (lights.isEmpty)
            const Text(
              'Geen loads. Settings → QLK-bestand laden.',
              style: TextStyle(color: AppColors.amber),
            )
          else
            ...lights.map((light) {
              final selected = _levels.containsKey(light.key);
              final level = _levels[light.key] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.charcoalElevated,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected,
                      activeColor: AppColors.amber,
                      title: Text(light.name),
                      subtitle: Text(
                        '${light.room} · ${light.master}.${light.enclosure}.${light.module}.${light.load}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _levels[light.key] = light.dimmable ? (level > 0 ? level : 100) : 100;
                          } else {
                            _levels.remove(light.key);
                          }
                        });
                      },
                    ),
                    if (selected) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text('$level%', style: const TextStyle(color: AppColors.amber)),
                          ),
                          Expanded(
                            child: Slider(
                              value: level.toDouble(),
                              min: 0,
                              max: 100,
                              divisions: light.dimmable ? 20 : 1,
                              label: '$level%',
                              onChanged: (v) {
                                setState(() => _levels[light.key] = v.round());
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _save(app),
            icon: const Icon(Icons.save_outlined),
            label: Text('Opslaan (${_levels.length} loads)'),
          ),
        ],
      ),
    );
  }
}
