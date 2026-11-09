/// «Прямоугольник мм»: прямоугольник заданного физического размера (мм) и цвета на экране.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Только портрет (то же задано в AndroidManifest.xml).
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (_) {
    // не критично
  }
  runApp(const RectApp());
}

class RectApp extends StatelessWidget {
  const RectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Прямоугольник мм',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const SettingsPage(),
    );
  }
}
