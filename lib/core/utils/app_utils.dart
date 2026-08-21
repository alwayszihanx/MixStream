import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppUtils {
  // Registered by main() before first runApp call.
  static void Function()? _restartImpl;

  static void setRestartFunction(void Function() fn) {
    _restartImpl = fn;
  }

  /// Two-phase restart:
  /// Phase 1 — replace the widget tree with an empty widget so Flutter
  ///            disposes the old ProviderScope, GoRouter GlobalKey, and all
  ///            stream subscriptions in the current frame.
  /// Phase 2 — after one addPostFrameCallback (disposal frame complete),
  ///            call the registered rebuild function to mount a fresh tree.
  static Future<void> restartApp(BuildContext? context) async {
    final fn = _restartImpl;
    if (fn == null) {
      if (kDebugMode) {
        debugPrint("AppUtils.restartApp: no restart function registered");
      }
      return;
    }

    // Phase 1: clear the entire widget tree.
    runApp(const SizedBox.shrink());

    // Phase 2: wait for the disposal frame to complete, then rebuild.
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    await completer.future;

    fn();
  }

  static bool isLocalFile(String path) {
    if (path.isEmpty) return false;
    // Android/Linux/macOS absolute
    if (path.startsWith('/')) return true;
    // Windows absolute (C:\ or D:/)
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path)) return true;
    // File URL
    if (path.startsWith('file:')) return true;
    return false;
  }

  static String normalizeUrl(String url) {
    if (url.isEmpty) return url;
    if (Platform.isAndroid) return url;

    if (isLocalFile(url) && !url.startsWith('file:')) {
      if (url.startsWith('/')) {
        return 'file://$url';
      }
      // Windows absolute path like C:\
      // Standardize on forward slashes for valid file:/// URIs
      final standardizedPath = url.replaceAll('\\', '/');
      return 'file:///$standardizedPath';
    }
    return url;
  }

  /// Converts a long scraped filename/source title into a clean display title.
  ///
  /// Strips season/episode markers, resolution, codec, audio, release group
  /// and quality tokens, then normalizes separators. The original data is
  /// never modified — this only affects what is shown under cards.
  ///
  /// Example: `Agent.Kim.Reactivated.S01E02.1080p.WEB-DL.x264-WEB`
  ///       -> `Agent Kim Reactivated`
  static String cleanDisplayTitle(String raw) {
    var title = raw.trim();
    if (title.isEmpty) return title;

    // Strip file extensions.
    title = title.replaceAll(RegExp(r'\.(mkv|mp4|avi|webm|mov|m4v|ts|flv)$', caseSensitive: false), '');

    // Remove season/episode markers (S01E02, 1x02, Episode 3, E02).
    title = title.replaceAll(
      RegExp(r'(?:\[)?\s*S\d{1,2}\s*E\d{1,3}\s*(?:\])?', caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r'(?:\[)?\s*S\d{1,2}\s*(?:-\s*S\d{1,2})?\s*(?:\])?', caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r'\b\d{1,2}x\d{1,3}\b', caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r'\b(?:Episode|Ep)\s*\d{1,3}\b', caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r'\[?\s*E\d{1,3}\s*\]?', caseSensitive: false),
      ' ',
    );

    // Remove release year when it stands alone.
    title = title.replaceAll(RegExp(r'\b(?:19|20)\d{2}\b'), ' ');

    // Remove resolution tokens.
    title = title.replaceAll(
      RegExp(r'\b(?:2160p|1080p|1080i|720p|480p|4k|uhd|8k)\b', caseSensitive: false),
      ' ',
    );

    // Remove quality / source tokens.
    title = title.replaceAll(
      RegExp(r'\b(?:web[- ]?dl|webrip|bluray|blu-ray|brrip|bdrip|hdtv|hdtvrip|dvdrip|remux|hdr10?|dv|hdr)\b', caseSensitive: false),
      ' ',
    );

    // Remove codec tokens.
    title = title.replaceAll(
      RegExp(r'\b(?:x264|x265|h[. ]?264|h[. ]?265|hevc|avc|av1|aac|mp3|flac)\b', caseSensitive: false),
      ' ',
    );

    // Remove audio channel tokens.
    title = title.replaceAll(
      RegExp(r'\b(?:ddp?5[. ]?1|dts[- ]?hd|dts|atmos|aac2[. ]?0|truehd|eac3|ac3|dd)\b', caseSensitive: false),
      ' ',
    );

    // Remove release-group tags (trailing token after a separator).
    title = title.replaceAll(
      RegExp(r'(?:[-_~]\s*[A-Za-z0-9]{2,6})$'),
      '',
    );
    title = title.replaceAll(
      RegExp(r'(?:\[[A-Za-z0-9 _-]{1,12}\])$'),
      '',
    );

    // Normalize separators to single spaces.
    title = title.replaceAll(RegExp(r'[._\-\[\]()]+'), ' ');

    // Collapse whitespace and clean double spaces from "S E" markers.
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    return title;
  }
}
