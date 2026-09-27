// Probe test: drives the REAL JS plugin pipeline (worker isolate + QuickJS +
// HTTP bridge) for an installed default MixStream plugin, then calls
// getDetails() — the exact path the details screen uses. Run manually:
//
//   flutter test test/probe/plugin_details_probe_test.dart --timeout 10m
//
// Requires network access to raw.githubusercontent.com (plugin download).
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mixstream/core/extensions/engine/js_engine.dart';
import 'package:mixstream/core/extensions/providers/js_based_provider.dart';
import 'package:mixstream/core/storage/extension_repository.dart';
import 'package:mixstream/core/storage/storage_service.dart';

/// Minimal in-memory extension storage so the engine has no Hive/path
/// provider dependencies in the test environment.
class FakeExtensionRepository extends ExtensionRepository {
  final Map<String, String?> _data = <String, String?>{};
  FakeExtensionRepository() : super(StorageService());

  @override
  Future<void> setExtensionData(String key, String? value) async {
    _data[key] = value;
  }

  @override
  String? getExtensionData(String key) => _data[key];
}

class DownloadablePlugin {
  final String packageName;
  final String name;
  final String mixUrl;
  final String dir;
  final String jsPath;

  DownloadablePlugin({
    required this.packageName,
    required this.name,
    required this.mixUrl,
    required this.dir,
    required this.jsPath,
  });
}

void _log(String s) => debugPrint('[PROBE] $s');

Future<void> _download(String url, String dest) async {
  final resp = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = resp.data;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('empty download for $url');
  }
  await File(dest).writeAsBytes(bytes, flush: true);
}

Future<DownloadablePlugin> _fetchPlugin(
  String packageName,
  String name,
  String mixUrl,
  String tmpDir,
) async {
  final dir = '$tmpDir/$name';
  await Directory(dir).create(recursive: true);
  final mixPath = '$dir/plugin.mix';
  await _download(mixUrl, mixPath);
  // .mix is a plain zip: plugin.js + plugin.json
  final decoded = await Process.run('unzip', ['-o', '-q', mixPath, '-d', dir]);
  if (decoded.exitCode != 0) {
    throw StateError('unzip failed: ${decoded.stderr}');
  }
  return DownloadablePlugin(
    packageName: packageName,
    name: name,
    mixUrl: mixUrl,
    dir: dir,
    jsPath: '$dir/plugin.js',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test's binding installs a mock HttpOverrides that turns every
  // HTTP call into a 400 response. Real plugins need real networking, so
  // restore the platform HttpClient.
  HttpOverrides.global = null;

  late String tmpDir;
  JsEngineService? engine;
  final results = <String, Map<String, dynamic>>{};

  setUpAll(() async {
    tmpDir = (await Directory.systemTemp.createTemp('probe_plugins')).path;
    final castletv = await _fetchPlugin(
      'io.alwayszihan.mixstream.castletv',
      'castle_tv',
      'https://raw.githubusercontent.com/alwayszihanx/Mixplug/main/plugins/io.alwayszihan.mixstream.castletv.mix',
      tmpDir,
    );
    final anikage = await _fetchPlugin(
      'io.alwayszihan.mixstream.anikage',
      'anikage',
      'https://raw.githubusercontent.com/alwayszihanx/Mixplug/main/plugins/io.alwayszihan.mixstream.anikage.mix',
      tmpDir,
    );
    engine = JsEngineService(FakeExtensionRepository(), Dio());
    final eng = engine!;

    final jobs = <(DownloadablePlugin, Map<String, dynamic>)>[
      (
        castletv,
        const {
          'packageName': 'io.alwayszihan.mixstream.castletv',
          'name': 'Castle TV',
          'version': 9,
          'baseUrl': 'https://example.com',
          'languages': ['en', 'hi'],
          'categories': ['Movies', 'Series'],
        },
      ),
      (
        anikage,
        const {
          'packageName': 'io.alwayszihan.mixstream.anikage',
          'name': 'Anikage',
          'version': 7,
          'baseUrl': 'https://anikage.cc',
          'languages': ['en', 'ja'],
          'categories': ['Anime'],
        },
      ),
    ];

    for (final (plugin, manifest) in jobs) {
      final provider = JsBasedProvider(
        eng,
        plugin.jsPath,
        packageName: plugin.packageName,
        manifest: manifest,
      );
      final entry = <String, dynamic>{'plugin': plugin.name};
      try {
        final home = await provider.getHome();
        _log('==== ${plugin.name}: getHome OK, sections=${home.length}');
        for (final entry2 in home.entries.take(4)) {
          _log(
            '  section "${entry2.key}" -> ${entry2.value.take(3).map((x) => x.title).toList()}',
          );
        }
        entry['homeSections'] = home.length;
        final allItems = home.values.expand((v) => v).toList();
        entry['homeItems'] = allItems.length;
        if (allItems.isEmpty) {
          entry['detailsStatus'] = 'SKIP (no home items)';
          results[plugin.name] = entry;
          continue;
        }

        var detailsOk = 0;
        var detailsErr = 0;
        final sampleErrors = <String>[];
        for (final item in allItems.take(6)) {
          try {
            final details = await provider.getDetails(item.url);
            _log(
              '  getDetails(${item.title}) -> title="${details.title}" '
              'url="${details.url}" eps=${details.episodes?.length ?? 0} '
              'type=${details.contentType}',
            );
            if (details.title.startsWith('Error:')) {
              sampleErrors.add('${item.title}: ${details.title}');
            } else {
              detailsOk++;
            }
          } catch (e) {
            _log('  getDetails(${item.title}) THREW: $e');
            detailsErr++;
            sampleErrors.add('${item.title}: THREW $e');
          }
        }
        entry['detailsOk'] = detailsOk;
        entry['detailsErr'] = detailsErr;
        entry['sampleErrors'] = sampleErrors;
        _log(
          '==== ${plugin.name}: details OK=$detailsOk ERR=$detailsErr '
          'samples=$sampleErrors',
        );
      } catch (e) {
        _log('==== ${plugin.name}: getHome THREW: $e');
        entry['homeError'] = '$e';
      }
      results[plugin.name] = entry;
    }
  });

  test('probe default plugin details', () async {
    // Just surface the collected probe results in the failure message.
    var failed = false;
    final buf = StringBuffer();
    results.forEach((plugin, entry) {
      buf.writeln('$plugin: ${entry.toString()}');
      if (entry['detailsOk'] != null && entry['detailsErr'] != null) {
        final errors = (entry['detailsErr'] as num?) ?? 0;
        final oks = (entry['detailsOk'] as num?) ?? 1;
        if (errors > 0 || oks == 0) failed = true;
      } else if (entry['homeError'] != null || entry['detailsStatus'] != null) {
        failed = true;
      }
    });
    _log(buf.toString());
    expect(failed, isFalse, reason: buf.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));

  tearDownAll(() {
    engine?.dispose();
    try {
      Directory(tmpDir).deleteSync(recursive: true);
    } catch (_) {}
  });
}