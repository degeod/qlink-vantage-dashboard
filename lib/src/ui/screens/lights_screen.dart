import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/devices.dart';
import '../../state/app_controller.dart';
import '../../state/dashboard_config.dart';
import '../device_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/device_icon_view.dart';
import '../widgets/icon_type_picker.dart';
import '../widgets/rename_dialog.dart';
import '../widgets/tile_color_picker.dart';

class LightsScreen extends StatelessWidget {
  const LightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lights = app.project?.lights ?? const <LightDevice>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lights', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'Potlood = naam · adres = IPE-load kiezen · icoon = Type · '
            'kleurtje = tegelkleur · vink = Dashboard · '
            'bediening = schuif of toggle op Remote/Dashboard',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: lights.isEmpty
                ? const Center(child: Text('No lights in project'))
                : ListView.separated(
                    itemCount: lights.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _LightTile(light: lights[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LightTile extends StatelessWidget {
  const _LightTile({required this.light});
  final LightDevice light;

  Future<void> _pickLoad(BuildContext context) async {
    final app = context.read<AppController>();
    final chosen = await showDialog<(int, int, int)>(
      context: context,
      builder: (ctx) => _LoadPickDialog(light: light),
    );
    if (chosen == null) return;
    await app.rebindLight(
      light,
      enclosure: chosen.$1,
      module: chosen.$2,
      load: chosen.$3,
    );
  }

  Future<void> _rename(BuildContext context) async {
    final app = context.read<AppController>();
    final name = await showRenameDialog(
      context,
      title: 'Load hernoemen',
      currentName: light.name,
      hint: 'bijv. Woonkamer plafond',
      maxLength: 32,
    );
    if (name != null && name.isNotEmpty) {
      await app.renameLight(light, name);
    }
  }

  Future<void> _pickIcon(BuildContext context) async {
    final app = context.read<AppController>();
    final chosen = await showIconTypePicker(context, currentType: light.iconType);
    if (chosen != null && chosen.isNotEmpty) {
      await app.setLightIcon(light, chosen);
    }
  }

  Future<void> _pickColor(BuildContext context) async {
    final app = context.read<AppController>();
    final current = app.dashboard.tileColors[light.key];
    final chosen = await showTileColorPicker(
      context,
      title: light.name,
      currentArgb: current,
    );
    if (chosen == null) return; // dismissed
    if (chosen == -1) {
      await app.setLightTileColor(light.key, null);
    } else {
      await app.setLightTileColor(light.key, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final type = DeviceIcons.byId(light.iconType);
    final pinned = app.dashboard.isLightPinned(light.key);
    final tileArgb = app.dashboard.tileColors[light.key];
    final tileColor = (tileArgb != null && !isTileColorNone(tileArgb))
        ? Color(tileArgb)
        : null;
    final controlMode = app.dashboard.controlModeForLight(light.key, dimmable: light.dimmable);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.charcoalElevated,
        borderRadius: BorderRadius.circular(20),
        border: tileColor != null
            ? Border.all(color: tileColor.withValues(alpha: 0.55), width: 1.2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: light.isOn ? AppColors.amber : const Color(0x22FFFFFF),
                  foregroundColor: light.isOn ? const Color(0xFF1A1208) : AppColors.ink,
                ),
                tooltip: 'Aan/uit',
                onPressed: () => app.toggleLight(light),
                onLongPress: () => _pickIcon(context),
                icon: DeviceIconView(
                  typeId: light.iconType,
                  isOn: light.isOn,
                  size: 20,
                  color: light.isOn ? const Color(0xFF1A1208) : AppColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickLoad(context),
                  onLongPress: () => _rename(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(light.name, style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${light.room} · ${type.label} · '
                        '${light.master}/${light.enclosure}/${light.module}/${light.load}  · tik = load',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Checkbox(
                value: pinned,
                activeColor: AppColors.amber,
                side: const BorderSide(color: AppColors.muted),
                onChanged: (v) => app.setLightPinned(light.key, v ?? false),
              ),
              IconButton(
                tooltip: 'Tegelkleur Dashboard',
                onPressed: () => _pickColor(context),
                icon: Icon(
                  Icons.palette_outlined,
                  color: tileColor ?? AppColors.muted,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'Type / icoon',
                onPressed: () => _pickIcon(context),
                icon: DeviceIconView(
                  typeId: light.iconType,
                  isOn: true,
                  size: 18,
                  color: type.hasAsset ? null : AppColors.muted,
                ),
              ),
              IconButton(
                tooltip: 'Hernoemen',
                onPressed: () => _rename(context),
                icon: const Icon(Icons.edit_outlined, color: AppColors.muted, size: 20),
              ),
              Text('${light.level}%', style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
            ],
          ),
          if (light.dimmable) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Remote / Dashboard', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<LightControlMode>(
                    segments: const [
                      ButtonSegment(
                        value: LightControlMode.slider,
                        label: Text('Schuif'),
                        icon: Icon(Icons.tune, size: 16),
                      ),
                      ButtonSegment(
                        value: LightControlMode.toggle,
                        label: Text('Toggle'),
                        icon: Icon(Icons.toggle_on, size: 16),
                      ),
                    ],
                    selected: {controlMode},
                    onSelectionChanged: (s) => app.setLightControlMode(light.key, s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Slider(
              value: light.level.toDouble(),
              min: 0,
              max: 100,
              onChanged: (v) => context.read<AppController>().previewLightLevel(light, v.round()),
              onChangeEnd: (v) => app.setLightLevel(light, v.round()),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadPickDialog extends StatefulWidget {
  const _LoadPickDialog({required this.light});
  final LightDevice light;

  @override
  State<_LoadPickDialog> createState() => _LoadPickDialogState();
}

class _LoadPickDialogState extends State<_LoadPickDialog> {
  late final TextEditingController _enc;
  late final TextEditingController _mod;
  late final TextEditingController _load;

  @override
  void initState() {
    super.initState();
    _enc = TextEditingController(text: '${widget.light.enclosure}');
    _mod = TextEditingController(text: '${widget.light.module}');
    _load = TextEditingController(text: '${widget.light.load}');
  }

  @override
  void dispose() {
    _enc.dispose();
    _mod.dispose();
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Load voor ${widget.light.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Master ${widget.light.master} · enclosure / module / load',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _enc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enc'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _mod, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mod'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _load, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Load'))),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleer')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, (
              int.tryParse(_enc.text.trim()) ?? widget.light.enclosure,
              int.tryParse(_mod.text.trim()) ?? widget.light.module,
              int.tryParse(_load.text.trim()) ?? widget.light.load,
            ));
          },
          child: const Text('Kies'),
        ),
      ],
    );
  }
}
