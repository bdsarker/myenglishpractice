import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myenglishpractice/core/theme/app_theme.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  setUpAll(() {
    // Building the theme resolves GoogleFonts, which would otherwise fetch over
    // HTTP and leave timers pending. The tests that touch ThemeData are
    // testWidgets for the same reason — a bare `test` has no binding to absorb
    // the font loader's async failure.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('is a light theme, and stays one', (tester) async {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.lightTheme.colorScheme.brightness, Brightness.light);
    // The surfaces are what actually make it look light; brightness alone is
    // just a flag the widgets consult.
    expect(_luminance(AppTheme.background), greaterThan(0.7));
    expect(_luminance(AppTheme.cardColor), greaterThan(0.7));
  });

  // Pins the property rather than the hex, so retuning the palette stays free
  // but a swatch that nobody can read on the new light surfaces fails here.
  group('foreground colours clear WCAG AA on the surfaces they sit on', () {
    const foregrounds = {
      'ink': AppTheme.ink,
      'inkMuted': AppTheme.inkMuted,
      'inkFaint': AppTheme.inkFaint,
      'primary': AppTheme.primary,
      'accentInk': AppTheme.accentInk,
      'error': AppTheme.error,
    };

    for (final surface in {'card': AppTheme.cardColor, 'scaffold': AppTheme.background}.entries) {
      foregrounds.forEach((name, color) {
        test('$name on ${surface.key}', () {
          expect(_contrast(color, surface.value), greaterThanOrEqualTo(4.5));
        });
      });
    }
  });

  test('the brand amber is a fill, never a foreground', () {
    // 1.7:1 on white. This is the whole reason accentInk exists — if someone
    // reaches for `accent` as a text colour, this is the note explaining why.
    expect(_contrast(AppTheme.accent, AppTheme.cardColor), lessThan(3.0));
  });

  testWidgets('flat white cards carry their own edge', (tester) async {
    // Card and scaffold sit 1.07:1 apart, so without the hairline an elevation-0
    // card is invisible — the dark theme never needed one.
    final cardShape = AppTheme.lightTheme.cardTheme.shape as RoundedRectangleBorder;
    expect(cardShape.side.style, BorderStyle.solid);
    expect(cardShape.side.color, AppTheme.line);
  });
}
