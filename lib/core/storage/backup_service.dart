import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

/// Current on-disk backup schema. Bump when the layout changes in a way that
/// older builds cannot read.
const int kBackupSchemaVersion = 1;

const String _kManifestEntry = 'manifest.json';
const String _kPrefsEntry = 'shared_preferences.json';
const String _kHivePrefix = 'hive/';
const String _kFilesPrefix = 'files/';

final backupServiceProvider = Provider<BackupService>((ref) {
  ref.watch(storageServiceProvider);
  return BackupService();
});

/// Summary of what a backup contains, surfaced to the UI.
class BackupSummary {
  const BackupSummary({
    required this.prefCount,
    required this.boxCounts,
    required this.fileCount,
    required this.byteCount,
  });

  final int prefCount;
  final Map<String, int> boxCounts;
  final int fileCount;
  final int byteCount;

  bool get isEmpty =>
      prefCount == 0 &&
      fileCount == 0 &&
      boxCounts.values.every((c) => c == 0);
}

/// Exports and restores the user's data as a single zip archive (`.mixbackup`).
///
/// The archive holds:
///  * `manifest.json`                — schema/app metadata
///  * `shared_preferences.json`      — every SharedPreferences key
///  * `hive/<box>.json`              — every persisted Hive box
///  * `files/<relative path>`        — installed plugins / extension bundles
///
/// Secrets kept in secure storage are intentionally excluded.
class BackupService {
  BackupService();

  static const List<String> _boxes = <String>[
    StorageService.kLibraryBox,
    StorageService.kSettingsBox,
    StorageService.kExtensionsBox,
    StorageService.kHistoryBox,
    StorageService.kDownloadMetadataBox,
  ];

  static const List<String> _fileDirs = <String>['extensions', 'nuvio_plugins'];

  /// Builds the backup archive in memory.
  Future<(Uint8List, BackupSummary)> buildBackup() async {
    final archive = Archive();
    var fileCount = 0;
    var byteCount = 0;

    archive.addFile(
      ArchiveFile.string(
        _kManifestEntry,
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'app': 'MixStream',
          'schema': kBackupSchemaVersion,
          'createdAt': DateTime.now().toIso8601String(),
          'platform': Platform.operatingSystem,
        }),
      ),
    );

    // --- SharedPreferences ---
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      prefsMap[key] = _jsonSafe(prefs.get(key));
    }
    archive.addFile(
      ArchiveFile.string(_kPrefsEntry, jsonEncode(prefsMap)),
    );

    // --- Hive boxes ---
    final boxCounts = <String, int>{};
    for (final name in _boxes) {
      final box = Hive.isBoxOpen(name)
          ? Hive.box<dynamic>(name)
          : await Hive.openBox<dynamic>(name);
      final map = <String, dynamic>{};
      for (var i = 0; i < box.length; i++) {
        final key = box.keyAt(i);
        map[key.toString()] = _jsonSafe(box.get(key));
      }
      boxCounts[name] = map.length;
      archive.addFile(
        ArchiveFile.string('$_kHivePrefix$name.json', jsonEncode(map)),
      );
    }

    // --- Plugin / extension files ---
    final support = await getApplicationSupportDirectory();
    for (final dirName in _fileDirs) {
      final dir = Directory(p.join(support.path, dirName));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        try {
          final bytes = await entity.readAsBytes();
          final rel = p.relative(entity.path, from: support.path);
          final entry = '$_kFilesPrefix${p.split(rel).join('/')}';
          archive.addFile(ArchiveFile(entry, bytes.length, bytes));
          fileCount++;
          byteCount += bytes.length;
        } catch (error) {
          if (kDebugMode) {
            debugPrint('[BackupService] skipped ${entity.path}: $error');
          }
        }
      }
    }

    final encoded = ZipEncoder().encode(archive);
    final bytes = Uint8List.fromList(encoded);
    return (
      bytes,
      BackupSummary(
        prefCount: prefsMap.length,
        boxCounts: boxCounts,
        fileCount: fileCount,
        byteCount: byteCount,
      ),
    );
  }

  /// Writes a backup to a shareable file and returns its path.
  Future<(String, BackupSummary)> writeBackupFile() async {
    final (bytes, summary) = await buildBackup();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final file = File(p.join(dir.path, 'MixStream-backup-$stamp.mixbackup'));
    await file.writeAsBytes(bytes, flush: true);
    return (file.path, summary);
  }

  /// Restores all data from [bytes]. The caller should restart the app
  /// afterwards so providers re-read the restored state.
  Future<BackupSummary> restoreFromBytes(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('That file is not a valid backup archive.');
    }

    final manifest = archive.findFile(_kManifestEntry);
    if (manifest == null) {
      throw const FormatException('That file is not a MixStream backup.');
    }
    final manifestMap =
        jsonDecode(utf8.decode(manifest.content)) as Map<String, dynamic>;
    final schema = manifestMap['schema'] as int?;
    if (schema != null && schema > kBackupSchemaVersion) {
      throw const FormatException(
        'This backup was created by a newer version of MixStream.',
      );
    }

    // --- SharedPreferences ---
    var prefCount = 0;
    final prefsFile = archive.findFile(_kPrefsEntry);
    if (prefsFile != null) {
      final raw = jsonDecode(utf8.decode(prefsFile.content)) as Map;
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.map((e) => '$e').toList());
        }
        prefCount++;
      }
    }

    // --- Hive boxes ---
    final boxCounts = <String, int>{};
    for (final name in _boxes) {
      final box = Hive.isBoxOpen(name)
          ? Hive.box<dynamic>(name)
          : await Hive.openBox<dynamic>(name);
      await box.clear();

      final file = archive.findFile('$_kHivePrefix$name.json');
      if (file == null) {
        boxCounts[name] = 0;
        continue;
      }
      final raw = jsonDecode(utf8.decode(file.content)) as Map;
      final entries = <dynamic, dynamic>{};
      for (final entry in raw.entries) {
        entries[entry.key.toString()] = entry.value;
      }
      await box.putAll(entries);
      boxCounts[name] = entries.length;
    }

    // --- Plugin / extension files ---
    final support = await getApplicationSupportDirectory();
    for (final dirName in _fileDirs) {
      final dir = Directory(p.join(support.path, dirName));
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('[BackupService] could not clear $dirName: $error');
          }
        }
      }
    }

    var fileCount = 0;
    var byteCount = 0;
    for (final file in archive) {
      if (!file.isFile || !file.name.startsWith(_kFilesPrefix)) continue;
      final rel = file.name.substring(_kFilesPrefix.length);
      if (rel.isEmpty || rel.contains('..')) continue;
      final out = File(p.joinAll([support.path, ...p.split(rel)]));
      await out.parent.create(recursive: true);
      final data = file.content;
      await out.writeAsBytes(data, flush: true);
      fileCount++;
      byteCount += data.length;
    }

    return BackupSummary(
      prefCount: prefCount,
      boxCounts: boxCounts,
      fileCount: fileCount,
      byteCount: byteCount,
    );
  }

  /// Recursively converts Hive values into something [jsonEncode] accepts.
  static dynamic _jsonSafe(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _jsonSafe(v)));
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList();
    }
    if (value is Uint8List) {
      return base64Encode(value);
    }
    return value.toString();
  }
}
