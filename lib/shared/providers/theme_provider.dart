import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/color_constants.dart';

enum AppThemeType {
  light,
  dark,
  midnight,
  neonPurple,
  electricBlue,
  emerald,
  ocean,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeType _themeType = AppThemeType.dark;
  AppThemeType get themeType => _themeType;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('app_theme') ?? 1;
    _themeType = AppThemeType.values[index];
    _syncPrimaryColor();
    notifyListeners();
  }

  Future<void> setTheme(AppThemeType type) async {
    _themeType = type;
    _syncPrimaryColor();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme', type.index);
  }

  void _syncPrimaryColor() {
    switch (_themeType) {
      case AppThemeType.light:
        ColorConstants.setPrimary(const Color(0xFF6C63FF));
        break;
      case AppThemeType.dark:
        ColorConstants.setPrimary(const Color(0xFF8B85FF));
        break;
      case AppThemeType.midnight:
        ColorConstants.setPrimary(const Color(0xFFBB86FC));
        break;
      case AppThemeType.neonPurple:
        ColorConstants.setPrimary(const Color(0xFFCE93D8));
        break;
      case AppThemeType.electricBlue:
        ColorConstants.setPrimary(const Color(0xFF64B5F6));
        break;
      case AppThemeType.emerald:
        ColorConstants.setPrimary(const Color(0xFF69F0AE));
        break;
      case AppThemeType.ocean:
        ColorConstants.setPrimary(const Color(0xFF4DD0E1));
        break;
    }
  }

  ThemeData get theme {
    switch (_themeType) {
      case AppThemeType.light:
        return _lightTheme;
      case AppThemeType.dark:
        return _darkTheme;
      case AppThemeType.midnight:
        return _midnightTheme;
      case AppThemeType.neonPurple:
        return _neonPurpleTheme;
      case AppThemeType.electricBlue:
        return _electricBlueTheme;
      case AppThemeType.emerald:
        return _emeraldTheme;
      case AppThemeType.ocean:
        return _oceanTheme;
    }
  }

  Brightness get brightness => theme.brightness;

  static const _fontFamily = 'GoogleSans';

  TextTheme _buildTextTheme(TextTheme base) {
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

  InputDecorationTheme _inputTheme(Color focus, Color fill, Color border) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focus, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // === LIGHT ===
  ThemeData get _lightTheme {
    final tt = _buildTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: Brightness.light),
      textTheme: tt,
      scaffoldBackgroundColor: const Color(0xFFF5F5F8),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100))),
      inputDecorationTheme: _inputTheme(const Color(0xFF6C63FF), Colors.grey.shade50, Colors.grey.shade200),
      appBarTheme: AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0, titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200),
    );
  }

  // === DARK ===
  ThemeData get _darkTheme {
    final tt = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: Brightness.dark, primary: const Color(0xFF8B85FF)),
      textTheme: tt,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      cardTheme: CardThemeData(color: const Color(0xFF1A1A1A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
      inputDecorationTheme: _inputTheme(const Color(0xFF8B85FF), const Color(0xFF1A1A1A), Colors.white.withValues(alpha: 0.1)),
      appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF0D0D0D), foregroundColor: Colors.white, elevation: 0, titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.06)),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    );
  }

  // === MIDNIGHT ===
  ThemeData get _midnightTheme {
    final tt = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBB86FC), brightness: Brightness.dark, primary: const Color(0xFFBB86FC)),
      textTheme: tt,
      scaffoldBackgroundColor: const Color(0xFF080808),
      cardTheme: CardThemeData(color: const Color(0xFF141414), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
      inputDecorationTheme: _inputTheme(const Color(0xFFBB86FC), const Color(0xFF141414), Colors.white.withValues(alpha: 0.08)),
      appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF080808), foregroundColor: Colors.white, elevation: 0, titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBB86FC), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF141414), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.05)),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    );
  }

  // === NEON PURPLE ===
  ThemeData get _neonPurpleTheme {
    final tt = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9C27B0), brightness: Brightness.dark, primary: const Color(0xFFCE93D8)),
      textTheme: tt,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      cardTheme: CardThemeData(color: const Color(0xFF1A1A1A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF9C27B0).withValues(alpha: 0.12)))),
      inputDecorationTheme: _inputTheme(const Color(0xFFCE93D8), const Color(0xFF1A1A1A), const Color(0xFF9C27B0).withValues(alpha: 0.15)),
      appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF0D0D0D), foregroundColor: Colors.white, elevation: 0, titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(color: const Color(0xFF9C27B0).withValues(alpha: 0.08)),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    );
  }

  // === ELECTRIC BLUE ===
  ThemeData get _electricBlueTheme {
    final tt = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3), brightness: Brightness.dark, primary: const Color(0xFF64B5F6)),
      textTheme: tt,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      cardTheme: CardThemeData(color: const Color(0xFF1A1A1A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF2196F3).withValues(alpha: 0.1)))),
      inputDecorationTheme: _inputTheme(const Color(0xFF64B5F6), const Color(0xFF1A1A1A), const Color(0xFF2196F3).withValues(alpha: 0.12)),
      appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF0D0D0D), foregroundColor: Colors.white, elevation: 0, titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(color: const Color(0xFF2196F3).withValues(alpha: 0.08)),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    );
  }

  // === EMERALD ===
  ThemeData get _emeraldTheme {
    final tt = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C853), brightness: Brightness.dark, primary: const Color(0xFF69F0AE)),
      textTheme: tt,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      cardTheme: CardThemeData(color: const Color(0xFF1A1A1A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF00C853).withValues(alpha: 0.1)))),
      inputDecorationTheme: _inputTheme(const Color(0xFF69F0AE), const Color(0xFF1A1A1A), const Color(0xFF00C853).withValues(alpha: 0.12)),
      appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF0D0D0D), foregroundColor: Colors.white, elevation: 0, titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(color: const Color(0xFF00C853).withValues(alpha: 0.08)),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    );
  }

  // === OCEAN ===
  ThemeData get _oceanTheme {
    final tt = _buildTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BCD4), brightness: Brightness.dark, primary: const Color(0xFF4DD0E1)),
      textTheme: tt,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      cardTheme: CardThemeData(color: const Color(0xFF1A1A1A), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF00BCD4).withValues(alpha: 0.1)))),
      inputDecorationTheme: _inputTheme(const Color(0xFF4DD0E1), const Color(0xFF1A1A1A), const Color(0xFF00BCD4).withValues(alpha: 0.12)),
      appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF0D0D0D), foregroundColor: Colors.white, elevation: 0, titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(color: const Color(0xFF00BCD4).withValues(alpha: 0.08)),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    );
  }
}
