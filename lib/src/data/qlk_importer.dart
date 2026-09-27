import '../models/devices.dart';

/// Parse a textual QLink 3.x / 4.x `.qlk` project into the app device model.
///
/// Based on QLink Explorer's read-only parser. This does not upload to the
/// controller — it only builds the on-phone control UI from the file.
class QlkImporter {
  static ProjectModel parse(
    String text, {
    MasterInfo? existingMaster,
  }) {
    final lines = text.split(RegExp(r'\r?\n'));
    var qlinkVersion = '';
    var projectName = '';
    var currentRoom = '';
    var currentMaster = 11;
    final masters = <(String, int)>[];
    final lights = <LightDevice>[];
    final keypads = <KeypadDevice>[];
    final macros = <MacroDevice>[];
    final schedules = <ScheduleDevice>[];
    final temperatures = <TemperatureDevice>[];
    final lightKeys = <String>{};

    KeypadDevice? currentKeypad;
    KeypadButton? currentButton;
    final keypadButtons = <KeypadButton>[];

    void addLight(LightDevice light) {
      if (lightKeys.add(light.key)) lights.add(light);
    }

    ({int master, int enclosure, int module, int load, int? level})? parseLdA(String raw) {
      final parts = raw.split(':');
      final token = parts.first.trim();
      final digits = token.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 5) return null;
      final master = int.tryParse(digits.substring(0, 2)) ?? currentMaster;
      final enclosure = int.tryParse(digits.substring(2, 3)) ?? 1;
      final module = int.tryParse(digits.substring(3, 4)) ?? 1;
      final load = int.tryParse(digits.substring(4, 5)) ?? 1;
      int? level;
      if (parts.length >= 2) {
        final pct = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        level = int.tryParse(pct);
      }
      return (
        master: master,
        enclosure: enclosure,
        module: module,
        load: load,
        level: level,
      );
    }

    /// QLink LdA address like `11111` or `11111:95%` → master/enc/mod/load.
    void ensureLightFromLdA(String raw, {required String fallbackName}) {
      final parsed = parseLdA(raw);
      if (parsed == null) return;
      addLight(
        LightDevice(
          key: 'Load ${parsed.master} ${parsed.enclosure} ${parsed.module} ${parsed.load}',
          name: fallbackName,
          room: currentRoom.isEmpty ? 'Home' : currentRoom,
          master: parsed.master,
          enclosure: parsed.enclosure,
          module: parsed.module,
          load: parsed.load,
          dimmable: true,
        ),
      );
    }

    void flushKeypad() {
      final kp = currentKeypad;
      if (kp == null) return;
      keypads.add(
        KeypadDevice(
          key: kp.key,
          name: kp.name,
          room: kp.room,
          master: kp.master,
          station: kp.station,
          serialNumber: kp.serialNumber,
          buttons: List<KeypadButton>.from(keypadButtons),
        ),
      );
      currentKeypad = null;
      currentButton = null;
      keypadButtons.clear();
    }

