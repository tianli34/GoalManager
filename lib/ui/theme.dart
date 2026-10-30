import 'package:flutter/material.dart';

/// 应用主题：安静、低刺激，重点让数字和解释可读。
ThemeData buildTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2F6F62),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.zero),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
