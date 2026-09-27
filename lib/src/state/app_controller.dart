import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/project_importer.dart';
import '../data/qlk_importer.dart';
import '../models/devices.dart';
import '../protocol/vcommand_client.dart';
import 'dashboard_config.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

/// Local LAN to the IPE, or remote via router WAN / DynDNS port-forward.
enum NetworkProfile { local, remote }

class AppController extends ChangeNotifier {
  AppController() {
    _client = VCommandClient();
    _lineSub = _client.lines.listen(_onLine);
    _logSub = _client.log.listen((m) {
      sessionLog.insert(0, m);
      if (sessionLog.length > 200) sessionLog.removeLast();
      notifyListeners();
    });
  }

  late final VCommandClient _client;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<String>? _logSub;
  Timer? _loadPoll;
  bool _refreshingLoads = false;

  ProjectModel? project;
  ConnectionStatus status = ConnectionStatus.disconnected;
  String statusMessage =
      'WebPoint and QLink must be closed — IPE allows one TCP session.';
  bool nvrReady = false;
  String nvrStatus = '';
  List<Map<String, dynamic>> nvrChannels = const [];
  NetworkProfile profile = NetworkProfile.local;

  /// Direct LAN address of the IPE1000-P.
  String localHost = '192.168.1.33';
  int localPort = 3041;

  /// Public router hostname/IP (DynDNS / WAN) with forwarded VCommand port.
  String remoteHost = '';
  int remotePort = 3041;

  final List<String> sessionLog = [];
  String? lastError;

  /// Persisted custom labels: light:<key>, keypad:<key>, button:<keypadKey>:<switch>
  Map<String, String> customNames = {};

  /// Persisted WebPoint-style icon types: lightKey -> IconName (Light, Fan, …)
  Map<String, String> lightIcons = {};

  /// Persisted phone-side macro scenes: macroKey -> {name, actions:[{lightKey,level}]}
  Map<String, Map<String, dynamic>> macroConfigs = {};

  /// Dashboard pins, layout, optional weather.
  DashboardConfig dashboard = DashboardConfig();

  /// Last imported `.qlk` file name (null = bundled WebPoint project).
  String? qlkSourceName;

  String get activeHost => profile == NetworkProfile.local ? localHost : remoteHost;
  int get activePort => profile == NetworkProfile.local ? localPort : remotePort;

  /// Back-compat aliases used by older UI code.
  String get host => activeHost;
  int get port => activePort;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    project = await ProjectImporter.loadBundled();

    localHost = prefs.getString('localHost') ??
        prefs.getString('host') ??
        project!.master.host;
    localPort = prefs.getInt('localPort') ??
        prefs.getInt('port') ??
        project!.master.port;
    remoteHost = prefs.getString('remoteHost') ?? '';
    remotePort = prefs.getInt('remotePort') ?? 3041;
    final profileName = prefs.getString('networkProfile') ?? 'local';
    profile = profileName == 'remote' ? NetworkProfile.remote : NetworkProfile.local;
    qlkSourceName = prefs.getString('qlkSourceName');

    // Prefer a previously imported QLK over the bundled test project.
    final savedQlk = await _readSavedQlk();
    if (savedQlk != null && savedQlk.trim().isNotEmpty) {
      try {
        project = QlkImporter.parse(savedQlk, existingMaster: project?.master);
      } catch (e) {
        statusMessage = 'Opgeslagen QLK kon niet geladen worden: $e';
        qlkSourceName = null;
      }
    }

    _loadCustomNames(prefs);
    _loadLightIcons(prefs);
    _applyCustomNames();
    _applyLightIcons();
    await _loadMacroConfigs(prefs);
    _applyMacroConfigs();
    await _ensurePresetMacros();
    dashboard = DashboardConfig.decode(prefs.getString('dashboardConfigJson'));
    _ensureSixteenIpeLights();
    await _persistDashboard();
    dashboard.showWeather = true;
    // Force Zeebrugge until the user picks another place later.
    if (dashboard.weatherPlaceName.contains('Brussel') ||
        dashboard.weatherPlaceName.contains('standaard') ||
        (dashboard.weatherLat - 50.85).abs() < 0.05) {
      dashboard.weatherLat = 51.3306;
      dashboard.weatherLon = 3.2061;
      dashboard.weatherPlaceName = 'Zeebrugge';
      dashboard.useDeviceLocation = false;
      await _persistDashboard();
    }

