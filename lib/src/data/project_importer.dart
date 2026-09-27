import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/devices.dart';

class ProjectImporter {
  /// Load bundled WebPoint export (master.xml + config.xml).
  static Future<ProjectModel> loadBundled() async {
    final masterXml = await rootBundle.loadString('assets/project/master.xml');
    final configXml = await rootBundle.loadString('assets/project/config.xml');
    return parse(masterXml: masterXml, configXml: configXml);
  }

  static ProjectModel parse({required String masterXml, required String configXml}) {
    final masterDoc = XmlDocument.parse(masterXml);
    final configDoc = XmlDocument.parse(configXml);

    final master = MasterInfo(
      id: _int(masterDoc, 'Id_BusObject') ?? 1049,
      name: _text(masterDoc, 'Name_BusObject') ?? 'thuis',
      host: _text(masterDoc, 'TCPHostName_HA_') ?? '192.168.1.33',
      port: _int(masterDoc, 'TCPPort_HA_') ?? 3041,
      qLinkPort: _int(masterDoc, 'QLinkPort_VQM') ?? 3040,
      hostPort: _int(masterDoc, 'HostPort_VQM') ?? 3041,
    );

    final lights = <LightDevice>[];
    final keypads = <KeypadDevice>[];
    final macros = <MacroDevice>[];
    final schedules = <ScheduleDevice>[];
    final temperatures = <TemperatureDevice>[];
    final timeControls = <TimeControlDevice>[];

    // Collect button names keyed by "Button master station switch"
    final buttonNames = <String, String>{};

    for (final el in configDoc.findAllElements('VantageElement')) {
      final type = _childText(el, 'TypeDesc_HA_') ?? '';
      final key = _childText(el, 'DeviceUniqueKey_VQM') ??
          _childText(el, 'UniqueKey_HA_') ??
          type;
      final name = _childText(el, 'DeviceName_VQM') ??
          _childText(el, 'Name_BusObject') ??
          key;
      final room = _childText(el, 'RoomName_VQM') ?? 'Equipment';
      final masterId = _childInt(el, 'Master_VQM') ?? 11;

      if (type == 'Button') {
        final station = _childInt(el, 'Station_VQM') ?? 0;
        final sw = _childInt(el, 'Switch_VQM') ?? 0;
        buttonNames['Button $masterId $station $sw'] = name;
        continue;
      }

      if (type == 'Light') {
        lights.add(
          LightDevice(
            key: key,
            name: name,
            room: room,
            master: masterId,
            enclosure: _childInt(el, 'Enclosure_VQM') ?? 1,
            module: _childInt(el, 'Module_VQM') ?? 1,
            load: _childInt(el, 'Load_VQM') ?? 1,
            dimmable: (_childText(el, 'Dimmable_HA_') ?? 'True').toLowerCase() == 'true',
          ),
        );
        continue;
      }

      if (type == 'Keypad') {
        final station = _childInt(el, 'Station_VQM') ?? 1;
        final switches = el.findElements('Switch_VQM').map((n) => int.tryParse(n.innerText.trim()) ?? 0).where((n) => n > 0).toList();
        final names = el.findElements('BtnName_VQM').map((n) => n.innerText.trim()).toList();
        final buttons = <KeypadButton>[];
        for (var i = 0; i < switches.length; i++) {
          final sw = switches[i];
          final btnName = i < names.length
              ? names[i]
              : (buttonNames['Button $masterId $station $sw'] ?? 'Button $sw');
          buttons.add(KeypadButton(name: btnName, switchNumber: sw));
        }
        keypads.add(
          KeypadDevice(
            key: key,
            name: name,
            room: room,
            master: masterId,
            station: station,
            buttons: buttons,
          ),
        );
        continue;
      }

      if (type == 'Macro') {
        macros.add(
          MacroDevice(
            key: key,
            name: name,
            room: room,
            master: masterId,
            index: _childInt(el, 'Id') ?? macros.length + 1,
          ),
        );
        continue;
      }

      if (type == 'Schedule' || type == 'TimeSchedule') {
        schedules.add(
          ScheduleDevice(
            key: key,
            name: name,
            room: room,
            master: masterId,
            index: _childInt(el, 'Id') ?? schedules.length + 1,
            fromQlk: true,
          ),
        );
        continue;
      }

      if (type == 'Thermostat' || type == 'Temperature') {
        temperatures.add(
          TemperatureDevice(
            key: key,
            name: name,
            room: room,
            master: masterId,
            station: _childInt(el, 'Station_VQM') ?? 1,
            setpoint: 21,
          ),
        );
        continue;
      }

      if (type == 'TimeControl' || type == 'Timer') {
        timeControls.add(
          TimeControlDevice(
            key: key,
            name: name,
            room: room,
            master: masterId,
            index: _childInt(el, 'Id') ?? timeControls.length + 1,
          ),
        );
      }
    }

    // Demo placeholders so Macro/Schedule/Temp/Time screens are usable
    // when the bundled test QLK only contains lights/keypads.
    if (macros.isEmpty) {
      macros.addAll([
        MacroDevice(key: 'macro-demo-1', name: 'All Off', room: 'Home', master: 11, index: 1),
        MacroDevice(key: 'macro-demo-2', name: 'Evening', room: 'Home', index: 2),
      ]);
    }
    // No fake schedules: empty list until QLK/WebPoint has Schedule: records.
    if (temperatures.isEmpty) {
      temperatures.add(
        TemperatureDevice(
          key: 'temp-demo-1',
          name: 'Living climate',
          room: 'Living',
          master: 11,
          station: 1,
          setpoint: 21,
        ),
      );
    }
    if (timeControls.isEmpty) {
      timeControls.add(
        TimeControlDevice(key: 'time-demo-1', name: 'Sync controller clock', room: 'System', index: 1),
      );
    }

    return ProjectModel(
      master: master,
      lights: lights,
      keypads: keypads,
      macros: macros,
      schedules: schedules,
      temperatures: temperatures,
      timeControls: timeControls,
    );
  }

  static String? _text(XmlDocument doc, String name) {
    final nodes = doc.findAllElements(name);
    if (nodes.isEmpty) return null;
    return nodes.first.innerText.trim();
  }

  static int? _int(XmlDocument doc, String name) {
    final t = _text(doc, name);
    return t == null ? null : int.tryParse(t);
  }

  static String? _childText(XmlElement el, String name) {
    final nodes = el.findElements(name);
    if (nodes.isEmpty) return null;
    return nodes.first.innerText.trim();
  }

  static int? _childInt(XmlElement el, String name) {
    final t = _childText(el, name);
    return t == null ? null : int.tryParse(t);
  }
}
