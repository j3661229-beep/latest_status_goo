// lib/core/theme/theme_mode_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';

/// User-selected theme mode (system / light / dark), persisted in settings_box.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  Box get _box => Hive.box(AppConstants.hiveBoxSettings);

  @override
  ThemeMode build() {
    switch (_box.get(AppConstants.keyThemeMode) as String?) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _box.put(AppConstants.keyThemeMode, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
