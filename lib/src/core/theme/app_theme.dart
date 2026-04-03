import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E5FF), // Cyan/Neon Teal accent
        onPrimary: Colors.black,
        secondary: Color(0xFF3D5AFE),
        surface: Color(0xFF141A29), // Slightly lighter surface
        error: Color(0xFFFF3D00),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0E17),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0E17),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF141A29),
        indicatorColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: Colors.grey, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF00E5FF));
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF00E5FF),
        foregroundColor: Colors.black,
      ),
    );
  }
}
