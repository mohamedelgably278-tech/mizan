import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kV = Color(0xFF301A5B);
const kVl = Color(0xFFEEE9F7);
const kO = Color(0xFFFF4900);
const kOl = Color(0xFFFFF1E8);
const kY = Color(0xFFFFCC33);
const kYl = Color(0xFFFFF6D9);
const kG = Color(0xFF1D6B43);
const kGl = Color(0xFFE3F4EA);
const kR = Color(0xFFAC0019);
const kRl = Color(0xFFFCE8EB);
const kBg = Color(0xFFF6F3F9);
const kMu = Color(0xFF6B6375);
const kLn = Color(0xFFECE6F1);
const kInk = Color(0xFF262626);
const kCur = 'ر.س';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kO, primary: kO, secondary: kV, surface: Colors.white),
    scaffoldBackgroundColor: Colors.white,
  );
  final tt = GoogleFonts.cairoTextTheme(base.textTheme).apply(bodyColor: kInk, displayColor: kV);
  return base.copyWith(
    textTheme: tt,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kV,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800, color: kV),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kO,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFFFC2A6),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: GoogleFonts.cairo(color: kMu, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLn, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLn, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kV, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kOl,
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kV,
      contentTextStyle: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

String fmt(num v) {
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return r.toStringAsFixed(2);
}

double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

LinearGradient gradFrom(String? css) {
  final m = RegExp(r'#([0-9A-Fa-f]{6})').allMatches(css ?? '').map((e) => Color(int.parse('FF${e.group(1)}', radix: 16))).toList();
  if (m.length < 2) return const LinearGradient(colors: [kOl, kO]);
  return LinearGradient(colors: m, begin: Alignment.topRight, end: Alignment.bottomLeft);
}
