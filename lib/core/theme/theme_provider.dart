import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../storage/settings_repository.dart';
import '../providers/device_info_provider.dart';
import 'app_theme.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  late SettingsRepository _repository;

  @override
  ThemeMode build() {
    _repository = ref.watch(settingsRepositoryProvider);
    final saved = _repository.getThemeMode();
    if (saved == null) {
      final profileAsync = ref.watch(deviceProfileProvider);
      final profile = profileAsync.asData?.value;
      if (profile == null) {
        return ThemeMode.dark;
      }
      if (profile.isTv) {
        return ThemeMode.dark;
      }
      return ThemeMode.system;
    }
    return _getThemeMode(saved);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _repository.saveThemeMode(mode.name);
  }

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

@Riverpod(keepAlive: true)
class AppThemeConfig extends _$AppThemeConfig {
  late SettingsRepository _repository;

  @override
  int build() {
    _repository = ref.watch(settingsRepositoryProvider);
    final saved = _repository.getThemeConfig();
    if (saved >= 0 && saved < allThemes.length) return saved;
    return 0;
  }

  Future<void> setThemeConfig(int index) async {
    state = index;
    await _repository.saveThemeConfig(index);
  }

  ThemeConfig get currentConfig => allThemes[state];
}
