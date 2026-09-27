class MasterInfo {
  const MasterInfo({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.qLinkPort,
    required this.hostPort,
  });

  final int id;
  final String name;
  final String host;
  final int port;
  final int qLinkPort;
  final int hostPort;
}

class LightDevice {
  LightDevice({
    required this.key,
    required this.name,
    required this.room,
    required this.master,
    required this.enclosure,
    required this.module,
    required this.load,
    required this.dimmable,
    this.level = 0,
    this.isOn = false,
    this.iconType = 'Light',
    String? originalName,
  }) : originalName = originalName ?? name;

  final String key;
  String name;
  final String originalName;
  final String room;
  final int master;
  final int enclosure;
  final int module;
  final int load;
  final bool dimmable;
  int level;
  bool isOn;

  /// WebPoint Object Properties "Type" / IconName (e.g. Light, Fan, Television).
  String iconType;
}

class KeypadButton {
  KeypadButton({
    required this.name,
    required this.switchNumber,
    this.hasProgram = false,
    this.eventSummary,
    String? originalName,
  }) : originalName = originalName ?? name;

  String name;
  final String originalName;
  final int switchNumber;

  /// True when geladen QLK een Event:/LdA: onder deze knop heeft.
  bool hasProgram;
  String? eventSummary;
}

class KeypadDevice {
  KeypadDevice({
    required this.key,
    required this.name,
    required this.room,
    required this.master,
    required this.station,
    required this.buttons,
    this.serialNumber,
    String? originalName,
  }) : originalName = originalName ?? name;

  final String key;
  String name;
  final String originalName;
  final String room;
  final int master;
  final int station;
  final int? serialNumber;
  final List<KeypadButton> buttons;
}

/// One load target inside a phone-side macro (executed via VLB).
class MacroAction {
  MacroAction({
    required this.lightKey,
    required this.level,
  });

  final String lightKey;
  int level;

  Map<String, dynamic> toJson() => {'lightKey': lightKey, 'level': level};

  factory MacroAction.fromJson(Map<String, dynamic> json) {
    return MacroAction(
      lightKey: json['lightKey']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt().clamp(0, 100) ?? 0,
    );
  }
}

class MacroDevice {
  MacroDevice({
    required this.key,
    required this.name,
    required this.room,
    this.master = 11,
    this.index = 1,
    this.iconType = 'Light',
    List<MacroAction>? actions,
  }) : actions = actions ?? <MacroAction>[];

  final String key;
  String name;
  final String room;
  final int master;
  final int index;

  /// Zelfde icoon-keuze als loads (Material of … 1 PNG).
  String iconType;

  /// Local scene definition: which loads from the QLK/project and at which %.
  List<MacroAction> actions;

  bool get isConfigured => actions.isNotEmpty;
}

class ScheduleDevice {
  ScheduleDevice({
    required this.key,
    required this.name,
    required this.room,
    this.enabled = true,
    this.master = 11,
    this.index = 1,
    this.fromQlk = false,
  });

  final String key;
  final String name;
  final String room;
  bool enabled;
  final int master;
  final int index;

  /// True when parsed from QLK/WebPoint — not a UI placeholder.
  final bool fromQlk;

  bool get isDemo => !fromQlk || key.startsWith('sched-demo');
}

class TemperatureDevice {
  TemperatureDevice({
    required this.key,
    required this.name,
    required this.room,
    required this.master,
    required this.station,
    this.setpoint = 21,
    this.currentTemp,
  });

  final String key;
  final String name;
  final String room;
  final int master;
  final int station;
  double setpoint;
  double? currentTemp;
}

class TimeControlDevice {
  TimeControlDevice({
    required this.key,
    required this.name,
    required this.room,
    this.master = 11,
    this.index = 1,
  });

  final String key;
  final String name;
  final String room;
  final int master;
  final int index;
}

class ProjectModel {
  ProjectModel({
    required this.master,
    required this.lights,
    required this.keypads,
    required this.macros,
    required this.schedules,
    required this.temperatures,
    required this.timeControls,
  });

  final MasterInfo master;
  final List<LightDevice> lights;
  final List<KeypadDevice> keypads;
  final List<MacroDevice> macros;
  final List<ScheduleDevice> schedules;
  final List<TemperatureDevice> temperatures;
  final List<TimeControlDevice> timeControls;
}
