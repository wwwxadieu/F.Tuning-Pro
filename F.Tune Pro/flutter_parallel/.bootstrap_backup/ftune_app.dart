import 'package:flutter/material.dart';

import 'ftune_app_controller.dart';
import 'ftune_shell.dart';

class FTuneApp extends StatefulWidget {
  const FTuneApp({super.key});

  @override
  State<FTuneApp> createState() => _FTuneAppState();
}

class _FTuneAppState extends State<FTuneApp> {
  late final FTuneAppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FTuneAppController();
  }

  @override
  Widget build(BuildContext context) {
    const shell = Color(0xFF1C1422);
    const panel = Color(0xFF25172C);
    const accent = Color(0xFFFF5B87);
    const border = Color(0x33FFFFFF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'F.Tune Pro Flutter',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: shell,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          primary: accent,
          secondary: const Color(0xFFFF8B4F),
          surface: panel,
        ),
        fontFamily: 'Segoe UI',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0x40241A30),
          hintStyle: const TextStyle(color: Color(0x8AFFFFFF)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: accent),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
        ),
      ),
      home: FTuneShell(controller: _controller),
    );
  }
}
