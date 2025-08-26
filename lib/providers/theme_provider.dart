import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/theme_model.dart' as theme_model;
import '../services/storage_service.dart';

class ThemeNotifier extends StateNotifier<theme_model.ThemeMode> {
  ThemeNotifier() : super(theme_model.ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final settings = StorageService.getThemeSettings();
    if (settings != null) {
      state = settings.themeMode;
    }
  }

  Future<void> setTheme(theme_model.ThemeMode themeMode) async {
    state = themeMode;
    final settings = theme_model.ThemeSettings(themeMode: themeMode);
    await StorageService.saveThemeSettings(settings);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, theme_model.ThemeMode>(
  (ref) => ThemeNotifier(),
);

final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeProvider);
  switch (themeMode) {
    case theme_model.ThemeMode.light:
      return false;
    case theme_model.ThemeMode.dark:
      return true;
    case theme_model.ThemeMode.system:
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }
});