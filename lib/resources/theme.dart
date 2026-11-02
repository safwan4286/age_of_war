import 'package:flutter/material.dart';

import '../services/responsiveness/device_manager.dart';

/// "Stone & ember" palette: warm stone panels, gold buttons, dark brown
/// outlines like the characters' line art.
class Pal {
  Pal._();

  /// Behind everything (loading, letterbox).
  static const night = Color(0xFF2A2018);

  /// Outlines and text strokes.
  static const ink = Color(0xFF2B1B10);

  static const cream = Color(0xFFFFF3D6);
  static const muted = Color(0xFFD2BE9E);

  /// Stone panels: top and bottom of the gradient, and the inner rim.
  static const stoneTop = Color(0xFF7A6857);
  static const stoneBottom = Color(0xFF55473A);
  static const stoneRim = Color(0xFFA08C76);

  /// Translucent dark wash for HUD chips over the battlefield.
  static const shade = Color(0xCC2B1B10);

  static const amber = Color(0xFFFFB52E);
  static const amberDark = Color(0xFFB8680F);
  static const ember = Color(0xFFE0482F);
  static const leaf = Color(0xFF7CC843);
  static const sky = Color(0xFF6FB7E0);
  static const xp = Color(0xFFB98CF0);
}

class AppFonts {
  AppFonts._();

  /// Titles, numbers, buttons: chunky rounded cartoon letters.
  static const display = 'LilitaOne';

  /// Sentences.
  static const body = 'Nunito';
}

class AppTheme {
  AppTheme._();

  /// Outline made of shadows in eight directions, cartoon-title style.
  static List<Shadow> outline(double size, {Color color = Pal.ink}) {
    final w = (size * 0.07).clamp(1.0, 4.0);
    return [
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)])
        Shadow(color: color, offset: Offset(dx * w, dy * w)),
      Shadow(color: color, offset: Offset(0, w * 2)),
    ];
  }

  /// Display text in design units (scaled here), outlined by default.
  static TextStyle display(double size, {Color color = Pal.cream, bool outlined = true}) {
    final s = size.sp;
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: s,
      color: color,
      height: 1.1,
      letterSpacing: s * 0.02,
      shadows: outlined ? outline(s) : null,
    );
  }

  /// Body text in design units (scaled here).
  static TextStyle body(double size, {Color color = Pal.cream, FontWeight weight = FontWeight.w800}) =>
      TextStyle(fontFamily: AppFonts.body, fontSize: size.sp, color: color, fontWeight: weight, height: 1.25);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Pal.night,
    fontFamily: AppFonts.body,
    colorScheme: const ColorScheme.dark(
      primary: Pal.amber,
      secondary: Pal.leaf,
      surface: Pal.stoneBottom,
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
        (s) => s.contains(WidgetState.selected) ? Pal.amberDark : Pal.stoneBottom,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Pal.ink),
    ),
  );
}
