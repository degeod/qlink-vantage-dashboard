import 'dart:convert';

/// Hoe een load op Dashboard/Remote bediend wordt (alleen bij dimbare loads).
enum LightControlMode { slider, toggle }

/// Persisted layout **shared by Dashboard and Remote**.
///
/// Kalender/memo: [memoNote] (boodschappenlijst) + [dayMemos] (afspraken).
/// Schrijven via [setMemoForDay] / `AppController.setDashboardDayMemo`.
/// Tegelkleuren: [tileColors] (zelfde keys op beide tabs).
/// Remote-volgorde: [remoteOrder]; Dashboard-raster: [tileOrder].
class DashboardConfig {
  DashboardConfig({
    Set<String>? pinnedLights,
    Set<String>? pinnedMacros,
    this.showWeather = true,
    this.weatherLat = 51.3306,
    this.weatherLon = 3.2061,
    this.weatherPlaceName = 'Zeebrugge',
    this.useDeviceLocation = false,
    this.gridColumnsPhone = 2,
    this.gridColumnsTablet = 4,
    this.memoNote = '',
    Map<String, String>? dayMemos,
    Map<String, int>? tileColors,
    this.wallTabletMode = false,
    this.proximitySensitivity = 70,
    Map<String, String>? lightControlModes,
    List<String>? tileOrder,
    List<String>? remoteOrder,
    this.remoteColumns = 1,
    this.showNvr = true,
    this.nvrUid = '',
    this.nvrUser = 'admin',
    this.nvrPassword = '',
    this.nvrChannel = 0,
    List<int>? nvrSelectedChannels,
  })  : pinnedLights = pinnedLights ?? <String>{},
        pinnedMacros = pinnedMacros ?? <String>{},
        dayMemos = dayMemos ?? <String, String>{},
        tileColors = tileColors ?? <String, int>{},
        lightControlModes = lightControlModes ?? <String, String>{},
        tileOrder = _sanitizeOrder(tileOrder ?? <String>[]),
        remoteOrder = List<String>.from(remoteOrder ?? const []),
        nvrSelectedChannels = List<int>.from(nvrSelectedChannels ?? const []);

  /// Placeholder cell so tegels niet links aaneen pakken — elke kolom bruikbaar.
  static const emptyCell = 'empty';

  /// Idle → dim standby after this duration (wall tablet mode).
  static const wallStandbyTimeout = Duration(minutes: 3);

  final Set<String> pinnedLights;
  final Set<String> pinnedMacros;
  bool showWeather;
  double weatherLat;
  double weatherLon;
  String weatherPlaceName;
  bool useDeviceLocation;
  int gridColumnsPhone;
  int gridColumnsTablet;

  /// Algemeen memoblok (zichtbaar wanneer geen gemarkeerde dag geselecteerd is).
  String memoNote;

  /// Per-dag notities: sleutel `yyyy-MM-dd` → tekst. Dag blijft gemarkeerd tot clear (C).
  final Map<String, String> dayMemos;

  /// Dashboard-tegelkleur per light-key → ARGB int. Ontbreekt = automatische accentkleur.
  final Map<String, int> tileColors;

  /// Muur-tablet: na 3 min dimmen; camera-beweging wekt + IPE-connect.
  bool wallTabletMode;

  /// Bewegingsdetectie 0 (dof) … 100 (gevoelig). Standaard ~70.
  int proximitySensitivity;

  /// Per light-key: `slider` of `toggle` op Dashboard/Remote.
  final Map<String, String> lightControlModes;

  LightControlMode controlModeForLight(String lightKey, {required bool dimmable}) {
    if (!dimmable) return LightControlMode.toggle;
    final stored = lightControlModes[lightKey];
    if (stored == 'toggle') return LightControlMode.toggle;
    return LightControlMode.slider;
  }

  bool showSliderForLight(String lightKey, {required bool dimmable}) =>
      controlModeForLight(lightKey, dimmable: dimmable) == LightControlMode.slider;

