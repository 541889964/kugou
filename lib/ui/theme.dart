import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF7C4DFF);
  static const Color secondary = Color(0xFF21D4FD);
  static const Color bg = Color(0xFF0A0812);
  static const Color surface = Color(0xFF1A1726);
  static const Color surfaceHigh = Color(0xFF24203A);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: surface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0,
        centerTitle: true, scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: Colors.white, letterSpacing: 0.5)),
      cardTheme: CardTheme(
        color: surface, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35))),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.22),
        elevation: 0, height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500))),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08), thickness: 1, space: 1),
      splashColor: Colors.white10, highlightColor: Colors.white10,
      listTileTheme: ListTileThemeData(
        iconColor: Colors.white70, textColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
  }

  static const LinearGradient grad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [primary, secondary]);

  static const LinearGradient bgGrad = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF141021), bg]);

  static const LinearGradient playerGrad = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF2A1B4A), bg]);
}