    for (final original in lines) {
      final line = original.trim();
      if (line.isEmpty || line.startsWith('*')) continue;

      if (line.startsWith('QLink:')) {
        qlinkVersion = _afterColon(line);
      } else if (line.startsWith('Project:')) {
        projectName = _afterColon(line);
      } else if (line.startsWith('Master:') || line.startsWith('DINMaster:')) {
        flushKeypad();
        final values = _values(line);
        if (values.length >= 2) {
          currentMaster = int.tryParse(values[1]) ?? currentMaster;
          masters.add((values[0], currentMaster));
        }
      } else if (line.startsWith('Room:')) {
        currentRoom = _afterColon(line);
      } else if (line.startsWith('Module:')) {
        // Module: name,type,master,enclosure,module — MDS* often has multiple loads.
        final values = _values(line);
        if (values.length >= 5) {
          final master = int.tryParse(values[2]) ?? currentMaster;
          final enclosure = int.tryParse(values[3]) ?? 1;
          final module = int.tryParse(values[4]) ?? 1;
          final type = values[1].toUpperCase();
          final channels = type.contains('MDS8') || type.contains('8')
              ? 8
              : (type.contains('MDS4') || type.contains('4') ? 4 : 1);
          for (var ch = 1; ch <= channels; ch++) {
            addLight(
              LightDevice(
                key: 'Load $master $enclosure $module $ch',
                name: '${values[0]} L$ch',
                room: currentRoom.isEmpty ? 'Home' : currentRoom,
                master: master,
                enclosure: enclosure,
                module: module,
                load: ch,
                dimmable: !type.contains('RLY') && !type.contains('RELAY'),
              ),
            );
          }
        }
      } else if (line.startsWith('Load:') ||
          line.startsWith('DimmedLoad:') ||
          line.startsWith('HVRelay:')) {
        final values = _values(line);
        if (line.startsWith('Load:') && values.length >= 5) {
          addLight(
            LightDevice(
              key: 'Load ${values[1]} ${values[2]} ${values[3]} ${values[4]}',
              name: values[0],
              room: currentRoom.isEmpty ? 'Home' : currentRoom,
              master: int.tryParse(values[1]) ?? currentMaster,
              enclosure: int.tryParse(values[2]) ?? 1,
              module: int.tryParse(values[3]) ?? 1,
              load: int.tryParse(values[4]) ?? 1,
              dimmable: true,
            ),
          );
        } else if (values.length >= 4) {
          addLight(
            LightDevice(
              key: 'Load $currentMaster ${values[1]} ${values[2]} ${values[3]}',
              name: values[0],
              room: currentRoom.isEmpty ? 'Home' : currentRoom,
              master: currentMaster,
              enclosure: int.tryParse(values[1]) ?? 1,
              module: int.tryParse(values[2]) ?? 1,
              load: int.tryParse(values[3]) ?? 1,
              dimmable: !line.startsWith('HVRelay:'),
            ),
          );
        }
      } else if (line.startsWith('Station:')) {
        flushKeypad();
        final values = _values(line);
        if (values.length >= 4) {
          final master = int.tryParse(values[2]) ?? currentMaster;
          final station = int.tryParse(values[3]) ?? 1;
          final serial = values.length >= 5 ? int.tryParse(values[4]) : null;
          currentKeypad = KeypadDevice(
            key: 'Keypad $master $station',
            name: values[0],
            room: currentRoom.isEmpty ? 'Home' : currentRoom,
            master: master,
            station: station,
            serialNumber: serial,
            buttons: const [],
          );
        }
      } else if (line.startsWith('Btn:') && currentKeypad != null) {
        final values = _values(line);
        if (values.length >= 2) {
          final number = int.tryParse(values[1]) ?? (keypadButtons.length + 1);
          final label = values.length >= 3 && values[2].isNotEmpty ? values[2] : values[0];
          currentButton = KeypadButton(name: label, switchNumber: number);
          keypadButtons.add(currentButton!);
        }
      } else if (line.startsWith('Event:') && currentButton != null) {
        final ev = _afterColon(line);
        // NOT_DEFINED = geen bruikbare actie
        if (!ev.toUpperCase().contains('NOT_DEFINED')) {
          currentButton!.hasProgram = true;
          currentButton!.eventSummary = ev;
        }
      } else if (line.startsWith('LdA:') && currentButton != null) {
        currentButton!.hasProgram = true;
        final lda = _afterColon(line);
        final prev = currentButton!.eventSummary;
        currentButton!.eventSummary =
            prev == null || prev.isEmpty ? 'LdA $lda' : '$prev · LdA $lda';
        ensureLightFromLdA(
          lda,
          fallbackName: '${currentKeypad?.name ?? "Keypad"} btn ${currentButton!.switchNumber}',
        );
      } else if (line.startsWith('Macro:')) {
        final values = _values(line);
        if (values.isNotEmpty) {
          macros.add(
            MacroDevice(
              key: 'macro-${macros.length + 1}',
              name: values[0],
              room: currentRoom.isEmpty ? 'Home' : currentRoom,
              master: currentMaster,
              index: macros.length + 1,
            ),
          );
        }
      } else if (line.startsWith('Schedule:') || line.startsWith('TimeSchedule:')) {
        final values = _values(line);
        if (values.isNotEmpty) {
          schedules.add(
            ScheduleDevice(
              key: 'sched-${schedules.length + 1}',
              name: values[0],
              room: currentRoom.isEmpty ? 'Home' : currentRoom,
              master: currentMaster,
              index: schedules.length + 1,
              fromQlk: true,
            ),
          );
        }
      } else if (line.startsWith('Thermostat:') || line.startsWith('Temperature:')) {
        final values = _values(line);
        if (values.length >= 3) {
          temperatures.add(
            TemperatureDevice(
              key: 'temp-${temperatures.length + 1}',
              name: values[0],
              room: currentRoom.isEmpty ? 'Home' : currentRoom,
              master: int.tryParse(values[1]) ?? currentMaster,
              station: int.tryParse(values[2]) ?? 1,
            ),
          );
        }
      }
    }
    flushKeypad();

    if (qlinkVersion.isEmpty && lights.isEmpty && keypads.isEmpty) {
      throw FormatException('Geen herkend QLink .qlk-bestand (geen QLink:-header of objecten).');
    }

    final masterName = projectName.isNotEmpty
        ? projectName
        : (masters.isNotEmpty ? masters.first.$1 : (existingMaster?.name ?? 'thuis'));
    final masterNumber = masters.isNotEmpty ? masters.first.$2 : 11;

    // Ensure keypads with no Btn: lines still get 8 placeholder buttons.
    final normalizedKeypads = keypads.map((kp) {
      if (kp.buttons.isNotEmpty) return kp;
      return KeypadDevice(
        key: kp.key,
        name: kp.name,
        room: kp.room,
        master: kp.master,
        station: kp.station,
        serialNumber: kp.serialNumber,
        buttons: [
          for (var i = 1; i <= 8; i++) KeypadButton(name: 'Button $i', switchNumber: i),
        ],
      );
    }).toList();

    return ProjectModel(
      master: MasterInfo(
        id: existingMaster?.id ?? masterNumber,
        name: masterName,
        host: existingMaster?.host ?? '192.168.1.33',
        port: existingMaster?.port ?? 3041,
        qLinkPort: existingMaster?.qLinkPort ?? 3040,
        hostPort: existingMaster?.hostPort ?? 3041,
      ),
      lights: lights,
      keypads: normalizedKeypads,
      macros: macros.isEmpty
          ? [
              MacroDevice(key: 'macro-demo-1', name: 'All Off', room: 'Home', master: masterNumber, index: 1),
              MacroDevice(key: 'macro-demo-2', name: 'Evening', room: 'Home', master: masterNumber, index: 2),
            ]
          : macros,
      schedules: schedules,
      temperatures: temperatures.isEmpty
          ? [
              TemperatureDevice(
                key: 'temp-demo-1',
                name: 'Climate',
                room: 'Home',
                master: masterNumber,
                station: 1,
              ),
            ]
          : temperatures,
      timeControls: [
        TimeControlDevice(key: 'time-1', name: 'Sync controller clock', room: 'System', master: masterNumber),
      ],
    );
  }

  static String _afterColon(String line) {
    final i = line.indexOf(':');
    return i < 0 ? line : line.substring(i + 1).trim();
  }

  static List<String> _values(String line) {
    final payload = _afterColon(line);
    return payload.split(',').map((p) => p.trim()).toList();
  }
}
