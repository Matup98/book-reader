import 'package:flutter/material.dart';

/// Persisted user preference for the app color scheme. Kept as a dedicated
/// enum (instead of persisting [ThemeMode] directly) so the wire format
/// matches the rest of the app's preferences.
enum ThemeModePreference {
  system,
  light,
  dark;

  String get wireValue => name;

  ThemeMode toThemeMode() {
    switch (this) {
      case ThemeModePreference.system:
        return ThemeMode.system;
      case ThemeModePreference.light:
        return ThemeMode.light;
      case ThemeModePreference.dark:
        return ThemeMode.dark;
    }
  }

  static ThemeModePreference fromWireValue(String? value) {
    for (final pref in ThemeModePreference.values) {
      if (pref.wireValue == value) return pref;
    }
    return ThemeModePreference.system;
  }
}
