import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'services/settings_service.dart';
import 'services/file_state_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.loadSettings();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide system titlebar for custom one
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsService),
        ChangeNotifierProvider(create: (_) => FileStateService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final primaryColor = settings.accentColor;

    return MaterialApp(
      title: 'MyMeta',
      themeMode: settings.themeMode,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(primaryColor),
      darkTheme: AppTheme.darkTheme(primaryColor),
      home: const HomePage(),
    );
  }
}
