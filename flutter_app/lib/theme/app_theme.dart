import 'package:flutter/material.dart';

/// DeepSeek 品牌蓝
const Color kDeepSeekBlue = Color(0xFF4D6BFE);

/// 与原生 colors_m3.xml 完全一致的语义色板
class AppColors {
  static const light = {
    'primary': Color(0xFF4D6BFE),
    'onPrimary': Color(0xFFFFFFFF),
    'primaryContainer': Color(0xFFDCE4FF),
    'onPrimaryContainer': Color(0xFF0A1F5C),
    'secondary': Color(0xFF5A5F6B),
    'onSecondary': Color(0xFFFFFFFF),
    'background': Color(0xFFF7F8FA),
    'onBackground': Color(0xFF171A1F),
    'surface': Color(0xFFFFFFFF),
    'surfaceContainer': Color(0xFFF1F3F7),
    'surfaceContainerHigh': Color(0xFFE9ECF2),
    'onSurface': Color(0xFF171A1F),
    'onSurfaceVariant': Color(0xFF5B6270),
    'outline': Color(0xFFC6CBD4),
    'outlineVariant': Color(0xFFE1E4EA),
    'error': Color(0xFFBA1A1A),
  };

  static const dark = {
    'primary': Color(0xFF8FA6FF),
    'onPrimary': Color(0xFF0A1F5C),
    'primaryContainer': Color(0xFF1F2B66),
    'onPrimaryContainer': Color(0xFFDDE2FF),
    'secondary': Color(0xFFBEC4D0),
    'onSecondary': Color(0xFF1A1F2B),
    'background': Color(0xFF0F1115),
    'onBackground': Color(0xFFE6E8EC),
    'surface': Color(0xFF161920),
    'surfaceContainer': Color(0xFF1E222B),
    'surfaceContainerHigh': Color(0xFF262B36),
    'onSurface': Color(0xFFE6E8EC),
    'onSurfaceVariant': Color(0xFFA6ADBB),
    'outline': Color(0xFF3A404C),
    'outlineVariant': Color(0xFF2A2F39),
    'error': Color(0xFFFFB4AB),
  };
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, Map<String, Color> c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c['primary']!,
      onPrimary: c['onPrimary']!,
      primaryContainer: c['primaryContainer']!,
      onPrimaryContainer: c['onPrimaryContainer']!,
      secondary: c['secondary']!,
      onSecondary: c['onSecondary']!,
      error: c['error']!,
      onError: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF690005),
      surface: c['surface']!,
      onSurface: c['onSurface']!,
      onSurfaceVariant: c['onSurfaceVariant']!,
      outline: c['outline']!,
      outlineVariant: c['outlineVariant']!,
      surfaceContainerHighest: c['surfaceContainerHigh']!,
      surfaceContainerHigh: c['surfaceContainerHigh']!,
      surfaceContainer: c['surfaceContainer']!,
      surfaceContainerLow: c['surfaceContainer']!,
      inverseSurface: c['onSurface']!,
      onInverseSurface: c['surface']!,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c['surface']!,
      canvasColor: c['surface']!,
      appBarTheme: AppBarTheme(
        backgroundColor: c['surface']!,
        foregroundColor: c['onSurface']!,
        elevation: 0,
        centerTitle: false,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: c['outlineVariant']!),
        backgroundColor: c['surface']!,
        selectedColor: c['primaryContainer']!,
        labelStyle: TextStyle(fontSize: 12, color: c['onSurface']!),
      ),
      dividerTheme: DividerThemeData(color: c['outlineVariant']!),
    );
  }
}
