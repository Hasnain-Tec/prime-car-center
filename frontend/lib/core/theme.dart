import 'package:flutter/material.dart';

class PccColors {
  static const charcoal = Color(0xFF1B1F24);
  static const charcoal2 = Color(0xFF262B33);
  static const charcoal3 = Color(0xFF323844);
  static const steel = Color(0xFF3A6690);
  static const steelLight = Color(0xFF5487B3);
  static const hazard = Color(0xFFE8590C);
  static const hazardDark = Color(0xFFC94A08);
  static const paper = Color(0xFFF6F5F2);
  static const inkSoft = Color(0xFF5B6570);
  static const line = Color(0xFFD8D3C9);
  static const success = Color(0xFF2F9E44);
  static const danger = Color(0xFFC92A2A);
}

ThemeData buildPccTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: PccColors.hazard, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(primary: PccColors.hazard, secondary: PccColors.steel, surface: Colors.white),
    scaffoldBackgroundColor: PccColors.paper,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(backgroundColor: PccColors.charcoal, foregroundColor: Colors.white, elevation: 0),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: PccColors.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFDFDFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: PccColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: PccColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: PccColors.steelLight, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: PccColors.hazard, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: PccColors.charcoal, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)), side: const BorderSide(color: PccColors.line)),
    ),
  );
}
