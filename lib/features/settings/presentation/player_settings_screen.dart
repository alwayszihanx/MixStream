import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixstream/core/utils/layout_constants.dart';
import 'package:mixstream/core/utils/responsive_breakpoints.dart';
import 'package:mixstream/l10n/generated/app_localizations.dart';
import 'package:mixstream/shared/widgets/app_icon.dart';
import 'package:mixstream/shared/widgets/custom_widgets.dart';

import '../../../core/providers/device_info_provider.dart';
import 'player_settings_provider.dart';
import 'widgets/settings_dialogs.dart';
import 'widgets/settings_widgets.dart';

/// Sub-screen for configuring video playback, gestures, display, and quality.
class PlayerSettingsScreen extends ConsumerWidget {
  final bool isEmbedded;

  const PlayerSettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    final isWidescreen = isTv || context.isTabletOrLarger;
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    final content = _buildSettingsList(context, ref, isTv);

    if (isWidescreen) {
      return Scaffold(
        backgroundColor: bg,
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
                  'Player Perfect',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Player Settings',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: content,
    );
  }

  Widget _buildSettingsList(BuildContext context, WidgetRef ref, bool isTv) {
    final l10n = AppLocalizations.of(context)!;
    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    final notifier = ref.read(playerSettingsProvider.notifier);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.only(bottom: LayoutConstants.spacingLg),
          children: [
            const SizedBox(height: LayoutConstants.spacingXs),
            SettingsGroup(
              title: l10n.player,
              description: 'Player, codec, and buffering',
              children: [
                SettingsTile(
                  icon: const AppIcon('play_arrow', size: 20),
                  title: l10n.defaultPlayer,
                  subtitle: _defaultPlayerLabel(playerSettings.preferredPlayer, l10n),
                  onTap: () => showDefaultPlayerDialog(
                    context,
                    ref,
                    playerSettings.preferredPlayer,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('aspect_ratio', size: 20),
                  title: l10n.defaultResizeMode,
                  subtitle: _resizeModeLabel(playerSettings.defaultResizeMode),
                  onTap: () =>
                      showResizeDialog(context, ref, playerSettings.defaultResizeMode),
                ),
                SettingsTile(
                  icon: const AppIcon('memory', size: 20),
                  title: l10n.hardwareDecoding,
                  subtitle: playerSettings.hardwareDecoding ? l10n.enabled : l10n.disabled,
                  trailing: CustomSwitch(
                    value: playerSettings.hardwareDecoding,
                    onChanged: notifier.setHardwareDecoding,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('buffer', size: 20),
                  title: 'Readahead',
                  subtitle: '${playerSettings.readaheadSeconds}s',
                  isLast: true,
                  onTap: () =>
                      showReadaheadDialog(context, ref, playerSettings.readaheadSeconds),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: 'Gestures & Controls',
              description: 'Mobile gestures and seeking behavior',
              children: [
                SettingsTile(
                  icon: const AppIcon('gesture', size: 20),
                  title: l10n.leftGesture,
                  subtitle: getGestureLabel(playerSettings.leftGesture, l10n),
                  onTap: () => showGestureDialog(
                    context,
                    ref,
                    true,
                    playerSettings.leftGesture,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('gesture', size: 20),
                  title: l10n.rightGesture,
                  subtitle: getGestureLabel(playerSettings.rightGesture, l10n),
                  onTap: () => showGestureDialog(
                    context,
                    ref,
                    false,
                    playerSettings.rightGesture,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('touch_app', size: 20),
                  title: l10n.doubleTapToSeek,
                  subtitle: playerSettings.doubleTapEnabled
                      ? l10n.enabled
                      : l10n.disabled,
                  trailing: CustomSwitch(
                    value: playerSettings.doubleTapEnabled,
                    onChanged: notifier.setDoubleTapEnabled,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('swipe', size: 20),
                  title: l10n.swipeToSeek,
                  subtitle: playerSettings.swipeSeekEnabled
                      ? l10n.enabled
                      : l10n.disabled,
                  trailing: CustomSwitch(
                    value: playerSettings.swipeSeekEnabled,
                    onChanged: notifier.setSwipeSeekEnabled,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('fast_forward', size: 20),
                  title: l10n.seekDuration,
                  subtitle: '${playerSettings.seekDuration}s',
                  isLast: true,
                  onTap: () =>
                      showDurationDialog(context, ref, playerSettings.seekDuration),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: 'Quality',
              description: 'Stream quality and filtering',
              children: [
                SettingsTile(
                  icon: const AppIcon('wifi', size: 20),
                  title: l10n.wifiQualityPreference,
                  subtitle: _qualityLabel(
                    playerSettings.wifiQuality,
                    l10n,
                  ),
                  onTap: () => showQualityDialog(
                    context,
                    ref,
                    title: l10n.wifiQualityPreference,
                    current: playerSettings.wifiQuality,
                    onChanged: notifier.setWifiQuality,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('signal_cellular_alt', size: 20),
                  title: l10n.mobileQualityPreference,
                  subtitle: _qualityLabel(
                    playerSettings.mobileQuality,
                    l10n,
                  ),
                  onTap: () => showQualityDialog(
                    context,
                    ref,
                    title: l10n.mobileQualityPreference,
                    current: playerSettings.mobileQuality,
                    onChanged: notifier.setMobileQuality,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('quality', size: 20),
                  title: 'Quality Filter Mode',
                  subtitle: _qualityFilterModeLabel(
                    playerSettings.qualityFilterMode,
                    l10n,
                  ),
                  isLast: true,
                  onTap: () => showQualityFilterModeDialog(
                    context,
                    ref,
                    current: playerSettings.qualityFilterMode,
                    onChanged: notifier.setQualityFilterMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: LayoutConstants.spacingLg),
            SettingsGroup(
              title: 'Subtitles',
              description: 'Subtitle size, color, and appearance',
              children: [
                SettingsTile(
                  icon: const AppIcon('subtitles', size: 20),
                  title: 'Subtitle Style',
                  subtitle: _subtitleStyleLabel(playerSettings),
                  onTap: () => showSubtitleDialog(
                    context,
                    ref,
                    playerSettings,
                  ),
                ),
                SettingsTile(
                  icon: const AppIcon('subtitle_offset', size: 20),
                  title: 'Subtitle Position',
                  subtitle: playerSettings.subtitlePosition.toStringAsFixed(0),
                  isLast: true,
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) {
                        var value = playerSettings.subtitlePosition;
                        return StatefulBuilder(
                          builder: (dialogContext2, setDialogState) {
                            return AlertDialog(
                              surfaceTintColor: Colors.transparent,
                              title: const Text('Subtitle Position'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomSlider(
                                    min: 0,
                                    max: 100,
                                    value: value,
                                    onChanged: (v) {
                                      setDialogState(() => value = v);
                                    },
                                  ),
                                  Text(value.toStringAsFixed(0)),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    notifier.setSubtitlePosition(value);
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _defaultPlayerLabel(String? preferredPlayer, AppLocalizations l10n) {
    if (preferredPlayer == null) return 'Internal (media_kit)';
    return preferredPlayer == 'vlc' ? 'External (VLC)' : preferredPlayer;
  }

  String _resizeModeLabel(String mode) {
    switch (mode) {
      case 'contain':
        return 'Fit';
      case 'cover':
        return 'Fill';
      default:
        return mode;
    }
  }

  String _qualityLabel(QualityPreference q, AppLocalizations l10n) {
    switch (q) {
      case QualityPreference.q4k:
        return '4K (2160p)';
      case QualityPreference.q1080:
        return '1080p';
      case QualityPreference.q720:
        return '720p';
      case QualityPreference.q480:
        return '480p';
      case QualityPreference.q360:
        return '360p';
      case QualityPreference.any:
        return l10n.anyNoPreference;
    }
  }

  String _qualityFilterModeLabel(QualityFilterMode mode, AppLocalizations l10n) {
    switch (mode) {
      case QualityFilterMode.atOrBelow:
        return 'Hide above preference';
      case QualityFilterMode.atOrAbove:
        return 'Hide below preference';
      case QualityFilterMode.any:
        return l10n.anyNoPreference;
    }
  }

  String _subtitleStyleLabel(PlayerSettings p) {
    return 'Size ${p.subtitleSize.toStringAsFixed(0)} · Opacity '
        '${(p.subtitleBackgroundOpacity * 100).round()}%';
  }
}