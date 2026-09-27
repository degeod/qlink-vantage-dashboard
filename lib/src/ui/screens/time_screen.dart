import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../theme/app_theme.dart';

class TimeScreen extends StatelessWidget {
  const TimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final controls = app.project?.timeControls ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('Query/sync controller clock (VGT / VST)', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: app.syncControllerTime,
            icon: const Icon(Icons.sync),
            label: const Text('Sync phone time to controller'),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: controls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = controls[i];
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: AppColors.charcoalElevated,
                  title: Text(item.name),
                  subtitle: Text(item.room),
                  trailing: const Icon(Icons.access_time, color: AppColors.amber),
                  onTap: app.syncControllerTime,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
