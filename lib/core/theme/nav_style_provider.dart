import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../storage/settings_repository.dart';

part 'nav_style_provider.g.dart';

enum NavStyle { floatingPill, bottomBar }

@Riverpod(keepAlive: true)
class AppNavStyle extends _$AppNavStyle {
  late SettingsRepository _repository;

  @override
  NavStyle build() {
    _repository = ref.watch(settingsRepositoryProvider);
    final saved = _repository.getNavStyle();
    if (saved == null) return NavStyle.floatingPill;
    return NavStyle.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => NavStyle.floatingPill,
    );
  }

  Future<void> setNavStyle(NavStyle style) async {
    state = style;
    await _repository.saveNavStyle(style.name);
  }
}
