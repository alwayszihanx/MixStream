import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path_provider/path_provider.dart';

/// Applies the user's chosen app logo as the OS / launcher icon.
///
/// - Linux: rewrites the installed `.desktop` file's `Icon=` to point at the
///   selected logo PNG (extracted from assets into the app support dir).
/// - Android: toggles the `Logo2Alias` activity-alias via flutter_dynamic_icon.
/// - Windows / macOS / iOS: runtime launcher-icon switching isn't supported by
///   the OS, so the choice is persisted but the icon stays at the build default
///   (logo-1).
class LauncherIconService {
  LauncherIconService._();
  static final LauncherIconService instance = LauncherIconService._();

  static const _androidIconChannel =
      MethodChannel('io.alwayszihan.mixstream/launcher_icon');

  Future<void> applyChoice(String choice) async {
    if (Platform.isLinux) {
      await _applyLinux(choice);
    } else if (Platform.isAndroid) {
      await _applyAndroid(choice);
    }
  }

  Future<void> _applyAndroid(String choice) async {
    try {
      await _androidIconChannel.invokeMethod('setAlternateIconName', {
        'iconName': choice == 'logo2' ? 'Logo2Alias' : null,
      });
    } catch (_) {
      // Best-effort; ignore failures (e.g. unsupported device).
    }
  }

  Future<void> _applyLinux(String choice) async {
    try {
      final asset = choice == 'logo2'
          ? 'assets/images/logo-2.png'
          : 'assets/images/logo-1.png';
      final bytes = await rootBundle.load(asset);
      final support = await getApplicationSupportDirectory();
      final iconsDir = Directory('${support.path}/icons');
      await iconsDir.create(recursive: true);
      final pngFile = File('${iconsDir.path}/$choice.png');
      await pngFile.writeAsBytes(bytes.buffer.asUint8List());
      await _updateDesktopFiles(pngFile.path);
    } catch (_) {
      // Best-effort; ignore failures.
    }
  }

  Future<void> _updateDesktopFiles(String iconPath) async {
    final home = Platform.environment['HOME'] ?? '';
    final xdgData =
        Platform.environment['XDG_DATA_HOME'] ?? '$home/.local/share';
    final candidates = <File>[
      File('$xdgData/applications/mixstream.desktop'),
      File('/usr/share/applications/mixstream.desktop'),
    ];
    for (final f in candidates) {
      if (!await f.exists()) continue;
      final content = await f.readAsString();
      final updated = content.split('\n').map((line) {
        return line.trim().startsWith('Icon=') ? 'Icon=$iconPath' : line;
      }).join('\n');
      await f.writeAsString(updated);
    }
    await Process.run(
      'update-desktop-database',
      [xdgData],
    ).catchError((_) => ProcessResult(0, 0, '', ''));
    await Process.run(
      'gtk-update-icon-cache',
      ['-f', '-t', '$home/.local/share/icons/hicolor'],
    ).catchError((_) => ProcessResult(0, 0, '', ''));
  }
}
