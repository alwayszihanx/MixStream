import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/extension_repository.dart';
import '../models/extension_plugin.dart';

class RepositoryService {
  final Dio _dio;
  final bool enableGithubProxy;

  RepositoryService(this._dio, {this.enableGithubProxy = false});

  /// Resolves the actual URL from shortcodes or custom schemes
  Future<String?> parseRepoUrl(String url) async {
    final fixedUrl = url.trim();

    // Standard HTTP/HTTPS
    if (RegExp(r'^https?://').hasMatch(fixedUrl)) {
      return fixedUrl;
    }

    // Known shortcodes
    if (fixedUrl == 'mixplug' || fixedUrl == 'mixplugs') {
      return 'https://raw.githubusercontent.com/alwayszihanx/Mixplug/main/plugins/repo.json';
    }

    // Shortcode (Alphanumeric) -> cutt.ly
    if (RegExp(r'^[a-zA-Z0-9!_-]+$').hasMatch(fixedUrl)) {
      try {
        final response = await _dio.get<dynamic>(
          "https://cutt.ly/sky-$fixedUrl",
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 400,
          ),
        );

        // 3xx status codes usually have location header
        if (response.statusCode == 301 ||
            response.statusCode == 302 ||
            response.statusCode == 303 ||
            response.statusCode == 307) {
          final location = response.headers.value('location');
          if (location != null) {
            if (location.startsWith("https://cutt.ly/404") ||
                location.replaceAll(RegExp(r'/$'), '') == "https://cutt.ly") {
              throw Exception("Shortcode not found");
            }
            return location;
          }
        }
        throw Exception("Invalid response from shortcode service");
      } on DioException catch (e) {
        throw Exception("Network error resolving shortcode: ${e.message}");
      } catch (e) {
        throw Exception("Shortcode resolution failed: $e");
      }
    }

    throw Exception("Invalid URL format");
  }

  /// Fetch and parse a Repository from a URL
  Future<ExtensionRepository?> fetchRepository(String url) async {
    try {
      // Resolve Shortcodes / Protocols
      final resolvedUrl = await parseRepoUrl(url);
      if (resolvedUrl == null) {
        // Should be unreachable if parseRepoUrl throws, but for safety:
        throw Exception("Failed to resolve URL");
      }

      // Handle raw github urls -> jsdelivr if needed
      final normalizedUrl = _normalizeUrl(resolvedUrl);

      final response = await _dio.request<String>(normalizedUrl);
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic>? data = response.data is String
            ? _jsonDecodeSafe(response.data!) as Map<String, dynamic>?
            : response.data as Map<String, dynamic>;

        if (data != null) {
          // Validation: a repository needs a name and at least one source of
          // plugins. CloudStream-style repos use `pluginLists` without an
          // `id`/`packageName`; their id is derived from the URL instead.
          final hasName = data.containsKey('name');
          final plugins = (data['pluginLists'] as List?) ?? <dynamic>[];
          final repos = (data['repos'] as List?) ?? <dynamic>[];
          final embedded = (data['plugins'] as List?) ?? <dynamic>[];

          final hasPlugins =
              plugins.isNotEmpty || repos.isNotEmpty || embedded.isNotEmpty;

          if (!hasName || !hasPlugins) {
            throw Exception(
              'Invalid repository format: Missing name or plugin/repo list',
            );
          }

          if ((plugins.isNotEmpty && repos.isNotEmpty) ||
              (plugins.isNotEmpty && embedded.isNotEmpty) ||
              (repos.isNotEmpty && embedded.isNotEmpty)) {
            throw Exception(
              "Repository cannot contain more than one of 'pluginLists', "
              "'repos', or 'plugins'. Please separate them.",
            );
          }

          return ExtensionRepository.fromJson(data, url);
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to fetch repository $url: $e');
      }
    } catch (e) {
      // Rethrow validation exceptions or others
      rethrow;
    }
    return null;
  }

  /// Fetch all plugin listed in a Repository
  Future<List<ExtensionPlugin>> getRepoPlugins(ExtensionRepository repo) async {
    final List<ExtensionPlugin> allPlugins = <ExtensionPlugin>[];

    // Add plugins directly embedded in the repository manifest (Enterprise V2)
    allPlugins.addAll(repo.plugins);

    for (final pluginListUrl in repo.pluginLists) {
      try {
        final normalizedUrl = _normalizeUrl(pluginListUrl);
        final response = await _dio.get<dynamic>(normalizedUrl);

        if (response.statusCode == 200 && response.data != null) {
          final decoded = response.data is String
              ? _jsonDecodeSafe(response.data as String)
              : response.data;

          List<dynamic> list;
          if (decoded is List) {
            list = decoded;
          } else if (decoded is Map && decoded['plugins'] is List) {
            // CloudStream-style plugins.json: {"plugins":[...]}
            list = decoded['plugins'] as List;
          } else {
            list = const [];
          }

          for (final entry in list) {
            if (entry is! Map) continue;
            final map = Map<String, dynamic>.from(entry);
            if (map['packageName'] != null || map['sourceUrl'] != null) {
              // MixStream plugin entry
              allPlugins.add(
                ExtensionPlugin.fromJson(map, repo.packageName),
              );
            } else if (map['url'] != null) {
              // CloudStream JS provider entry (`.cs3`/zip with plugin.js)
              allPlugins.add(
                ExtensionPlugin.cloudStreamFromJson(map, repo.packageName),
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to fetch plugin list $pluginListUrl: $e');
        }
      }
    }

    return allPlugins;
  }

  /// Downloads a plugin package and returns its raw bytes (used for CloudStream
  /// `.cs3`/zip installs where we hand the bytes to the CloudStream installer).
  Future<Uint8List?> downloadPluginBytes(String url) async {
    try {
      final normalizedUrl = _normalizeUrl(url);
      final response = await _dio.get<List<int>>(
        normalizedUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to download plugin bytes $url: $e');
      }
    }
    return null;
  }

  /// Download a plugin file to a temporary location
  Future<File?> downloadPlugin(String url) async {
    try {
      final normalizedUrl = _normalizeUrl(url);
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.mix',
      );

      await _dio.download(normalizedUrl, tempFile.path);

      if (await tempFile.exists()) {
        return tempFile;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to download plugin $url: $e');
      }
    }
    return null;
  }

  String _normalizeUrl(String url) {
    if (!enableGithubProxy) return url;

    // Convert raw.githubusercontent.com to jsdelivr for caching/performance
    if (url.contains('raw.githubusercontent.com')) {
      final regex = RegExp(
        r'^https://raw\.githubusercontent\.com/([A-Za-z0-9-]+)/([A-Za-z0-9_.-]+)/(.*)$',
      );
      final match = regex.firstMatch(url);
      if (match != null) {
        final user = match.group(1);
        final repo = match.group(2);
        final path = match.group(3);
        return 'https://cdn.jsdelivr.net/gh/$user/$repo@$path';
      }
    }
    return url;
  }

  dynamic _jsonDecodeSafe(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }
}
