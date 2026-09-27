import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'src/state/app_controller.dart';
import 'src/ui/screens/home_shell.dart';
import 'src/ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phone + tablet / landscape for Dashboard grids.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C1018),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // Fullscreen: verberg de Android status- en navigatiebalk (uur, verbindingen,
  // batterij). Vegen vanaf de rand toont ze tijdelijk, daarna weer weg.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final controller = AppController();
  await controller.init();
  runApp(VantageApp(controller: controller));
}

class VantageApp extends StatelessWidget {
  const VantageApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        title: 'Vantage Remote',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const AppShell(),
      ),
    );
  }
}
