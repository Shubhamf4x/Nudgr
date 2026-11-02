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

class _ThemePalette {
  final Color seed;
  final Color primary;
  final Color button;
  final Color scaffold;
  final Color card;
  final Color cardBorder;
  final Color inputFocus;
  final Color inputFill;
  final Color inputBorder;
  final Color snackBar;
  final Color divider;
  final Brightness brightness;
  const _ThemePalette({
    required this.seed,
    required this.primary,
    required this.button,
    required this.scaffold,
    required this.card,
    required this.cardBorder,
    required this.inputFocus,
    required this.inputFill,
    required this.inputBorder,
    required this.snackBar,
    required this.divider,
    required this.brightness,
  });
}

class ThemeProvider extends ChangeNotifier {
  AppThemeType _themeType = AppThemeType.dark;
  AppThemeType get themeType => _themeType;
  ThemeProvider() {
    _loadTheme();
  }
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_prefKey);
      _themeType =
          stored != null && stored >= 0 && stored < AppThemeType.values.length
          ? AppThemeType.values[stored]
          : AppThemeType.dark;
    } catch (_) {
      _themeType = AppThemeType.dark;
    }
    _syncPrimaryColor();
    notifyListeners();
  }

  Future<void> setTheme(AppThemeType type) async {
    _themeType = type;
    _syncPrimaryColor();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, type.index);
  }

  void _syncPrimaryColor() {
    ColorConstants.setPrimary(_paletteFor(_themeType).primary);
  }

  static const _prefKey = 'app_theme';

  ThemeData get theme => _buildTheme(_paletteFor(_themeType));

  static _ThemePalette _paletteFor(AppThemeType type) {
    const darkScaffold = Color(0xFF0D0D0D);
    const darkCard = Color(0xFF1A1A1A);
    switch (type) {
      case AppThemeType.light:
        return _ThemePalette(
          seed: const Color(0xFF6C63FF),
          primary: const Color(0xFF6C63FF),
          button: const Color(0xFF6C63FF),
          scaffold: const Color(0xFFF5F5F8),
          card: Colors.white,
          cardBorder: Colors.grey.shade100,
          inputFocus: const Color(0xFF6C63FF),
          inputFill: Colors.grey.shade50,
          inputBorder: Colors.grey.shade200,
          snackBar: Colors.black87,
          divider: Colors.grey.shade200,
          brightness: Brightness.light,
        );
      case AppThemeType.dark:
        return _ThemePalette(
          seed: const Color(0xFF6C63FF),
          primary: const Color(0xFF8B85FF),
          button: const Color(0xFF6C63FF),
          scaffold: darkScaffold,
          card: darkCard,
          cardBorder: Colors.white.withValues(alpha: 0.06),
          inputFocus: const Color(0xFF8B85FF),
          inputFill: darkCard,
          inputBorder: Colors.white.withValues(alpha: 0.1),
          snackBar: darkCard,
          divider: Colors.white.withValues(alpha: 0.06),
          brightness: Brightness.dark,
        );
      case AppThemeType.midnight:
        return _ThemePalette(
          seed: const Color(0xFFBB86FC),
          primary: const Color(0xFFBB86FC),
          button: const Color(0xFFBB86FC),
          scaffold: const Color(0xFF080808),
          card: const Color(0xFF141414),
          cardBorder: Colors.white.withValues(alpha: 0.05),
          inputFocus: const Color(0xFFBB86FC),
          inputFill: const Color(0xFF141414),
          inputBorder: Colors.white.withValues(alpha: 0.08),
          snackBar: const Color(0xFF141414),
          divider: Colors.white.withValues(alpha: 0.05),
          brightness: Brightness.dark,
        );
      case AppThemeType.neonPurple:
        return _ThemePalette(
          seed: const Color(0xFF9C27B0),
          primary: const Color(0xFFCE93D8),
          button: const Color(0xFF9C27B0),
          scaffold: darkScaffold,
          card: darkCard,
          cardBorder: const Color(0xFF9C27B0).withValues(alpha: 0.12),
          inputFocus: const Color(0xFFCE93D8),
          inputFill: darkCard,
          inputBorder: const Color(0xFF9C27B0).withValues(alpha: 0.15),
          snackBar: darkCard,
          divider: const Color(0xFF9C27B0).withValues(alpha: 0.08),
          brightness: Brightness.dark,
        );
      case AppThemeType.electricBlue:
        return _ThemePalette(
          seed: const Color(0xFF2196F3),
          primary: const Color(0xFF64B5F6),
          button: const Color(0xFF2196F3),
          scaffold: darkScaffold,
          card: darkCard,
          cardBorder: const Color(0xFF2196F3).withValues(alpha: 0.1),
          inputFocus: const Color(0xFF64B5F6),
          inputFill: darkCard,
          inputBorder: const Color(0xFF2196F3).withValues(alpha: 0.12),
          snackBar: darkCard,
          divider: const Color(0xFF2196F3).withValues(alpha: 0.08),
          brightness: Brightness.dark,
        );
      case AppThemeType.emerald:
        return _ThemePalette(
          seed: const Color(0xFF00C853),
          primary: const Color(0xFF69F0AE),
          button: const Color(0xFF00C853),
          scaffold: darkScaffold,
          card: darkCard,
          cardBorder: const Color(0xFF00C853).withValues(alpha: 0.1),
          inputFocus: const Color(0xFF69F0AE),
          inputFill: darkCard,
          inputBorder: const Color(0xFF00C853).withValues(alpha: 0.12),
          snackBar: darkCard,
          divider: const Color(0xFF00C853).withValues(alpha: 0.08),
          brightness: Brightness.dark,
        );
      case AppThemeType.ocean:
        return _ThemePalette(
          seed: const Color(0xFF00BCD4),
          primary: const Color(0xFF4DD0E1),
          button: const Color(0xFF00BCD4),
          scaffold: darkScaffold,
          card: darkCard,
          cardBorder: const Color(0xFF00BCD4).withValues(alpha: 0.1),
          inputFocus: const Color(0xFF4DD0E1),
          inputFill: darkCard,
          inputBorder: const Color(0xFF00BCD4).withValues(alpha: 0.12),
          snackBar: darkCard,
          divider: const Color(0xFF00BCD4).withValues(alpha: 0.08),
          brightness: Brightness.dark,
        );
    }
  }

  static ThemeData _buildTheme(_ThemePalette p) {
    final tt = ThemeData(brightness: p.brightness).textTheme;
    final isDark = p.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.seed,
        brightness: p.brightness,
        primary: p.primary,
      ),
      textTheme: tt,
      scaffoldBackgroundColor: p.scaffold,
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.cardBorder),
        ),
      ),
      inputDecorationTheme: _inputTheme(p.inputFocus, p.inputFill, p.inputBorder),
      appBarTheme: AppBarTheme(
        backgroundColor: p.scaffold,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.button,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.snackBar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: p.divider),
      iconTheme: isDark ? const IconThemeData(color: Colors.white70) : null,
      listTileTheme: isDark
          ? const ListTileThemeData(iconColor: Colors.white70)
          : null,
    );
  }

  static InputDecorationTheme _inputTheme(
    Color focus,
    Color fill,
    Color border,
  ) {
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
}
