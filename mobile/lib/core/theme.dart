import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours taken from the Autocall wireframe design system (primary orange #F97316).
class AppColors {
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);
  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF111827);
}

class Pal {
  final Color bg, card, border, text, muted, field, soft, navBg;
  const Pal({required this.bg, required this.card, required this.border, required this.text,
      required this.muted, required this.field, required this.soft, required this.navBg});
  static const light = Pal(bg: Color(0xFFF8FAFC), card: Colors.white, border: Color(0xFFE2E8F0),
      text: Color(0xFF0F172A), muted: Color(0xFF64748B), field: Color(0xFFF1F5F9),
      soft: Color(0xFFFFF1E6), navBg: Colors.white);
  static const dark = Pal(bg: Color(0xFF0B1220), card: Color(0xFF162032), border: Color(0xFF263449),
      text: Color(0xFFF1F5F9), muted: Color(0xFF94A3B8), field: Color(0xFF1E2A3F),
      soft: Color(0xFF3A2414), navBg: Color(0xFF111A2B));
}

extension PalX on BuildContext {
  Pal get pal => Theme.of(this).brightness == Brightness.dark ? Pal.dark : Pal.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.orange, brightness: b)
        .copyWith(primary: AppColors.orange, surface: p.card),
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.text, elevation: 0, scrolledUnderElevation: 0),
    dividerColor: p.border,
  );
}
