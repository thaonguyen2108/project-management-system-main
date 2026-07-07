import 'package:flutter/material.dart';
import 'package:todo/core/pref_halper.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> notifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  static Future<void> load() async {
    notifier.value = _modeFromString(PrefHelper.themeMode);
  }

  static Future<void> setMode(ThemeMode mode) async {
    notifier.value = mode;
    await PrefHelper.setThemeMode(_modeToString(mode));
  }

  static String labelOf(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Sáng',
      ThemeMode.dark => 'Tối',
      ThemeMode.system => 'Theo hệ thống',
    };
  }

  static ThemeMode _modeFromString(String value) {
    return switch (value.trim().toLowerCase()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _modeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
