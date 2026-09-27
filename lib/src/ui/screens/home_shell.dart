import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../shell_nav.dart';
import '../theme/app_theme.dart';
import 'connection_help_screen.dart';
import 'dashboard_screen.dart';
import 'keypads_screen.dart';
import 'lights_screen.dart';
import 'macros_screen.dart';
import 'phone_remote_screen.dart';
import 'schedules_screen.dart';
import 'settings_screen.dart';
import 'temperature_screen.dart';
import 'time_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 1; // start op Remote

  static const _labels = [
    'Home',
    'Remote',
    'Dashboard',
    'Lights',
    'Keypads',
    'Macros',
    'Schedules',
    'Temp',
    'Time',
    'Settings',
  ];

  static const _icons = [
    Icons.home_rounded,
    Icons.smartphone_rounded,
    Icons.dashboard_rounded,
    Icons.lightbulb_rounded,
    Icons.grid_view_rounded,
    Icons.auto_awesome_rounded,
    Icons.calendar_month_rounded,
    Icons.thermostat_rounded,
    Icons.schedule_rounded,
    Icons.settings_rounded,
  ];

  Future<void> _applyOrientationForTab(int i) async {
    if (i == 2) {
      // Dashboard: vaste liggende stand (telefoon + tablet).
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _goTo(int i) {
    if (i < 0 || i >= _labels.length) return;
    setState(() => index = i);
    _applyOrientationForTab(i);
  }

  @override
  void initState() {
    super.initState();
    _applyOrientationForTab(index);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _HomeDashboard(),
      const PhoneRemoteScreen(),
      const DashboardScreen(),
      const LightsScreen(),
      const KeypadsScreen(),
      const MacrosScreen(),
      const SchedulesScreen(),
      const TemperatureScreen(),
      const TimeScreen(),
      const SettingsScreen(),
    ];

    final immersive = index == 1 || index == 2;
    if (immersive) {
      return ShellNav(
        index: index,
        goTo: _goTo,
        child: Scaffold(body: pages[index]),
      );
    }

    return ShellNav(
      index: index,
      goTo: _goTo,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2030), AppColors.charcoal],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (index != 1 && index != 2)
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, i) {
                        final selected = i == index;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _icons[i],
                                size: 16,
                                color: selected ? const Color(0xFF1A1208) : AppColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(_labels[i]),
                            ],
                          ),
                          selected: selected,
                          onSelected: (_) => _goTo(i),
                          selectedColor: AppColors.amber,
                          backgroundColor: AppColors.charcoalElevated,
                          labelStyle: TextStyle(
                            color: selected ? const Color(0xFF1A1208) : AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          showCheckmark: false,
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: _labels.length,
                    ),
                  ),
                Expanded(child: pages[index]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final master = app.project?.master;
    final connected = app.status == ConnectionStatus.connected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vantage', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(
            master == null ? 'Loading project…' : 'Control · ${master.name}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.charcoalElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: connected ? AppColors.amber.withValues(alpha: 0.55) : const Color(0x22FFFFFF)),
              boxShadow: [
                if (connected)
                  BoxShadow(color: AppColors.amber.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: connected
                            ? AppColors.ok
                            : (app.status == ConnectionStatus.error ? AppColors.danger : AppColors.muted),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      connected ? 'Live' : app.status.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${app.profile == NetworkProfile.remote ? "Via router" : "Local LAN"} · ${app.activeHost}:${app.activePort}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Text(app.statusMessage, style: const TextStyle(height: 1.35)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Local'),
                      selected: app.profile == NetworkProfile.local,
                      onSelected: connected ? null : (_) => app.setProfile(NetworkProfile.local),
                      selectedColor: AppColors.amber,
                      labelStyle: TextStyle(
                        color: app.profile == NetworkProfile.local ? const Color(0xFF1A1208) : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      showCheckmark: false,
                    ),
                    ChoiceChip(
                      label: const Text('Via router'),
                      selected: app.profile == NetworkProfile.remote,
                      onSelected: connected ? null : (_) => app.setProfile(NetworkProfile.remote),
                      selectedColor: AppColors.amber,
                      labelStyle: TextStyle(
                        color: app.profile == NetworkProfile.remote ? const Color(0xFF1A1208) : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      showCheckmark: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: app.status == ConnectionStatus.connecting
                          ? null
                          : () => connected ? app.disconnect() : app.connect(),
                      child: Text(connected ? 'Disconnect' : 'Connect'),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const ConnectionHelpScreen()),
                        );
                      },
                      child: const Text('Router-uitleg', style: TextStyle(color: AppColors.amber)),
                    ),
                    TextButton(
                      onPressed: () => ShellNav.of(context).goTo(1),
                      child: const Text('Remote', style: TextStyle(color: AppColors.amber)),
                    ),
                    TextButton(
                      onPressed: () => ShellNav.of(context).goTo(2),
                      child: const Text('Dashboard', style: TextStyle(color: AppColors.amber)),
                    ),
                    if (app.lastError != null)
                      Expanded(
                        child: Text(
                          app.lastError!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Project', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(label: 'Lights', value: '${app.project?.lights.length ?? 0}'),
              _StatChip(label: 'Keypads', value: '${app.project?.keypads.length ?? 0}'),
              _StatChip(label: 'Macros', value: '${app.project?.macros.length ?? 0}'),
              _StatChip(label: 'Schedules', value: '${app.project?.schedules.length ?? 0}'),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.charcoalElevated.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session log', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: app.sessionLog.length,
                      itemBuilder: (_, i) => Text(
                        app.sessionLog[i],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.charcoalElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
