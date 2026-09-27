import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/devices.dart';
import '../../state/app_controller.dart';
import '../../state/dashboard_config.dart';
import '../shell_nav.dart';
import '../widgets/glass_panel.dart';
import '../widgets/neo_device_tile.dart';
import '../widgets/tile_color_picker.dart';

/// Compact smartphone **Remote-tab** (`AppShell` index 1).
///
/// Deelt met Dashboard via [AppController.dashboard]: `tileColors`,
/// `lightControlModes`, namen/iconen, pins/macros, `remoteOrder`.
/// Styling: zelfde glass/neo als Dashboard ([GlassPanel], [NeoDeviceTile]).
/// Dim-logica ongewijzigd laten.
class PhoneRemoteScreen extends StatefulWidget {
  const PhoneRemoteScreen({super.key});

  @override
  State<PhoneRemoteScreen> createState() => _PhoneRemoteScreenState();
}

class _RemotePalette {
  static const gold = Color(0xFFC9A45C);
  static const ink = Color(0xFFE8E2D6);
}

class _PhoneRemoteScreenState extends State<PhoneRemoteScreen> {
  bool _editing = false;

  Future<void> _pickLightColor(BuildContext context, LightDevice light) async {
    final app = context.read<AppController>();
    final current = app.dashboard.tileColors[light.key];
    final chosen = await showTileColorPicker(
      context,
      title: light.name,
      currentArgb: current,
    );
    if (chosen == null) return;
    await app.setLightTileColor(light.key, chosen == -1 ? null : chosen);
  }

  Future<void> _pickMacroColor(BuildContext context, MacroDevice macro) async {
    final app = context.read<AppController>();
    final key = 'macro:${macro.key}';
    final current = app.dashboard.tileColors[key];
    final chosen = await showTileColorPicker(
      context,
      title: macro.name,
      currentArgb: current,
    );
    if (chosen == null) return;
    await app.setMacroTileColor(macro.key, chosen == -1 ? null : chosen);
  }

  List<String> _layoutIds({
    required List<LightDevice> lights,
    required List<MacroDevice> macros,
    required List<String> saved,
  }) {
    final wanted = <String>{
      for (final m in macros) DashboardConfig.macroTile(m.key),
      for (final l in lights) DashboardConfig.lightTile(l.key),
    };
    final out = <String>[];
    for (final id in saved) {
      if (wanted.remove(id)) out.add(id);
    }
    // Nieuw: macros eerst, daarna loads — zoals de oude remote.
    out.addAll([
      for (final m in macros)
        if (wanted.contains(DashboardConfig.macroTile(m.key))) DashboardConfig.macroTile(m.key),
      for (final l in lights)
        if (wanted.contains(DashboardConfig.lightTile(l.key))) DashboardConfig.lightTile(l.key),
    ]);
    return out;
  }

  Widget _tileForId({
    required String id,
    required AppController app,
    required Map<String, LightDevice> lightsByKey,
    required Map<String, MacroDevice> macrosByKey,
    required bool editing,
  }) {
    if (id.startsWith('macro:')) {
      final m = macrosByKey[id.substring(6)];
      if (m == null) return const SizedBox.shrink();
      return _ScenePill(
        label: m.name,
        iconType: m.iconType,
        accent: _macroAccent(app, m),
        plain: isTileColorNone(app.dashboard.tileColors['macro:${m.key}']),
        onTap: editing ? null : () => app.runMacro(m),
        onLongPress: editing ? null : () => _pickMacroColor(context, m),
        gesturesEnabled: !editing,
      );
    }
    if (id.startsWith('light:')) {
      final light = lightsByKey[id.substring(6)];
      if (light == null) return const SizedBox.shrink();
      return _LoadRow(
        light: light,
        accent: _lightAccent(app, light),
        plain: isTileColorNone(app.dashboard.tileColors[light.key]),
        showSlider: app.dashboard.showSliderForLight(
          light.key,
          dimmable: light.dimmable,
        ),
        gesturesEnabled: !editing,
        onToggle: editing ? () {} : () => app.toggleLight(light),
        onDimPreview: editing ? (_) {} : (v) => app.previewLightLevel(light, v),
        onDimEnd: editing ? (_) {} : (v) => app.setLightLevel(light, v),
        onLongPress: editing ? () {} : () => _pickLightColor(context, light),
      );
    }
    return const SizedBox.shrink();
  }

