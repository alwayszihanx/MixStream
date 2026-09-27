import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixstream/core/services/mkv_remuxer.dart';

/// Matches the encoder name out of an `ffmpeg -encoders` line, which is
///   " V....D libopenh264          OpenH264 H.264 / AVC / ..."
/// i.e. a six-character capability field, then the name.
final _encoderName = RegExp(r'^[ \t]*[VASXBD\.]{6}[ \t]+(\S+)');

/// The encoder names this host's ffmpeg advertises, or null if ffmpeg is not
/// installed at all. Probed once per run.
Set<String>? _probeEncoders() {
  try {
    final r = Process.runSync('ffmpeg', ['-hide_banner', '-encoders']);
    if (r.exitCode != 0) return null;
    return (r.stdout as String)
        .split('\n')
        .map(_encoderName.firstMatch)
        .nonNulls
        .map((m) => m.group(1)!)
        .toSet();
  } on ProcessException {
    return null;
  }
}

/// Generates a small test MP4 with the host system's ffmpeg and validates that
/// the pure-Dart remuxer produces a genuine, playable MKV (checked with
/// ffprobe / full decode). These tools are only needed on the development
/// machine — the app itself has no FFmpeg dependency.
///
/// Encoders are picked from what the host actually has, because ffmpeg builds
/// differ: Ubuntu's package has libx264/libx265/libvpx and no libopenh264,
/// while the machine this was written on has libopenh264 and neither x264 nor
/// x265. Both produce the same codec_name, which is all the assertions read.
/// A host with none of an encoder's candidates skips that test rather than
/// failing it.
void main() {
  final tmp = Directory.systemTemp.createTempSync('mkv_remux_test');
  final encoders = _probeEncoders();

  /// The first of [candidates] this ffmpeg has, or null after skipping the
  /// test with the reason printed.
  String? pick(List<String> candidates, String what) {
    if (encoders == null) {
      markTestSkipped('ffmpeg is not installed on this machine');
      return null;
    }
    for (final c in candidates) {
      if (encoders.contains(c)) return c;
    }
    markTestSkipped(
      'no $what encoder in this ffmpeg build (tried ${candidates.join(', ')})',
    );
    return null;
  }

  /// H.264: the two encoders either build ships, in preference order.
  String? pickH264() => pick(const ['libx264', 'libopenh264'], 'H.264');
  String? pickVp9() => pick(const ['libvpx-vp9'], 'VP9');

  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<String> run(String exe, List<String> args) async {
    final r = await Process.run(exe, args);
    if (r.exitCode != 0) {
      fail('$exe ${args.join(' ')} failed:\n${r.stderr}');
    }
    return (r.stdout as String).trim();
  }

  Future<String> makeMp4({
    required String name,
    required String vcodec,
    required String acodec,
    List<String> extra = const [],
  }) async {
    final out = '${tmp.path}/$name';
    await run('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x180:rate=25',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000',
      '-t',
      '5',
      '-c:v',
      vcodec,
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      acodec,
      ...extra,
      out,
    ]);
    return out;
  }

  Future<void> expectValidMkv(String path, {required String vcodec}) async {
    final probe = await run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=format_name,duration:stream=index,codec_name,codec_type',
      '-of',
      'json',
      path,
    ]);
    final json = jsonDecode(probe) as Map<String, dynamic>;
    final format = json['format'] as Map<String, dynamic>;
    expect(format['format_name'], contains('matroska'),
        reason: 'container must be Matroska for $path');
    final duration = double.parse(format['duration'] as String);
    expect(duration, closeTo(5.0, 0.6), reason: 'duration ~5s for $path');

    final streams = json['streams'] as List;
    final video = streams.cast<Map<String, dynamic>>().firstWhere(
          (s) => s['codec_type'] == 'video',
        );
    final audio = streams.cast<Map<String, dynamic>>().firstWhere(
          (s) => s['codec_type'] == 'audio',
        );
    expect(video['codec_name'], vcodec,
        reason: 'video codec preserved for $path');
    expect(audio['codec_name'], 'aac', reason: 'audio codec preserved');

    // Full decode to the end without errors.
    final decode = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-i',
      path,
      '-f',
      'null',
      '-',
    ]);
    expect(decode.exitCode, 0, reason: 'decode without errors for $path');
    expect((decode.stderr as String).trim(), isEmpty,
        reason: 'no ffmpeg errors for $path');
  }

  test('H.264 + AAC (moov at end) → valid MKV', () async {
    final vcodec = pickH264();
    if (vcodec == null) return;
    final mp4 = await makeMp4(
      name: 'h264_moov_end.mp4',
      vcodec: vcodec,
      acodec: 'aac',
      extra: ['-bf', '3', '-g', '50'], // B-frames exercise the ctts path
    );
    final result = await remuxDownloadedVideoToMkv(mp4);
    expect(result.success, isTrue, reason: result.error);
    expect(result.outputPath, endsWith('.mkv'));
    expect(File(mp4).existsSync(), isFalse, reason: 'original mp4 removed');
    await expectValidMkv(result.outputPath!, vcodec: 'h264');
  });

  test('H.264 + AAC (moov at start / faststart) → valid MKV', () async {
    final vcodec = pickH264();
    if (vcodec == null) return;
    final mp4 = await makeMp4(
      name: 'h264_faststart.mp4',
      vcodec: vcodec,
      acodec: 'aac',
      extra: ['-movflags', '+faststart'],
    );
    final result = await remuxDownloadedVideoToMkv(mp4);
    expect(result.success, isTrue, reason: result.error);
    await expectValidMkv(result.outputPath!, vcodec: 'h264');
  });

  test('HEVC + AAC → valid MKV', () async {
    final vcodec = pick(const ['libx265'], 'HEVC');
    if (vcodec == null) return;
    final mp4 = await makeMp4(
      name: 'hevc.mp4',
      vcodec: vcodec,
      acodec: 'aac',
    );
    final result = await remuxDownloadedVideoToMkv(mp4);
    expect(result.success, isTrue, reason: result.error);
    await expectValidMkv(result.outputPath!, vcodec: 'hevc');
  });

  test('WebM (VP9 + Opus) → renamed to .mkv, bytes untouched', () async {
    final vcodec = pickVp9();
    if (vcodec == null) return;
    final acodec = pick(const ['libopus'], 'Opus');
    if (acodec == null) return;
    final webm = '${tmp.path}/clip.webm';
    await run('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x180:rate=25',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000',
      '-t',
      '3',
      '-c:v',
      vcodec,
      '-c:a',
      acodec,
      webm,
    ]);
    final before = await File(webm).readAsBytes();
    final result = await remuxDownloadedVideoToMkv(webm);
    expect(result.success, isTrue, reason: result.error);
    expect(result.outputPath, endsWith('.mkv'));
    final after = await File(result.outputPath!).readAsBytes();
    expect(after, equals(before), reason: 'webm bytes must be preserved');
    expect(File(webm).existsSync(), isFalse);
  });

  test('unrelated file → failure, original untouched', () async {
    final bogus = '${tmp.path}/notes.txt';
    File(bogus).writeAsStringSync('definitely not a video');
    final result = await remuxDownloadedVideoToMkv(bogus);
    expect(result.success, isFalse);
    expect(File(bogus).existsSync(), isTrue);
  });

  test('already-.mkv Matroska → no-op success', () async {
    final vcodec = pickVp9();
    if (vcodec == null) return;
    final webm = '${tmp.path}/already.mkv';
    await run('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x180:rate=25',
      '-t',
      '2',
      '-c:v',
      vcodec,
      '-f',
      'matroska',
      webm,
    ]);
    final result = await remuxDownloadedVideoToMkv(webm);
    expect(result.success, isTrue, reason: result.error);
    expect(result.outputPath, webm);
    expect(File(webm).existsSync(), isTrue);
  });
}