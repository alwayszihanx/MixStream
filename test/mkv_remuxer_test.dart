import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixstream/core/services/mkv_remuxer.dart';

/// Generates a small test MP4 with the host system's ffmpeg and validates that
/// the pure-Dart remuxer produces a genuine, playable MKV (checked with
/// ffprobe / full decode). These tools are only needed on the development
/// machine — the app itself has no FFmpeg dependency.
void main() {
  final tmp = Directory.systemTemp.createTempSync('mkv_remux_test');

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
    final mp4 = await makeMp4(
      name: 'h264_moov_end.mp4',
      vcodec: 'libopenh264',
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
    final mp4 = await makeMp4(
      name: 'h264_faststart.mp4',
      vcodec: 'libopenh264',
      acodec: 'aac',
      extra: ['-movflags', '+faststart'],
    );
    final result = await remuxDownloadedVideoToMkv(mp4);
    expect(result.success, isTrue, reason: result.error);
    await expectValidMkv(result.outputPath!, vcodec: 'h264');
  });

  test('HEVC + AAC → valid MKV', () async {
    final encoders = (await Process.run(
      'ffmpeg',
      ['-hide_banner', '-encoders'],
    ))
        .stdout
        .toString();
    if (!encoders.contains('libx265')) {
      markTestSkipped('libx265 not available on this machine');
      return;
    }
    final mp4 = await makeMp4(
      name: 'hevc.mp4',
      vcodec: 'libx265',
      acodec: 'aac',
    );
    final result = await remuxDownloadedVideoToMkv(mp4);
    expect(result.success, isTrue, reason: result.error);
    await expectValidMkv(result.outputPath!, vcodec: 'hevc');
  });

  test('WebM (VP9 + Opus) → renamed to .mkv, bytes untouched', () async {
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
      'libvpx-vp9',
      '-c:a',
      'libopus',
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
      'libvpx-vp9',
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