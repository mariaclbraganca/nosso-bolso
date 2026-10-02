import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NBColors {
  static const papel = Color(0xFFF3EFE6);
  static const cartao = Color(0xFFFFFDF8);
  static const afundado = Color(0xFFE9E3D6);
  static const linha = Color(0xFFDED7C8);
  static const tinta = Color(0xFF1A2420);
  static const tintaSuave = Color(0xFF5A635E);

  static const verde = Color(0xFF0E6B57);
  static const verdeProfundo = Color(0xFF0A4F40);
  static const verdeClaro = Color(0xFFD5E8DF);

  static const reserva = Color(0xFF2D5B87);
  static const reservaClaro = Color(0xFFDCE6F0);

  static const ambar = Color(0xFFF2B544);
  static const ambarTexto = Color(0xFF8A5208);
  static const ambarClaro = Color(0xFFF8E6C2);
  static const ambarBarra = Color(0xFFD98E1C);

  static const estouro = Color(0xFFB23A2A);
  static const estouroClaro = Color(0xFFF5DAD3);

  static const lavanda = Color(0xFF6B5B95);
  static const lavandaClara = Color(0xFFE6E1F0);
}

enum NaturezaEnvelope {
  consumo,
  reserva,
  objetivo;

  static NaturezaEnvelope from(Map<String, dynamic> env) {
    final n = env['natureza'] as String?;
    if (n == 'objetivo') return NaturezaEnvelope.objetivo;
    if (n == 'reserva' || env['is_reserva'] == true) return NaturezaEnvelope.reserva;
    return NaturezaEnvelope.consumo;
  }

  String get rotulo => switch (this) {
        NaturezaEnvelope.consumo => 'Consumo',
        NaturezaEnvelope.reserva => 'Reserva',
        NaturezaEnvelope.objetivo => 'Objetivo',
      };

  Color get aba => switch (this) {
        NaturezaEnvelope.consumo => NBColors.verdeClaro,
        NaturezaEnvelope.reserva => NBColors.reservaClaro,
        NaturezaEnvelope.objetivo => NBColors.ambarClaro,
      };

  Color get forte => switch (this) {
        NaturezaEnvelope.consumo => NBColors.verde,
        NaturezaEnvelope.reserva => NBColors.reserva,
        NaturezaEnvelope.objetivo => NBColors.ambarTexto,
      };
}

class NBSpacing {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 24.0, x3 = 32.0, x4 = 48.0;
  static const margemTela = 16.0;
  static const alvoToque = 48.0;
}

class NBRadius {
  static const chip = 8.0;
  static const campo = 12.0;
  static const cartao = 14.0;
  static const destaque = 20.0;
  static const sheet = 24.0;
  static const pilula = 999.0;
}

class NBText {
  static const _tab = [FontFeature.tabularFigures()];

  static TextStyle saldo = GoogleFonts.bricolageGrotesque(
      fontSize: 44, height: 48 / 44, fontWeight: FontWeight.w800, letterSpacing: -0.88, fontFeatures: _tab, color: NBColors.tinta);
  static TextStyle tituloTela = GoogleFonts.bricolageGrotesque(
      fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w700, color: NBColors.tinta);
  static TextStyle valorCartao = GoogleFonts.bricolageGrotesque(
      fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: _tab, color: NBColors.tinta);
  static TextStyle secao = GoogleFonts.bricolageGrotesque(
      fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700, color: NBColors.tinta);
  static TextStyle corpo = GoogleFonts.figtree(
      fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w500, fontFeatures: _tab, color: NBColors.tinta);
  static TextStyle rotulo = GoogleFonts.figtree(
      fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w700, color: NBColors.tinta);
  static TextStyle legenda = GoogleFonts.figtree(
      fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: NBColors.tintaSuave);
  static TextStyle eyebrow = GoogleFonts.figtree(
      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: NBColors.tintaSuave);
}

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
final _brlCurto = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

/// "R$ 1.240,00" · negativos com sinal de menos tipográfico: "−R$ 42,00".
String brl(num valor, {bool sinal = false, bool curto = false}) {
  final f = curto ? _brlCurto : _brl;
  final abs = f.format(valor.abs());
  if (valor < 0) return '−$abs';
  if (sinal && valor > 0) return '+$abs';
  return abs;
}

ThemeData nossoBolsoTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: NBColors.papel,
    colorScheme: const ColorScheme.light(
      primary: NBColors.verde,
      onPrimary: Colors.white,
      secondary: NBColors.ambar,
      onSecondary: NBColors.tinta,
      surface: NBColors.cartao,
      onSurface: NBColors.tinta,
      error: NBColors.estouro,
      outline: NBColors.linha,
    ),
    textTheme: GoogleFonts.figtreeTextTheme(base.textTheme).apply(
      bodyColor: NBColors.tinta,
      displayColor: NBColors.tinta,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: NBColors.papel,
      foregroundColor: NBColors.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: NBText.secao,
    ),
    dividerTheme: const DividerThemeData(color: NBColors.linha, thickness: 1, space: 1),
    cardTheme: const CardThemeData(
      color: NBColors.cartao,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(NBRadius.cartao)),
        side: BorderSide(color: NBColors.linha),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NBColors.verde,
        foregroundColor: Colors.white,
        disabledBackgroundColor: NBColors.afundado,
        disabledForegroundColor: NBColors.tintaSuave,
        minimumSize: const Size.fromHeight(54),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(NBRadius.cartao))),
        textStyle: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NBColors.tinta,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: NBColors.tinta, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(NBRadius.cartao))),
        textStyle: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NBColors.verde,
        textStyle: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NBColors.cartao,
      hintStyle: NBText.corpo.copyWith(color: NBColors.tintaSuave),
      labelStyle: NBText.rotulo.copyWith(color: NBColors.tintaSuave),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(NBRadius.campo)),
        borderSide: BorderSide(color: NBColors.linha, width: 1.5),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(NBRadius.campo)),
        borderSide: BorderSide(color: NBColors.tinta, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(NBRadius.campo)),
        borderSide: BorderSide(color: NBColors.estouro, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(NBRadius.campo)),
        borderSide: BorderSide(color: NBColors.estouro, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NBColors.tinta,
      contentTextStyle: NBText.corpo.copyWith(color: NBColors.papel),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(NBRadius.campo))),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NBColors.cartao,
      modalBarrierColor: Color(0x8C1A2420),
      showDragHandle: true,
      dragHandleColor: NBColors.linha,
      dragHandleSize: Size(40, 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NBRadius.sheet)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NBColors.cartao,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? NBColors.verde : NBColors.tintaSuave,
            size: 22,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? NBColors.verde : NBColors.tintaSuave,
          )),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NBColors.tinta,
      foregroundColor: NBColors.papel,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: NBColors.verde),
  );
}
