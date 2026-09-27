import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/devices.dart';
import '../../state/app_controller.dart';
import '../../state/dashboard_config.dart';
import '../shell_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_top_band.dart';
import '../widgets/glass_panel.dart';
import '../widgets/neo_device_tile.dart';
import '../widgets/nvr_live_panel.dart';
import '../widgets/tile_color_picker.dart';
import '../widgets/wall_tablet_presence.dart';
import '../widgets/weather_city_picker.dart';

/// Dashboard-tab: vaste [DashboardTopBand] + tile-raster + muur-tablet.
///
/// Kalender/memo-gedrag zit in `dashboard_top_band.dart`, persist in
/// [DashboardConfig] / [AppController.setDashboardDayMemo].
/// Remote-tab (`phone_remote_screen.dart`) deelt `tileColors` en apparaatinstellingen.
/// Styling: [GlassPanel] + [NeoDeviceTile]; functionele logica niet wijzigen bij een restyle.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _card = Color(0xFF25262B);

  bool _editing = false;
  late DateTime _now;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _runLight(LightDevice light) async {
    final app = context.read<AppController>();
    try {
      await app.toggleLight(light);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lamp: $e')));
    }
  }

  Future<void> _dimLight(LightDevice light, int level) async {
    final app = context.read<AppController>();
    try {
      await app.setLightLevel(light, level);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dim: $e')));
    }
  }

  Future<void> _runMacro(MacroDevice macro) async {
    final app = context.read<AppController>();
    try {
      await app.runMacro(macro);
      if (!mounted) return;
      if (!macro.isConfigured) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scene "${macro.name}" is leeg — bewerk in Macros')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Macro: $e')));
    }
  }

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

  String _tileLabel(
    String id, {
    required Map<String, LightDevice> lightsByKey,
    required Map<String, MacroDevice> macrosByKey,
  }) {
    if (id.startsWith('light:')) {
      return lightsByKey[id.substring(6)]?.name ?? id.substring(6);
    }
    if (id.startsWith('macro:')) {
      return macrosByKey[id.substring(6)]?.name ?? id.substring(6);
    }
    return id;
  }

  Future<void> _removeTile(String id) async {
    final app = context.read<AppController>();
    if (id.startsWith('light:')) {
      await app.setLightPinned(id.substring(6), false);
    } else if (id.startsWith('macro:')) {
      await app.setMacroPinned(id.substring(6), false);
    }
  }

  Future<void> _openAddTilesSheet() async {
    final app = context.read<AppController>();
    final lights = [...(app.project?.lights ?? const <LightDevice>[])]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final macros = [...(app.project?.macros ?? const <MacroDevice>[])]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.charcoalElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scroll) {
            return Consumer<AppController>(
              builder: (_, live, __) {
                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const Text(
                      'Tegels op Dashboard',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Vink lights/macros aan. Volgorde wijzig je daarna door te slepen.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    const Text('Lights', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600)),
                    if (lights.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Geen lights in project', style: TextStyle(color: Colors.white38)),
                      )
                    else
                      for (final light in lights)
                        CheckboxListTile(
                          dense: true,
                          value: live.dashboard.isLightPinned(light.key),
                          onChanged: (v) => live.setLightPinned(light.key, v ?? false),
                          title: Text(light.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(light.room, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.amber,
                        ),
                    const SizedBox(height: 12),
                    const Text('Macros', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600)),
                    if (macros.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Geen macros in project', style: TextStyle(color: Colors.white38)),
                      )
                    else
                      for (final macro in macros)
                        CheckboxListTile(
                          dense: true,
                          value: live.dashboard.isMacroPinned(macro.key),
                          onChanged: (v) => live.setMacroPinned(macro.key, v ?? false),
                          title: Text(macro.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            macro.isConfigured ? 'Klaar' : 'Nog leeg',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.amber,
                        ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final cfg = app.dashboard;
    final connected = app.status == ConnectionStatus.connected;
    final realTiles = cfg.visibleTiles();
    final showCamPreview =
        MediaQuery.sizeOf(context).width >= 700 && cfg.showNvr;
    final lightsByKey = {
      for (final l in app.project?.lights ?? const <LightDevice>[]) l.key: l,
    };
    final macrosByKey = {
      for (final m in app.project?.macros ?? const <MacroDevice>[]) m.key: m,
    };

    return WallTabletPresence(
      enabled: cfg.wallTabletMode,
      sensitivity: cfg.proximitySensitivity,
      onWake: () async {
        if (app.status != ConnectionStatus.connected &&
            app.status != ConnectionStatus.connecting) {
          await app.connect();
        }
      },
      child: GlassBackdrop(
      // De achtergrond vult het hele scherm; alleen de inhoud houdt afstand
      // van statusbalk, cutout en navigatiebalk.
      child: SafeArea(
      child: Stack(
        children: [
          Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Home',
                    onPressed: () => ShellNav.of(context).goTo(0),
                    icon: const Icon(Icons.home_outlined,
                        color: Colors.white70),
                  ),
                  Expanded(
                    child: _editing
                        ? const Text(
                            'Indelen: raster — elke kolom bruikbaar',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: connected ? Neo.accent : Colors.white24,
                      shape: BoxShape.circle,
                      boxShadow: connected
                          ? [
                              BoxShadow(
                                color: Neo.accent.withValues(alpha: 0.55),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: _editing ? 'Klaar' : 'Indelen / verslepen',
                    onPressed: () =>
                        setState(() => _editing = !_editing),
                    icon: Icon(
                      _editing
                          ? Icons.check_rounded
                          : Icons.open_with_rounded,
                      color: _editing ? AppColors.amber : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
              child: DashboardTopBand(
                cardColor: _card,
                now: _now,
                memoNote: cfg.memoNote,
                onMemoChanged: (t) => app.setDashboardMemoNote(t),
                dayMemos: cfg.dayMemos,
                onDayMemoChanged: (day, note) => app.setDashboardDayMemo(day, note),
                weatherLat: cfg.weatherLat,
                weatherLon: cfg.weatherLon,
                placeName: cfg.weatherPlaceName,
                onPlaceTap: () async {
                  final city = await showWeatherCityPicker(
                    context,
                    currentName: app.dashboard.weatherPlaceName,
                  );
                  if (city == null) return;
                  await app.setDashboardWeatherLocation(
                    lat: city.lat,
                    lon: city.lon,
                    placeName: city.name,
                  );
                },
              ),
            ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _EditStrip(
                cfg: cfg,
                onAddTiles: _openAddTilesSheet,
                onColumns: (n) => app.setDashboardColumnCount(n),
                onAddRow: () {
                  final wide = MediaQuery.sizeOf(context).width >= 700;
                  final cols = wide ? cfg.gridColumnsTablet : cfg.gridColumnsPhone;
                  return app.addDashboardEmptyRow(columns: cols);
                },
                onSettings: () => ShellNav.of(context).goTo(9),
              ),
            ),
          Expanded(
            child: realTiles.isEmpty && !_editing && !showCamPreview
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Nog geen tegels op het Dashboard',
                          style: TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _editing = true);
                            _openAddTilesSheet();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Lights / macros kiezen'),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 700;
                      final cols = wide && cfg.showNvr
                          ? 6
                          : (wide ? cfg.gridColumnsTablet : cfg.gridColumnsPhone);
                      final cells = cfg.layoutCells(cols);
                      final showCam = wide && cfg.showNvr && !_editing;
                      final pad = EdgeInsets.fromLTRB(wide ? 20 : 12, 0, wide ? 20 : 12, 24);
                      if (_editing) {
                        return SingleChildScrollView(
                          padding: pad,
                          child: _EditableHaGrid(
                            columns: cols,
                            cellIds: cells,
                            onSwap: (from, to) => app.swapDashboardCells(from, to, columns: cols),
                            onPlaceInColumn: (from, col) =>
                                app.placeDashboardTileInColumn(from, col, columns: cols),
                            onRemove: _removeTile,
                            tileBuilder: (id) => _tileWidget(
                              id: id,
                              lightsByKey: lightsByKey,
                              macrosByKey: macrosByKey,
                              showSlider: false,
                            ),
                            labelBuilder: (id) => _tileLabel(
                              id,
                              lightsByKey: lightsByKey,
                              macrosByKey: macrosByKey,
                            ),
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        padding: pad,
                        child: _HaGrid(
                          columns: cols,
                          cellIds: cells,
                          showCamera: showCam,
                          camera: showCam
                              ? NvrLivePanel(
                                  selected: cfg.nvrSelectedChannels,
                                  ready: app.nvrReady,
                                  message: app.nvrStatus.isEmpty
                                      ? null
                                      : app.nvrStatus,
                                  channels: app.nvrChannels,
                                  onSelect: app.selectNvrChannel,
                                  onSelectAll: app.selectAllNvrChannels,
                                )
                              : null,
                          tileBuilder: (id) => _tileWidget(
                            id: id,
                            lightsByKey: lightsByKey,
                            macrosByKey: macrosByKey,
                            showSlider: true,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _tileWidget({
    required String id,
    required Map<String, LightDevice> lightsByKey,
    required Map<String, MacroDevice> macrosByKey,
    required bool showSlider,
  }) {
    if (id.startsWith('light:')) {
      final light = lightsByKey[id.substring(6)];
      if (light == null) return const SizedBox.shrink();
      final custom = context.read<AppController>().dashboard.tileColors[light.key];
      final cfg = context.read<AppController>().dashboard;
      return _EntityCard(
        card: _card,
        light: light,
        accentOverride: isTileColorNone(custom) ? null : (custom != null ? Color(custom) : null),
        plain: isTileColorNone(custom),
        showSlider: showSlider && cfg.showSliderForLight(light.key, dimmable: light.dimmable),
        onToggle: () => _runLight(light),
        onDimPreview: (v) => context.read<AppController>().previewLightLevel(light, v),
        onDimEnd: (v) => _dimLight(light, v),
        onLongPress: _editing ? null : () => _pickLightColor(context, light),
      );
    }
    if (id.startsWith('macro:')) {
      final macro = macrosByKey[id.substring(6)];
      if (macro == null) return const SizedBox.shrink();
      final macroColor = context.read<AppController>().dashboard.tileColors['macro:${macro.key}'];
      return _MacroPill(
        card: _card,
        title: macro.name,
        iconType: macro.iconType,
        ready: macro.isConfigured,
        accentOverride: isTileColorNone(macroColor)
            ? null
            : (macroColor != null ? Color(macroColor) : null),
        plain: isTileColorNone(macroColor),
        onTap: () => _runMacro(macro),
        onLongPress: _editing ? null : () => _pickMacroColor(context, macro),
      );
    }
    return const SizedBox.shrink();
  }
}

class _EditStrip extends StatelessWidget {
  const _EditStrip({
    required this.cfg,
    required this.onAddTiles,
    required this.onColumns,
    required this.onAddRow,
    required this.onSettings,
  });

  final DashboardConfig cfg;
  final VoidCallback onAddTiles;
  final ValueChanged<int> onColumns;
  final Future<void> Function() onAddRow;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Lights / macros'),
                onPressed: onAddTiles,
                backgroundColor: AppColors.amber.withValues(alpha: 0.25),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              ActionChip(
                avatar: const Icon(Icons.table_rows_outlined, size: 18, color: Colors.white70),
                label: const Text('Rij +'),
                onPressed: () => onAddRow(),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              ActionChip(label: const Text('Settings'), onPressed: onSettings),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Kolommen', style: TextStyle(color: Colors.white54, fontSize: 12)),
              for (final n in const [1, 2, 3, 4, 5, 6])
                ChoiceChip(
                  label: Text('$n'),
                  selected: cfg.gridColumnsPhone == n,
                  onSelected: (_) => onColumns(n),
                  selectedColor: AppColors.amberSoft,
                  labelStyle: const TextStyle(color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Weer, kalender en memo staan vast bovenaan. Raster is lights/macros — sleep of tik 1…N.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Fixed cell grid: empty cells keep column positions (no left-packing).
/// NVR: 2 kolommen × 5 tegelrijen, midden in 6 kolommen.
class _HaGrid extends StatelessWidget {
  const _HaGrid({
    required this.columns,
    required this.cellIds,
    required this.tileBuilder,
    this.showCamera = false,
    this.camera,
  });

  static const _tileH = 68.0;
  static const _gap = 4.0;
  static const _camCols = 2;
  static const _camRows = 5;

  final int columns;
  final List<String> cellIds;
  final Widget Function(String id) tileBuilder;
  final bool showCamera;
  final Widget? camera;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final colW = (c.maxWidth - _gap * (columns - 1)) / columns;
        if (showCamera && camera != null && columns == 6) {
          return _cameraLayout(colW);
        }
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
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

  Widget _cameraLayout(double colW) {
    const camH = _tileH * _camRows + _gap * (_camRows - 1);
    final pairW = colW * _camCols + _gap;
    var i = 0;
    String next() {
      if (i < cellIds.length) return cellIds[i++];
      return DashboardConfig.emptyCell;
    }

    Widget slot(String id) {
      return SizedBox(
        width: colW,
        height: _tileH,
        child: DashboardConfig.isEmptyCell(id)
            ? const SizedBox.expand()
            : tileBuilder(id),
      );
    }

    final left = <Widget>[];
    final right = <Widget>[];
    for (var r = 0; r < _camRows; r++) {
      left.add(slot(next()));
      left.add(slot(next()));
      right.add(slot(next()));
      right.add(slot(next()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: camH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: pairW,
                child: Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: left,
                ),
              ),
              const SizedBox(width: _gap),
              SizedBox(
                width: pairW,
                height: camH,
                child: camera,
              ),
              const SizedBox(width: _gap),
              SizedBox(
                width: pairW,
                child: Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: right,
                ),
              ),
            ],
          ),
        ),
        if (i < cellIds.length) ...[
          const SizedBox(height: _gap),
          Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (; i < cellIds.length; i++)
                SizedBox(
                  width: colW,
                  child: DashboardConfig.isEmptyCell(cellIds[i])
                      ? const SizedBox(height: 4)
                      : tileBuilder(cellIds[i]),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Edit grid: visible raster, empty drop zones, drag or jump to any column.
class _EditableHaGrid extends StatelessWidget {
  const _EditableHaGrid({
    required this.columns,
    required this.cellIds,
    required this.tileBuilder,
    required this.labelBuilder,
    required this.onSwap,
    required this.onPlaceInColumn,
    required this.onRemove,
  });

  final int columns;
  final List<String> cellIds;
  final Widget Function(String id) tileBuilder;
  final String Function(String id) labelBuilder;
  final Future<void> Function(int from, int to) onSwap;
  final Future<void> Function(int from, int column) onPlaceInColumn;
  final Future<void> Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    const pad = 6.0;
    return LayoutBuilder(
      builder: (context, c) {
        final inner = (c.maxWidth - pad * 2).clamp(0.0, double.infinity);
        final colW = (inner - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: pad),
              child: Row(
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: colW,
                      child: Text(
                        '${col + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
                color: Colors.white.withValues(alpha: 0.03),
              ),
              child: Padding(
                padding: const EdgeInsets.all(pad),
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < cellIds.length; i++)
                      SizedBox(
                        width: colW,
                        child: _EditableCell(
                          index: i,
                          columns: columns,
                          dragWidth: colW,
                          id: cellIds[i],
                          label: DashboardConfig.isEmptyCell(cellIds[i])
                              ? 'Leeg'
                              : labelBuilder(cellIds[i]),
                          onSwap: onSwap,
                          onPlaceInColumn: onPlaceInColumn,
                          onRemove: DashboardConfig.isEmptyCell(cellIds[i])
                              ? null
                              : () => onRemove(cellIds[i]),
                          child: DashboardConfig.isEmptyCell(cellIds[i])
                              ? null
                              : tileBuilder(cellIds[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditableCell extends StatelessWidget {
  const _EditableCell({
    required this.index,
    required this.columns,
    required this.dragWidth,
    required this.id,
    required this.label,
    required this.child,
    required this.onSwap,
    required this.onPlaceInColumn,
    required this.onRemove,
  });

  final int index;
  final int columns;
  final double dragWidth;
  final String id;
  final String label;
  final Widget? child;
  final Future<void> Function(int from, int to) onSwap;
  final Future<void> Function(int from, int column) onPlaceInColumn;
  final VoidCallback? onRemove;

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
          return _EmptySlot(hot: hovering, column: col + 1);
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
                child: _tileChrome(
                  label: label,
                  column: col,
                  child: child!,
                  onRemove: null,
                  onPlaceInColumn: null,
                  highlight: true,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: _tileChrome(
              label: label,
              column: col,
              child: child!,
              onRemove: onRemove,
              onPlaceInColumn: null,
            ),
          ),
          child: _tileChrome(
            label: label,
            column: col,
            child: child!,
            onRemove: onRemove,
            onPlaceInColumn: (c) => onPlaceInColumn(index, c),
            highlight: hovering,
          ),
        );
      },
    );
  }

  Widget _tileChrome({
    required String label,
    required int column,
    required Widget child,
    required VoidCallback? onRemove,
    required ValueChanged<int>? onPlaceInColumn,
    bool highlight = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.amber : Colors.white24,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, color: AppColors.amber, size: 16),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Weg',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                  ),
              ],
            ),
          ),
          IgnorePointer(child: child),
          // Spring naar elke kolom in deze rij (niet ±1).
          if (onPlaceInColumn != null && columns > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (var c = 0; c < columns; c++)
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
                              ? AppColors.amber.withValues(alpha: 0.35)
                              : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: c == column ? AppColors.amber : Colors.white24,
                          ),
                        ),
                        child: Text(
                          '${c + 1}',
                          style: TextStyle(
                            color: c == column ? AppColors.amber : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.hot, required this.column});
  final bool hot;
  final int column;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hot ? AppColors.amber : Colors.white24,
          width: hot ? 2 : 1,
        ),
        color: hot ? AppColors.amber.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_box_outlined,
            size: 20,
            color: hot ? AppColors.amber : Colors.white24,
          ),
          const SizedBox(height: 4),
          Text(
            hot ? 'Hier' : 'Kolom $column',
            style: TextStyle(
              color: hot ? AppColors.amber : Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.card,
    required this.light,
    required this.showSlider,
    required this.onToggle,
    required this.onDimPreview,
    required this.onDimEnd,
    this.accentOverride,
    this.plain = false,
    this.onLongPress,
  });

  final Color card;
  final LightDevice light;
  final Color? accentOverride;
  final bool showSlider;
  final VoidCallback onToggle;
  final ValueChanged<int> onDimPreview;
  final ValueChanged<int> onDimEnd;
  final bool plain;
  final VoidCallback? onLongPress;

  Color? get _glow =>
      plain ? null : (accentOverride ?? _tileAccentForLight(light));

  @override
  Widget build(BuildContext context) {
    final dimmable = showSlider && light.dimmable;
    return NeoDeviceTile(
      name: light.name,
      iconType: light.iconType,
      active: light.isOn,
      dimmable: dimmable,
      level: light.level,
      glowColor: _glow,
      showToggleLed: !dimmable,
      onToggle: onToggle,
      onDimPreview: onDimPreview,
      onDimEnd: onDimEnd,
      onLongPress: onLongPress,
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.card,
    required this.title,
    required this.iconType,
    required this.ready,
    required this.onTap,
    this.accentOverride,
    this.plain = false,
    this.onLongPress,
  });

  final Color card;
  final String title;
  final String iconType;
  final bool ready;
  final VoidCallback onTap;
  final Color? accentOverride;
  final bool plain;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final glow = plain ? null : (accentOverride ?? _tileAccentForMacro(title));
    return Opacity(
      opacity: ready ? 1 : 0.45,
      child: NeoDeviceTile(
        name: title,
        status: '',
        iconType: iconType,
        active: false,
        glowColor: glow,
        iconTint: glow,
        glowWhenOff: false,
        pulse: true,
        onToggle: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

Color _tileAccentForLight(LightDevice light) {
  switch (light.iconType) {
    case 'Fan':
      return const Color(0xFFE07A5F); // coral
    case 'Blinds':
    case 'Window':
    case 'Garage':
    case 'Door':
      return const Color(0xFF5B9BD5); // sky blue
    case 'Music':
      return const Color(0xFF7BC8A4); // mint
    case 'Television':
      return const Color(0xFF6C8EBF); // steel blue
    case 'Thermostat':
    case 'Spa':
      return const Color(0xFF4FB0A5); // teal
    case 'Fire Place':
      return const Color(0xFFE07040);
    case 'Coffee Pot':
      return const Color(0xFFC4A35A);
    case 'Chandelier':
    case 'Sconce':
    case 'Track Light':
    case 'Recessed':
    case 'Fluorescent':
    case 'Lamp':
    case 'Light':
    default:
      // Stable hue per light key so tegels verschillen.
      final hues = <Color>[
        const Color(0xFFE0A14A), // amber
        const Color(0xFF5DADE2), // blue
        const Color(0xFF58D68D), // green
        const Color(0xFFE59866), // peach
        const Color(0xFF48C9B0), // teal
        const Color(0xFFF5B041), // gold
        const Color(0xFF85C1E9), // light blue
        const Color(0xFFDC7633), // orange
      ];
      final h = light.key.hashCode.abs();
      return hues[h % hues.length];
  }
}

Color _tileAccentForMacro(String title) {
  final t = title.toLowerCase();
  if (t.contains('off') || t.contains('uit') || t.contains('all off')) {
    return const Color(0xFF6FBF8B); // green
  }
  if (t.contains('evening') || t.contains('avond') || t.contains('sfeer')) {
    return const Color(0xFFE07A45); // warm orange
  }
  if (t.contains('on') || t.contains('aan') || t.contains('ochtend') || t.contains('morning')) {
    return const Color(0xFF48C9B0); // teal
  }
  final hues = <Color>[
    const Color(0xFFE0A14A),
    const Color(0xFF5DADE2),
    const Color(0xFF58D68D),
    const Color(0xFFE59866),
    const Color(0xFFE07A5F),
  ];
  return hues[title.hashCode.abs() % hues.length];
}

