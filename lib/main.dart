import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'providers/arb_project.dart';
import 'config/app_config.dart';
import 'screens/home_screen.dart';

final _log = Logger('Main');

/// Bootstraps the app: initialises logging, loads configuration from
/// assets, and launches the widget tree with Provider-based DI.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      time: record.time,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  _log.info('Starting Arbility...');
  final config = await AppConfig.load();
  _log.info(
    'Config loaded: filePriority=${config.filePriority}, pageSize=${config.pageSize}',
  );
  runApp(ArbilityApp(config: config));
}

const _seedColor = Color(0xFF3B82F6);

/// Root widget that sets up Provider scope, Material theme, and routing.
class ArbilityApp extends StatelessWidget {
  final AppConfig config;

  const ArbilityApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: config),
        ChangeNotifierProvider(
          create: (_) => ArbProject(filePriorityEnabled: config.filePriority),
        ),
      ],
      child: MaterialApp(
        title: 'Arbility',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _seedColor,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF0F4FA),
          fontFamily: 'Segoe UI',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