  void setTileColorForLight(String lightKey, int? argb) {
    if (argb == null) {
      tileColors.remove(lightKey);
    } else {
      tileColors[lightKey] = argb;
    }
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String memoForDay(DateTime d) => dayMemos[dayKey(d)] ?? '';

  bool hasMemoOn(DateTime d) => memoForDay(d).trim().isNotEmpty;

  void setMemoForDay(DateTime d, String note) {
    final key = dayKey(d);
    final t = note.trimRight();
    if (t.trim().isEmpty) {
      dayMemos.remove(key);
    } else {
      dayMemos[key] = t;
    }
  }

  /// Ordered cell ids for the **tile grid only**: `light:<key>`, `macro:<key>`, `empty`.
  /// Weather is a fixed full-width band, never part of this list.
  List<String> tileOrder;

  /// Volgorde op de Remote-tab: `light:<key>` / `macro:<key>` / `empty`.
  List<String> remoteOrder;

  /// Remote-raster: 1 of 2 tegels per rij (volle schermbreedte, kleine spatie).
  int remoteColumns;

  /// IvyIo NVR-beeld (Foscam-app-stack), 2×5 midden in 6 kolommen.
  bool showNvr;
  String nvrUid;
  String nvrUser;
  String nvrPassword;
  int nvrChannel;
  /// SDK-kanaalnummers die tegelijk in het cameravak staan (1–4).
  List<int> nvrSelectedChannels;

  bool isLightPinned(String key) => pinnedLights.contains(key);
  bool isMacroPinned(String key) => pinnedMacros.contains(key);

  static String lightTile(String key) => 'light:$key';
  static String macroTile(String key) => 'macro:$key';
  static bool isEmptyCell(String id) => id == emptyCell || id.startsWith('empty:');

  static bool _isGridTile(String id) =>
      isEmptyCell(id) || id.startsWith('light:') || id.startsWith('macro:');

  static List<String> _sanitizeOrder(List<String> raw) => [
        for (final id in raw)
          if (_isGridTile(id)) id,
      ];

  void ensureTile(String id) {
    if (!_isGridTile(id) || isEmptyCell(id)) return;
    if (tileOrder.contains(id)) return;
    final gap = tileOrder.indexWhere(isEmptyCell);
    if (gap >= 0) {
      tileOrder[gap] = id;
    } else {
      tileOrder.add(id);
    }
  }

  void removeTile(String id) {
    for (var i = 0; i < tileOrder.length; i++) {
      if (tileOrder[i] == id) tileOrder[i] = emptyCell;
    }
  }

  bool _isActiveTile(String id) {
    if (isEmptyCell(id)) return false;
    if (id.startsWith('light:')) {
      return pinnedLights.contains(id.substring(6));
    }
    if (id.startsWith('macro:')) {
      return pinnedMacros.contains(id.substring(6));
    }
    return false;
  }

  /// Full grid including empty cells (view + edit). Pads to full rows.
  /// Weather/clock are never included.
  List<String> layoutCells(int columns) {
    final cols = columns.clamp(1, 6);
    final out = <String>[];
    for (final id in tileOrder) {
      if (isEmptyCell(id)) {
        out.add(emptyCell);
      } else if (_isActiveTile(id)) {
        out.add(id);
      }
    }
    for (final key in pinnedLights) {
      final id = lightTile(key);
      if (!out.contains(id)) out.add(id);
    }
    for (final key in pinnedMacros) {
      final id = macroTile(key);
      if (!out.contains(id)) out.add(id);
    }
    while (out.length % cols != 0) {
      out.add(emptyCell);
    }
    if (out.isEmpty) {
      for (var i = 0; i < cols; i++) {
        out.add(emptyCell);
      }
    }
    return out;
  }

  /// Remote-raster inclusief lege cellen, zodat vrij verplaatsen kan (zoals Dashboard).
  List<String> layoutRemoteCells(int columns, Iterable<String> wantedIds) {
    final cols = columns.clamp(1, 2);
    final wanted = wantedIds.toSet();
    final out = <String>[];
    for (final id in remoteOrder) {
      if (isEmptyCell(id)) {
        out.add(emptyCell);
      } else if (wanted.remove(id)) {
        out.add(id);
      }
    }
    out.addAll(wanted);
    while (out.length % cols != 0) {
      out.add(emptyCell);
    }
    if (out.isEmpty) {
      for (var i = 0; i < cols; i++) {
        out.add(emptyCell);
      }
    }
    return out;
  }

  /// Real tiles only (no empties).
  List<String> visibleTiles() {
    return [
      for (final id in layoutCells(1))
        if (!isEmptyCell(id)) id,
    ];
  }

  Map<String, dynamic> toJson() => {
        'pinnedLights': pinnedLights.toList(),
        'pinnedMacros': pinnedMacros.toList(),
        'showWeather': showWeather,
        'showClock': false,
        'weatherLat': weatherLat,
        'weatherLon': weatherLon,
        'weatherPlaceName': weatherPlaceName,
        'useDeviceLocation': useDeviceLocation,
        'gridColumnsPhone': gridColumnsPhone,
        'gridColumnsTablet': gridColumnsTablet,
        'memoNote': memoNote,
        'dayMemos': dayMemos,
        'tileColors': tileColors.map((k, v) => MapEntry(k, v)),
        'wallTabletMode': wallTabletMode,
        'proximitySensitivity': proximitySensitivity,
        'lightControlModes': lightControlModes,
        'tileOrder': tileOrder,
        'remoteOrder': remoteOrder,
        'remoteColumns': remoteColumns,
        'showNvr': showNvr,
        'nvrUid': nvrUid,
        'nvrUser': nvrUser,
        'nvrPassword': nvrPassword,
        'nvrChannel': nvrChannel,
        'nvrSelectedChannels': nvrSelectedChannels,
      };

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    final rawMemos = json['dayMemos'];
    final memos = <String, String>{};
    if (rawMemos is Map) {
      rawMemos.forEach((k, v) {
        final text = v?.toString() ?? '';
        if (text.trim().isNotEmpty) memos[k.toString()] = text;
      });
    }
    final rawColors = json['tileColors'];
    final colors = <String, int>{};
    if (rawColors is Map) {
      rawColors.forEach((k, v) {
        if (v is num) colors[k.toString()] = v.toInt();
      });
    }
    return DashboardConfig(
      pinnedLights: {
        for (final e in (json['pinnedLights'] as List? ?? const [])) e.toString(),
      },
      pinnedMacros: {
        for (final e in (json['pinnedMacros'] as List? ?? const [])) e.toString(),
      },
      showWeather: true,
      weatherLat: (json['weatherLat'] as num?)?.toDouble() ?? 51.3306,
      weatherLon: (json['weatherLon'] as num?)?.toDouble() ?? 3.2061,
      weatherPlaceName: json['weatherPlaceName']?.toString() ?? 'Zeebrugge',
      useDeviceLocation: json['useDeviceLocation'] == true,
      gridColumnsPhone: (json['gridColumnsPhone'] as num?)?.toInt().clamp(1, 6) ?? 2,
      gridColumnsTablet: (json['gridColumnsTablet'] as num?)?.toInt().clamp(1, 6) ?? 4,
      memoNote: json['memoNote']?.toString() ?? '',
      dayMemos: memos,
      tileColors: colors,
      wallTabletMode: json['wallTabletMode'] == true,
      proximitySensitivity: (json['proximitySensitivity'] as num?)?.toInt().clamp(0, 100) ?? 70,
      lightControlModes: {
        if (json['lightControlModes'] is Map)
          for (final e in (json['lightControlModes'] as Map).entries)
            if (e.value?.toString() == 'toggle' || e.value?.toString() == 'slider')
              e.key.toString(): e.value.toString(),
      },
      tileOrder: [
        for (final e in (json['tileOrder'] as List? ?? json['sectionOrder'] as List? ?? const []))
          e.toString(),
      ],
      remoteOrder: [
        for (final e in (json['remoteOrder'] as List? ?? const [])) e.toString(),
      ],
      remoteColumns: (json['remoteColumns'] as num?)?.toInt().clamp(1, 2) ?? 1,
      showNvr: json['showNvr'] != false,
      nvrUid: json['nvrUid']?.toString() ?? '',
      nvrUser: json['nvrUser']?.toString() ?? 'admin',
      nvrPassword: json['nvrPassword']?.toString() ?? '',
      nvrChannel: (json['nvrChannel'] as num?)?.toInt().clamp(0, 32) ?? 0,
      nvrSelectedChannels: _parseChannelIds(json['nvrSelectedChannels']) ??
          _legacySelected((json['nvrChannel'] as num?)?.toInt()),
    );
  }

  static List<int>? _parseChannelIds(Object? raw) {
    if (raw is! List) return null;
    final ids = <int>[
      for (final e in raw)
        if (e is num) e.toInt().clamp(0, 32),
    ];
    return ids.isEmpty ? null : ids;
  }

  static List<int> _legacySelected(int? channel) =>
      channel == null ? <int>[] : <int>[channel.clamp(0, 32)];

  String encode() => jsonEncode(toJson());

  static DashboardConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) return DashboardConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return DashboardConfig.fromJson(decoded);
      if (decoded is Map) {
        return DashboardConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return DashboardConfig();
  }
}
