import 'package:flutter/material.dart';
import '../constants/color_constants.dart';

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'GoogleSans';

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFamily: _fontFamily),
      displayMedium: base.displayMedium?.copyWith(fontFamily: _fontFamily),
      displaySmall: base.displaySmall?.copyWith(fontFamily: _fontFamily),
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: _fontFamily),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: _fontFamily),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: _fontFamily),
      titleLarge: base.titleLarge?.copyWith(fontFamily: _fontFamily),
      titleMedium: base.titleMedium?.copyWith(fontFamily: _fontFamily),
      titleSmall: base.titleSmall?.copyWith(fontFamily: _fontFamily),
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: _fontFamily),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: _fontFamily),
      bodySmall: base.bodySmall?.copyWith(fontFamily: _fontFamily),
      labelLarge: base.labelLarge?.copyWith(fontFamily: _fontFamily),
      labelMedium: base.labelMedium?.copyWith(fontFamily: _fontFamily),
      labelSmall: base.labelSmall?.copyWith(fontFamily: _fontFamily),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = _buildTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ColorConstants.primary,
        brightness: Brightness.light,
        primary: ColorConstants.primary,
        secondary: ColorConstants.secondary,
        error: ColorConstants.error,
        surface: Colors.white,
      ),
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: const Color(0xFFF5F5F8),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorConstants.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColorConstants.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: ColorConstants.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ColorConstants.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ColorConstants.primary,
        brightness: Brightness.dark,
        primary: ColorConstants.primaryLight,
        secondary: ColorConstants.secondary,
        error: ColorConstants.error,
        surface: const Color(0xFF1E1E2E),
      ),
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: const Color(0xFF141422),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E2E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252538),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorConstants.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColorConstants.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF141422),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E2E),
        selectedItemColor: ColorConstants.primaryLight,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ColorConstants.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF252538),
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }
}
