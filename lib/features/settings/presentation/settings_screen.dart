import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/nav_style_provider.dart';
import '../../../shared/widgets/app_icon.dart';

import 'widgets/settings_widgets.dart';
import 'widgets/settings_dialogs.dart';
import 'player_settings_provider.dart';
import 'general_settings_provider.dart';

import 'package:mixstream/l10n/generated/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/network/doh_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/app_logo_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    final isWidescreen = isTv || context.isTabletOrLarger;

    final theme = Theme.of(context);

    if (isWidescreen) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                height: LayoutConstants.dashboardHeaderHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.dashboardContentPadding,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildSettingsList(context, ref, isTv)),
          ],
        ),
      );
    }

    // Mobile layout
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(l10n.settings, style: TextStyle(color: theme.colorScheme.onSurface)),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _buildSettingsList(context, ref, isTv),
    );
  }

  Widget _buildSettingsList(BuildContext context, WidgetRef ref, bool isTv) {
    final themeMode = ref.watch(appThemeModeProvider);
    final generalSettings = ref.watch(generalSettingsProvider);

    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();

    final l10n = AppLocalizations.of(context)!;

    final theme = Theme.of(context);
    final currentNavStyle = ref.watch(appNavStyleProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.only(bottom: LayoutConstants.spacingLg),
          children: [
            const SizedBox(height: LayoutConstants.spacingXs),
            _buildNavStyleSelector(context, ref, currentNavStyle, theme),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.general,
              description: 'Appearance, history, and language',
              children: [
                SettingsTile(
                  icon: const AppIcon('dark_mode_rounded'),
                  title: l10n.appTheme,
                  subtitle: themeMode == ThemeMode.system
                      ? l10n.system
                      : (themeMode == ThemeMode.dark ? l10n.dark : l10n.light),
                  onTap: () => showThemeDialog(context, ref, themeMode),
                ),
                SettingsTile(
                  icon: const AppIcon('palette_rounded'),
                  title: 'Color Theme',
                  subtitle: ref.read(appThemeConfigProvider.notifier).currentConfig.displayName,
                  isLast: true,
                  onTap: () => showThemeConfigDialog(context, ref),
                ),
                SettingsTile(
                  icon: const AppIcon('history_rounded'),
                  title: l10n.recordWatchHistory,
                  subtitle: generalSettings.watchHistoryEnabled
                      ? l10n.enabled
                      : l10n.disabled,
                  trailing: Switch(
                    value: generalSettings.watchHistoryEnabled,
                    onChanged: (val) => ref
                        .read(generalSettingsProvider.notifier)
                        .setWatchHistoryEnabled(val),
                  ),
                  onTap: () => ref
                      .read(generalSettingsProvider.notifier)
                      .setWatchHistoryEnabled(
                        !generalSettings.watchHistoryEnabled,
                      ),
                ),
                SettingsTile(
                  icon: const AppIcon('home_rounded'),
                  title: l10n.defaultHomeScreen,
                  subtitle: getHomeScreenLabel(
                    generalSettings.defaultHomeScreen,
                    l10n,
                  ),
                  onTap: () => showDefaultHomeScreenDialog(
                    context,
                    ref,
                    generalSettings.defaultHomeScreen,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('translate_rounded'),
                  title: l10n.language,
                  subtitle: l10n.languageName,
                  onTap: () => showLanguageDialog(
                    context,
                    ref,
                    ref.read(localeProvider),
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('brandfetch'),
                  title: 'App Icon',
                  subtitle: ref.watch(appLogoProvider) == 'logo2'
                      ? 'Logo 2'
                      : 'Logo 1',
                  isLast: true,
                  onTap: () async {
                    final current = ref.read(appLogoProvider);
                    final choice = await showAppLogoDialog(context, current);
                    if (choice != null && choice != current) {
                      ref.read(appLogoProvider.notifier).setChoice(choice);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.extensions,
              description: 'Install and manage content providers',
              children: [
                SettingsTile(
                  icon: const AppIcon('extension_rounded'),
                  title: l10n.manageExtensions,
                  subtitle: l10n.installRemoveProviders,
                  isLast: true,
                  onTap: () => const ExtensionsRoute().go(context),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.player,
              icon: const AppIcon('play_arrow', size: 20),
              description: 'Playback and quality',
              children: [
                SettingsTile(
                  icon: const AppIcon('quality'),
                  title: 'Quality Filter Mode',
                  subtitle: _qualityFilterModeLabel(
                    playerSettings.qualityFilterMode,
                  ),
                  isLast: true,
                  onTap: () => showQualityFilterModeDialog(
                    context,
                    ref,
                    current: playerSettings.qualityFilterMode,
                    onChanged: ref
                        .read(playerSettingsProvider.notifier)
                        .setQualityFilterMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            Builder(
              builder: (context) {
                final dohState =
                    ref.watch(dohSettingsProvider).asData?.value ??
                    const DohSettings();
                return SettingsGroup(
                  title: l10n.network,
                  description: 'DNS, proxy, and connectivity',
                  children: [
                    SettingsTile(
                      icon: const AppIcon('dns_rounded'),
                      title: l10n.dnsOverHttps,
                      subtitle: dohState.enabled
                          ? '${l10n.on} (${getDohProviderLabel(dohState.provider, dohState.customUrl, l10n)})'
                          : l10n.off,
                      trailing: Switch(
                        value: dohState.enabled,
                        onChanged: (val) {
                          ref
                              .read(dohSettingsProvider.notifier)
                              .setEnabled(val);
                        },
                      ),
                      onTap: () {
                        ref
                            .read(dohSettingsProvider.notifier)
                            .setEnabled(!dohState.enabled);
                      },
                    ),
                    if (dohState.enabled)
                      SettingsTile(
                        icon: const AppIcon('cloud_rounded'),
                        title: l10n.dohProvider,
                        subtitle: getDohProviderLabel(
                          dohState.provider,
                          dohState.customUrl,
                          l10n,
                        ),
                        onTap: () => showDohProviderDialog(context, ref),
                      ),

                    SettingsTile(
                      icon: const AppIcon('github-proxy'),
                      title: l10n.githubProxy,
                      subtitle: l10n.githubProxySubtitle,
                      trailing: Switch(
                        value: generalSettings.githubProxyEnabled,
                        onChanged: (val) {
                          ref
                              .read(generalSettingsProvider.notifier)
                              .setGithubProxyEnabled(val);
                        },
                      ),
                      onTap: () {
                        ref
                            .read(generalSettingsProvider.notifier)
                            .setGithubProxyEnabled(
                              !generalSettings.githubProxyEnabled,
                            );
                      },
                      isLast: true,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.appData,
              description: 'Reset and clear application data',
              children: [
                SettingsTile(
                  icon: const AppIcon('restore_rounded'),
                  title: l10n.resetDataKeepExtensions,
                  subtitle: l10n.resetDataSubtitle,
                  onTap: () => showResetDataDialog(context, ref),
                ),
                SettingsTile(
                  icon: const AppIcon('delete_forever_rounded'),
                  title: l10n.factoryReset,
                  subtitle: l10n.factoryResetSubtitle,
                  isLast: true,
                  onTap: () => showFactoryResetDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: l10n.about,
              description: 'App version and credits',
              children: [
                SettingsTile(
                  icon: const AppIcon('developer'),
                  title: l10n.about,
                  subtitle: l10n.developer,
                  isLast: true,
                  onTap: () => const AboutRoute().go(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Center(
                  child: Text(
                    info != null
                        ? '${info.appName} v${info.version}+${info.buildNumber}'
                        : 'MixStream',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String _qualityFilterModeLabel(QualityFilterMode mode) {
  switch (mode) {
    case QualityFilterMode.any:
      return 'Show all (sort only)';
    case QualityFilterMode.atOrAbove:
      return 'Hide sources below preference';
    case QualityFilterMode.atOrBelow:
      return 'Hide sources above preference';
  }
}

Widget _buildNavStyleSelector(
  BuildContext context,
  WidgetRef ref,
  NavStyle currentStyle,
  ThemeData theme,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Navigation Style',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildNavStyleChip(
                context,
                ref,
                label: 'Floating Pill',
                style: NavStyle.floatingPill,
                currentStyle: currentStyle,
                theme: theme,
              ),
              _buildNavStyleChip(
                context,
                ref,
                label: 'Bottom Bar',
                style: NavStyle.bottomBar,
                currentStyle: currentStyle,
                theme: theme,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildNavStyleChip(
  BuildContext context,
  WidgetRef ref, {
  required String label,
  required NavStyle style,
  required NavStyle currentStyle,
  required ThemeData theme,
}) {
  final isSelected = currentStyle == style;

  return Expanded(
    child: GestureDetector(
      onTap: () {
        ref.read(appNavStyleProvider.notifier).setNavStyle(style);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}
