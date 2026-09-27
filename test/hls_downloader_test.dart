import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixstream/core/services/hls_downloader.dart';

/// Matches the encoder name out of an `ffmpeg -encoders` line, which is
///   " V....D libopenh264          OpenH264 H.264 / AVC / ..."
/// i.e. a six-character capability field, then the name.
final _encoderName = RegExp(r'^[ \t]*[VASXBD\.]{6}[ \t]+(\S+)');

/// Whether [exe] can be started at all. Process.runSync throws rather than
/// returning a non-zero code when the binary is not on PATH, which is the case
/// this has to distinguish.
bool _canRun(String exe) {
  try {
    return Process.runSync(exe, ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// The first of [candidates] this host's ffmpeg advertises, or null when ffmpeg
/// is missing or has none of them.
String? _firstEncoder(List<String> candidates) {
  if (!_canRun('ffmpeg')) return null;
  final out = Process.runSync('ffmpeg', ['-hide_banner', '-encoders']);
  if (out.exitCode != 0) return null;
  final names = (out.stdout as String)
      .split('\n')
      .map(_encoderName.firstMatch)
      .nonNulls
      .map((m) => m.group(1)!)
      .toSet();
  for (final c in candidates) {
    if (names.contains(c)) return c;
  }
  return null;
}

/// End-to-end HLS tests against streams generated on the host with ffmpeg.
///
/// Covers a plain VOD playlist and the harder AES-128 encrypted case; both must
/// come out as a genuine, fully decodable MKV.
///
/// ffmpeg is a development tool — the app has no FFmpeg dependency — so the
/// suite skips itself when it is missing instead of failing. The H.264 encoder
/// is chosen from what the host has, because builds differ: Ubuntu's ffmpeg has
/// libx264 and no libopenh264, and vice versa on some other machines. Both
/// yield the same codec_name, which is all the assertions read.
void main() {
  final hasFfmpeg = _canRun('ffmpeg');
  final hasFfprobe = _canRun('ffprobe');
  final h264Encoder = _firstEncoder(const ['libx264', 'libopenh264']);

  late Directory workDir;
  late HttpServer server;

  setUpAll(() async {
    if (!hasFfmpeg || !hasFfprobe) return;
    workDir = await Directory.systemTemp.createTemp('hls_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(() async {
      await for (final req in server) {
        final file = File('${workDir.path}/${req.uri.path}');
        if (!await file.exists()) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          continue;
        }
        req.response.headers.contentType = ContentType.binary;
        await req.response.addStream(file.openRead());
        await req.response.close();
      }
    }());
  });

  tearDownAll(() async {
    if (!hasFfmpeg || !hasFfprobe) return;
    await server.close(force: true);
    try {
      await workDir.delete(recursive: true);
    } catch (_) {}
  });

  String url(String name) => 'http://127.0.0.1:${server.port}/$name';

  /// Generates a 4s H.128 test stream as HLS. [encrypted] wraps it in
  /// AES-128, which is the case real scrapers actually use.
  Future<void> generateHls({required bool encrypted}) async {
    final args = [
      '-y', '-hide_banner', '-loglevel', 'error',
      '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25',
      '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000',
      '-t', '4',
      '-c:v', h264Encoder!, '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-profile:a', 'aac_low', '-bf', '3', '-g', '50',
      '-f', 'hls', '-hls_time', '2', '-hls_playlist_type', 'vod',
      '-hls_segment_filename',
      '${workDir.path}/${encrypted ? "enc" : "seg"}%03d.ts',
    ];
    if (encrypted) {
      final keyFile = File('${workDir.path}/enc.key');
      await keyFile.writeAsBytes(
        List<int>.generate(16, (i) => i * 7 + 3),
        flush: true,
      );
      // The key-info file is two lines: the public key URL, then a *path* to
      // the local key file. FFmpeg requires both.
      await File('${workDir.path}/keyinfo').writeAsString(
        '${url('enc.key')}\n${keyFile.path}\n',
        flush: true,
      );
      args.addAll([
        '-hls_key_info_file', '${workDir.path}/keyinfo',
        '-hls_segment_type', 'mpegts',
      ]);
    }
    args.add('${workDir.path}/${encrypted ? 'aes' : 'plain'}.m3u8');
    final result = await Process.run('ffmpeg', args);
    expect(
      result.exitCode,
      0,
      reason: 'ffmpeg failed to build the fixture: ${result.stderr}',
    );
  }

  Future<void> verifyMkv(String path) async {
    // Container + streams.
    final probe = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=format_name:stream=codec_name,codec_type',
      '-of', 'json', path,
    ]);
    expect(probe.exitCode, 0, reason: 'ffprobe failed: ${probe.stderr}');
    final json = _decode(probe.stdout as String);
    expect(json['format']['format_name'], contains('matroska'));
    final codecs = (json['streams'] as List)
        .map((s) => s['codec_name'])
        .toList();
    expect(codecs, contains('h264'));
    expect(codecs, contains('aac'));

    // A full decode must be completely clean — this is what proves the mux is
    // correct rather than merely parseable.
    final decode = await Process.run(
      'ffmpeg',
      ['-v', 'error', '-i', path, '-f', 'null', '-'],
    );
    expect(decode.exitCode, 0);
    expect((decode.stderr as String).trim(), isEmpty);
  }

  test('HLS VOD playlist becomes a decodable MKV', () async {
    if (!hasFfmpeg || !hasFfprobe || h264Encoder == null) {
      markTestSkipped(
        h264Encoder == null && hasFfmpeg
            ? 'no H.264 encoder (libx264/libopenh264) in this ffmpeg build'
            : 'ffmpeg/ffprobe not available',
      );
      return;
    }
    await generateHls(encrypted: false);
    final out = '${workDir.path}/plain.mkv';
    final file = await HlsDownloader(_dio()).downloadToMkv(
      url('plain.m3u8'),
      out,
    );
    expect(await file.exists(), isTrue);
    await verifyMkv(out);
  });

  test('AES-128 encrypted HLS becomes a decodable MKV', () async {
    if (!hasFfmpeg || !hasFfprobe || h264Encoder == null) {
      markTestSkipped(
        h264Encoder == null && hasFfmpeg
            ? 'no H.264 encoder (libx264/libopenh264) in this ffmpeg build'
            : 'ffmpeg/ffprobe not available',
      );
      return;
    }
    await generateHls(encrypted: true);
    final out = '${workDir.path}/aes.mkv';
    final file = await HlsDownloader(_dio()).downloadToMkv(
      url('aes.m3u8'),
      out,
    );
    expect(await file.exists(), isTrue);
    await verifyMkv(out);
  });

  test('rejects a live playlist instead of hanging', () async {
    await File('${workDir.path}/live.m3u8').writeAsString(
      '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2.0,\na.ts\n',
    );
    await expectLater(
      HlsDownloader(_dio()).downloadToMkv(
        url('live.m3u8'),
        '${workDir.path}/live.mkv',
      ),
      throwsA(isA<HlsDownloadException>()),
    );
  });

  test('rejects a non-playlist link', () async {
    await File('${workDir.path}/notmedia.txt').writeAsString('hello');
    await expectLater(
      HlsDownloader(_dio()).downloadToMkv(
        url('notmedia.txt'),
        '${workDir.path}/notmedia.mkv',
      ),
      throwsA(isA<HlsDownloadException>()),
    );
  });
}

Dio _dio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ),
);

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;
