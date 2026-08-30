import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle googleSans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'GoogleSans',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle googleSansTextTheme() {
    return const TextStyle(
      fontFamily: 'GoogleSans',
    );
  }
}
