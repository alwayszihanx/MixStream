import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/backup_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../shared/widgets/app_icon.dart';
import 'widgets/settings_widgets.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;
  String? _status;
  bool _failed = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Preparing backup…';
      _failed = false;
    });

    try {
      final (path, summary) =
          await ref.read(backupServiceProvider).writeBackupFile();
      if (!mounted) return;
      setState(() {
        _status = 'Backup ready · ${_describe(summary)}';
      });
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              path,
              mimeType: 'application/zip',
              name: path.split(Platform.pathSeparator).last,
            ),
          ],
          subject: 'MixStream backup',
          text: 'MixStream backup · ${_describe(summary)}',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = 'Export failed: $error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _status = null;
    });

    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final picked = result.files.single;
      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) {
        throw const FormatException('Could not read the selected file.');
      }

      if (!mounted) return;
      final confirmed = await _confirmRestore();
      if (confirmed != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final summary =
          await ref.read(backupServiceProvider).restoreFromBytes(bytes);
      if (!mounted) return;
      setState(() {
        _status = 'Restored · ${_describe(summary)}';
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          surfaceTintColor: Colors.transparent,
          title: const Text('Restore complete'),
          content: const Text(
            'MixStream needs to restart to load the restored data.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop<void>(dialogContext),
              child: const Text('Restart now'),
            ),
          ],
        ),
      );
      if (mounted) await AppUtils.restartApp(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = 'Import failed: $error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Text('Restore from backup?'),
        content: const Text(
          'This replaces your current library, watch history, settings, '
          'add-ons and extensions with the contents of the backup.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  String _describe(BackupSummary summary) {
    final items = summary.boxCounts[StorageService.kLibraryBox] ?? 0;
    final history = summary.boxCounts[StorageService.kHistoryBox] ?? 0;
    final parts = <String>[
      '$items library',
      '$history history',
      '${summary.prefCount} settings',
    ];
    if (summary.fileCount > 0) {
      parts.add('${summary.fileCount} files');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
              vertical: LayoutConstants.spacingLg,
            ),
            children: [
              SettingsGroup(
                title: 'Backup',
                description:
                    'Save your library, watch history, settings, add-ons and '
                    'extensions to a single file you can keep or move to '
                    'another device.',
                children: [
                  SettingsTile(
                    icon: const AppIcon('backup_rounded'),
                    title: 'Export backup',
                    subtitle: 'Create a .mixbackup file and share it',
                    isLast: true,
                    onTap: _busy ? null : () => _export(),
                  ),
                ],
              ),
              const SizedBox(height: LayoutConstants.spacingLg),
              SettingsGroup(
                title: 'Restore',
                description:
                    'Load a previously exported .mixbackup file. This replaces '
                    'all current app data.',
                children: [
                  SettingsTile(
                    icon: const AppIcon('restore_rounded'),
                    title: 'Import backup',
                    subtitle: 'Pick a .mixbackup file to restore',
                    isLast: true,
                    onTap: _busy ? null : () => _import(),
                  ),
                ],
              ),
              const SizedBox(height: LayoutConstants.spacingLg),
              if (_busy || _status != null)
                Container(
                  padding: const EdgeInsets.all(LayoutConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(LayoutConstants.radiusLg),
                  ),
                  child: Row(
                    children: [
                      if (_busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        AppIcon(
                          _failed ? 'error_outline_rounded' : 'check_circle',
                          color: _failed
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          size: 20,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status ?? 'Working…',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
