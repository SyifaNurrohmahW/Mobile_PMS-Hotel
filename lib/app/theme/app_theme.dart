import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Primary Brand & Surface Palette
  static const Color primary = Color(0xFF0F4C81); // Deep Classic Blue
  static const Color primaryLight = Color(0xFFE0ECF8);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  // 1. Walk-In & Status Ready / Clean / Lunas (Green)
  static const Color walkInGreen = Color(0xFF16A34A);
  static const Color walkInGreenBg = Color(0xFFDCFCE7);

  // 2. Booking & Status Occupied / In-House (Blue)
  static const Color bookingBlue = Color(0xFF2563EB);
  static const Color bookingBlueBg = Color(0xFFDBEAFE);

  // 3. Arrivals / Kedatangan / Check-In (Teal)
  static const Color arrivalsTeal = Color(0xFF0D9488);
  static const Color arrivalsTealBg = Color(0xFFCCFBF1);

  // 4. In-House Management (Indigo)
  static const Color inHouseIndigo = Color(0xFF4F46E5);
  static const Color inHouseIndigoBg = Color(0xFFE0E7FF);

  // 5. Checkout & Warning / Inspeksi (Orange)
  static const Color checkoutOrange = Color(0xFFEA580C);
  static const Color checkoutOrangeBg = Color(0xFFFFEDD5);

  // Danger / Dirty / Belum Lunas / Outstanding (Red)
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color dangerRedBg = Color(0xFFFEE2E2);

  // Neutral / Maintenance (Slate)
  static const Color neutralSlate = Color(0xFF4B5563);
  static const Color neutralSlateBg = Color(0xFFF3F4F6);

  // Legacy aliases for backwards compatibility
  static const Color accent = checkoutOrange;
  static const Color success = walkInGreen;
  static const Color warning = checkoutOrange;
  static const Color danger = dangerRed;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: arrivalsTeal,
      surface: surface,
      error: dangerRed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? primary : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: isSelected ? primary : textSecondary,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
