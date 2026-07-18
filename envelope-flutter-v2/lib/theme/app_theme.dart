import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds — 3 camadas de profundidade
  static const Color bg   = Color(0xFF080A06);
  static const Color surf = Color(0xFF111408);
  static const Color card = Color(0xFF181C12);
  static const Color bord = Color(0xFF1E2419);

  // Texto
  static const Color tx = Color(0xFFEFF5E1);
  static const Color mu = Color(0xFF5A6450);

  // Marca
  static const Color acc  = Color(0xFF9ED465); // verde primário
  static const Color gold = Color(0xFFF5C542); // dourado premium

  // Semânticas
  static const Color grn  = Color(0xFF4CAF50);
  static const Color red  = Color(0xFFEF4444);
  static const Color dred = Color(0xFF8B0000);
  static const Color org  = Color(0xFFFF9800);
  static const Color blu  = Color(0xFF60A5FA);
  static const Color pur  = Color(0xFFA78BFA);

  static Color corDoUsuario(String nome) {
    const cores = [
      Color(0xFF9ED465),
      Color(0xFF5B9BD5),
      Color(0xFFED7D31),
      Color(0xFF7030A0),
      Color(0xFFFFC000),
      Color(0xFF00B0F0),
      Color(0xFF70AD47),
      Color(0xFFFF2D55),
    ];
    int hash = 0;
    for (int i = 0; i < nome.length; i++) {
      hash = nome.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return cores[hash.abs() % cores.length];
  }
}

class AppTextStyles {
  static TextStyle get display => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.tx,
    letterSpacing: -0.5,
  );

  static TextStyle get title => GoogleFonts.inter(
    fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.tx,
  );

  static TextStyle get titleSm => GoogleFonts.inter(
    fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.tx,
  );

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.tx,
  );

  static TextStyle get bodySm => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.tx,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.mu,
    letterSpacing: 0.3,
  );

  // Valores monetários — tabular nums para alinhamento
  static TextStyle get mono => GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.tx,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  static TextStyle get monoLg => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.tx,
    letterSpacing: -0.5,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  static TextStyle get monoSm => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.tx,
    fontFeatures: [const FontFeature.tabularFigures()],
  );
}

class AppSpacing {
  static const double pagePad  = 20.0;
  static const double cardGap  = 12.0;
  static const double sectionGap = 24.0;
  static const double itemGap  = 8.0;

  // Border radius
  static const double radiusCard   = 16.0;
  static const double radiusBtn    = 12.0;
  static const double radiusChip   = 20.0;
  static const double radiusInput  = 12.0;
  static const double radiusSm     = 8.0;
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.acc,
        secondary: AppColors.gold,
        surface: AppColors.surf,
        onSurface: AppColors.tx,
        error: AppColors.red,
      ),
      textTheme: textTheme.copyWith(
        bodyLarge:   textTheme.bodyLarge?.copyWith(color: AppColors.tx),
        bodyMedium:  textTheme.bodyMedium?.copyWith(color: AppColors.tx),
        titleMedium: textTheme.titleMedium?.copyWith(color: AppColors.tx),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.tx,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.tx),
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        modalBackgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.mu, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.bord,
        thickness: 0.5,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : AppColors.mu),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.grn : AppColors.bord),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.acc,
        foregroundColor: AppColors.bg,
        elevation: 8,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surf,
        selectedItemColor: AppColors.acc,
        unselectedItemColor: AppColors.mu,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
