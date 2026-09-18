import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'providers/music_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/home_ui_provider.dart';
import 'screens/main_layout.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => HomeUiProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'MusicK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: settingsProvider.isDarkMode ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: settingsProvider.isDarkMode ? Colors.black : Colors.white,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: settingsProvider.isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
          contentTextStyle: TextStyle(color: settingsProvider.isDarkMode ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          actionTextColor: Colors.blueAccent,
        ),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      home: const MainLayout(),
    );
  }
}
