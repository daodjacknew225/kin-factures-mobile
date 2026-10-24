import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Couleurs et mesures du design system Kin Factures (src/styles/tokens.css du site).
// Jamais de couleur codée en dur dans les écrans : toujours KfColors / KfSpace / KfRadius.
class KfColors {
  static const surface = Color(0xFFF7F8F6);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFEEF1EF);
  static const line = Color(0xFFDDE3DF);
  static const ink = Color(0xFF17201B);
  static const inkMuted = Color(0xFF5B665F);
  static const inkSoft = Color(0xFF3F4A44);
  static const brand = Color(0xFF0F5C45);
  static const brandHover = Color(0xFF0B4535);
  static const onBrand = Color(0xFFFFFFFF);
  static const brandSoft = Color(0xFFE3F1EB);
  static const pending = Color(0xFF8A5300);
  static const pendingSoft = Color(0xFFFDF0D5);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFDE8E6);
  static const overlay = Color(0x7317201B); // --ink à 45 %
}

class KfSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

class KfRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
}

ThemeData buildTheme() {
  // Inter sans espacement entre les lettres (comme le site ; Material en ajoute par défaut)
  final base = GoogleFonts.interTextTheme().apply(bodyColor: KfColors.ink, displayColor: KfColors.ink);
  TextStyle? tight(TextStyle? style) => style?.copyWith(letterSpacing: 0);
  final text = base.copyWith(
    displayLarge: tight(base.displayLarge),
    displayMedium: tight(base.displayMedium),
    displaySmall: tight(base.displaySmall),
    headlineLarge: tight(base.headlineLarge),
    headlineMedium: tight(base.headlineMedium),
    headlineSmall: tight(base.headlineSmall),
    titleLarge: tight(base.titleLarge),
    titleMedium: tight(base.titleMedium),
    titleSmall: tight(base.titleSmall),
    bodyLarge: tight(base.bodyLarge),
    bodyMedium: tight(base.bodyMedium),
    bodySmall: tight(base.bodySmall),
    labelLarge: tight(base.labelLarge),
    labelMedium: tight(base.labelMedium),
    labelSmall: tight(base.labelSmall),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(KfRadius.md),
    borderSide: const BorderSide(color: KfColors.line),
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(KfRadius.md));
  const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: KfColors.brand,
      primary: KfColors.brand,
      onPrimary: KfColors.onBrand,
      error: KfColors.danger,
      surface: KfColors.surface,
      onSurface: KfColors.ink,
    ),
    scaffoldBackgroundColor: KfColors.surface,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600),
      titleLarge: text.titleLarge?.copyWith(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 22 / 15),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 18 / 13, color: KfColors.inkMuted),
      labelLarge: text.labelLarge?.copyWith(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: KfColors.surfaceRaised,
      foregroundColor: KfColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: KfColors.line)),
      titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: KfColors.ink),
    ),
    cardTheme: CardThemeData(
      color: KfColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KfRadius.md),
        side: const BorderSide(color: KfColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: KfColors.line, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KfColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: KfColors.brand, width: 2)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: KfColors.danger)),
      focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: KfColors.danger, width: 2)),
      labelStyle: const TextStyle(color: KfColors.inkMuted),
      floatingLabelStyle: const TextStyle(color: KfColors.brand),
      hintStyle: const TextStyle(color: KfColors.inkMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KfColors.brand,
        foregroundColor: KfColors.onBrand,
        minimumSize: const Size.fromHeight(48),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KfColors.ink,
        backgroundColor: KfColors.surfaceRaised,
        side: const BorderSide(color: KfColors.line),
        minimumSize: const Size.fromHeight(48),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: KfColors.brand, textStyle: buttonText.copyWith(fontSize: 13)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KfColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      indicatorColor: KfColors.brandSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? KfColors.brand : KfColors.inkMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? KfColors.brand : KfColors.inkMuted),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KfColors.brand : null),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: KfColors.ink),
  );
}
