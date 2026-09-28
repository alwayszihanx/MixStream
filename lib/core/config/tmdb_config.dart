import '../providers/device_info_provider.dart';

/// Compile-time TMDB constants + device-class-aware image-size resolution.
///
/// **Why this is a global mutable** (`_profile`): TMDB URLs are produced by
/// pure utility functions ([AppImageFallbacks]) and by model constructors
/// ([TmdbDetails], [MultimediaItem.fromTmdb]) that do not have a Riverpod
/// `Ref`. Threading the device profile through every call site is far more
/// churn than the value warrants — device class doesn't morph at runtime,
/// so a set-once global is correct *and* avoids leaking Riverpod into pure
/// data layers.
///
/// The default value (`const DeviceProfile()`) corresponds to a phone, so
/// any code that runs before [setProfile] is called (e.g. the very first
/// frame on cold start) gets the mobile-sized URLs. Once [_MyAppState]'s
/// listener on `deviceProfileProvider` fires (within milliseconds of app
/// boot), TV / desktop devices switch to higher-res sources.
class TmdbConfig {
  /// TMDB API key – compile-time override takes priority, fallback is the
  /// bundled key so the app works out of the box.
  ///
  /// The empty-string check is load-bearing, not defensive noise. A CI build
  /// that has no `TMDB_API_KEY` secret still passes one, as an EMPTY string,
  /// and `--dart-define X=` overrides `defaultValue` just as a real value
  /// does. So the key silently became "", every TmdbService method short-
  /// circuited on `apiKey.isEmpty`, and the home screen rendered empty with no
  /// error anywhere. An empty override now means "not supplied", which is what
  /// it actually means.
  static const String _apiKeyOverride = String.fromEnvironment('TMDB_API_KEY');
  static const String apiKey = _apiKeyOverride == ''
      ? '1865f43a0549ca50d341dd9ab8b29f49'
      : _apiKeyOverride;

  /// Separate key used by Nuvio scrapers / logo fetches.
  static const String _logoApiKeyOverride = String.fromEnvironment(
    'TMDB_LOGO_API_KEY',
  );
  static const String logoApiKey = _logoApiKeyOverride == ''
      ? '98ae14df2b8d8f8f8136499daf79f0e0'
      : _logoApiKeyOverride;

  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageRoot = 'https://image.tmdb.org/t/p';

  static DeviceProfile _profile = const DeviceProfile();

  /// Called from `_MyAppState`'s `ref.listen(deviceProfileProvider, …)`.
  /// Idempotent; safe to call repeatedly.
  static void setProfile(DeviceProfile profile) {
    _profile = profile;
  }

  /// Backdrop / poster sources should be high-res when rendered on a TV
  /// (4K panels upscale `w1280` ~3× and look soft) or a desktop OS (retina
  /// displays at large hero sizes hit the same upscale wall). Tablet stays
  /// on mobile sizes — iPad-class screens render posters at ~200 dp wide
  /// where `w500` is already adequate at 2× DPR.
  static bool get _needsHighRes => _profile.isTv || _profile.isDesktopOS;

  /// Backdrop size: phone/tablet → `w1280`. TV/desktop → `original`
  /// (TMDB's max, typically ≥ 1920 px wide).
  static String get backdropSizeUrl =>
      '$_imageRoot/${_needsHighRes ? 'original' : 'w1280'}';

  /// Poster size: phone/tablet → `w500`. TV/desktop → `w780`.
  static String get posterSizeUrl =>
      '$_imageRoot/${_needsHighRes ? 'w780' : 'w500'}';

  /// Cast profile / thumbnail size: phone/tablet → `w185`. TV/desktop → `h632`.
  static String get profileSizeUrl =>
      '$_imageRoot/${_needsHighRes ? 'h632' : 'w185'}';

  /// Generic fallback (logos, stills, etc.) — same default as poster.
  static String get imageBaseUrl => posterSizeUrl;

  static String _nuvioApiKey = '';

  /// TMDB key used by Nuvio scrapers and the Nuvio tab. Kept separate from
  /// [apiKey]; falls back to it when empty.
  static String get nuvioApiKey {
    if (_nuvioApiKey.isNotEmpty) return _nuvioApiKey;
    return apiKey;
  }

  static void setNuvioApiKey(String key) {
    _nuvioApiKey = key;
  }

  /// TMDB image base with original quality (for full-size assets).
  static String get tmdbImageBase => '$_imageRoot/original';
}
