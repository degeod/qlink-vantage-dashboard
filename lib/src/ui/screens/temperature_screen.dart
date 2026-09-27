import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../theme/app_theme.dart';

class TemperatureScreen extends StatelessWidget {
  const TemperatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final devices = app.project?.temperatures ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Temperature', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('Setpoints via VHT (best effort)', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final device = devices[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalElevated,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: Theme.of(context).textTheme.titleLarge),
                      Text(device.room, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Text(
                        '${device.setpoint.toStringAsFixed(0)}°C',
                        style: const TextStyle(color: AppColors.amber, fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      Slider(
                        value: device.setpoint.clamp(10, 30),
                        min: 10,
                        max: 30,
                        divisions: 20,
                        label: '${device.setpoint.round()}°C',
                        onChanged: (v) => context.read<AppController>().previewTemperature(device, v),
                        onChangeEnd: (v) => app.setTemperature(device, v),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
