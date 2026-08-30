import 'package:flutter/material.dart';

class ColorConstants {
  ColorConstants._();

  static Color _primaryOverride = const Color(0xFF6C63FF);
  static bool _hasOverride = false;

  static void setPrimary(Color color) {
    _primaryOverride = color;
    _hasOverride = true;
  }

  static void clearPrimary() {
    _hasOverride = false;
  }

  static Color get primary => _hasOverride ? _primaryOverride : const Color(0xFF6C63FF);
  static Color get primaryDark => _hasOverride
      ? Color.lerp(_primaryOverride, Colors.black, 0.15)!
      : const Color(0xFF5A52D5);
  static Color get primaryLight => _hasOverride
      ? Color.lerp(_primaryOverride, Colors.white, 0.2)!
      : const Color(0xFF8B85FF);
  static const Color secondary = Color(0xFF00D9A6);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF00D9A6);
  static const Color warning = Color(0xFFFFB347);
  static const Color priorityLow = Color(0xFF4CAF50);
  static const Color priorityMedium = Color(0xFFFFB347);
  static const Color priorityHigh = Color(0xFFFF8A65);
  static const Color priorityUrgent = Color(0xFFFF6B6B);
  static const List<Color> categoryColors = [
    Color(0xFF6C63FF),
    Color(0xFF00D9A6),
    Color(0xFFFFB347),
    Color(0xFFFF6B6B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF5722),
    Color(0xFF00BCD4),
    Color(0xFF795548),
  ];
}
