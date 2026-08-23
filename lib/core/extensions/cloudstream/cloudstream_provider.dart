import 'package:dio/dio.dart';

import '../../domain/entity/multimedia_item.dart';
import '../base_provider.dart';
import '../models/extension_plugin.dart';
import 'cloudstream_executor.dart';

/// A CloudStream `.cs3` provider exposed through MixStream's [MixStreamProvider]
/// contract. The actual JS execution is delegated to a [CloudStreamExecutor]
/// (cross-platform QuickJS shim in a later phase). The mapping helpers below
/// translate CloudStream's native map shapes into MixStream's entities.
class CloudStreamProvider extends MixStreamProvider {
  final ExtensionPlugin plugin;
  final CloudStreamExecutor executor;

  CloudStreamProvider(this.plugin, this.executor);

  @override
  String get packageName => plugin.packageName;

  @override
  String get name => plugin.name;

  @override
  String get mainUrl =>
      (plugin.manifest['mainClass'] as String?) ??
      (plugin.manifest['baseUrl'] as String?) ??
      '';

  @override
  String get version => plugin.version.toString();

  @override
  List<String> get languages => plugin.languages;

  @override
  Set<ProviderType> get supportedTypes => _typesFromManifest(plugin.manifest);

  @override
  bool get hasSearch => true;

