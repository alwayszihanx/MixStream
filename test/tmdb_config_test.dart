// Guards the TMDB key against the silent-empty-define trap.
//
// A CI build with no TMDB_API_KEY secret still passes one, as an EMPTY string,
// and `--dart-define X=` overrides `defaultValue` exactly as a real value does.
// That shipped for a while: the key became "", every TmdbService method
// returned [] on its `apiKey.isEmpty` guard, and the home screen rendered
// empty with nothing logged anywhere. On a build machine nobody noticed,
// because there the default applied.
//
// These assertions are about the CONSTANT, which is evaluated at compile time,
// so they pass in any build that ends up with a usable key. They cannot detect
// the bad case directly (that is decided by the build's defines) — but a key
// that is empty or has lost its default fails here, and that is the symptom
// that actually reaches a user.

import 'package:flutter_test/flutter_test.dart';
import 'package:mixstream/core/config/tmdb_config.dart';

void main() {
  group('TMDB key is usable in a release build', () {
    test('apiKey is never empty', () {
      expect(
        TmdbConfig.apiKey,
        isNotEmpty,
        reason:
            'An empty TMDB key makes every TmdbService call return [] and the '
            'home screen renders empty. If this fails, a --dart-define with an '
            'empty value has overridden the bundled default again.',
      );
    });

    test('apiKey looks like a TMDB v3 key (32 hex chars)', () {
      expect(TmdbConfig.apiKey, hasLength(32));
      expect(
        TmdbConfig.apiKey,
        matches(RegExp(r'^[0-9a-f]{32}$')),
        reason: 'TMDB v3 api keys are 32 lowercase hex characters.',
      );
    });

    test('logoApiKey is usable too', () {
      // Separate key, same trap: the logo fetches go silent rather than
      // throwing, so an empty value here is just a missing image.
      expect(TmdbConfig.logoApiKey, isNotEmpty);
      expect(TmdbConfig.logoApiKey, hasLength(32));
    });

    test('nuvioApiKey falls back to apiKey when unset', () {
      // Before anything calls setNuvioApiKey, scrapers must still have a key.
      expect(TmdbConfig.nuvioApiKey, TmdbConfig.apiKey);
    });

    test('baseUrl is the v3 API root', () {
      expect(TmdbConfig.baseUrl, 'https://api.themoviedb.org/3');
    });
  });
}
