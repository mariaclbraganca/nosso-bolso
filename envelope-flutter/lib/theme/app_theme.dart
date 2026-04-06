import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color bg = Color(0xFF0B0E09);
  static const Color surf = Color(0xFF141710);
  static const Color card = Color(0xFF1A1E15);
  static const Color bord = Color(0xFF242820);
  static const Color tx = Color(0xFFE4EAD8);
  static const Color mu = Color(0xFF6A7460);
  static const Color acc = Color(0xFF8DC65B);
  static const Color grn = Color(0xFF4CAF50);
  static const Color org = Color(0xFFFF9800);
  static const Color red = Color(0xFFEF4444);
  static const Color dred = Color(0xFF8B0000);
  static const Color blu = Color(0xFF60A5FA);
  static const Color pur = Color(0xFFA78BFA);

  static Color corDoUsuario(String nome) {
    final cores = [
      const Color(0xFF8DC65B), // Verde original
      const Color(0xFF5B9BD5), // Azul
      const Color(0xFFED7D31), // Laranja
      const Color(0xFF7030A0), // Roxo
      const Color(0xFFFFC000), // Amarelo
      const Color(0xFF00B0F0), // Ciano
      const Color(0xFF70AD47), // Oliva
      const Color(0xFFFF2D55), // Rosa
    ];
    int hash = 0;
    for (int i = 0; i < nome.length; i++) {
        hash = nome.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return cores[hash.abs() % cores.length];
  }

  // Mantendo os nomes antigos por compatibilidade temporária se necessário, 
  // mas apontando para as novas cores do protótipo v2
  static const Color teal = acc;
  static const Color bgGrey = surf;
  static const Color textGrey = mu;
  static const Color textBlack = tx;
}

class AppTheme {
  static ThemeData get dark {
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.acc,
        surface: AppColors.surf,
        onSurface: AppColors.tx,
        error: AppColors.red,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.tx,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        modalBackgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: AppColors.tx),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: AppColors.tx),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: AppColors.tx),
      ),
    );
  }
}

