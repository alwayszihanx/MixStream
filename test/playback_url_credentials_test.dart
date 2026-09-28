// Unit tests for the playback-URL credential heuristic.
//
// Pure string logic, so these run anywhere with no ffmpeg, network or plugin
// setup. The cases that matter are the ones where being wrong costs something:
// a false positive re-runs a scraper (cheap), a false negative hands the user
// a dead link (not cheap).

import 'package:flutter_test/flutter_test.dart';
import 'package:mixstream/core/network/playback_url_credentials.dart';

void main() {
  group('signed/tokenised links are recognised', () {
    test('long opaque token', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://cdn.example.com/v/1.mkv?token=abcdef0123456789abcdef0123456789',
        ),
        isTrue,
      );
    });

    test('explicit expiry alone is decisive', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://cdn.example.com/v/1.mkv?expires=1789000000',
        ),
        isTrue,
      );
    });

    test('signature key with a hex digest', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://x.cloudfront.net/a/b.mp4?Policy=key-pair-id&Signature=deadbeef',
        ),
        isTrue,
      );
    });

    test('X-Amz-* cloudfront set', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://d1234.cloudfront.net/k.m3u8'
          '?X-Amz-Algorithm=AWS4-HMAC-SHA256'
          '&X-Amz-Expires=900'
          '&X-Amz-Signature=0123456789abcdef0123456789abcdef',
        ),
        isTrue,
      );
    });

    test('a weak key plus a signed-looking sibling still counts', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://hls.example.com/s/2.m3u8?t=1234567890&h=0123456789abcdef0123456789',
        ),
        isTrue,
      );
    });

    test('token key is enough even when the value is short', () {
      // CloudFront-style signed cookies often use a short key with a short
      // value; the KEY is the evidence, and paying a re-resolve is cheap.
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://e.example.com/i.m3u8?token=abc123',
        ),
        isTrue,
      );
    });
  });

  group('ordinary links are not', () {
    test('no query at all', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://cdn.example.com/v/1.mkv',
        ),
        isFalse,
      );
    });

    test('a plain cache-buster is not a credential', () {
      // The regression this guards: every CDN puts ?t=<epoch> on a static
      // file. Treating that as signed would re-resolve every source.
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://cdn.example.com/v/1.mkv?t=1789000000',
        ),
        isFalse,
      );
    });

    test('layout/quality params', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://cdn.example.com/v/1.mkv?quality=1080p&height=1080&width=1920',
        ),
        isFalse,
      );
    });

    test('a session id that is just an id', () {
      // Short value + no signature sibling: a static file behind a session
      // parameter, not a signed link.
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://example.com/v/1.mkv?session=42',
        ),
        isFalse,
      );
    });

    test('fragment is not a query', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://example.com/v/1.mkv#t=10',
        ),
        isFalse,
      );
    });

    test('null and empty', () {
      expect(hasLikelyExpiringPlaybackCredentials(null), isFalse);
      expect(hasLikelyExpiringPlaybackCredentials(''), isFalse);
    });

    test('trailing ? with nothing after it', () {
      expect(
        hasLikelyExpiringPlaybackCredentials('https://example.com/v/1.mkv?'),
        isFalse,
      );
    });
  });

  group('malformed input does not throw', () {
    test('a stray percent escape in a value', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://example.com/v/1.mkv?token=%E0%A4%A&expires=1',
        ),
        isTrue,
      );
    });

    test('a key with no value at all', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://example.com/v/1.mkv?token',
        ),
        isFalse,
      );
    });

    test('repeated ampersands', () {
      expect(
        hasLikelyExpiringPlaybackCredentials(
          'https://example.com/v/1.mkv?&&quality=720p&&',
        ),
        isFalse,
      );
    });
  });
}
