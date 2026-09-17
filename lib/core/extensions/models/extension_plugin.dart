import 'dart:convert';

enum PluginSettingType { toggle, toggleGroup, select, text, url }

class PluginSettingOption {
  final String label;
  final String value;
  final String? description;
  final String? icon;
  final String defaultValue;

  const PluginSettingOption({
    required this.label,
    required this.value,
    this.description,
    this.icon,
    this.defaultValue = 'false',
  });

  factory PluginSettingOption.fromJson(dynamic raw) {
    if (raw is Map) {
      final json = Map<String, dynamic>.from(raw);
      final value = (json['value'] ?? json['id'] ?? '').toString();
      final label = (json['label'] ?? json['name'] ?? value).toString();
      final rawDefault =
          json['defaultValue'] ?? json['default'] ?? json['enabled'] ?? false;
      return PluginSettingOption(
        label: label,
        value: value,
        description: json['description']?.toString(),
        icon: json['icon']?.toString(),
        defaultValue: rawDefault is bool
            ? (rawDefault ? 'true' : 'false')
            : rawDefault.toString(),
      );
    }

    final value = raw?.toString() ?? '';
    return PluginSettingOption(label: value, value: value);
  }

  bool get defaultBool {
    final normalized = defaultValue.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
}

class PluginSettingDefinition {
  final String key;
  final String title;
  final String? description;
  final PluginSettingType type;
  final String defaultValue;
  final List<PluginSettingOption> options;
  final bool reloadOnChange;
  final bool isBaseUrl;

  const PluginSettingDefinition({
    required this.key,
    required this.title,
    required this.type,
    this.description,
    this.defaultValue = '',
    this.options = const [],
    this.reloadOnChange = true,
    this.isBaseUrl = false,
  });

  factory PluginSettingDefinition.fromJson(Map<String, dynamic> json) {
    final key = (json['key'] ?? json['id'] ?? '').toString().trim();
    final rawType = (json['type'] ?? 'text').toString().trim().toLowerCase();

    final PluginSettingType type;
    switch (rawType) {
      case 'bool':
      case 'boolean':
      case 'switch':
      case 'toggle':
        type = PluginSettingType.toggle;
        break;
      case 'select':
      case 'dropdown':
      case 'list':
        type = PluginSettingType.select;
        break;
      case 'toggle_group':
      case 'togglegroup':
      case 'multi_toggle':
      case 'multitoggle':
      case 'switch_group':
        type = PluginSettingType.toggleGroup;
        break;
      case 'url':
      case 'domain':
        type = PluginSettingType.url;
        break;
      default:
        type = PluginSettingType.text;
        break;
    }

    final rawDefault =
        json['defaultValue'] ?? json['default'] ?? json['value'] ?? '';
    final String defaultValue;
    if (rawDefault is bool) {
      defaultValue = rawDefault ? 'true' : 'false';
    } else if (rawDefault is Map || rawDefault is List) {
      defaultValue = jsonEncode(rawDefault);
    } else {
      defaultValue = rawDefault.toString();
    }

    final rawDescription = json['description']?.toString().trim();
    final options = (json['options'] as List<dynamic>? ?? const [])
        .take(100)
        .map(PluginSettingOption.fromJson)
        .where((option) => option.value.isNotEmpty)
        .toList(growable: false);

    final reloadValue = json['reloadOnChange'];
    final baseUrlValue = json['isBaseUrl'] ?? json['baseUrl'];

    return PluginSettingDefinition(
      key: key,
      title: (json['title'] ?? json['name'] ?? key).toString(),
      description: rawDescription == null || rawDescription.isEmpty
          ? null
          : rawDescription,
      type: type,
      defaultValue: defaultValue,
      options: options,
      reloadOnChange: reloadValue is bool ? reloadValue : true,
      isBaseUrl: baseUrlValue == true || key == 'base_url' || key == 'baseUrl',
    );
  }

  bool get defaultBool {
    final normalized = defaultValue.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
}

class PluginDomain {
  final String name;
  final String url;

  const PluginDomain({required this.name, required this.url});

