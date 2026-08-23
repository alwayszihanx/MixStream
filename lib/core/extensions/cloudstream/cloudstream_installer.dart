import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/extension_plugin.dart';

/// Cross-platform installer for CloudStream `.cs3` plugins.
///
/// A `.cs3` is a ZIP containing `plugin.json` (CloudStream manifest) and
/// `plugin.js` (the provider script). Unlike MixStream's own `.mix` format,
/// the CloudStream manifest uses `id` (not `packageName`) and a dotted
/// `version` string (e.g. "1.2.3"). We adapt it to [ExtensionPlugin] and
/// extract the script to `extensions/cloudstream/<id>/plugin.js` so it never
/// touches the existing `.mix` provider storage.
///
/// Everything here is pure Dart (no native/Android dependencies), so the same
/// code path runs on Android, iOS, Linux, macOS and Windows.

class CloudStreamInstallException implements Exception {
  final String message;
  const CloudStreamInstallException(this.message);
  @override
  String toString() => 'CloudStreamInstallException: $message';
}

/// Root directory for unpacked CloudStream plugins.
Future<Directory> get cloudStreamRoot async {
  final appDocDir = await getApplicationSupportDirectory();
  final dir = Directory(p.join(appDocDir.path, 'extensions', 'cloudstream'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Unpacks a `.cs3` (ZIP) byte blob and returns the adapted [ExtensionPlugin].
///
/// [repoId] is the origin repo label persisted for grouping in the UI.
/// [idOverride] keeps the on-disk plugin id stable with the id advertised by
/// the repository listing (which may derive the id differently than the
/// package manifest).
Future<ExtensionPlugin> installCloudStreamPlugin(
  Uint8List bytes, {
  String repoId = 'cloudstream',
  String? idOverride,
}) async {
  final archive = ZipDecoder().decodeBytes(bytes);

  final jsonFile =
      archive.findFile('plugin.json') ?? archive.findFile('manifest.json');
  if (jsonFile == null) {
    throw const CloudStreamInstallException(
      'Missing plugin.json/manifest.json (not a valid .cs3)',
    );
  }

  final manifest =
      jsonDecode(utf8.decode(jsonFile.content as List<int>))
          as Map<String, dynamic>;

  final id = idOverride ??
      (manifest['id'] ?? manifest['packageName']) as String?;
  if (id == null || id.isEmpty) {
    throw const CloudStreamInstallException('Manifest missing plugin "id"');
  }

  final root = await cloudStreamRoot;
  final target = Directory(p.join(root.path, id));
  if (await target.exists()) {
    await target.delete(recursive: true);
  }
  await target.create(recursive: true);

  for (final entity in archive) {
    if (!entity.isFile) continue;
    final name = entity.name;
    // Block zip-slip escapes.
    if (name.contains('..')) continue;
    final out = File(p.join(target.path, name));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(entity.content as List<int>);
  }

  // Persist an adapted manifest for later reloads (mirrors MixStream's meta.json).
  // Stamp the (possibly overridden) id so reloads reproduce the same packageName.
  final meta = Map<String, dynamic>.from(manifest);
  meta['repositoryId'] = repoId;
  meta['id'] = id;
  await File(p.join(target.path, 'meta.json'))
      .writeAsString(jsonEncode(meta));

  // Keep the original bytes so the native engine can re-load the plugin on the
  // next app start (Android-only bridge) without re-downloading.
  await File(p.join(target.path, 'plugin.cs3')).writeAsBytes(bytes);

  return _pluginFromManifest(manifest, repoId: repoId, idOverride: idOverride);
}

/// Reads every unpacked CloudStream plugin from disk.
Future<List<ExtensionPlugin>> loadInstalledCloudStreamPlugins() async {
  final root = await cloudStreamRoot;
  if (!await root.exists()) return const [];

  final out = <ExtensionPlugin>[];
  await for (final entity in root.list()) {
    if (entity is! Directory) continue;
    final metaFile = File(p.join(entity.path, 'meta.json'));
    if (!await metaFile.exists()) continue;
    try {
      final meta = jsonDecode(await metaFile.readAsString())
          as Map<String, dynamic>;
      out.add(_pluginFromManifest(meta, repoId: 'cloudstream'));
    } catch (_) {
      // Skip corrupt entries rather than breaking the whole list.
    }
  }
  return out;
}

/// Deletes an installed CloudStream plugin by its id.
Future<void> uninstallCloudStreamPlugin(String id) async {
  final root = await cloudStreamRoot;
  final target = Directory(p.join(root.path, id));
  if (await target.exists()) {
    await target.delete(recursive: true);
  }
}

/// Absolute path to an installed plugin's `plugin.js`.
Future<String> cloudStreamPluginJsPath(String id) async {
  final root = await cloudStreamRoot;
  return p.join(root.path, id, 'plugin.js');
}

/// Returns the original `.cs3` bytes for every installed CloudStream plugin,
/// keyed by its on-disk id. Used by the Android native bridge to re-load
/// plugins into the CloudStream engine on startup.
Future<Map<String, Uint8List>> loadInstalledCloudStreamPluginBytes() async {
  final root = await cloudStreamRoot;
  if (!await root.exists()) return const {};
  final out = <String, Uint8List>{};
  await for (final entity in root.list()) {
    if (entity is! Directory) continue;
    final file = File(p.join(entity.path, 'plugin.cs3'));
    if (await file.exists()) {
      out[p.basename(entity.path)] = await file.readAsBytes();
    }
  }
  return out;
}

/// Adapts a CloudStream manifest map into MixStream's [ExtensionPlugin].
ExtensionPlugin _pluginFromManifest(
  Map<String, dynamic> manifest, {
  required String repoId,
  String? idOverride,
}) {
  final id = idOverride ??
      ((manifest['id'] ?? manifest['packageName']) as String?) ??
      '';
  final rawVersion = manifest['version'];
  final version = rawVersion is int
      ? rawVersion
      : int.tryParse(
            ((rawVersion as String?) ?? '1').replaceAll(
              RegExp(r'[^0-9]'),
              '',
            ),
          ) ??
          1;

  List<String> readList(List<String> keys) {
    for (final key in keys) {
      final value = manifest[key];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value];
      }
    }
    return const [];
  }

  return ExtensionPlugin(
    packageName: id,
    name: (manifest['name'] as String?) ?? id,
    repositoryId: repoId,
    sourceUrl: '',
    version: version,
    iconUrl: manifest['iconUrl'] as String?,
    authors: readList(['authors', 'author']),
    description: manifest['description'] as String?,
    categories: readList(['tvTypes', 'categories', 'types']),
    languages: readList(['language', 'languages', 'lang']),
    manifest: manifest,
    isCloudStream: true,
  );
}