    notifyListeners();
  }

  Future<File> _qlkCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/imported_project.qlk');
  }

  Future<String?> _readSavedQlk() async {
    try {
      final f = await _qlkCacheFile();
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistQlk(String text, String? sourceName) async {
    final f = await _qlkCacheFile();
    await f.writeAsString(text, flush: true);
    final prefs = await SharedPreferences.getInstance();
    if (sourceName != null && sourceName.trim().isNotEmpty) {
      await prefs.setString('qlkSourceName', sourceName.trim());
      qlkSourceName = sourceName.trim();
    } else {
      await prefs.remove('qlkSourceName');
      qlkSourceName = null;
    }
  }

  Future<void> _clearSavedQlk() async {
    try {
      final f = await _qlkCacheFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('qlkSourceName');
    qlkSourceName = null;
  }

  Future<void> _persistDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboardConfigJson', dashboard.encode());
  }

  Future<void> setLightPinned(String lightKey, bool pinned) async {
    final tile = DashboardConfig.lightTile(lightKey);
    if (pinned) {
      dashboard.pinnedLights.add(lightKey);
      dashboard.ensureTile(tile);
    } else {
      dashboard.pinnedLights.remove(lightKey);
      dashboard.removeTile(tile);
    }
    await _persistDashboard();
    notifyListeners();
  }

  /// Dashboard-tegelkleur voor een light. `null` = automatische kleur.
  Future<void> setLightTileColor(String lightKey, int? argb) async {
    dashboard.setTileColorForLight(lightKey, argb);
    await _persistDashboard();
    notifyListeners();
  }

  /// Tegel-/remote-kleur voor een macro. Opgeslagen als `macro:<key>` in tileColors.
  Future<void> setMacroTileColor(String macroKey, int? argb) async {
    dashboard.setTileColorForLight('macro:$macroKey', argb);
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setMacroPinned(String macroKey, bool pinned) async {
    final tile = DashboardConfig.macroTile(macroKey);
    if (pinned) {
      dashboard.pinnedMacros.add(macroKey);
      dashboard.ensureTile(tile);
    } else {
      dashboard.pinnedMacros.remove(macroKey);
      dashboard.removeTile(tile);
    }
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setDashboardShowWeather(bool value) async {
    dashboard.showWeather = true;
    // Weer/kalender/memo staan vast bovenaan — nooit een tegel, nooit uit.
    dashboard.tileOrder.removeWhere((id) => id == 'weather' || id == 'clock');
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setNvrSettings({
    bool? show,
    String? uid,
    String? user,
    String? password,
    int? channel,
  }) async {
    if (show != null) dashboard.showNvr = show;
    if (uid != null) dashboard.nvrUid = uid.trim();
    if (user != null) dashboard.nvrUser = user.trim();
    if (password != null) dashboard.nvrPassword = password;
    if (channel != null) dashboard.nvrChannel = channel.clamp(0, 32);
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> applyNvrLogin(List<Map<String, dynamic>> channels) async {
    nvrChannels = channels;
    nvrReady = true;
    nvrStatus = channels.isEmpty
        ? 'Ingelogd, geen kanaallijst.'
        : 'Ingelogd, ${channels.length} kanaal(en).';
    final ids = [
      for (final c in channels)
        if (c['channel'] is num) (c['channel'] as num).toInt(),
    ];
    var selected = dashboard.nvrSelectedChannels.where(ids.contains).toList();
    if (selected.isEmpty) selected = List<int>.from(ids);
    dashboard.nvrSelectedChannels = selected;
    if (selected.isNotEmpty) dashboard.nvrChannel = selected.first;
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> selectNvrChannel(int channel) async {
    final id = channel.clamp(0, 32);
    dashboard.nvrSelectedChannels = [id];
    dashboard.nvrChannel = id;
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> selectAllNvrChannels() async {
    final ids = [
      for (final c in nvrChannels)
        if (c['channel'] is num) (c['channel'] as num).toInt(),
    ];
    if (ids.isEmpty) return;
    dashboard.nvrSelectedChannels = ids;
    dashboard.nvrChannel = ids.first;
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> toggleNvrChannel(int channel) async {
    final id = channel.clamp(0, 32);
    final selected = List<int>.from(dashboard.nvrSelectedChannels);
    if (selected.contains(id)) {
      if (selected.length <= 1) return;
      selected.remove(id);
    } else {
      selected.add(id);
      selected.sort();
    }
    dashboard.nvrSelectedChannels = selected;
    dashboard.nvrChannel = selected.first;
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setDashboardMemoNote(String note) async {
    dashboard.memoNote = note;
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setDashboardDayMemo(DateTime day, String note) async {
    dashboard.setMemoForDay(day, note);
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setWallTabletMode(bool value) async {
    dashboard.wallTabletMode = value;
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setProximitySensitivity(int value) async {
    dashboard.proximitySensitivity = value.clamp(0, 100);
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setLightControlMode(String lightKey, LightControlMode mode) async {
    if (mode == LightControlMode.slider) {
      dashboard.lightControlModes.remove(lightKey);
    } else {
      dashboard.lightControlModes[lightKey] = 'toggle';
    }
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setDashboardColumns({int? phone, int? tablet}) async {
    if (phone != null) dashboard.gridColumnsPhone = phone.clamp(1, 6);
    if (tablet != null) dashboard.gridColumnsTablet = tablet.clamp(1, 6);
    await _persistDashboard();
    notifyListeners();
  }

  /// Set phone + tablet columns to the same value (1–6).
  Future<void> setDashboardColumnCount(int columns) async {
    final n = columns.clamp(1, 6);
    dashboard.gridColumnsPhone = n;
    dashboard.gridColumnsTablet = n;
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setDashboardWeatherLocation({
    required double lat,
    required double lon,
    required String placeName,
    bool useDeviceLocation = false,
  }) async {
    dashboard.weatherLat = lat;
    dashboard.weatherLon = lon;
    dashboard.weatherPlaceName = placeName;
    dashboard.useDeviceLocation = useDeviceLocation;
    await _persistDashboard();
    notifyListeners();
  }

  int _dashboardColsForPersist() {
    // Keep phone/tablet in sync via setDashboardColumnCount; use phone as source.
    return dashboard.gridColumnsPhone.clamp(1, 6);
  }

  Future<void> setRemoteOrder(List<String> order) async {
    dashboard.remoteOrder = List<String>.from(order);
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> setRemoteColumnCount(int columns) async {
    dashboard.remoteColumns = columns.clamp(1, 2);
    await _persistDashboard();
    notifyListeners();
  }

  Future<void> swapRemoteCells(
    int from,
    int to, {
    required Iterable<String> wanted,
  }) async {
    final cols = dashboard.remoteColumns.clamp(1, 2);
    final cells = dashboard.layoutRemoteCells(cols, wanted);
    if (from < 0 || to < 0 || from >= cells.length || to >= cells.length) return;
    if (from == to) return;
    final tmp = cells[from];
    cells[from] = cells[to];
    cells[to] = tmp;
    await setRemoteOrder(cells);
  }

  Future<void> placeRemoteTileInColumn(
    int from,
    int column, {
    required Iterable<String> wanted,
  }) async {
    final cols = dashboard.remoteColumns.clamp(1, 2);
    final cells = dashboard.layoutRemoteCells(cols, wanted);
    if (from < 0 || from >= cells.length) return;
    if (DashboardConfig.isEmptyCell(cells[from])) return;
    final col = column.clamp(0, cols - 1);
    final row = from ~/ cols;
    final to = row * cols + col;
    if (to == from) return;
    await swapRemoteCells(from, to, wanted: wanted);
  }

  Future<void> addRemoteEmptyRow({required Iterable<String> wanted}) async {
    final cols = dashboard.remoteColumns.clamp(1, 2);
    final cells = dashboard.layoutRemoteCells(cols, wanted);
    for (var i = 0; i < cols; i++) {
      cells.add(DashboardConfig.emptyCell);
    }
    await setRemoteOrder(cells);
  }

  Future<void> _commitDashboardCells(List<String> cells) async {
    dashboard.tileOrder = List<String>.from(cells);
    await _persistDashboard();
    notifyListeners();
  }

  /// Swap two cells (tile ↔ tile, tile ↔ empty) — elke kolom bereikbaar.
  Future<void> swapDashboardCells(int from, int to, {int? columns}) async {
    final cols = columns ?? _dashboardColsForPersist();
    final cells = dashboard.layoutCells(cols);
    if (from < 0 || to < 0 || from >= cells.length || to >= cells.length) return;
    if (from == to) return;
    final tmp = cells[from];
    cells[from] = cells[to];
    cells[to] = tmp;
    await _commitDashboardCells(cells);
  }

  /// Move tile into target cell (target becomes empty if it was a tile → swap).
  Future<void> moveDashboardCell(int from, int to, {int? columns}) async {
    await swapDashboardCells(from, to, columns: columns);
  }

  /// Place tile in column [0..cols-1] of its current row (swap with that cell).
  Future<void> placeDashboardTileInColumn(int from, int column, {int? columns}) async {
    final cols = (columns ?? _dashboardColsForPersist()).clamp(1, 6);
    final cells = dashboard.layoutCells(cols);
    if (from < 0 || from >= cells.length) return;
    if (DashboardConfig.isEmptyCell(cells[from])) return;
    final col = column.clamp(0, cols - 1);
    final row = from ~/ cols;
    final to = row * cols + col;
    if (to == from) return;
    await swapDashboardCells(from, to, columns: cols);
  }

  Future<void> addDashboardEmptyRow({int? columns}) async {
    final cols = (columns ?? _dashboardColsForPersist()).clamp(1, 6);
    final cells = dashboard.layoutCells(cols);
    for (var i = 0; i < cols; i++) {
      cells.add(DashboardConfig.emptyCell);
    }
    await _commitDashboardCells(cells);
  }

  Future<void> reorderDashboardTiles(int oldIndex, int newIndex, {int? columns}) async {
    final cols = columns ?? _dashboardColsForPersist();
    final cells = dashboard.layoutCells(cols);
    if (oldIndex < 0 || oldIndex >= cells.length) return;
    var target = newIndex;
    if (oldIndex < target) target -= 1;
    final item = cells.removeAt(oldIndex);
    cells.insert(target.clamp(0, cells.length), item);
    await _commitDashboardCells(cells);
  }

  void _loadCustomNames(SharedPreferences prefs) {
    final raw = prefs.getString('customNamesJson');
    if (raw == null || raw.isEmpty) {
      customNames = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        customNames = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {
      customNames = {};
    }
  }

  void _loadLightIcons(SharedPreferences prefs) {
    final raw = prefs.getString('lightIconsJson');
    if (raw == null || raw.isEmpty) {
      lightIcons = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        lightIcons = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {
      lightIcons = {};
    }
  }

  Future<void> _persistCustomNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customNamesJson', jsonEncode(customNames));
  }

  Future<void> _persistLightIcons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lightIconsJson', jsonEncode(lightIcons));
  }

  void _applyCustomNames() {
    final p = project;
    if (p == null) return;
    for (final light in p.lights) {
      final custom = customNames['light:${light.key}'];
      if (custom != null && custom.isNotEmpty) light.name = custom;
    }
    for (final keypad in p.keypads) {
      final customKp = customNames['keypad:${keypad.key}'];
      if (customKp != null && customKp.isNotEmpty) keypad.name = customKp;
      for (final button in keypad.buttons) {
        final customBtn = customNames['button:${keypad.key}:${button.switchNumber}'];
        if (customBtn != null && customBtn.isNotEmpty) button.name = customBtn;
      }
    }
  }

  void _applyLightIcons() {
    final p = project;
    if (p == null) return;
    for (final light in p.lights) {
      final icon = lightIcons[light.key];
      if (icon != null && icon.isNotEmpty) light.iconType = icon;
    }
  }

  Future<void> setLightIcon(LightDevice light, String iconType) async {
    final type = iconType.trim().isEmpty ? 'Light' : iconType.trim();
    light.iconType = type;
    lightIcons[light.key] = type;
    await _persistLightIcons();
    notifyListeners();
  }

  Future<void> renameLight(LightDevice light, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    light.name = name;
    customNames['light:${light.key}'] = name;
    await _persistCustomNames();
    notifyListeners();
  }

  Future<void> renameKeypad(KeypadDevice keypad, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    keypad.name = name;
    customNames['keypad:${keypad.key}'] = name;
    await _persistCustomNames();
    notifyListeners();
  }

  Future<void> renameKeypadButton(
    KeypadDevice keypad,
    KeypadButton button,
    String newName,
  ) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    button.name = name;
    customNames['button:${keypad.key}:${button.switchNumber}'] = name;
    await _persistCustomNames();
    notifyListeners();
  }

  Future<void> resetCustomName({
    LightDevice? light,
    KeypadDevice? keypad,
    KeypadButton? button,
  }) async {
    if (light != null) {
      customNames.remove('light:${light.key}');
      light.name = light.originalName;
    }
    if (keypad != null && button == null) {
      customNames.remove('keypad:${keypad.key}');
      keypad.name = keypad.originalName;
    }
    if (keypad != null && button != null) {
      customNames.remove('button:${keypad.key}:${button.switchNumber}');
      button.name = button.originalName;
    }
    await _persistCustomNames();
    notifyListeners();
  }

  Future<void> setProfile(NetworkProfile value) async {
    profile = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('networkProfile', value.name);
    statusMessage = value == NetworkProfile.local
        ? 'Using local LAN → $localHost:$localPort'
        : 'Using router/WAN → ${remoteHost.isEmpty ? "(set remote host)" : "$remoteHost:$remotePort"}';
    notifyListeners();
  }

  /// Replace the in-app project from a full `.qlk` text export (UI only).
  Future<void> importQlkText(String text, {String? sourceName}) async {
    final imported = QlkImporter.parse(text, existingMaster: project?.master);
    project = imported;
    await _persistQlk(text, sourceName);
    _applyCustomNames();
    _applyLightIcons();
    _applyMacroConfigs();
    await _ensurePresetMacros();
    statusMessage =
        'QLK geladen${sourceName == null ? "" : " ($sourceName)"}: '
        '${imported.lights.length} lights, ${imported.keypads.length} keypads, '
        '${imported.macros.length} macros.';
    notifyListeners();
  }

  Future<void> reloadBundledProject() async {
    await _clearSavedQlk();
    final bundled = await ProjectImporter.loadBundled();
    project = ProjectModel(
      master: MasterInfo(
        id: bundled.master.id,
        name: bundled.master.name,
        host: localHost,
        port: localPort,
        qLinkPort: bundled.master.qLinkPort,
        hostPort: bundled.master.hostPort,
      ),
      lights: bundled.lights,
      keypads: bundled.keypads,
      macros: bundled.macros,
      schedules: bundled.schedules,
      temperatures: bundled.temperatures,
      timeControls: bundled.timeControls,
    );
    _applyCustomNames();
    _applyLightIcons();
    _applyMacroConfigs();
    await _ensurePresetMacros();
    _ensureSixteenIpeLights();
    await _persistDashboard();
    statusMessage = 'Bundled WebPoint-project herladen.';
    notifyListeners();
  }

  /// 16 echte IPE-loads (2× MDS8: module 1–2, load 1–8) om te plaatsen.
  void _ensureSixteenIpeLights() {
    final p = project;
    if (p == null) return;
    p.lights.removeWhere((l) => l.key.startsWith('layout:'));
    dashboard.pinnedLights.removeWhere((k) => k.startsWith('layout:'));
    dashboard.tileOrder.removeWhere((id) => id.startsWith('light:layout:'));

    final known = p.lights.where((l) => l.key.startsWith('Load '));
    final master = known.isEmpty ? 11 : known.first.master;
    var n = 0;
    for (var module = 1; module <= 2; module++) {
      for (var load = 1; load <= 8; load++) {
        n++;
        final key = 'Load $master 1 $module $load';
        if (!p.lights.any((l) => l.key == key)) {
          p.lights.add(
            LightDevice(
              key: key,
              name: 'Light $n',
              room: 'Home',
              master: master,
              enclosure: 1,
              module: module,
              load: load,
              dimmable: true,
            ),
          );
        }
        dashboard.pinnedLights.add(key);
        dashboard.ensureTile(DashboardConfig.lightTile(key));
      }
    }
  }

  Future<void> rebindLight(
    LightDevice light, {
    required int enclosure,
    required int module,
    required int load,
  }) async {
    final p = project;
    if (p == null) return;
    final enc = enclosure.clamp(1, 8);
    final mod = module.clamp(1, 16);
    final ld = load.clamp(1, 16);
    final newKey = 'Load ${light.master} $enc $mod $ld';
    if (newKey == light.key &&
        light.enclosure == enc &&
        light.module == mod &&
        light.load == ld) {
      return;
    }
    final next = LightDevice(
      key: newKey,
      name: light.name,
      room: light.room,
      master: light.master,
      enclosure: enc,
      module: mod,
      load: ld,
      dimmable: light.dimmable,
      level: light.level,
      isOn: light.isOn,
      iconType: light.iconType,
      originalName: light.originalName,
    );
    final idx = p.lights.indexWhere((l) => l.key == light.key);
    if (idx < 0) return;
    p.lights.removeWhere((l) => l.key == newKey && l.key != light.key);
    p.lights[idx] = next;
    if (dashboard.pinnedLights.remove(light.key)) {
      dashboard.pinnedLights.add(newKey);
    }
    final oldTile = DashboardConfig.lightTile(light.key);
    final newTile = DashboardConfig.lightTile(newKey);
    for (var i = 0; i < dashboard.tileOrder.length; i++) {
      if (dashboard.tileOrder[i] == oldTile) dashboard.tileOrder[i] = newTile;
    }
    final color = dashboard.tileColors.remove(light.key);
    if (color != null) dashboard.tileColors[newKey] = color;
    final icon = lightIcons.remove(light.key);
    if (icon != null) lightIcons[newKey] = icon;
    final custom = customNames.remove('light:${light.key}');
    if (custom != null) customNames['light:$newKey'] = custom;
    await _persistDashboard();
    await _persistCustomNames();
    await _persistLightIcons();
    notifyListeners();
  }

  Future<void> _loadMacroConfigs(SharedPreferences prefs) async {
    final raw = prefs.getString('macroConfigsJson');
    if (raw == null || raw.isEmpty) {
      macroConfigs = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        macroConfigs = decoded.map((k, v) {
          final map = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
          return MapEntry(k.toString(), map);
        });
      }
    } catch (_) {
      macroConfigs = {};
    }
  }

  Future<void> _persistMacroConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('macroConfigsJson', jsonEncode(macroConfigs));
  }

  List<MacroAction> _actionsFromConfig(Map<String, dynamic> cfg) {
    final actionsRaw = cfg['actions'];
    if (actionsRaw is! List) return const [];
    return actionsRaw
        .whereType<Map>()
        .map((e) => MacroAction.fromJson(Map<String, dynamic>.from(e)))
        .where((a) => a.lightKey.isNotEmpty)
        .toList();
  }

  void _applyMacroConfigs() {
    final p = project;
    if (p == null) return;
    final existingKeys = p.macros.map((m) => m.key).toSet();
    for (final macro in p.macros) {
      final cfg = macroConfigs[macro.key];
      if (cfg == null) continue;
      final name = cfg['name']?.toString();
      if (name != null && name.trim().isNotEmpty) macro.name = name.trim();
      final icon = cfg['iconType']?.toString();
      if (icon != null && icon.trim().isNotEmpty) macro.iconType = icon.trim();
      macro.actions = _actionsFromConfig(cfg);
    }
    // Restore phone-side scenes that are only in SharedPreferences.
    for (final entry in macroConfigs.entries) {
      if (existingKeys.contains(entry.key)) continue;
      final cfg = entry.value;
      final name = cfg['name']?.toString().trim();
      p.macros.add(
        MacroDevice(
          key: entry.key,
          name: (name == null || name.isEmpty) ? 'Scene' : name,
          room: 'Home',
          index: p.macros.length + 1,
          iconType: cfg['iconType']?.toString() ?? 'Light',
          actions: _actionsFromConfig(cfg),
        ),
      );
    }
  }

  static const _presetMacros = <({String key, String name, String iconType})>[
    (key: 'macro-preset-emergency-flash', name: 'Emergency flash', iconType: 'Emergency Flash 1'),
    (key: 'macro-preset-intruder-alert', name: 'Intruder alert', iconType: 'Intruder Alert 1'),
    (key: 'macro-preset-arriving-home', name: 'Arriving home', iconType: 'Home Analytics 1'),
    (key: 'macro-preset-leaving-home', name: 'Leaving home', iconType: 'Leaving Home 1'),
    (key: 'macro-preset-party', name: 'Party modus', iconType: 'Party Popper 1'),
    (key: 'macro-preset-entertainment', name: 'Entertainment modus', iconType: 'Entertainment 1'),
    (key: 'macro-preset-cleaning', name: 'Cleaning modus', iconType: 'Cleaning 1'),
    (key: 'macro-preset-storm', name: 'Storm modus', iconType: 'Storm 1'),
    (key: 'macro-preset-heatwave', name: 'Heatwave modus', iconType: 'Heatwave 1'),
  ];

  Future<void> _ensurePresetMacros() async {
    final p = project;
    if (p == null) return;
    var changed = false;
    for (final preset in _presetMacros) {
      final existing = p.macros.where((m) => m.key == preset.key).toList();
      if (macroConfigs.containsKey(preset.key) || existing.isNotEmpty) {
        final cfg = macroConfigs[preset.key] ??= {
          'name': preset.name,
          'iconType': preset.iconType,
          'actions': <Map<String, dynamic>>[],
        };
        if (cfg['iconType'] != preset.iconType) {
          cfg['iconType'] = preset.iconType;
          changed = true;
        }
        for (final m in existing) {
          if (m.iconType != preset.iconType) {
            m.iconType = preset.iconType;
            changed = true;
          }
        }
        continue;
      }
      p.macros.add(
        MacroDevice(
          key: preset.key,
          name: preset.name,
          room: 'Scenes',
          index: p.macros.length + 1,
          iconType: preset.iconType,
        ),
      );
      macroConfigs[preset.key] = {
        'name': preset.name,
        'iconType': preset.iconType,
        'actions': <Map<String, dynamic>>[],
      };
      changed = true;
    }
    if (changed) await _persistMacroConfigs();
  }

  Future<void> saveMacroConfig(MacroDevice macro) async {
    macroConfigs[macro.key] = {
      'name': macro.name,
      'iconType': macro.iconType,
      'actions': macro.actions.map((a) => a.toJson()).toList(),
    };
    await _persistMacroConfigs();
    notifyListeners();
  }

  Future<void> setMacroIcon(MacroDevice macro, String iconType) async {
    final type = iconType.trim().isEmpty ? 'Light' : iconType.trim();
    macro.iconType = type;
    await saveMacroConfig(macro);
  }

  Future<void> addMacro({String name = 'Nieuwe scene'}) async {
    final p = project;
    if (p == null) return;
    final index = p.macros.length + 1;
    final macro = MacroDevice(
      key: 'macro-local-$index-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      room: 'Home',
      index: index,
    );
    p.macros.add(macro);
    await saveMacroConfig(macro);
    statusMessage = 'Scene "${macro.name}" toegevoegd — stel lampen in.';
    notifyListeners();
  }

  Future<void> deleteMacro(MacroDevice macro) async {
    final p = project;
    if (p == null) return;
    p.macros.removeWhere((m) => m.key == macro.key);
    macroConfigs.remove(macro.key);
    await _persistMacroConfigs();
    statusMessage = 'Scene "${macro.name}" verwijderd.';
    notifyListeners();
  }

  /// Fill a scene with every project load at [level] (0–100).
  Future<void> fillMacroAllLights(MacroDevice macro, int level) async {
    final lights = project?.lights ?? const <LightDevice>[];
    macro.actions = [
      for (final light in lights)
        MacroAction(lightKey: light.key, level: level.clamp(0, 100)),
    ];
    await saveMacroConfig(macro);
    statusMessage =
        'Scene "${macro.name}": ${lights.length} loads @ ${level.clamp(0, 100)}%';
    notifyListeners();
  }

  Future<void> saveNetworkSettings({
    required String localHost,
    required int localPort,
    required String remoteHost,
    required int remotePort,
    required NetworkProfile profile,
  }) async {
    this.localHost = localHost.trim();
    this.localPort = localPort;
    this.remoteHost = remoteHost.trim();
    this.remotePort = remotePort;
    this.profile = profile;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localHost', this.localHost);
    await prefs.setInt('localPort', this.localPort);
    await prefs.setString('remoteHost', this.remoteHost);
    await prefs.setInt('remotePort', this.remotePort);
    await prefs.setString('networkProfile', profile.name);
    // Keep legacy keys in sync for older builds.
    await prefs.setString('host', activeHost);
    await prefs.setInt('port', activePort);
    notifyListeners();
  }

  Future<void> connect() async {
    final host = activeHost;
    final port = activePort;
    if (host.isEmpty) {
      status = ConnectionStatus.error;
      statusMessage = profile == NetworkProfile.remote
          ? 'Set a router WAN / DynDNS hostname in Settings first.'
          : 'Local host is empty.';
      lastError = 'Missing host';
      notifyListeners();
      return;
    }

    status = ConnectionStatus.connecting;
    statusMessage = profile == NetworkProfile.remote
        ? 'Connecting via router $host:$port …'
        : 'Connecting to $host:$port …';
    lastError = null;
    notifyListeners();
    try {
      final timeout = profile == NetworkProfile.remote
          ? const Duration(seconds: 20)
          : const Duration(seconds: 8);
      await _client.connect(host, port, timeout: timeout);
      status = ConnectionStatus.connected;
      statusMessage = profile == NetworkProfile.remote
          ? 'Connected via router ($host:$port)'
          : 'Connected on LAN ($host:$port)';
      _startLoadPoll();
      await _refreshAll();
    } catch (e) {
      _stopLoadPoll();
      status = ConnectionStatus.error;
      lastError = e.toString();
      statusMessage = profile == NetworkProfile.remote
          ? 'Remote failed. Check router port-forward TCP → IPE:3041 and that WebPoint/QLink are closed.'
          : 'Connection failed. Is WebPoint/QLink using the IPE?';
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _stopLoadPoll();
    await _client.disconnect();
    status = ConnectionStatus.disconnected;
    statusMessage = 'Disconnected';
    notifyListeners();
  }

  void _startLoadPoll() {
    _loadPoll?.cancel();
    _loadPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_refreshLoads());
    });
  }

  void _stopLoadPoll() {
    _loadPoll?.cancel();
    _loadPoll = null;
  }

  Future<void> _refreshLoads() async {
    if (!_client.isConnected || _refreshingLoads) return;
    final lights = project?.lights;
    if (lights == null || lights.isEmpty) return;
    _refreshingLoads = true;
    try {
      for (final light in lights) {
        if (!_client.isConnected) return;
        await _client.requestLoad(
          light.master,
          light.enclosure,
          light.module,
          light.load,
        );
      }
    } catch (_) {
      // Socket can drop mid-poll; connect/disconnect own the status.
    } finally {
      _refreshingLoads = false;
    }
  }

  Future<void> _refreshAll() async {
    final p = project;
    if (p == null) return;
    // Loads first — otherwise the tiles stay "Uit" while keypads are queried.
    await _refreshLoads();
    if (!_client.isConnected) return;
    for (final kp in p.keypads) {
      if (!_client.isConnected) return;
      await _client.requestStationList(kp.master, kp.station);
    }
  }

  void previewLightLevel(LightDevice light, int level) {
    light.level = level.clamp(0, 100);
    light.isOn = light.level > 0;
    notifyListeners();
  }

  Future<void> setLightLevel(LightDevice light, int level) async {
    final target = level.clamp(0, 100);
    previewLightLevel(light, target);
    await _ensureConnected();
    await _client.setLoad(
      master: light.master,
      enclosure: light.enclosure,
      module: light.module,
      load: light.load,
      level: target,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_client.isConnected) {
      await _client.requestLoad(
        light.master,
        light.enclosure,
        light.module,
        light.load,
      );
    }
  }

  Future<void> toggleLight(LightDevice light) async {
    await setLightLevel(light, light.isOn ? 0 : 100);
  }

  Future<void> pressKeypadButton(KeypadDevice keypad, KeypadButton button) async {
    await _ensureConnected();
    final before = {
      for (final light in project?.lights ?? const <LightDevice>[])
        light.key: light.level,
    };
    await _client.pressButton(
      master: keypad.master,
      station: keypad.station,
      switchNumber: button.switchNumber,
    );
    // Wait for LO/SW replies, then refresh known loads (incl. load 2 on module 2).
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final lights = project?.lights ?? const <LightDevice>[];
    for (final light in lights) {
      await _client.requestLoad(light.master, light.enclosure, light.module, light.load);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final changed = <String>[];
    for (final light in project?.lights ?? const <LightDevice>[]) {
      final prev = before[light.key];
      if (prev == null || prev != light.level) {
        changed.add('${light.name}=${light.level}%');
      }
    }
    final sn = keypad.serialNumber == null ? '' : ' SN ${keypad.serialNumber}';
    statusMessage = changed.isEmpty
        ? 'Keypad ${keypad.name}$sn · knop ${button.switchNumber} → Master '
            '(VSW# ${keypad.master} ${keypad.station} ${button.switchNumber} 6)'
            '${button.hasProgram ? "" : " — geen Event/LdA in geladen QLK"}'
        : 'Keypad ${keypad.name}$sn · knop ${button.switchNumber}: ${changed.join(", ")}';
    notifyListeners();
  }

  Future<void> runMacro(MacroDevice macro) async {
    if (!macro.isConfigured) {
      statusMessage =
          'Scene "${macro.name}" is nog leeg. Tik op bewerken en kies lampen + dimniveau.';
      notifyListeners();
      return;
    }

    final lightsByKey = {
      for (final light in project?.lights ?? const <LightDevice>[]) light.key: light,
    };

    await _ensureConnected();
    var ok = 0;
    var missing = 0;
    try {
      for (final action in macro.actions) {
        final light = lightsByKey[action.lightKey];
        if (light == null) {
          missing++;
          continue;
        }
        await _client.setLoad(
          master: light.master,
          enclosure: light.enclosure,
          module: light.module,
          load: light.load,
          level: action.level.clamp(0, 100),
        );
        light.level = action.level.clamp(0, 100);
        light.isOn = light.level > 0;
        ok++;
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      statusMessage = missing == 0
          ? 'Scene "${macro.name}" uitgevoerd ($ok loads)'
          : 'Scene "${macro.name}": $ok loads, $missing ontbrekende loads';
    } catch (e) {
      lastError = e.toString();
      statusMessage = 'Scene "${macro.name}" mislukt: $e';
    }
    notifyListeners();
  }

  Future<void> toggleSchedule(ScheduleDevice schedule) async {
    schedule.enabled = !schedule.enabled;
    notifyListeners();
    await _ensureConnected();
    try {
      await _client.setScheduleEnabled(
        master: schedule.master,
        index: schedule.index,
        enabled: schedule.enabled,
      );
      statusMessage = 'Schedule "${schedule.name}" → ${schedule.enabled ? "on" : "off"}';
    } catch (e) {
      lastError = e.toString();
      statusMessage = 'Schedule command failed or unsupported';
    }
    notifyListeners();
  }

  void previewTemperature(TemperatureDevice device, double setpoint) {
    device.setpoint = setpoint;
    notifyListeners();
  }

  Future<void> setTemperature(TemperatureDevice device, double setpoint) async {
    previewTemperature(device, setpoint);
    await _ensureConnected();
    try {
      await _client.setThermostatSetpoint(
        master: device.master,
        station: device.station,
        celsius: setpoint,
      );
      statusMessage = 'Setpoint ${setpoint.toStringAsFixed(0)}°C sent';
    } catch (e) {
      lastError = e.toString();
      statusMessage = 'Thermostat command failed or unsupported';
    }
    notifyListeners();
  }

  Future<void> syncControllerTime() async {
    await _ensureConnected();
    try {
      await _client.querySystemTime();
      await _client.setSystemTime(DateTime.now());
      statusMessage = 'Time sync commands sent';
    } catch (e) {
      lastError = e.toString();
      statusMessage = 'Time command failed or unsupported';
    }
    notifyListeners();
  }

  Future<void> _ensureConnected() async {
    if (_client.isConnected) return;
    await connect();
    if (!_client.isConnected) {
      throw StateError(lastError ?? 'Not connected');
    }
  }

  void _onLine(String line) {
    final text = line.trim();
    final load = RegExp(
      r'^(?:RGB#?|LO)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (load != null) {
      _applyLoadLevel(
        master: int.parse(load.group(1)!),
        enclosure: int.parse(load.group(2)!),
        module: int.parse(load.group(3)!),
        load: int.parse(load.group(4)!),
        level: int.parse(load.group(5)!),
        createIfMissing: text.toUpperCase().startsWith('LO'),
      );
      return;
    }

    if (line.startsWith('ROS')) {
      statusMessage = 'Session acknowledged ($line)';
      notifyListeners();
    }
  }

  void _applyLoadLevel({
    required int master,
    required int enclosure,
    required int module,
    required int load,
    required int level,
    bool createIfMissing = false,
  }) {
    final p = project;
    if (p == null) return;
    LightDevice? match;
    for (final light in p.lights) {
      if (light.master == master &&
          light.enclosure == enclosure &&
          light.module == module &&
          light.load == load) {
        match = light;
        break;
      }
    }
    if (match == null && createIfMissing) {
      match = LightDevice(
        key: 'Load $master $enclosure $module $load',
        name: 'Load $enclosure.$module.$load',
        room: 'Home',
        master: master,
        enclosure: enclosure,
        module: module,
        load: load,
        dimmable: true,
      );
      p.lights.add(match);
      _applyCustomNames();
      _applyLightIcons();
    }
    if (match == null) return;
    match.level = level.clamp(0, 100);
    match.isOn = match.level > 0;
    notifyListeners();
  }

  /// Volledige UI-config voor overzetten tussen tablet en telefoon.
  Future<Map<String, dynamic>> exportSettingsBundle({bool includeQlk = true}) async {
    final qlk = includeQlk ? await _readSavedQlk() : null;
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'qlkSourceName': qlkSourceName,
      if (qlk != null && qlk.trim().isNotEmpty) 'qlkText': qlk,
      'dashboardConfig': dashboard.toJson(),
      'customNames': customNames,
      'lightIcons': lightIcons,
      'macroConfigs': macroConfigs,
    };
  }

  /// Importeert een export van [exportSettingsBundle] op dit apparaat.
  Future<void> importSettingsBundle(Map<String, dynamic> bundle) async {
    final version = bundle['version'] as num? ?? 0;
    if (version < 1) {
      throw FormatException('Onbekende instellingen-export (versie $version).');
    }

    if (bundle['customNames'] is Map) {
      customNames = (bundle['customNames'] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      await _persistCustomNames();
    }

    if (bundle['lightIcons'] is Map) {
      lightIcons = (bundle['lightIcons'] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      await _persistLightIcons();
    }

    if (bundle['macroConfigs'] is Map) {
      macroConfigs = (bundle['macroConfigs'] as Map).map((k, v) {
        final map = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
        return MapEntry(k.toString(), map);
      });
      await _persistMacroConfigs();
    }

    final qlkText = bundle['qlkText']?.toString();
    if (qlkText != null && qlkText.trim().isNotEmpty) {
      await importQlkText(qlkText, sourceName: bundle['qlkSourceName']?.toString());
    } else {
      _applyCustomNames();
      _applyLightIcons();
      _applyMacroConfigs();
    }

    if (bundle['dashboardConfig'] is Map) {
      dashboard = DashboardConfig.fromJson(
        Map<String, dynamic>.from(bundle['dashboardConfig'] as Map),
      );
      await _persistDashboard();
    }

    statusMessage = 'Instellingen geïmporteerd van ${bundle['exportedAt'] ?? 'export'}.';
    notifyListeners();
  }

  @override
  void dispose() {
    _stopLoadPoll();
    _lineSub?.cancel();
    _logSub?.cancel();
    unawaited(_client.dispose());
    super.dispose();
  }
}
