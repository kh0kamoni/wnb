import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand colors (can be overridden from server settings)
  static Color primary = const Color(0xFF2E7D32);        // Forest green
  static Color primaryDark = const Color(0xFF1B5E20);
  static Color primaryLight = const Color(0xFF4CAF50);
  static Color accent = const Color(0xFFFF6F00);          // Amber
  static Color accentLight = const Color(0xFFFFB300);

  // Status colors
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFA000);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF1E88E5);

  // Table status colors
  static const Color tableFree = Color(0xFF43A047);
  static const Color tableOccupied = Color(0xFFE53935);
  static const Color tableReserved = Color(0xFF1E88E5);
  static const Color tableCleaning = Color(0xFFFF9800);

  // Order item status colors
  static const Color itemPending = Color(0xFFFFA000);
  static const Color itemInProgress = Color(0xFF1E88E5);
  static const Color itemReady = Color(0xFF43A047);
  static const Color itemServed = Color(0xFF9E9E9E);
  static const Color itemVoid = Color(0xFFE53935);

  // Background
  static const Color bgLight = Color(0xFFF5F5F0);
  static const Color bgDark = Color(0xFF121212);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color surfaceDark = Color(0xFF252525);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFAFAFA);

  // Kitchen display specific
  static const Color kitchenBg = Color(0xFF0D0D0D);
  static const Color kitchenCard = Color(0xFF1A1A1A);
  static const Color kitchenBorder = Color(0xFF2E2E2E);
  static const Color kitchenNew = Color(0xFFFF6F00);
  static const Color kitchenProgress = Color(0xFF1E88E5);
  static const Color kitchenDone = Color(0xFF43A047);
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgLight,
      primaryColor: AppColors.primary,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardLight,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEEEEE),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDark,
      primaryColor: AppColors.primary,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
      ),
    );
  }

  // Kitchen Display theme (dark, high contrast)
  static ThemeData get kitchenTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.kitchenBg,
      primaryColor: AppColors.kitchenNew,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF6F00),
        surface: Color(0xFF1A1A1A),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      cardTheme: const CardTheme(
        color: Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFF2E2E2E)),
        ),
      ),
    );
  }
}
