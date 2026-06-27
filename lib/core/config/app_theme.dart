import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF209ea1);
  static const Color secondary = Color(0xFF13435d);
  static const Color danger = Color(0xFFB80000);
  static const Color success = Color(0xFF2E7D32);
  static const Color cancel = Color(0xFFC62828);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      scaffoldBackgroundColor: secondary,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
