import 'package:flutter/material.dart';

/// Night-camp palette from the design doc: deep blue sky, warm fire light.
class Pal {
  Pal._();

  static const night = Color(0xFF1B2A3A);
  static const panel = Color(0xFF24364A);
  static const panelHi = Color(0xFF30475F);
  static const ink = Color(0xFF0F1720);
  static const cream = Color(0xFFF4E9D0);
  static const muted = Color(0xFFB7AE98);
  static const amber = Color(0xFFF2B33D);
  static const amberDark = Color(0xFFB57A16);
  static const ember = Color(0xFFD9553B);
  static const leaf = Color(0xFF7BC86C);
  static const sky = Color(0xFF6FB7E0);
  static const xp = Color(0xFFB98CF0);
}

class AppFonts {
  AppFonts._();

  /// Titles, numbers, buttons.
  static const display = 'Silkscreen';

  /// Body text: still pixel, but easier to read in sentences.
  static const body = 'PixelifySans';
}

class AppTheme {
  AppTheme._();

  static TextStyle display(double size, {Color color = Pal.cream}) =>
      TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        color: color,
        height: 1.1,
        shadows: const [Shadow(color: Pal.ink, offset: Offset(0, 2))],
      );

  static TextStyle body(double size, {Color color = Pal.cream}) =>
      TextStyle(fontFamily: AppFonts.body, fontSize: size, color: color);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Pal.night,
    fontFamily: AppFonts.body,
    colorScheme: const ColorScheme.dark(
      primary: Pal.amber,
      secondary: Pal.leaf,
      surface: Pal.panel,
      error: Pal.ember,
      onPrimary: Pal.ink,
      onSurface: Pal.cream,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Pal.cream, fontSize: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Pal.amber : Pal.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Pal.amberDark : Pal.panelHi,
      ),
    ),
  );
}