  factory PluginDomain.fromJson(Map<String, dynamic> json) {
    return PluginDomain(
      name: json['name'] as String? ?? json['url'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

class PluginSubProvider {
  final String id;
  final String name;

  /// Optional static URL. When null the JS resolves the URL dynamically via manifest.providerId.
  final String? baseUrl;

  const PluginSubProvider({required this.id, required this.name, this.baseUrl});

  factory PluginSubProvider.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['baseUrl'] as String?;
    return PluginSubProvider(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      baseUrl: (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : null,
    );
  }
}

class ExtensionPlugin {
  final String packageName; // Unique Plugin ID (e.g. "com.hexated.superstream")
  final String name; // Display Name (e.g. "SuperStream")
  final String repositoryId; // "com.hexated" or "LocalAssets"
  final String sourceUrl; // Download Link or Local Path
  final int version;
  final String? iconUrl;

  // Metadata (Native Parity)
  final List<String> authors; // e.g. ["Hexated"]
  final String? description; // e.g. "Watch movies and TV shows"
  final List<String> categories; // e.g. ["Movie", "Anime"]
  final List<String> languages; // e.g. ["en"]
  final int? fileSize; // In bytes
  final int status; // 0: Down, 1: Ok, 2: Slow, 3: Beta
  final Map<String, dynamic> manifest; // Raw JSON manifest
  final String? customBaseUrl; // User-defined override for baseUrl
  final List<PluginDomain>? domains; // Available mirror domains from manifest
  final List<PluginSubProvider>?
  providers; // Sub-providers (one JS, many feeds)
  final bool isCloudStream; // JS provider running in the CloudStream shim runtime

  ExtensionPlugin({
    required this.packageName,
    required this.name,
    required this.repositoryId,
    required this.sourceUrl,
    required this.version,
    this.status = 1,
    this.iconUrl,
    this.authors = const [],
    this.description,
    this.categories = const [],
    this.languages = const [],
    this.fileSize,
    this.manifest = const {},
    this.customBaseUrl,
    this.domains,
    this.providers,
    this.isCloudStream = false,
  });

  /// Helper to check if this is a debug/asset plugin
  bool get isDebug => packageName.endsWith('.debug');

  /// Local File Path relative to plugin root
  /// e.g. "plugin/[packageName]/plugin.js"
  String get filePath => "$repositoryId/$packageName/plugin.js";

  static List<String> _readList(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value];
      }
    }
    return const [];
  }

  /// Factory constructor to parse from JSON (SitePlugin format or meta.json)
  factory ExtensionPlugin.fromJson(
    Map<String, dynamic> json,
    String repositoryId,
  ) {
    final String? packageName = json['packageName'] as String?;

    if (packageName == null) {
      throw Exception('Plugin manifest missing mandatory "packageName" field');
    }

    return ExtensionPlugin(
      packageName: packageName,
      name: json['name'] as String? ?? 'Unknown Plugin',
      repositoryId: repositoryId,
      sourceUrl: json['url'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      status: json['status'] as int? ?? 1,
      iconUrl: json['iconUrl'] as String?,
      authors:
          (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] as String?,
      categories: _readList(json, ['categories', 'types', 'tvTypes']),
      languages: _readList(json, ['languages', 'language', 'lang']),
      fileSize: json['fileSize'] as int?,
      manifest: json,
      customBaseUrl: json['customBaseUrl'] as String?,
      domains: (json['domains'] as List<dynamic>?)
          ?.whereType<Map<dynamic, dynamic>>()
          .map((d) => PluginDomain.fromJson(Map<String, dynamic>.from(d)))
          .where((d) => d.url.isNotEmpty)
          .toList(),
      providers: (json['providers'] as List<dynamic>?)
          ?.whereType<Map<dynamic, dynamic>>()
          .map((p) => PluginSubProvider.fromJson(Map<String, dynamic>.from(p)))
          .where((p) => p.id.isNotEmpty)
          .toList(),
    );
  }

  ExtensionPlugin copyWith({String? customBaseUrl}) {
    return ExtensionPlugin(
      packageName: packageName,
      name: name,
      repositoryId: repositoryId,
      sourceUrl: sourceUrl,
      version: version,
      status: status,
      iconUrl: iconUrl,
      authors: authors,
      description: description,
      categories: categories,
      languages: languages,
      fileSize: fileSize,
      manifest: manifest,
      customBaseUrl: customBaseUrl ?? this.customBaseUrl,
      domains: domains,
      providers: providers,
      isCloudStream: isCloudStream,
    );
  }

  /// Factory for CloudStream-style (JS) provider entries coming from a
  /// CloudStream repository's `plugins.json`. These entries use `url` for the
  /// `.cs3`/zip download and an integer `version`, and lack MixStream's
  /// `packageName`/`sourceUrl` fields. [packageNameOverride] keeps the id
  /// stable between the repo listing and the installed package.
  factory ExtensionPlugin.cloudStreamFromJson(
    Map<String, dynamic> json,
    String repositoryId, {
    String? packageNameOverride,
  }) {
    String deriveId() {
      final candidate =
          packageNameOverride ??
          json['internalName'] as String? ??
          json['packageName'] as String? ??
          json['id'] as String? ??
          json['name'] as String? ??
          (json['url'] as String? ?? '');
      if (candidate.isEmpty) {
        return 'cs.${candidate.hashCode.abs()}';
      }
      final sanitized = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      return sanitized.isEmpty ? 'cs.${candidate.hashCode.abs()}' : sanitized;
    }

    final id = deriveId();
    final rawVersion = json['version'];
    final version = rawVersion is int
        ? rawVersion
        : int.tryParse(
              (rawVersion as String? ?? '1').replaceAll(
                RegExp(r'[^0-9]'),
                '',
              ),
            ) ??
            1;

    return ExtensionPlugin(
      packageName: id,
      name: json['name'] as String? ?? id,
      repositoryId: repositoryId,
      sourceUrl: json['url'] as String? ?? '',
      version: version,
      status: json['status'] as int? ?? 1,
      iconUrl: json['iconUrl'] as String?,
      authors: _readList(json, ['authors', 'author']),
      description: json['description'] as String?,
      categories: _readList(json, ['tvTypes', 'categories', 'types']),
      languages: _readList(json, ['language', 'languages', 'lang']),
      manifest: json,
      isCloudStream: true,
    );
  }
}
