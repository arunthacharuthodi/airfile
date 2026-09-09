import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pure Black & White / Grayscale Minimalist Palette
  static const Color bgPrimary = Color(0xFF000000);
  static const Color bgSecondary = Color(0xFF0A0A0A);
  static const Color cardBg = Color(0xFF111111);
  static const Color cardBgHover = Color(0xFF1A1A1A);
  static const Color cardBorder = Color(0xFF242424);
  static const Color cardBorderHover = Color(0xFF3E3E3E);

  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textMuted = Color(0xFF6B6B6B);

  static const Color accentWhite = Color(0xFFFFFFFF);
  static const Color accentSilver = Color(0xFFD4D4D4);
  static const Color accentDark = Color(0xFF1C1C1C);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.ptSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: accentWhite,
        secondary: accentSilver,
        surface: cardBg,
        error: accentSilver,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.ptSans(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.ptSans(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: GoogleFonts.ptSans(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: 0.2),
        titleMedium: GoogleFonts.ptSans(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
        bodyLarge: GoogleFonts.ptSans(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.w400, color: textMuted),
        labelLarge: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: 0.4),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgSecondary,
        contentTextStyle: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.w400, color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: cardBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static BoxDecoration glassCardDecoration({
    bool isHighlighted = false,
    double radius = 10,
  }) {
    return BoxDecoration(
      color: isHighlighted ? cardBgHover : cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isHighlighted ? accentWhite.withValues(alpha: 0.4) : cardBorder,
        width: 1.0,
      ),
    );
  }

  static BoxDecoration buttonDecoration({bool isOutlined = false}) {
    if (isOutlined) {
      return BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorderHover, width: 1),
      );
    }
    return BoxDecoration(
      color: accentWhite,
      borderRadius: BorderRadius.circular(6),
    );
  }
}
