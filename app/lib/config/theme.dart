import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF065FD4);
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color dangerColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color surfaceColor = Color(0xFFF5F5F5);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );

  static Color riskColor(String riskLevel) {
    switch (riskLevel) {
      case '高':
        return dangerColor;
      case '中':
        return warningColor;
      case '低':
        return secondaryColor;
      default:
        return Colors.grey;
    }
  }
}
