import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/devices.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';

class SchedulesScreen extends StatelessWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final schedules = (app.project?.schedules ?? const <ScheduleDevice>[])
        .where((s) => !s.isDemo)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schedules', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.charcoalElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'Schema’s maak je in QLink (tijden, acties) en upload je via de QLK naar de Master.\n\n'
              'In deze app kun je ze alleen aan/uit zetten (ena/dis) — geen tijden wijzigen.\n'
              'Dat gaat via het VCommand-commando VSC (enable/disable), als de Master dat ondersteunt.\n\n'
              'Zie je hier niets? Dan staan er geen Schedule:/TimeSchedule:-regels in de geladen QLK.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: schedules.isEmpty
                ? const Center(
                    child: Text(
                      'Geen schema’s in dit project.\n'
                      'Voeg ze toe in QLink → QLK laden in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, height: 1.4),
                    ),
                  )
                : ListView.separated(
                    itemCount: schedules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final schedule = schedules[i];
                      return SwitchListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        tileColor: AppColors.charcoalElevated,
                        title: Text(schedule.name),
                        subtitle: Text(
                          '${schedule.room} · Master ${schedule.master} · index ${schedule.index}\n'
                          'Schakelaar = aan/uit op de Master (VSC)',
                        ),
                        isThreeLine: true,
                        value: schedule.enabled,
                        activeColor: AppColors.amber,
                        onChanged: (_) async {
                          try {
                            await app.toggleSchedule(schedule);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(app.statusMessage)),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Schedule: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
