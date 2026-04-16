import 'package:flutter/material.dart';

class AppTheme {
  // ライトベースの温かみのある配色
  static const Color primaryColor = Color(0xFF2D2D3A);
  static const Color primaryLight = Color(0xFF4A4A5A);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGreen = Color(0xFF44B87F);
  static const Color accentBlue = Color(0xFF4A90D9);

  static const Color dangerColor = Color(0xFFE54D4D);
  static const Color warningColor = Color(0xFFE8A838);
  static const Color secondaryColor = Color(0xFF44B87F);

  static const Color bgColor = Color(0xFFF7F6F3);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  static BoxDecoration cardDecoration({double borderRadius = 16}) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentOrange,
          brightness: Brightness.light,
          primary: accentOrange,
          secondary: accentGreen,
          surface: bgColor,
          error: dangerColor,
        ),
        scaffoldBackgroundColor: bgColor,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: textPrimary,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: bgColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: accentOrange.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentOrange,
              );
            }
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: accentOrange, size: 24);
            }
            return IconThemeData(color: Colors.grey.shade400, size: 24);
          }),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
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
