// Charte graphique Sync Watch — dark mode par défaut.
// Titres Sora · UI Inter · Rayons 12-16 px · Affiches 2:3.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class CouleursSW {
  static const fond = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const accent = Color(0xFF8B5CF6);
  static const accentSecondaire = Color(0xFF22D3EE);
  static const succes = Color(0xFF34D399);
  static const texte = Color(0xFFF1F5F9);
  static const texteSecondaire = Color(0xFF94A3B8);
  static const danger = Color(0xFFF87171);
}

ThemeData themeSyncWatch() {
  final schema = const ColorScheme.dark(
    primary: CouleursSW.accent,
    onPrimary: Colors.white,
    secondary: CouleursSW.accentSecondaire,
    onSecondary: CouleursSW.fond,
    tertiary: CouleursSW.succes,
    surface: CouleursSW.surface,
    onSurface: CouleursSW.texte,
    onSurfaceVariant: CouleursSW.texteSecondaire,
    error: CouleursSW.danger,
  );

  final typo = TextTheme(
    // Titre écran — Sora Bold 28
    headlineMedium: GoogleFonts.sora(
        fontSize: 28, fontWeight: FontWeight.w700, color: CouleursSW.texte),
    // Titre section — Sora SemiBold 20
    titleLarge: GoogleFonts.sora(
        fontSize: 20, fontWeight: FontWeight.w600, color: CouleursSW.texte),
    // Titre de carte — Sora SemiBold 15
    titleMedium: GoogleFonts.sora(
        fontSize: 15, fontWeight: FontWeight.w600, color: CouleursSW.texte),
    // Corps — Inter Regular 15
    bodyMedium: GoogleFonts.inter(fontSize: 15, color: CouleursSW.texte),
    // Légende — Inter Regular 13
    bodySmall:
        GoogleFonts.inter(fontSize: 13, color: CouleursSW.texteSecondaire),
    labelLarge: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: CouleursSW.texte),
    labelSmall: GoogleFonts.inter(
        fontSize: 11, color: CouleursSW.texteSecondaire, letterSpacing: 0),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    scaffoldBackgroundColor: CouleursSW.fond,
    textTheme: typo,
    appBarTheme: AppBarTheme(
      backgroundColor: CouleursSW.fond,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: typo.titleLarge,
      iconTheme: const IconThemeData(color: CouleursSW.texte),
    ),
    cardTheme: const CardThemeData(
      color: CouleursSW.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CouleursSW.surface,
      hintStyle: GoogleFonts.inter(fontSize: 15, color: CouleursSW.texteSecondaire),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CouleursSW.accent, width: 1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CouleursSW.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CouleursSW.accent,
        textStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CouleursSW.surface,
      indicatorColor: CouleursSW.accent.withValues(alpha: .18),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((etats) =>
          GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: etats.contains(WidgetState.selected)
                  ? CouleursSW.accent
                  : CouleursSW.texteSecondaire)),
      iconTheme: WidgetStateProperty.resolveWith((etats) => IconThemeData(
          size: 22,
          color: etats.contains(WidgetState.selected)
              ? CouleursSW.accent
              : CouleursSW.texteSecondaire)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CouleursSW.accent,
      linearTrackColor: Color(0xFF0B1120),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CouleursSW.surface,
      contentTextStyle: typo.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: CouleursSW.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dividerTheme:
        DividerThemeData(color: Colors.white.withValues(alpha: .06)),
  );
}
