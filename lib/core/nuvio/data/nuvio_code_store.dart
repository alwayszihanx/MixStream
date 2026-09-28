import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk cache for Nuvio scraper code.
///
/// The All-in-One repository alone is 3.3 MB of JavaScript across 61 files,
/// with one 1 MB bundle. SharedPreferences keeps everything in a single XML
/// document that is parsed into memory at startup and rewritten on every
/// change, so caching plugin code there makes launch slower the more plugins
/// the user installs. Nuvio keeps the code in files (`PluginScraperCodeFileStore`)
/// and so do we — one file per scraper *version*, which also means a stale
/// version can never be executed after an update.
class NuvioCodeStore {
  NuvioCodeStore({Directory? root}) : _root = root;

  Directory? _root;
  Future<Directory>? _pending;

  /// Small in-memory cache so a playback session doesn't re-read from disk.
  /// Bounded, because these strings are large.
  static const int _maxMemoryEntries = 8;
  final Map<String, String> _memory = <String, String>{};

  Future<Directory> _directory() async {
    final existing = _root;
    if (existing != null) return existing;
    return _pending ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'nuvio_plugins'));
      if (!await dir.exists()) await dir.create(recursive: true);
      _root = dir;
      return dir;
    }();
  }

  /// One file per repository + scraper + version.
  static String fileNameFor({
    required String manifestUrl,
    required String scraperId,
    required String version,
  }) {
    final repo = sha1
        .convert(utf8.encode(manifestUrl))
        .toString()
        .substring(0, 12);
    // `..` must not survive: these become file names.
    String sanitize(String value) => value
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        // A leading dot would run into the separator and recreate '..'.
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    final safeId = sanitize(scraperId);
    final safeVersion = sanitize(version);
    return '$repo.$safeId@$safeVersion.js';
  }

  String _memoryKey(String manifestUrl, String scraperId, String version) =>
      '$manifestUrl#$scraperId@$version';

  void _remember(String key, String code) {
    _memory[key] = code;
    while (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<String?> read({
    required String manifestUrl,
    required String scraperId,
    required String version,
  }) async {
    final key = _memoryKey(manifestUrl, scraperId, version);
    final cached = _memory[key];
    if (cached != null) return cached;
    try {
      final dir = await _directory();
      final file = File(
        p.join(
          dir.path,
          fileNameFor(
            manifestUrl: manifestUrl,
            scraperId: scraperId,
            version: version,
          ),
        ),
      );
      if (!await file.exists()) return null;
      final code = await file.readAsString();
      // A non-empty file is not necessarily a complete one. `write()` now goes
      // through a temp file and a rename, so a short file should be
      // impossible — but if one appears anyway (a filesystem that reordered
      // the rename, a full disk that truncated the temp before the copy, an
      // older build's non-atomic write), the only visible symptom is a
      // scraper that fails to compile on every launch forever, because the
      // filename is version-keyed and the version will not change. A bundle
      // that cannot even be parsed as text is worthless either way, so treat
      // it as absent and let the caller re-download.
      if (code.trim().isEmpty || !_looksLikeCompleteBundle(code)) {
        if (kDebugMode) {
          debugPrint(
            '[Nuvio] discarding unusable bundle at ${file.path} '
            '(${code.length} chars) so it can be re-downloaded',
          );
        }
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      _remember(key, code);
      return code;
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] code read failed: $error');
      return null;
    }
  }

  /// Whether [code] can plausibly be the whole bundle.
  ///
  /// Deliberately cheap and syntactic rather than a full parse: the check is
  /// meant to catch a truncated write, not to validate JavaScript, and the
  /// engine still compiles the code before running it. A bundle is
  /// brace/bracket/paren balanced, and it ends with either a newline or a
  /// closing brace — a half-written one reliably fails both.
  static bool _looksLikeCompleteBundle(String code) {
    var braces = 0;
    var brackets = 0;
    var parens = 0;
    for (final rune in code.runes) {
      switch (String.fromCharCode(rune)) {
        case '{':
          braces++;
        case '}':
          braces--;
        case '[':
          brackets++;
        case ']':
          brackets--;
        case '(':
          parens++;
        case ')':
          parens--;
      }
      // A negative count means the file starts mid-construct, i.e. it is a
      // fragment. Bail early rather than scanning megabytes pointlessly.
      if (braces < 0 || brackets < 0 || parens < 0) return false;
    }
    if (braces != 0 || brackets != 0 || parens != 0) return false;
    final trimmed = code.trimRight();
    return trimmed.isNotEmpty &&
        (trimmed.endsWith('}') || trimmed.endsWith(';') || trimmed.endsWith('\n'));
  }

  Future<void> write({
    required String manifestUrl,
    required String scraperId,
    required String version,
    required String code,
  }) async {
    _remember(_memoryKey(manifestUrl, scraperId, version), code);
    try {
      final dir = await _directory();
      final file = File(
        p.join(
          dir.path,
          fileNameFor(
            manifestUrl: manifestUrl,
            scraperId: scraperId,
            version: version,
          ),
        ),
      );
      // Write to a temp file and rename. `writeAsString` truncates the
      // destination and streams into it, so a kill — or an OOM under the
      // QuickJS memory limit, which is exactly what a large scraper bundle can
      // cause — leaves a short file sitting under the CURRENT version's name.
      // read() only rejected empty content, so that truncated bundle was
      // served forever: the scraper is permanently dead and the only escape is
      // removing and re-adding the repository. rename() is atomic within a
      // directory, so the target is either the old bundle or the new one.
      final temp = File('${file.path}.tmp');
      try {
        await temp.writeAsString(code, flush: true);
        await temp.rename(file.path);
      } catch (error) {
        try {
          if (await temp.exists()) await temp.delete();
        } catch (_) {}
        rethrow;
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] code write failed: $error');
    }
  }

  /// Forget every cached version of the given scrapers (used when the
  /// developer publishes a new version).
  Future<void> deleteScrapers({
    required String manifestUrl,
    required Set<String> scraperIds,
  }) async {
    if (scraperIds.isEmpty) return;
    _memory.removeWhere((key, _) {
      if (!key.startsWith('$manifestUrl#')) return false;
      final id = key.split('#').last.split('@').first;
      return scraperIds.contains(id);
    });
    await _sweep(manifestUrl, (id, _) => scraperIds.contains(id));
  }

  /// Drop files for scrapers/versions the manifest no longer lists.
  Future<void> prune({
    required String manifestUrl,
    required Set<String> keepIdVersions,
  }) async {
    _memory.removeWhere((key, _) {
      if (!key.startsWith('$manifestUrl#')) return false;
      return !keepIdVersions.contains(key.split('#').last);
    });
    await _sweep(
      manifestUrl,
      (id, version) => !keepIdVersions.contains('$id@$version'),
    );
  }

  Future<void> deleteRepository(String manifestUrl) async {
    _memory.removeWhere((key, _) => key.startsWith('$manifestUrl#'));
    await _sweep(manifestUrl, (_, _) => true);
  }

  Future<void> _sweep(
    String manifestUrl,
    bool Function(String scraperId, String version) shouldDelete,
  ) async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return;
      final prefix =
          '${sha1.convert(utf8.encode(manifestUrl)).toString().substring(0, 12)}.';
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(prefix) || !name.endsWith('.js')) continue;
        final body = name.substring(prefix.length, name.length - 3);
        final at = body.lastIndexOf('@');
        if (at < 0) continue;
        if (shouldDelete(body.substring(0, at), body.substring(at + 1))) {
          await entity.delete();
        }
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[Nuvio] code sweep failed: $error');
    }
  }

  /// Total bytes on disk, for the "storage used" line in the plugins screen.
  Future<int> usedBytes() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