  @override
  Future<List<MultimediaItem>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final raw = await executor.search(query, packageName);
    return raw.map(_mediaItemFromMap).toList();
  }

  @override
  Future<Map<String, List<MultimediaItem>>> getHome() async {
    final raw = await executor.getHome(packageName);
    final out = <String, List<MultimediaItem>>{};
    for (final row in raw) {
      final title = (row['title'] as String?) ?? '';
      final items = (row['items'] as List?) ?? const [];
      out[title] = items
          .map((e) => _mediaItemFromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return out;
  }

  @override
  Future<MultimediaItem> getDetails(String url) async {
    final m = await executor.getDetail(url, packageName);
    return _mediaItemFromMap(m);
  }

  @override
  Future<List<StreamResult>> loadStreams(String url) async {
    final raw = await executor.loadLinks(url, packageName);
    return _sourcesFromResult(raw);
  }

  // ── mapping helpers (ported from Zangetsu, adapted to MixStream entities) ──

  Map<String, dynamic> _asMap(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : const {};

  MultimediaItem _mediaItemFromMap(dynamic raw) {
    final m = _asMap(raw);
    final url = (m['url'] ?? '').toString();
    return MultimediaItem(
      title: (m['name'] ?? '').toString(),
      url: url,
      posterUrl: (m['posterUrl'] as String?) ?? (m['image'] as String?) ?? '',
      bannerUrl:
          (m['backgroundPosterUrl'] as String?) ?? (m['bannerUrl'] as String?),
      logoUrl: m['logoUrl'] is String ? m['logoUrl'] as String : null,
      description: (m['description'] ?? m['plot']) as String?,
      contentType: _typeFromCsType(m['type'] as String?),
      year: _parseYear(m['year']),
      score: (m['rating'] is num) ? (m['rating'] as num).toDouble() : null,
      tags: _stringList(m['genres']) ?? _stringList(m['tags']),
      cast: _castFrom(m['actors']),
      recommendations: _relationsFrom(m['recommendations']),
      episodes: _episodesFrom(m['episodes']),
      provider: packageName,
      source: 'cloudstream',
    );
  }

  List<Episode>? _episodesFrom(dynamic raw) {
    if (raw is! List) return null;
    return [
      for (final e in raw)
        Episode(
          name: (_asMap(e)['name'] ?? '').toString(),
          url: (_asMap(e)['data'] ?? _asMap(e)['url'] ?? '').toString(),
          season: (_asMap(e)['season'] as num?)?.toInt() ?? 0,
          episode: (_asMap(e)['episode'] as num?)?.toInt() ?? 0,
          posterUrl: _asMap(e)['posterUrl'] as String?,
        ),
    ];
  }

  List<Actor> _castFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Actor>[];
    for (final a in raw) {
      final am = _asMap(a);
      final name = (am['name'] ?? '').toString();
      if (name.isEmpty) continue;
      out.add(
        Actor(
          name: name,
          image: am['image'] as String?,
          role: am['role'] is String ? am['role'] as String : null,
        ),
      );
    }
    return out;
  }

  List<MultimediaItem>? _relationsFrom(dynamic raw) {
    if (raw is! List) return null;
    final out = <MultimediaItem>[];
    for (final r in raw) {
      final rm = _asMap(r);
      final title = (rm['name'] ?? '').toString();
      if (title.isEmpty) continue;
      out.add(
        MultimediaItem(
          title: title,
          url: (rm['url'] ?? '').toString(),
          posterUrl: (rm['posterUrl'] as String?) ?? '',
          contentType: MultimediaContentType.other,
          source: 'cloudstream',
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  List<StreamResult> _sourcesFromResult(List<dynamic> raw) {
    final sources = <StreamResult>[];
    for (final s in raw) {
      final sm = _asMap(s);
      final streamUrl = (sm['url'] ?? '').toString();
      if (streamUrl.isEmpty) continue;

      final headers = <String, String>{};
      final rawHeaders = sm['headers'];
      if (rawHeaders is Map) {
        rawHeaders.forEach((k, v) => headers['$k'] = '$v');
      }
      final referer = (sm['referer'] ?? '').toString();
      if (referer.isNotEmpty) headers['Referer'] = referer;

      final subtitles = <SubtitleFile>[];
      final subsRaw = sm['subtitles'];
      if (subsRaw is List) {
        for (final sub in subsRaw) {
          final sm2 = _asMap(sub);
          final subUrl = (sm2['url'] ?? '').toString();
          if (subUrl.isEmpty) continue;
          subtitles.add(
            SubtitleFile(
              url: subUrl,
              label: (sm2['name'] ?? sm2['lang'] ?? 'sub').toString(),
              lang: sm2['lang'] is String ? sm2['lang'] as String : null,
            ),
          );
        }
      }

      sources.add(
        StreamResult(
          url: streamUrl,
          source: (sm['name'] is String ? sm['name'] as String : null) ??
              (sm['quality'] != null ? '${sm['quality']}p' : 'Unknown'),
          headers: headers.isEmpty ? null : headers,
          subtitles: subtitles.isEmpty ? null : subtitles,
        ),
      );
    }
    return sources;
  }

  List<String>? _stringList(dynamic raw) {
    if (raw is! List) return null;
    final out = <String>[];
    for (final e in raw) {
      final s = '$e';
      if (s.isNotEmpty) out.add(s);
    }
    return out.isEmpty ? null : out;
  }

  int? _parseYear(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    final s = raw.toString();
    final match = RegExp(r'(\d{4})').firstMatch(s);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  MultimediaContentType _typeFromCsType(String? csType) {
    switch (csType) {
      case 'Movie':
      case 'AnimeMovie':
      case 'Torrent':
        return MultimediaContentType.movie;
      case 'TvSeries':
      case 'Anime':
      case 'OVA':
      case 'Cartoon':
      case 'AsianDrama':
      case 'Documentary':
        return MultimediaContentType.series;
      case 'LiveStream':
        return MultimediaContentType.livestream;
      default:
        return MultimediaContentType.other;
    }
  }

  Set<ProviderType> _typesFromManifest(Map<String, dynamic> manifest) {
    final types = <ProviderType>{};
    final raw = manifest['tvTypes'] ?? manifest['categories'] ?? manifest['types'];
    final list = raw is List
        ? raw.map((e) => '$e').toList()
        : <String>[];

    // Default to movie if nothing is declared.
    if (list.isEmpty) return {ProviderType.movie};

    for (final t in list) {
      switch (t) {
        case 'Movie':
        case 'AnimeMovie':
        case 'Torrent':
          types.add(ProviderType.movie);
        case 'TvSeries':
        case 'Anime':
        case 'OVA':
        case 'Cartoon':
        case 'AsianDrama':
        case 'Documentary':
          types.add(ProviderType.series);
        case 'LiveStream':
          types.add(ProviderType.livestream);
        default:
          types.add(ProviderType.other);
      }
    }
    return types.isEmpty ? {ProviderType.movie} : types;
  }
}
