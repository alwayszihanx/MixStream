import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/settings_repository.dart';
import '../../core/services/launcher_icon_service.dart';

/// Currently selected app logo ('logo1' = default, 'logo2' = alternate).
/// Persisted via [SettingsRepository.saveAppLogoChoice] and applied to the OS
/// launcher icon via [LauncherIconService].
class AppLogoNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.watch(settingsRepositoryProvider).getAppLogoChoice();
  }

  void setChoice(String choice) {
    ref.read(settingsRepositoryProvider).saveAppLogoChoice(choice);
    state = choice;
    LauncherIconService.instance.applyChoice(choice);
  }
}

final appLogoProvider =
    NotifierProvider<AppLogoNotifier, String>(AppLogoNotifier.new);
