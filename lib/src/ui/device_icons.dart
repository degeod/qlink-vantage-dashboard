import 'package:flutter/material.dart';

/// WebPoint Object Properties → Type / IconName.
/// Material-iconen + optionele PNG-varianten (`… 1` → `lamp1.png`, wit getint).
class DeviceIconType {
  const DeviceIconType(
    this.id,
    this.label, {
    this.asset,
    this.fallback,
  });

  final String id;
  final String label;
  final String? asset;
  final IconData? fallback;

  bool get hasAsset => asset != null && asset!.isNotEmpty;
  bool get isPng => hasAsset;
}

class DeviceIcons {
  static const defaultType = 'Light';

  static const _base = 'assets/icons';

  static const List<DeviceIconType> all = [
    // —— WebPoint (Material, zoals voorheen) ——
    DeviceIconType('Blinds', 'Blinds', fallback: Icons.blinds),
    DeviceIconType('Button', 'Button', fallback: Icons.radio_button_checked),
    DeviceIconType('Button 2', 'Button 2', fallback: Icons.smart_button),
    DeviceIconType('Chandelier', 'Chandelier', fallback: Icons.light),
    DeviceIconType('Coffee Pot', 'Coffee Pot', fallback: Icons.coffee),
    DeviceIconType('Door', 'Door', fallback: Icons.door_front_door),
    DeviceIconType('Fan', 'Fan', fallback: Icons.air),
    DeviceIconType('Fire Place', 'Fire Place', fallback: Icons.local_fire_department),
    DeviceIconType('Fluorescent', 'Fluorescent', fallback: Icons.wb_iridescent),
    DeviceIconType('Garage', 'Garage', fallback: Icons.garage),
    DeviceIconType('Keypad', 'Keypad', fallback: Icons.dialpad),
    DeviceIconType('Lamp', 'Lamp', fallback: Icons.emoji_objects),
    DeviceIconType('Light', 'Light', fallback: Icons.lightbulb),
    DeviceIconType('Music', 'Music', fallback: Icons.music_note),
    DeviceIconType('Recessed', 'Recessed', fallback: Icons.wb_incandescent),
    DeviceIconType('Sconce', 'Sconce', fallback: Icons.nightlight),
    DeviceIconType('Spa', 'Spa', fallback: Icons.hot_tub),
    DeviceIconType('Switch', 'Switch', fallback: Icons.toggle_on),
    DeviceIconType('Television', 'Television', fallback: Icons.tv),
    DeviceIconType('Thermostat', 'Thermostat', fallback: Icons.thermostat),
    DeviceIconType('Toggle', 'Toggle', fallback: Icons.toggle_on_outlined),
    DeviceIconType('Track Light', 'Track Light', fallback: Icons.highlight),
    DeviceIconType('Window', 'Window', fallback: Icons.window),

    // —— PNG-varianten (bestandsnaam eindigt op 1) ——
    DeviceIconType('Blinds 1', 'Blinds 1', asset: '$_base/blinds1.png'),
    DeviceIconType('Button 1', 'Button 1', asset: '$_base/button1.png'),
    DeviceIconType('Button 2 1', 'Button 2 1', asset: '$_base/button21.png'),
    DeviceIconType('Chandelier 1', 'Chandelier 1', asset: '$_base/chandelier1.png'),
    DeviceIconType('Door 1', 'Door 1', asset: '$_base/door1.png'),
    DeviceIconType('Fan 1', 'Fan 1', asset: '$_base/fan1.png'),
    DeviceIconType('Fluorescent 1', 'Fluorescent 1', asset: '$_base/fluorescent1.png'),
    DeviceIconType('Garage 1', 'Garage 1', asset: '$_base/garage1.png'),
    DeviceIconType('Lamp 1', 'Lamp 1', asset: '$_base/lamp1.png'),
    DeviceIconType('Light 1', 'Light 1', asset: '$_base/light1.png'),
    DeviceIconType('Recessed 1', 'Recessed 1', asset: '$_base/recessed1.png'),
    DeviceIconType('Sconce 1', 'Sconce 1', asset: '$_base/sconce1.png'),
    DeviceIconType('Spa 1', 'Spa 1', asset: '$_base/spa1.png'),
    DeviceIconType('Switch 1', 'Switch 1', asset: '$_base/switch1.png'),
    DeviceIconType('Toggle 1', 'Toggle 1', asset: '$_base/toggle1.png'),
    DeviceIconType('Track Light 1', 'Track Light 1', asset: '$_base/track-light1.png'),
    DeviceIconType('Window 1', 'Window 1', asset: '$_base/window1.png'),
    DeviceIconType('Thermostat 1', 'Thermostat 1', asset: '$_base/thermostat1.png'),

    DeviceIconType('Air Conditioner 1', 'Air Conditioner 1', asset: '$_base/air-conditioner1.png'),
    DeviceIconType('Air Purifier 1', 'Air Purifier 1', asset: '$_base/air-purifier1.png'),
    DeviceIconType('Alarm Light 1', 'Alarm Light 1', asset: '$_base/alarm-light1.png'),
    DeviceIconType('Bed King 1', 'Bed King 1', asset: '$_base/bed-king1.png'),
    DeviceIconType('Bed Single 1', 'Bed Single 1', asset: '$_base/bed-single1.png'),
    DeviceIconType('Biohazard 1', 'Biohazard 1', asset: '$_base/biohazard1.png'),
    DeviceIconType('Bulkhead Light 1', 'Bulkhead Light 1', asset: '$_base/bulkhead-light1.png'),
    DeviceIconType('Car Turbo 1', 'Car Turbo 1', asset: '$_base/car-turbo1.png'),
    DeviceIconType('CCTV 1', 'CCTV 1', asset: '$_base/cctv1.png'),
    DeviceIconType('Curtains 1', 'Curtains 1', asset: '$_base/curtains1.png'),
    DeviceIconType('Greenhouse 1', 'Greenhouse 1', asset: '$_base/greenhouse1.png'),
    DeviceIconType('Home Analytics 1', 'Home Analytics 1', asset: '$_base/home-analytics1.png'),
    DeviceIconType('LED Strip 1', 'LED Strip 1', asset: '$_base/led-strip1.png'),
    DeviceIconType('Motion Sensor 1', 'Motion Sensor 1', asset: '$_base/motion-sensor1.png'),
    DeviceIconType('Post Lamp 1', 'Post Lamp 1', asset: '$_base/post-lamp1.png'),
    DeviceIconType('Sofa 1', 'Sofa 1', asset: '$_base/sofa1.png'),
    DeviceIconType('Stairs 1', 'Stairs 1', asset: '$_base/stairs1.png'),
    DeviceIconType('CO Sensor 1', 'CO Sensor 1', asset: '$_base/co-sensor1.png'),
    DeviceIconType('Water Alert 1', 'Water Alert 1', asset: '$_base/water-alert1.png'),
    DeviceIconType('Window Shutter 1', 'Window Shutter 1', asset: '$_base/window-shutter1.png'),

    // Map 11 — scene / macro iconen
    DeviceIconType('Emergency Flash 1', 'Emergency Flash 1', asset: '$_base/emergency-flash1.png'),
    DeviceIconType('Intruder Alert 1', 'Intruder Alert 1', asset: '$_base/intruder-alert1.png'),
    DeviceIconType('Leaving Home 1', 'Leaving Home 1', asset: '$_base/leaving-home1.png'),
    DeviceIconType('Party Popper 1', 'Party Popper 1', asset: '$_base/party-popper1.png'),
    DeviceIconType('Heatwave 1', 'Heatwave 1', asset: '$_base/heatwave1.png'),
    DeviceIconType('Cleaning 1', 'Cleaning 1', asset: '$_base/cleaning1.png'),
    DeviceIconType('Entertainment 1', 'Entertainment 1', asset: '$_base/entertainment1.png'),
    DeviceIconType('Storm 1', 'Storm 1', asset: '$_base/storm1.png'),
  ];

  static DeviceIconType byId(String? id) {
    final key = (id == null || id.isEmpty) ? defaultType : id;
    for (final t in all) {
      if (t.id == key) return t;
    }
    return all.firstWhere((t) => t.id == defaultType);
  }

  static IconData iconFor(String? id, {required bool isOn}) {
    final type = byId(id);
    if (type.fallback != null) {
      if (id == 'Light' || id == null || id.isEmpty) {
        return isOn ? Icons.lightbulb : Icons.lightbulb_outline;
      }
      return type.fallback!;
    }
    return isOn ? Icons.lightbulb : Icons.lightbulb_outline;
  }

  static String? assetFor(String? id) => byId(id).asset;
}
