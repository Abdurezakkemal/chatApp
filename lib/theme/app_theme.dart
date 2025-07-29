import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Color Palette ---
  static const Color primaryGreen = Color(0xFF2E4009); // Darker Moss Green for AA contrast
  static const Color accentBrown = Color(0xFF6D4C41); // Darker Earthy Brown for AA contrast
  static const Color lightBackground = Color(0xFFF5F5DC); // Beige
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF333333); // Dark Grey
  static const Color subtleTextColor = Color(0xFF5A5A5A);

  // --- Light Theme ---
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentBrown,
        background: lightBackground,
        surface: cardColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: textColor,
        onSurface: textColor,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0, // Flat design
      ),
      textTheme: GoogleFonts.latoTextTheme(
        const TextTheme(
          bodyLarge: TextStyle(color: textColor),
          bodyMedium: TextStyle(color: subtleTextColor),
          titleLarge: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
        ),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: primaryGreen,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentBrown,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: const TextStyle(color: subtleTextColor),
      ),
    );
  }

  // Optional: Define a dark theme later if needed
}