  String _labelForId(
    String id, {
    required Map<String, LightDevice> lightsByKey,
    required Map<String, MacroDevice> macrosByKey,
  }) {
    if (id.startsWith('macro:')) {
      return macrosByKey[id.substring(6)]?.name ?? id;
    }
    if (id.startsWith('light:')) {
      return lightsByKey[id.substring(6)]?.name ?? id;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final allLights = app.project?.lights ?? const <LightDevice>[];
    final macros = app.project?.macros ?? const <MacroDevice>[];
    final pinnedKeys = app.dashboard.pinnedLights;
    final pinnedMacros = app.dashboard.pinnedMacros;

    final lights = pinnedKeys.isEmpty
        ? allLights.take(24).toList()
        : [
            ...allLights.where((l) => pinnedKeys.contains(l.key)),
            ...allLights.where((l) => !pinnedKeys.contains(l.key)),
          ].take(24).toList();
    final scenes = pinnedMacros.isEmpty
        ? macros.take(24).toList()
        : macros.where((m) => pinnedMacros.contains(m.key)).take(24).toList();

    final demo = allLights.isEmpty;
    final ids = demo
        ? const <String>['demo:avond', 'demo:film', 'demo:uit', 'demo:gasten', 'demo:plafond', 'demo:spots', 'demo:wand', 'demo:lees']
        : _layoutIds(lights: lights, macros: scenes, saved: app.dashboard.remoteOrder);
    final lightsByKey = {for (final l in lights) l.key: l};
    final macrosByKey = {for (final m in scenes) m.key: m};

    return GlassBackdrop(
      patternScale: 4.5,
      child: Stack(
        children: [
          Column(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                4,
                MediaQuery.viewPaddingOf(context).top + 10,
                4,
                2,
              ),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/remote/header-logo.png',
                      height: 22,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Home',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () => ShellNav.of(context).goTo(0),
                          icon: const Icon(Icons.home_outlined,
                              color: Colors.white70),
                        ),
                        if (_editing)
                          const Expanded(
                            child: Text(
                              'Indelen: sleep vrij — 1 of 2 rijen',
                              style: TextStyle(
                                color: _RemotePalette.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        _ConnectLed(status: app.status),
                        IconButton(
                          tooltip: _editing ? 'Klaar' : 'Indelen / verslepen',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              setState(() => _editing = !_editing),
                          icon: Icon(
                            _editing
                                ? Icons.check_rounded
                                : Icons.open_with_rounded,
                            color: _editing
                                ? _RemotePalette.gold
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: demo
                ? ListView(
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 20),
                    children: [
                      for (final s in const [
                        ('Avond', Color(0xFFE07A45)),
                        ('Film', Color(0xFF5DADE2)),
                        ('Alles uit', Color(0xFF6FBF8B)),
                        ('Gasten', Color(0xFFAF7AC5)),
                      ]) ...[
                        _ScenePill(label: s.$1, accent: s.$2, demo: true),
                        const SizedBox(height: 4),
                      ],
                      ..._demoLoads(),
                    ],
                  )
                : Column(
                    children: [
                      if (_editing)
                        _RemoteEditStrip(
                          columns: app.dashboard.remoteColumns.clamp(1, 2),
                          onColumns: (n) => app.setRemoteColumnCount(n),
                          onAddRow: () => app.addRemoteEmptyRow(wanted: ids),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, _) {
                            final cols = app.dashboard.remoteColumns.clamp(1, 2);
                            final cells = app.dashboard.layoutRemoteCells(cols, ids);
                            const pad = EdgeInsets.fromLTRB(6, 4, 6, 20);
                            Widget tileOf(String id) => _tileForId(
                                  id: id,
                                  app: app,
                                  lightsByKey: lightsByKey,
                                  macrosByKey: macrosByKey,
                                  editing: _editing,
                                );
                            if (_editing) {
                              return SingleChildScrollView(
                                clipBehavior: Clip.none,
                                padding: pad,
                                child: _RemoteEditGrid(
                                  columns: cols,
                                  cellIds: cells,
                                  onSwap: (from, to) =>
                                      app.swapRemoteCells(from, to, wanted: ids),
                                  onPlaceInColumn: (from, col) =>
                                      app.placeRemoteTileInColumn(
                                    from,
                                    col,
                                    wanted: ids,
                                  ),
                                  tileBuilder: tileOf,
                                  labelBuilder: (id) => _labelForId(
                                    id,
                                    lightsByKey: lightsByKey,
                                    macrosByKey: macrosByKey,
                                  ),
                                ),
                              );
                            }
                            return SingleChildScrollView(
                              clipBehavior: Clip.none,
                              padding: pad,
                              child: _RemoteViewGrid(
                                columns: cols,
                                cellIds: cells,
                                tileBuilder: tileOf,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  Color _lightAccent(AppController app, LightDevice light) {
    final custom = app.dashboard.tileColors[light.key];
    if (isTileColorNone(custom)) return _RemotePalette.ink;
    if (custom != null) return Color(custom);
    return _autoLightAccent(light);
  }

  Color _macroAccent(AppController app, MacroDevice macro) {
    final custom = app.dashboard.tileColors['macro:${macro.key}'];
    if (isTileColorNone(custom)) return _RemotePalette.ink;
    if (custom != null) return Color(custom);
    return _autoMacroAccent(macro.name);
  }

  List<Widget> _demoLoads() {
    const samples = [
      ('Plafond', true, 72, Color(0xFFE0A14A)),
      ('Spots eettafel', true, 45, Color(0xFF5DADE2)),
      ('Wandlampen', false, 0, Color(0xFF58D68D)),
      ('Leeslamp', true, 30, Color(0xFFE59866)),
    ];
    return [
      for (final s in samples) ...[
        _LoadRowDemo(name: s.$1, isOn: s.$2, level: s.$3, accent: s.$4),
        const SizedBox(height: 4),
      ],
    ];
  }
}

Color _autoLightAccent(LightDevice light) {
  switch (light.iconType) {
    case 'Fan':
      return const Color(0xFFE07A5F);
    case 'Blinds':
    case 'Window':
    case 'Garage':
    case 'Door':
      return const Color(0xFF5B9BD5);
    case 'Music':
      return const Color(0xFF7BC8A4);
    case 'Television':
      return const Color(0xFF6C8EBF);
    case 'Thermostat':
    case 'Spa':
      return const Color(0xFF4FB0A5);
    case 'Fire Place':
      return const Color(0xFFE07040);
    default:
      const hues = [
        Color(0xFFE0A14A),
        Color(0xFF5DADE2),
        Color(0xFF58D68D),
        Color(0xFFE59866),
        Color(0xFF48C9B0),
        Color(0xFFF5B041),
        Color(0xFF85C1E9),
        Color(0xFFDC7633),
      ];
      return hues[light.key.hashCode.abs() % hues.length];
  }
}

Color _autoMacroAccent(String title) {
  final t = title.toLowerCase();
  if (t.contains('off') || t.contains('uit')) return const Color(0xFF6FBF8B);
  if (t.contains('avond') || t.contains('evening') || t.contains('sfeer')) {
    return const Color(0xFFE07A45);
  }
  if (t.contains('aan') || t.contains('ochtend') || t.contains('morning')) {
    return const Color(0xFF48C9B0);
  }
  const hues = [
    Color(0xFFE0A14A),
    Color(0xFF5DADE2),
    Color(0xFF58D68D),
    Color(0xFFE59866),
    Color(0xFFE07A5F),
  ];
  return hues[title.hashCode.abs() % hues.length];
}

class _ConnectLed extends StatelessWidget {
  const _ConnectLed({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case ConnectionStatus.connected:
        color = Neo.accent;
      case ConnectionStatus.connecting:
        color = _RemotePalette.gold;
      case ConnectionStatus.error:
        color = const Color(0xFFD96B5B);
      case ConnectionStatus.disconnected:
        color = const Color(0xFF4A4F57);
    }
    return Tooltip(
      message: status.name,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: status == ConnectionStatus.connected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.7),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _ScenePill extends StatelessWidget {
  const _ScenePill({
    required this.label,
    required this.accent,
    this.iconType,
    this.onTap,
    this.onLongPress,
    this.demo = false,
    this.plain = false,
    this.gesturesEnabled = true,
  });
  final String label;
  final Color accent;
  final String? iconType;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool demo;
  final bool plain;
  final bool gesturesEnabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: demo ? 0.45 : 1,
      child: NeoDeviceTile(
        name: label,
        status: '',
        iconType: iconType,
        active: false,
        glowColor: plain ? null : accent,
        iconTint: plain ? null : accent,
        glowWhenOff: false,
        compact: true,
        pulse: true,
        gesturesEnabled: gesturesEnabled,
        onToggle: onTap ?? () {},
        onLongPress: onLongPress,
      ),
    );
  }
}

/// Load-rij: Wall/Bar-dim of Links/Rechts-toggle, zelfde chrome als Dashboard.
class _LoadRow extends StatelessWidget {
  const _LoadRow({
    required this.light,
    required this.accent,
    required this.onToggle,
    required this.onDimPreview,
    required this.onDimEnd,
    required this.onLongPress,
    this.plain = false,
    this.showSlider = true,
    this.gesturesEnabled = true,
  });

  final LightDevice light;
  final Color accent;
  final VoidCallback onToggle;
  final ValueChanged<int> onDimPreview;
  final ValueChanged<int> onDimEnd;
  final VoidCallback onLongPress;
  final bool plain;
  final bool showSlider;
  final bool gesturesEnabled;

  @override
  Widget build(BuildContext context) {
    return NeoDeviceTile(
      name: light.name,
      iconType: light.iconType,
      active: light.isOn,
      dimmable: showSlider && light.dimmable,
      level: light.level,
      glowColor: plain ? null : accent,
      compact: true,
      gesturesEnabled: gesturesEnabled,
      showToggleLed: !(showSlider && light.dimmable),
      onToggle: onToggle,
      onDimPreview: onDimPreview,
      onDimEnd: onDimEnd,
      onLongPress: onLongPress,
    );
  }
}

class _LoadRowDemo extends StatefulWidget {
  const _LoadRowDemo({
    required this.name,
    required this.isOn,
    required this.level,
    required this.accent,
  });
  final String name;
  final bool isOn;
  final int level;
  final Color accent;

  @override
  State<_LoadRowDemo> createState() => _LoadRowDemoState();
}

class _LoadRowDemoState extends State<_LoadRowDemo> {
  late bool _isOn = widget.isOn;
  late double _level = widget.level.toDouble();

  @override
  Widget build(BuildContext context) {
    return NeoDeviceTile(
      name: widget.name,
      active: _isOn,
      dimmable: true,
      level: _level.round(),
      glowColor: widget.accent,
      compact: true,
      icon: Icon(
        _isOn ? Icons.lightbulb : Icons.lightbulb_outline,
        size: 18,
        color: Colors.white.withValues(alpha: _isOn ? 1 : 0.58),
      ),
      onToggle: () => setState(() {
        _isOn = !_isOn;
        if (!_isOn) {
          _level = 0;
        } else if (_level < 1) {
          _level = 40;
        }
      }),
      onDimPreview: (v) => setState(() {
        _level = v.toDouble();
        _isOn = v > 0;
      }),
      onDimEnd: (v) => setState(() {
        _level = v.toDouble();
        _isOn = v > 0;
      }),
    );
  }
}

class _RemoteEditStrip extends StatelessWidget {
  const _RemoteEditStrip({
    required this.columns,
    required this.onColumns,
    required this.onAddRow,
  });

  final int columns;
  final ValueChanged<int> onColumns;
  final Future<void> Function() onAddRow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Row(
        children: [
          const Text(
            'Rijen',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          for (final n in const [1, 2]) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('$n'),
                selected: columns == n,
                onSelected: (_) => onColumns(n),
                selectedColor: _RemotePalette.gold.withValues(alpha: 0.35),
                labelStyle: const TextStyle(color: Colors.white),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          const Spacer(),
          ActionChip(
            avatar: const Icon(Icons.table_rows_outlined, size: 16, color: Colors.white70),
            label: const Text('Rij +'),
            onPressed: () => onAddRow(),
            labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _RemoteViewGrid extends StatelessWidget {
  const _RemoteViewGrid({
    required this.columns,
    required this.cellIds,
    required this.tileBuilder,
  });

  final int columns;
  final List<String> cellIds;
  final Widget Function(String id) tileBuilder;

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    return LayoutBuilder(
      builder: (context, c) {
        final colW = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final id in cellIds)
              SizedBox(
                width: colW,
                child: DashboardConfig.isEmptyCell(id)
                    ? const SizedBox(height: 4)
                    : tileBuilder(id),
              ),
          ],
        );
      },
    );
  }
}

class _RemoteEditGrid extends StatelessWidget {
  const _RemoteEditGrid({
    required this.columns,
    required this.cellIds,
    required this.tileBuilder,
    required this.labelBuilder,
    required this.onSwap,
    required this.onPlaceInColumn,
  });

  final int columns;
  final List<String> cellIds;
  final Widget Function(String id) tileBuilder;
  final String Function(String id) labelBuilder;
  final Future<void> Function(int from, int to) onSwap;
  final Future<void> Function(int from, int column) onPlaceInColumn;

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    return LayoutBuilder(
      builder: (context, c) {
        final colW = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < cellIds.length; i++)
              SizedBox(
                width: colW,
                child: _RemoteEditCell(
                  index: i,
                  columns: columns,
                  dragWidth: colW,
                  id: cellIds[i],
                  label: DashboardConfig.isEmptyCell(cellIds[i])
                      ? 'Leeg'
                      : labelBuilder(cellIds[i]),
                  onSwap: onSwap,
                  onPlaceInColumn: onPlaceInColumn,
                  child: DashboardConfig.isEmptyCell(cellIds[i])
                      ? null
                      : tileBuilder(cellIds[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RemoteEditCell extends StatelessWidget {
  const _RemoteEditCell({
    required this.index,
    required this.columns,
    required this.dragWidth,
    required this.id,
    required this.label,
    required this.child,
    required this.onSwap,
    required this.onPlaceInColumn,
  });

  final int index;
  final int columns;
  final double dragWidth;
  final String id;
  final String label;
  final Widget? child;
  final Future<void> Function(int from, int to) onSwap;
  final Future<void> Function(int from, int column) onPlaceInColumn;

  bool get _empty => DashboardConfig.isEmptyCell(id);

  @override
  Widget build(BuildContext context) {
    final col = index % columns;
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onSwap(d.data, index),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        if (_empty) {
          return Container(
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hovering ? _RemotePalette.gold : Colors.white24,
                width: hovering ? 2 : 1,
              ),
              color: hovering
                  ? _RemotePalette.gold.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.03),
            ),
            child: Text(
              hovering ? 'Hier' : 'Rij ${col + 1}',
              style: TextStyle(
                color: hovering ? _RemotePalette.gold : Colors.white38,
                fontSize: 11,
              ),
            ),
          );
        }
        return Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            elevation: 12,
            child: Opacity(
              opacity: 0.92,
              child: SizedBox(
                width: dragWidth,
                child: _chrome(
                  label: label,
                  column: col,
                  child: child!,
                  onPlaceInColumn: null,
                  highlight: true,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: _chrome(
              label: label,
              column: col,
              child: child!,
              onPlaceInColumn: null,
            ),
          ),
          child: _chrome(
            label: label,
            column: col,
            child: child!,
            onPlaceInColumn: (c) => onPlaceInColumn(index, c),
            highlight: hovering,
          ),
        );
      },
    );
  }

  Widget _chrome({
    required String label,
    required int column,
    required Widget child,
    required ValueChanged<int>? onPlaceInColumn,
    bool highlight = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? _RemotePalette.gold : Colors.white24,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, color: _RemotePalette.gold, size: 16),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(child: child),
          if (onPlaceInColumn != null && columns > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: 4),
                    InkWell(
                      onTap: c == column ? null : () => onPlaceInColumn(c),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: c == column
                              ? _RemotePalette.gold.withValues(alpha: 0.35)
                              : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: c == column ? _RemotePalette.gold : Colors.white24,
                          ),
                        ),
                        child: Text(
                          '${c + 1}',
                          style: TextStyle(
                            color: c == column ? _RemotePalette.gold : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
