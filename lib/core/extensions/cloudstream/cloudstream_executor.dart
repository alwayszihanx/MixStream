import 'dart:convert';

import 'package:flutter/services.dart';

import 'cloudstream_runtime.dart';

/// Abstraction over the backend that actually executes a CloudStream plugin's
/// JS and returns raw Dart maps (the contract CloudStream's native host speaks).
///
/// This is what makes the feature cross-platform: the default implementation
/// runs the plugin inside MixStream's isolated QuickJS runtime with a
/// CloudStream-compatible JS shim, so it works on Android, iOS, desktop and web
/// without any native code. An Android-only native bridge could implement the
/// same interface later if desired.
///
/// All methods return CloudStream's native map shapes:
///   search/getHome items: {name, posterUrl, url, type, ...}
///   detail:               {name, posterUrl, plot, episodes:[...], ...}
///   episode:              {name, data, season, episode, posterUrl, ...}
///   link:                 {url, quality, name, isM3u8, headers, subtitles:[...]}
abstract class CloudStreamExecutor {
  /// Resolve [query] to a list of search-result maps.
  Future<List<Map<String, dynamic>>> search(String query, String sourceId);

  /// Home/main-page rows: a list of {title, items:[...]} maps.
  Future<List<Map<String, dynamic>>> getHome(String sourceId);

  /// Detail page for [url]: a single map with episodes, plot, etc.
  Future<Map<String, dynamic>> getDetail(String url, String sourceId);

  /// Stream links for an episode [episodeUrl].
  Future<List<Map<String, dynamic>>> loadLinks(
    String episodeUrl,
    String sourceId,
  );
}

/// Placeholder executor used until the QuickJS shim is implemented. It returns
/// empty results so the UI degrades gracefully and existing MixStream providers
/// are unaffected.
class CloudStreamStubExecutor implements CloudStreamExecutor {
  const CloudStreamStubExecutor();

  @override
  Future<List<Map<String, dynamic>>> search(
    String query,
    String sourceId,
  ) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getHome(String sourceId) async => const [];

  @override
  Future<Map<String, dynamic>> getDetail(String url, String sourceId) async =>
      const {};

  @override
  Future<List<Map<String, dynamic>>> loadLinks(
    String episodeUrl,
    String sourceId,
  ) async =>
      const [];
}


/// Cross-platform executor that runs a CloudStream `.cs3` plugin inside the
/// isolated [CloudStreamRuntime] (QuickJS) and returns the raw Dart maps that
/// [CloudStreamProvider] maps into MixStream entities.
class CloudStreamJsExecutor implements CloudStreamExecutor {
  CloudStreamJsExecutor() : _rtFuture = CloudStreamRuntime.create();

  final Future<CloudStreamRuntime> _rtFuture;
  final Map<String, String> _scripts = {};
  final Set<String> _loaded = {};

  /// Registers a plugin's `plugin.js` source so it is loaded before first use.
  void register(String sourceId, String code) {
    _scripts[sourceId] = code;
    _loaded.remove(sourceId);
  }

  /// Drops a registered plugin (on uninstall).
  void unregister(String sourceId) {
    _scripts.remove(sourceId);
    _loaded.remove(sourceId);
  }

  Future<CloudStreamRuntime> get _rt => _rtFuture;

  Future<void> _ensureLoaded(String sourceId) async {
    if (_loaded.contains(sourceId)) return;
    final code = _scripts[sourceId];
    if (code == null || code.isEmpty) return;
    final rt = await _rt;
    await rt.load(sourceId, code);
    _loaded.add(sourceId);
  }

  dynamic _decode(String json) {
    if (json == '__dart_void__' || json.isEmpty) return null;
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query, String sourceId) async {
    await _ensureLoaded(sourceId);
    final decoded = _decode(await (await _rt).invoke('search', [query]));
    if (decoded is List) {
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getHome(String sourceId) async {
    await _ensureLoaded(sourceId);
    final decoded = _decode(await (await _rt).invoke('home', []));
    if (decoded is List) {
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getDetail(String url, String sourceId) async {
    await _ensureLoaded(sourceId);
    final decoded = _decode(await (await _rt).invoke('load', [url]));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return const {};
  }

  @override
  Future<List<Map<String, dynamic>>> loadLinks(
    String episodeUrl,
    String sourceId,
  ) async {
    await _ensureLoaded(sourceId);
    final decoded = _decode(await (await _rt).invoke('links', [episodeUrl]));
    if (decoded is List) {
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (decoded is Map && decoded['sources'] is List) {
      return (decoded['sources'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
}

/// Android-only executor that drives the native CloudStream engine
/// ([CloudStreamBridge] on the Kotlin side) over a [MethodChannel]. This is what
/// makes real CloudStream `.cs3` (DEX) plugins — e.g. CSX providers — work.
class CloudStreamNativeExecutor implements CloudStreamExecutor {
  CloudStreamNativeExecutor() : _channel = const MethodChannel(channelName);

  static const String channelName = 'io.alwayszihan.mixstream/cloudstream';
  final MethodChannel _channel;

  @override
  Future<List<Map<String, dynamic>>> search(
    String query,
    String sourceId,
  ) async {
    final result = await _channel.invokeMethod<List<dynamic>?>(
      'search',
      {'query': query, 'sourceId': sourceId},
    );
    return _toMaps(result);
  }

  @override
  Future<List<Map<String, dynamic>>> getHome(String sourceId) async {
    final result = await _channel.invokeMethod<List<dynamic>?>(
      'getHome',
      {'sourceId': sourceId},
    );
    return _toMaps(result);
  }

  @override
  Future<Map<String, dynamic>> getDetail(String url, String sourceId) async {
    final result = await _channel.invokeMethod<dynamic>(
      'load',
      {'url': url, 'sourceId': sourceId},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {};
  }

  @override
  Future<List<Map<String, dynamic>>> loadLinks(
    String episodeUrl,
    String sourceId,
  ) async {
    final result = await _channel.invokeMethod<List<dynamic>?>(
      'loadLinks',
      {'url': episodeUrl, 'sourceId': sourceId},
    );
    return _toMaps(result);
  }

  /// Loads a `.cs3` (DEX) plugin into the native engine.
  Future<Map<String, dynamic>> loadPlugin(String id, List<int> bytes) async {
    final result = await _channel.invokeMethod<dynamic>(
      'loadPlugin',
      {'id': id, 'bytes': Uint8List.fromList(bytes)},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {'success': false, 'error': 'no result'};
  }

  /// Unloads a previously loaded `.cs3` plugin from the native engine.
  Future<Map<String, dynamic>> unloadPlugin(String id) async {
    final result = await _channel.invokeMethod<dynamic>(
      'unloadPlugin',
      {'id': id},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {'success': false, 'error': 'no result'};
  }

  /// Lists providers currently registered in the native engine.
  Future<List<Map<String, dynamic>>> listProviders() async {
    final result =
        await _channel.invokeMethod<List<dynamic>?>('listProviders');
    return _toMaps(result);
  }

  List<Map<String, dynamic>> _toMaps(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
