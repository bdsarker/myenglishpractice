import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF006D77);

  /// The brand amber. Only ever a fill or a tint — it sits at 1.7:1 on white,
  /// so anything readable uses [accentInk] instead.
  static const Color accent = Color(0xFFE9C46A);

  /// The amber darkened until it passes AA as a foreground (5.3:1 on white).
  static const Color accentInk = Color(0xFF8A6516);

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  /// Text, darkest to faintest. [decor] is decorative only — it fails contrast
  /// as text, and is meant for empty-state artwork and hairlines.
  static const Color ink = Color(0xFF0F172A);
  static const Color inkMuted = Color(0xFF475569);
  // Slate-500 (#64748B) is the obvious pick here but lands at 4.43:1 on the
  // scaffold — passes on white cards, fails just off them. Darkened until it
  // clears AA on both, since this colour labels sections on either surface.
  static const Color inkFaint = Color(0xFF5F6D82);
  static const Color line = Color(0xFFE2E8F0);
  static const Color decor = Color(0xFFCBD5E1);

  static const Color error = Color(0xFFB3261E);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.merriweather(color: ink, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.merriweather(color: ink, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.merriweather(color: ink, fontWeight: FontWeight.w700, fontSize: 22),
        titleMedium: GoogleFonts.merriweather(color: inkMuted, fontSize: 16),
        bodyLarge: GoogleFonts.sourceSans3(color: ink, fontSize: 16),
        bodyMedium: GoogleFonts.sourceSans3(color: inkMuted, fontSize: 14),
        labelLarge: GoogleFonts.sourceSans3(color: ink, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.sourceSans3(color: inkFaint),
        // A white field on the near-white scaffold is only 1.07:1, so unlike the
        // dark theme it needs a visible edge to read as an input at all.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accent.withAlpha(45),
        labelStyle: GoogleFonts.sourceSans3(color: accentInk, fontWeight: FontWeight.w600),
        side: const BorderSide(color: Color(0xFFE3C46A), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        // Same 1.07:1 problem as the input field — the hairline is what makes a
        // flat white card visible on the scaffold.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: line),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        // Reads backwards: `.dark` means dark *icons*, for a light bar. Without
        // it the status bar keeps its white glyphs and disappears.
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.merriweather(
          color: ink,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      dividerColor: line,
    );
  }
}
