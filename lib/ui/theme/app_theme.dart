import 'package:flutter/material.dart';

import '../../core/tuning/tuning_math.dart';

/// 深色舞台主题（调音时弱光也清晰）
class AppTheme {
  static const bg = Color(0xFF0F1115);
  static const card = Color(0xFF171B22);
  static const line = Color(0xFF262C36);
  static const textDim = Color(0xFF9AA3B2);
  static const ok = Color(0xFF22C55E);
  static const warn = Color(0xFFF59E0B);
  static const bad = Color(0xFFEF4444);

  static Color tuneColor(TuneGrade g, bool hasSignal) {
    if (!hasSignal) return textDim;
    return switch (g) {
      TuneGrade.inTune => ok,
      TuneGrade.close => warn,
      TuneGrade.off => bad,
    };
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF59E0B),
      brightness: Brightness.dark,
      surface: card,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      cardTheme: const CardThemeData(
        color: card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
