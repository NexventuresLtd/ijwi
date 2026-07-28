import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IjwiColors {
  // Light
  static const lightBg = Color(0xFFFAF9F6);
  static const lightBg2 = Color(0xFFF3F1EC);
  static const lightBg3 = Color(0xFFECEAE3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightGold = Color(0xFFC8922A);
  static const lightGoldLight = Color(0xFFF0C060);
  static const lightGoldDim = Color(0xFF8B6220);
  static const lightGoldBg = Color(0xFFFFF8EC);
  static const lightGoldTint = Color(0x1AC8922A);
  static const lightText = Color(0xFF1A1814);
  static const lightText2 = Color(0xFF5C5649);
  static const lightText3 = Color(0xFF9B9488);
  static const lightBorder = Color(0x12000000);
  static const lightBorder2 = Color(0x1F000000);

  // Dark
  static const darkBg = Color(0xFF100F0D);
  static const darkBg2 = Color(0xFF1A1916);
  static const darkBg3 = Color(0xFF222019);
  static const darkSurface = Color(0xFF1E1C18);
  static const darkGold = Color(0xFFC8922A);
  static const darkGoldLight = Color(0xFFF0C060);
  static const darkGoldBg = Color(0xFF1E1A10);
  static const darkGoldTint = Color(0x26C8922A);
  static const darkGoldDim = Color(0xFF8B6220);
  static const darkText = Color(0xFFF4F0E8);
  static const darkText2 = Color(0xFFA8A098);
  static const darkText3 = Color(0xFF6A6358);
  static const darkBorder = Color(0x12FFFFFF);
  static const darkBorder2 = Color(0x21FFFFFF);
}

/// Standardized icon sizes — use these instead of ad-hoc values.
class IjwiSizes {
  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 28;
  static const double avatarSm = 28;
  static const double avatarMd = 36;
  static const double avatarLg = 48;
}

/// Standardized spacing scale.
class IjwiSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class IjwiTheme {
  static TextStyle _serif({double size = 22, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  static TextStyle _sans({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);

  static ThemeData light() {
    const c = IjwiColors.lightGold;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: IjwiColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: c,
        secondary: IjwiColors.lightGoldDim,
        surface: IjwiColors.lightSurface,
        onSurface: IjwiColors.lightText,
      ),
      textTheme: TextTheme(
        displayLarge: _serif(size: 28, weight: FontWeight.w400, color: IjwiColors.lightText).copyWith(letterSpacing: -0.3),
        displayMedium: _serif(size: 22, weight: FontWeight.w400, color: IjwiColors.lightText).copyWith(letterSpacing: -0.2),
        titleLarge: _serif(size: 20, weight: FontWeight.w400, color: IjwiColors.lightText).copyWith(letterSpacing: -0.2),
        titleMedium: _sans(size: 16, weight: FontWeight.w600, color: IjwiColors.lightText).copyWith(letterSpacing: -0.1),
        bodyLarge: _sans(size: 15, color: IjwiColors.lightText).copyWith(letterSpacing: -0.1),
        bodyMedium: _sans(size: 13.5, color: IjwiColors.lightText2).copyWith(letterSpacing: -0.1),
        bodySmall: _sans(size: 12, color: IjwiColors.lightText3),
        labelLarge: _sans(size: 14, weight: FontWeight.w600, color: IjwiColors.lightText),
        labelMedium: _sans(size: 12, weight: FontWeight.w500, color: IjwiColors.lightText2),
        labelSmall: _sans(size: 10, weight: FontWeight.w600, color: IjwiColors.lightText3),
      ),
      appBarTheme: AppBarTheme(backgroundColor: IjwiColors.lightBg, foregroundColor: IjwiColors.lightText, elevation: 0, scrolledUnderElevation: 0),
      cardTheme: CardThemeData(color: IjwiColors.lightSurface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: IjwiColors.lightBorder, width: 0.3))),
      dividerColor: IjwiColors.lightBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: IjwiColors.lightSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: IjwiColors.lightBorder2, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: IjwiColors.lightBorder2, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: IjwiColors.lightGold, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: _sans(size: 14, color: IjwiColors.lightText3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: c, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: _sans(size: 14, weight: FontWeight.w600),
      )),
    );
  }

  static ThemeData dark() {
    const c = IjwiColors.darkGold;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: IjwiColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: c,
        secondary: IjwiColors.darkGoldLight,
        surface: IjwiColors.darkSurface,
        onSurface: IjwiColors.darkText,
      ),
      textTheme: TextTheme(
        displayLarge: _serif(size: 28, weight: FontWeight.w400, color: IjwiColors.darkText).copyWith(letterSpacing: -0.3),
        displayMedium: _serif(size: 22, weight: FontWeight.w400, color: IjwiColors.darkText).copyWith(letterSpacing: -0.2),
        titleLarge: _serif(size: 20, weight: FontWeight.w400, color: IjwiColors.darkText).copyWith(letterSpacing: -0.2),
        titleMedium: _sans(size: 16, weight: FontWeight.w600, color: IjwiColors.darkText).copyWith(letterSpacing: -0.1),
        bodyLarge: _sans(size: 15, color: IjwiColors.darkText).copyWith(letterSpacing: -0.1),
        bodyMedium: _sans(size: 13.5, color: IjwiColors.darkText2).copyWith(letterSpacing: -0.1),
        bodySmall: _sans(size: 12, color: IjwiColors.darkText3),
        labelLarge: _sans(size: 14, weight: FontWeight.w600, color: IjwiColors.darkText),
        labelMedium: _sans(size: 12, weight: FontWeight.w500, color: IjwiColors.darkText2),
        labelSmall: _sans(size: 10, weight: FontWeight.w600, color: IjwiColors.darkText3),
      ),
      appBarTheme: AppBarTheme(backgroundColor: IjwiColors.darkBg, foregroundColor: IjwiColors.darkText, elevation: 0, scrolledUnderElevation: 0),
      cardTheme: CardThemeData(color: IjwiColors.darkSurface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: IjwiColors.darkBorder, width: 0.3))),
      dividerColor: IjwiColors.darkBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: IjwiColors.darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: IjwiColors.darkBorder2, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: IjwiColors.darkBorder2, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: IjwiColors.darkGold, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: _sans(size: 14, color: IjwiColors.darkText3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: c, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: _sans(size: 14, weight: FontWeight.w600),
      )),
    );
  }
}
