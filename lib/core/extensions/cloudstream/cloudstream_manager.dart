import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../base_provider.dart';
import '../extension_manager.dart';
import '../models/extension_plugin.dart';
import 'cloudstream_executor.dart';
import 'cloudstream_installer.dart';
import 'cloudstream_provider.dart';

/// Owns the set of installed CloudStream providers and their lifecycle.
///
/// On Android it drives the native CloudStream engine ([CloudStreamBridge]
/// via [CloudStreamNativeExecutor]) so real `.cs3` (DEX) plugins — e.g. CSX
/// providers — work. On every other platform it falls back to the cross-platform
/// QuickJS executor ([CloudStreamJsExecutor]).
///
/// Implemented as a Riverpod 3 [Notifier].
class CloudStreamManager extends Notifier<List<CloudStreamProvider>> {
  late final CloudStreamExecutor _executor;

  /// sourceIds the user toggled off.
  final Set<String> _disabled = {};

  /// True when the native (Android) bridge is active.
  bool get isNative => _executor is CloudStreamNativeExecutor;

  CloudStreamNativeExecutor? get _native =>
      _executor is CloudStreamNativeExecutor ? _executor : null;

  @override
  List<CloudStreamProvider> build() {
    _executor = Platform.isAndroid
        ? CloudStreamNativeExecutor()
        : CloudStreamJsExecutor();
    _loadInstalled();
    return const [];
  }

  /// All installed CloudStream providers (enabled + disabled).
  List<CloudStreamProvider> get all => state;

  /// Only the enabled providers — for source pickers / home.
  List<CloudStreamProvider> get enabled =>
      state.where((p) => isEnabled(p.packageName)).toList();

  bool isEnabled(String sourceId) => !_disabled.contains(sourceId);

  Future<void> setEnabled(String sourceId, bool value) async {
    if (value) {
      _disabled.remove(sourceId);
    } else {
      _disabled.add(sourceId);
    }
    state = [...state];
  }

  Future<void> _loadInstalled() async {
    if (isNative) {
      await _refreshNative();
      return;
    }
    final plugins = await loadInstalledCloudStreamPlugins();
    final providers = <CloudStreamProvider>[];
    for (final plugin in plugins) {
      await _registerScript(plugin.packageName);
      providers.add(CloudStreamProvider(plugin, _executor));
    }
    state = providers;
  }

  /// Reloads every installed `.cs3` into the native engine and rebuilds the
  /// provider list from what the engine currently exposes.
  Future<void> _refreshNative() async {
    final native = _native;
    if (native == null) return;
    final bytesMap = await loadInstalledCloudStreamPluginBytes();
    for (final entry in bytesMap.entries) {
      try {
        await native.loadPlugin(entry.key, entry.value);
      } catch (_) {
        // A broken plugin must not break the whole load.
      }
    }
    state = await _nativeProviders();
  }

  Future<List<CloudStreamProvider>> _nativeProviders() async {
    final native = _native;
    if (native == null) return const [];
    final list = await native.listProviders();
    final seen = <String>{};
    final providers = <CloudStreamProvider>[];
    for (final m in list) {
      final plugin = _pluginFromNative(m, seen);
      providers.add(CloudStreamProvider(plugin, native));
    }
    return providers;
  }

  ExtensionPlugin _pluginFromNative(Map<String, dynamic> m, Set<String> seen) {
    final name = (m['name'] as String?) ?? '';
    // Key providers by the plugin id (sourcePlugin) so install/uninstall line up
    // with the id we handed the native engine.
    var packageName = (m['sourcePlugin'] as String?) ?? name;
    while (!seen.add(packageName)) {
      packageName = '$packageName#${seen.length}';
    }
    final lang = m['lang'];
    return ExtensionPlugin(
      packageName: packageName,
      name: name,
      repositoryId: 'cloudstream',
      sourceUrl: (m['mainUrl'] as String?) ?? '',
      version: 1,
      iconUrl: null,
      authors: const [],
      description: null,
      categories: const [],
      languages: lang is String && lang.isNotEmpty ? [lang] : const [],
      manifest: {
        'name': name,
        'mainUrl': m['mainUrl'] ?? '',
        'hasMainPage': m['hasMainPage'] ?? false,
      },
      isCloudStream: true,
    );
  }

  /// Reads a plugin's `plugin.js` and registers it with the JS executor.
  Future<void> _registerScript(String id) async {
    try {
      final path = await cloudStreamPluginJsPath(id);
      final code = await File(path).readAsString();
      (_executor as CloudStreamJsExecutor).register(id, code);
    } catch (_) {
      // Missing script — provider will degrade to empty results.
    }
  }

  /// Installs a `.cs3` from raw bytes and registers its provider(s).
  Future<ExtensionPlugin> installPlugin(
    List<int> bytes, {
    String repoId = 'cloudstream',
    String? idOverride,
  }) async {
    final plugin = await installCloudStreamPlugin(
      Uint8List.fromList(bytes),
      repoId: repoId,
      idOverride: idOverride,
    );

    if (isNative) {
      final native = _native!;
      await native.loadPlugin(plugin.packageName, bytes);
      state = await _nativeProviders();
      final match = state.where((p) => p.packageName == plugin.packageName).firstOrNull;
      return match?.plugin ?? plugin;
    }

    await _registerScript(plugin.packageName);
    state = [...state, CloudStreamProvider(plugin, _executor)];
    return plugin;
  }

  /// Removes an installed CloudStream plugin by id.
  Future<void> uninstallPlugin(String id) async {
    await uninstallCloudStreamPlugin(id);
    if (isNative) {
      await _native?.unloadPlugin(id);
      _disabled.remove(id);
      state = await _nativeProviders();
      return;
    }
    (_executor as CloudStreamJsExecutor).unregister(id);
    _disabled.remove(id);
    state = state.where((p) => p.packageName != id).toList();
  }

  CloudStreamProvider? get(String sourceId) =>
      state.where((p) => p.packageName == sourceId).firstOrNull;
}

/// Owns the installed CloudStream providers (keep-alive so the list survives
/// across the app).
final cloudStreamManagerProvider =
    NotifierProvider<CloudStreamManager, List<CloudStreamProvider>>(
  CloudStreamManager.new,
);

/// Combined provider list: MixStream's own `.mix` providers PLUS the installed
/// CloudStream providers. Because [CloudStreamManager] starts empty, this list
/// is identical to the legacy [extensionManagerProvider] until CloudStream
/// plugins are installed — so existing providers keep working unchanged.
final allProvidersProvider = Provider<List<MixStreamProvider>>((ref) {
  final ext = ref.watch(extensionManagerProvider);
  final cs = ref.watch(cloudStreamManagerProvider);
  return [...ext, ...cs];
});
