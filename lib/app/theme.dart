import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Couleurs et mesures du design system Kin Factures (src/styles/tokens.css du site).
// Jamais de couleur codée en dur dans les écrans : toujours KfColors / KfSpace / KfRadius.
// Deux palettes (clair / sombre) : KfColors lit la palette active, choisie par ThemeController.
class KfPalette {
  const KfPalette({
    required this.dark,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkSoft,
    required this.brand,
    required this.brandHover,
    required this.onBrand,
    required this.brandSoft,
    required this.pending,
    required this.pendingSoft,
    required this.danger,
    required this.dangerSoft,
    required this.overlay,
  });
  final bool dark;
  final Color surface, surfaceRaised, surfaceSunken, line, ink, inkMuted, inkSoft;
  final Color brand, brandHover, onBrand, brandSoft, pending, pendingSoft, danger, dangerSoft, overlay;
}

// Palette du site (tokens.css)
const kfLight = KfPalette(
  dark: false,
  surface: Color(0xFFF7F8F6),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFEEF1EF),
  line: Color(0xFFDDE3DF),
  ink: Color(0xFF17201B),
  inkMuted: Color(0xFF5B665F),
  inkSoft: Color(0xFF3F4A44),
  brand: Color(0xFF0F5C45),
  brandHover: Color(0xFF0B4535),
  onBrand: Color(0xFFFFFFFF),
  brandSoft: Color(0xFFE3F1EB),
  pending: Color(0xFF8A5300),
  pendingSoft: Color(0xFFFDF0D5),
  danger: Color(0xFFB42318),
  dangerSoft: Color(0xFFFDE8E6),
  overlay: Color(0x7317201B), // --ink à 45 %
);

// Mode sombre : fonds gris très foncés teintés de vert, vert éclairci pour rester lisible
const kfDark = KfPalette(
  dark: true,
  surface: Color(0xFF0E1311),
  surfaceRaised: Color(0xFF161C19),
  surfaceSunken: Color(0xFF1D2521),
  line: Color(0xFF27312C),
  ink: Color(0xFFE7ECE9),
  inkMuted: Color(0xFF97A39C),
  inkSoft: Color(0xFFC2CBC6),
  brand: Color(0xFF3DB088),
  brandHover: Color(0xFF34A07B),
  onBrand: Color(0xFF05140E),
  brandSoft: Color(0xFF14322A),
  pending: Color(0xFFE5AE55),
  pendingSoft: Color(0xFF3A2C12),
  danger: Color(0xFFF1786C),
  dangerSoft: Color(0xFF3D1815),
  overlay: Color(0x99000000),
);

class KfColors {
  static KfPalette _p = kfLight;
  static void use(KfPalette palette) => _p = palette;
  static bool get isDark => _p.dark;

  static Color get surface => _p.surface;
  static Color get surfaceRaised => _p.surfaceRaised;
  static Color get surfaceSunken => _p.surfaceSunken;
  static Color get line => _p.line;
  static Color get ink => _p.ink;
  static Color get inkMuted => _p.inkMuted;
  static Color get inkSoft => _p.inkSoft;
  static Color get brand => _p.brand;
  static Color get brandHover => _p.brandHover;
  static Color get onBrand => _p.onBrand;
  static Color get brandSoft => _p.brandSoft;
  static Color get pending => _p.pending;
  static Color get pendingSoft => _p.pendingSoft;
  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.dangerSoft;
  static Color get overlay => _p.overlay;

  // Bandeau vert (accueil, connexion, verrouillage) : identique dans les deux modes
  static const heroStart = Color(0xFF0B4535);
  static const heroEnd = Color(0xFF0F5C45);
  static const onHero = Color(0xFFFFFFFF);
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
  final dark = KfColors.isDark;
  // Inter sans espacement entre les lettres (comme le site ; Material en ajoute par défaut)
  final base = (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(fontFamily: 'Inter', bodyColor: KfColors.ink, displayColor: KfColors.ink);
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
    borderSide: BorderSide(color: KfColors.line),
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(KfRadius.md));
  const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      brightness: dark ? Brightness.dark : Brightness.light,
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
      shape: Border(bottom: BorderSide(color: KfColors.line)),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, color: KfColors.ink),
    ),
    cardTheme: CardThemeData(
      color: KfColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KfRadius.md),
        side: BorderSide(color: KfColors.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: KfColors.line, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KfColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: KfColors.brand, width: 2)),
      errorBorder: border.copyWith(borderSide: BorderSide(color: KfColors.danger)),
      focusedErrorBorder: border.copyWith(borderSide: BorderSide(color: KfColors.danger, width: 2)),
      labelStyle: TextStyle(color: KfColors.inkMuted),
      floatingLabelStyle: TextStyle(color: KfColors.brand),
      hintStyle: TextStyle(color: KfColors.inkMuted),
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
        side: BorderSide(color: KfColors.line),
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
        (states) => TextStyle(
          fontFamily: 'Inter',
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
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: KfColors.ink),
  );
}
