import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF006D77);
  static const Color accent = Color(0xFFE9C46A);
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color cardColor = Color(0xFF1C2128);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: Color(0xFFCF6679),
      ),
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
        titleMedium: GoogleFonts.merriweather(color: Colors.white70, fontSize: 16),
        bodyLarge: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 16),
        bodyMedium: GoogleFonts.sourceSans3(color: Colors.white70, fontSize: 14),
        labelLarge: GoogleFonts.sourceSans3(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.sourceSans3(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accent.withAlpha(30),
        labelStyle: GoogleFonts.sourceSans3(color: accent, fontWeight: FontWeight.w600),
        side: const BorderSide(color: accent, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.merriweather(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      dividerColor: Colors.white12,
    );
  }
}
