import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

import 'mkv_remuxer.dart';

/// Why an HLS stream could not be turned into a file.
class HlsDownloadException implements Exception {
  HlsDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downloads an HLS (`.m3u8`) stream and converts it into a real `.mkv`.
///
/// HLS is how most scrapers deliver video, but a manifest is not a file: it
/// points at dozens of small segments that may be AES-128 encrypted. This
/// fetches the segments, decrypts them, demuxes the MPEG-TS container into
/// H.264/AAC samples, writes a minimal MP4, and hands that to the existing
/// MP4→MKV remuxer — so the final container logic is the same, already
/// validated code path used for ordinary MP4 downloads.
class HlsDownloader {
  HlsDownloader(this._dio);

  final Dio _dio;

  /// Segments fetched in parallel.
  static const int _segmentConcurrency = 6;

  /// Guard against a hostile or looping playlist.
  static const int _maxSegments = 20000;

  /// Downloads [playlistUrl] and returns the resulting `.mkv` file.
  ///
  /// The MKV is left in [outputPath]; the temporary MP4 is always cleaned up.
  Future<File> downloadToMkv(
    String playlistUrl,
    String outputPath, {
    Map<String, String>? headers,
    void Function(double)? onProgress,
  }) async {
    final media = await _loadMediaPlaylist(
      Uri.parse(playlistUrl),
      headers: headers,
    );

    if (media.segments.isEmpty) {
      throw HlsDownloadException('The playlist contains no segments.');
    }
    if (!media.hasEndList) {
      throw HlsDownloadException(
        'This is a live stream; only on-demand playlists can be saved.',
      );
    }

    final dir = await Directory.systemTemp.createTemp('hls_dl_');
    final tsPath = p.join(dir.path, 'stream.ts');
    final mp4Path = p.join(dir.path, 'stream.mp4');

    try {
      final total = media.segments.length;
      var done = 0;
      final sink = File(tsPath).openWrite();

      for (var start = 0; start < total; start += _segmentConcurrency) {
        final end = min(start + _segmentConcurrency, total);
        final window = media.segments.sublist(start, end);

        final fetched = await Future.wait([
          for (final seg in window)
            _fetchSegment(seg, headers: headers, onOne: () {}),
        ]);

        for (final bytes in fetched) {
          sink.add(bytes);
          done++;
          onProgress?.call(done / total * 0.9);
        }
      }

      await sink.flush();
      await sink.close();

      final ts = File(tsPath).readAsBytesSync();
      if (!buildMp4FromTransportStream(ts, mp4Path)) {
        throw HlsDownloadException(
          'The stream had no H.264 video or AAC audio that could be extracted.',
        );
      }

      onProgress?.call(0.95);
      final result = await remuxDownloadedVideoToMkv(mp4Path);
      if (!result.success) {
        throw HlsDownloadException(
          'Downloaded the stream but could not convert it: ${result.error}',
        );
      }
      onProgress?.call(1.0);

      // The remuxer writes next to its input; move it to the requested path.
      final produced = File(result.outputPath!);
      final target = File(outputPath);
      if (target.existsSync()) target.deleteSync();
      await produced.rename(outputPath);
      return target;
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  // ── playlists ────────────────────────────────────────────────────────────

  Future<_MediaPlaylist> _loadMediaPlaylist(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final text = await _getText(url, headers: headers);
    if (!text.trimLeft().startsWith('#EXTM3U')) {
      throw HlsDownloadException('That link is not an HLS playlist.');
    }

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // A master playlist offers variants; take the highest bandwidth one.
    final variants = <({Uri uri, double bandwidth})>[];
    for (final line in lines) {
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final attrs = _attributes(_valueOf(line));
      final uri = attrs['URI'];
      if (uri == null) continue;
      variants.add((
        uri: url.resolve(uri),
        bandwidth: double.tryParse(attrs['BANDWIDTH'] ?? '') ?? 0,
      ));
    }
    if (variants.isNotEmpty) {
      variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
      return _loadMediaPlaylist(variants.first.uri, headers: headers);
    }

    return _parseMediaPlaylist(lines, url);
  }

  _MediaPlaylist _parseMediaPlaylist(List<String> lines, Uri base) {
    final segments = <_Segment>[];
    var targetSeconds = 2;
    var hasEndList = false;
    var duration = Duration.zero;
    Uri? keyUri;
    Uint8List? iv;
    var sequence = 0;
    var sawMap = false;

    for (final line in lines) {
      if (line == '#EXT-X-ENDLIST') {
        hasEndList = true;
      } else if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        targetSeconds = int.tryParse(_valueOf(line)) ?? targetSeconds;
      } else if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        sequence = int.tryParse(_valueOf(line)) ?? sequence;
      } else if (line.startsWith('#EXT-X-MAP:')) {
        // fMP4 segments can't be demuxed out of TS; say so instead of
        // silently writing a broken file.
        sawMap = true;
      } else if (line.startsWith('#EXT-X-KEY:')) {
        final attrs = _attributes(_valueOf(line));
        final method = (attrs['METHOD'] ?? 'NONE').toUpperCase();
        if (method == 'NONE') {
          keyUri = null;
          iv = null;
        } else if (method == 'AES-128') {
          final uri = attrs['URI'];
          if (uri != null) {
            keyUri = base.resolve(uri);
            iv = _parseIv(attrs['IV']);
          }
        } else {
          throw HlsDownloadException(
            'This stream uses $method encryption, which cannot be saved.',
          );
        }
      } else if (line.startsWith('#EXTINF:')) {
        final seconds = double.tryParse(
          _valueOf(line).split(',').first,
        ) ??
            0;
        duration = Duration(milliseconds: (seconds * 1000).round());
      } else if (!line.startsWith('#')) {
        if (segments.length >= _maxSegments) break;
        segments.add(
          _Segment(
            uri: base.resolve(line),
            duration: duration,
            sequence: sequence++,
            keyUri: keyUri,
            iv: iv,
          ),
        );
        duration = Duration.zero;
      }
    }

    if (sawMap && segments.isNotEmpty) {
      throw HlsDownloadException(
        'This stream uses fragmented MP4 segments, which cannot be saved yet.',
      );
    }

    return _MediaPlaylist(
      segments: segments,
      targetDuration: Duration(seconds: targetSeconds),
      hasEndList: hasEndList,
    );
  }

  static Uint8List? _parseIv(String? raw) {
    if (raw == null) return null;
    final hex = raw.startsWith('0x') || raw.startsWith('0X')
        ? raw.substring(2)
        : raw;
    if (hex.length != 32) return null;
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      final pair = hex.substring(i * 2, i * 2 + 2);
      final value = int.tryParse(pair, radix: 16);
      if (value == null) return null;
      bytes[i] = value;
    }
    return bytes;
  }

  // ── segments ─────────────────────────────────────────────────────────────

  Future<Uint8List> _fetchSegment(
    _Segment seg, {
    Map<String, String>? headers,
    void Function()? onOne,
  }) async {
    final bytes = await _getBytes(seg.uri, headers: headers);
    if (seg.keyUri == null) return bytes;

    final key = await _getBytes(seg.keyUri!, headers: headers);
    // With no explicit IV, HLS uses the media sequence number as a big-endian
    // 128-bit integer.
    final iv = seg.iv ?? _ivForSequence(seg.sequence);
    return _aes128CbcDecrypt(bytes, key, iv);
  }

  static Uint8List _ivForSequence(int sequence) {
    final iv = Uint8List(16);
    ByteData.sublistView(iv).setUint64(8, sequence);
    return iv;
  }

  /// AES-128-CBC decryption with PKCS#7 padding removed.
///
/// Decryption is expressed as CBC *encryption* (XOR is symmetric), using
/// pointycastle — `package:crypto` only provides digests.
Uint8List _aes128CbcDecrypt(
  Uint8List data,
  Uint8List key,
  Uint8List iv,
) {
  if (key.length != 16 || iv.length != 16) {
    throw HlsDownloadException('Invalid AES-128 key or IV length.');
  }
  if (data.isEmpty) return Uint8List(0);
  if (data.length % 16 != 0) {
    throw HlsDownloadException(
      'Encrypted segment length (${data.length}) is not a multiple of 16.',
    );
  }

  // AES-CBC decryption = CBC encryption of the ciphertext (XOR is symmetric).
  // No padding wrapper: HLS AES-128 uses PKCS#7, stripped explicitly below.
  final cipher = CBCBlockCipher(AESEngine())
    ..init(
      false,
      ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
    );

  final blockSize = cipher.blockSize;
  final out = Uint8List(data.length);
  var written = 0;
  var offset = 0;
  while (offset + blockSize <= data.length) {
    cipher.processBlock(data, offset, out, written);
    offset += blockSize;
    written += blockSize;
  }
  if (written == 0) return Uint8List(0);

  // Strip PKCS#7 padding.
  final pad = out[written - 1];
  if (pad >= 1 && pad <= 16 && pad <= written) {
    return Uint8List.sublistView(out, 0, written - pad);
  }
  return Uint8List.sublistView(out, 0, written);
}

  Future<String> _getText(Uri url, {Map<String, String>? headers}) async {
    final res = await _dio.get<List<int>>(
      url.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return utf8.decode(res.data ?? const [], allowMalformed: true);
  }

  Future<Uint8List> _getBytes(Uri url, {Map<String, String>? headers}) async {
    final res = await _dio.get<List<int>>(
      url.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 45),
      ),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  /// Everything after the tag's first colon.
  ///
  /// Must be the *first* colon: attribute values such as
  /// `URI="http://host/key"` contain further colons, and splitting on the last
  /// one silently truncates the URL.
  static String _valueOf(String line) {
    final i = line.indexOf(':');
    return i < 0 ? '' : line.substring(i + 1);
  }

  static Map<String, String> _attributes(String input) {
    final out = <String, String>{};
    for (final m in RegExp(
      r'([A-Za-z0-9\-]+)=("[^"]*"|[^,]*)',
    ).allMatches(input)) {
      var value = m.group(2) ?? '';
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      out[m.group(1)!] = value;
    }
    return out;
  }
}

class _MediaPlaylist {
  const _MediaPlaylist({
    required this.segments,
    required this.targetDuration,
    required this.hasEndList,
  });

  final List<_Segment> segments;
  final Duration targetDuration;
  final bool hasEndList;
}

class _Segment {
  const _Segment({
    required this.uri,
    required this.duration,
    required this.sequence,
    required this.keyUri,
    required this.iv,
  });

  final Uri uri;
  final Duration duration;
  final int sequence;
  final Uri? keyUri;
  final Uint8List? iv;
}

// ─────────────────────────────────────────────────────────────────────────────
// MPEG-TS → samples → minimal MP4
// ─────────────────────────────────────────────────────────────────────────────
// MPEG-TS → samples → minimal MP4
// ─────────────────────────────────────────────────────────────────────────────

const int _tsPacket = 188;

class _ElementaryTrack {
  _ElementaryTrack({
    required this.samples,
    required this.timescale,
    required this.sampleDuration,
    this.width = 0,
    this.height = 0,
    this.sps,
    this.pps,
    this.sampleRate = 0,
    this.channels = 0,
  });

  /// One entry per access unit / audio frame, without any length prefix.
  final List<Uint8List> samples;
  final int timescale;
  final int sampleDuration;
  final int width;
  final int height;
  final Uint8List? sps;
  final Uint8List? pps;
  final int sampleRate;
  final int channels;
}

class _TsTracks {
  const _TsTracks(this.video, this.audio);
  final _ElementaryTrack? video;
  final _ElementaryTrack? audio;
}

/// Builds a progressive MP4 from an MPEG-TS byte stream. Returns false when
/// neither H.264 video nor AAC audio could be recovered.
bool buildMp4FromTransportStream(Uint8List ts, String outputPath) {
  final tracks = _demuxTransportStream(ts);
  if (tracks.video == null && tracks.audio == null) return false;

  final builder = _Mp4Builder();
  if (tracks.video != null) builder.addVideo(tracks.video!);
  if (tracks.audio != null) builder.addAudio(tracks.audio!);
  File(outputPath).writeAsBytesSync(builder.build(), flush: true);
  return true;
}

_TsTracks _demuxTransportStream(Uint8List ts) {
  final pmtPid = _findPmtPid(ts);
  final pids = _findElementaryPids(ts, pmtPid);
  if (pids == null) return const _TsTracks(null, null);

  final videoPid = pids.videoPid;
  final audioPid = pids.audioPid;
  if (videoPid < 0 && audioPid < 0) return const _TsTracks(null, null);

  final videoPes = <Uint8List>[];
  final audioPes = <Uint8List>[];
  // BytesBuilder rather than a growing Uint8List: appending to one of those
  // per 188-byte packet is quadratic over a full-length movie.
  BytesBuilder? videoBuffer;
  BytesBuilder? audioBuffer;

  var pos = 0;
  while (pos + _tsPacket <= ts.length) {
    if (ts[pos] != 0x47) {
      final next = _nextSync(ts, pos + 1);
      if (next < 0) break;
      pos = next;
      continue;
    }

    final base = pos;
    final pid = ((ts[base + 1] & 0x1F) << 8) | ts[base + 2];
    // TS header byte 1: [TEI][payload_unit_start_indicator][priority][PID hi].
    // The start flag is 0x40; 0x20 is the transport-priority bit.
    final payloadStart = (ts[base + 1] & 0x40) != 0;
    final afc = (ts[base + 3] >> 4) & 0x03;
    var offset = base + 4;

    if (afc == 0 || afc == 2) {
      pos += _tsPacket;
      continue;
    }
    if (afc == 3) {
      offset += 1 + ts[offset];
      if (offset > base + _tsPacket) {
        pos += _tsPacket;
        continue;
      }
    }
    if (offset >= base + _tsPacket) {
      pos += _tsPacket;
      continue;
    }

    if (pid == videoPid) {
      if (payloadStart) {
        final finished = videoBuffer;
        if (finished != null) {
          final pes = _stripPesHeader(finished.toBytes());
          if (pes != null) videoPes.add(pes);
        }
        videoBuffer = BytesBuilder(copy: true);
      }
      videoBuffer?.add(
        Uint8List.sublistView(ts, offset, base + _tsPacket),
      );
    } else if (pid == audioPid) {
      if (payloadStart) {
        final finished = audioBuffer;
        if (finished != null) {
          final pes = _stripPesHeader(finished.toBytes());
          if (pes != null) audioPes.add(pes);
        }
        audioBuffer = BytesBuilder(copy: true);
      }
      audioBuffer?.add(
        Uint8List.sublistView(ts, offset, base + _tsPacket),
      );
    }

    pos += _tsPacket;
  }

  final videoTail = videoBuffer;
  if (videoTail != null) {
    final pes = _stripPesHeader(videoTail.toBytes());
    if (pes != null) videoPes.add(pes);
  }
  final audioTail = audioBuffer;
  if (audioTail != null) {
    final pes = _stripPesHeader(audioTail.toBytes());
    if (pes != null) audioPes.add(pes);
  }

  return _TsTracks(
    videoPid >= 0 && videoPes.isNotEmpty ? _videoTrack(videoPes) : null,
    audioPid >= 0 && audioPes.isNotEmpty ? _audioTrack(audioPes) : null,
  );
}

int _nextSync(Uint8List data, int from) {
  for (var i = from; i < data.length; i++) {
    if (data[i] == 0x47) return i;
  }
  return -1;
}

Uint8List? _stripPesHeader(Uint8List pes) {
  if (pes.length < 9) return null;
  if (pes[0] != 0x00 || pes[1] != 0x00 || pes[2] != 0x01) return null;
  final headerDataLength = pes[8];
  final start = 9 + headerDataLength;
  if (start >= pes.length) return null;
  return Uint8List.sublistView(pes, start);
}

class _PmtInfo {
  const _PmtInfo(this.videoPid, this.audioPid);
  final int videoPid;
  final int audioPid;
}

/// Reads the PAT to locate the PMT PID.
int _findPmtPid(Uint8List ts) {
  for (var pos = 0; pos + _tsPacket <= ts.length; pos += _tsPacket) {
    if (ts[pos] != 0x47) continue;
    if (((ts[pos + 1] & 0x1F) << 8) | ts[pos + 2] != 0) continue;
    // No payload-start requirement: some muxers send PSI with the flag clear.
    final section = _psiSection(ts, pos, 0x00);
    if (section == null) continue;

    // Program entries sit between the 8-byte fixed header and the 4-byte CRC.
    final entriesEnd = section.length - 4;
    var i = 8;
    while (i + 4 <= entriesEnd) {
      final program = (section[i] << 8) | section[i + 1];
      final pid = ((section[i + 2] & 0x1F) << 8) | section[i + 3];
      if (program != 0) return pid;
      i += 4;
    }
  }
  return -1;
}

/// Reads the PMT to find the H.264 and AAC elementary PIDs.
_PmtInfo? _findElementaryPids(Uint8List ts, int pmtPid) {
  if (pmtPid < 0) return null;
  for (var pos = 0; pos + _tsPacket <= ts.length; pos += _tsPacket) {
    if (ts[pos] != 0x47) continue;
    if (((ts[pos + 1] & 0x1F) << 8) | ts[pos + 2] != pmtPid) continue;
    final section = _psiSection(ts, pos, 0x02);
    if (section == null) continue;

    final programInfoLength = ((section[10] & 0x0F) << 8) | section[11];
    var i = 12 + programInfoLength;
    final entriesEnd = section.length - 4;
    int? videoPid;
    int? audioPid;
    while (i + 5 <= entriesEnd) {
      final streamType = section[i];
      final pid = ((section[i + 1] & 0x1F) << 8) | section[i + 2];
      final esInfoLength = ((section[i + 3] & 0x0F) << 8) | section[i + 4];
      if (streamType == 0x1b && videoPid == null) {
        videoPid = pid; // H.264
      } else if ((streamType == 0x0f || streamType == 0x11) &&
          audioPid == null) {
        audioPid = pid; // AAC
      }
      i += 5 + esInfoLength;
    }
    if (videoPid == null && audioPid == null) return null;
    return _PmtInfo(videoPid ?? -1, audioPid ?? -1);
  }
  return null;
}

/// Finds a PSI section with the given table id in this TS packet.
///
/// Real muxers are inconsistent here: some set the payload-start flag and
/// prefix the payload with a pointer field, others (ffmpeg among them) emit a
/// pointer field with the flag clear, and others start the section immediately.
/// Guessing produced the wrong PMT PID, so candidates are accepted only when
/// their MPEG-2 CRC-32 checks out — that makes the parse unambiguous.
Uint8List? _psiSection(Uint8List ts, int packetStart, int expectedTableId) {
  var i = packetStart + 4;
  final afc = (ts[packetStart + 3] >> 4) & 0x03;
  if (afc == 3) i += 1 + ts[i];
  final end = packetStart + _tsPacket;
  if (i >= end) return null;

  // When the payload-start flag is set the payload begins with a pointer
  // field, so the section may not be at offset 0.
  if ((ts[packetStart + 1] & 0x40) != 0) {
    i += 1 + ts[i];
  }

  final limit = min(i + 24, end);
  for (var k = i; k + 8 <= limit; k++) {
    if (ts[k] != expectedTableId) continue;
    final sectionLength = ((ts[k + 1] & 0x0F) << 8) | ts[k + 2];
    final total = 3 + sectionLength;
    if (total < 8 || k + total > end) continue;
    final candidate = Uint8List.sublistView(ts, k, k + total);
    if (_mpegCrc32(candidate) == 0) return candidate;
  }
  return null;
}

/// MPEG-2 systems CRC-32 (poly 0x04C11DB7, no reflection, no final XOR).
/// Returns 0 for a well-formed section, CRC appended.
int _mpegCrc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte << 24;
    for (var i = 0; i < 8; i++) {
      if ((crc & 0x80000000) != 0) {
        crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
      } else {
        crc = (crc << 1) & 0xFFFFFFFF;
      }
    }
  }
  return crc;
}

/// Splits an Annex-B byte stream into NAL units (without start codes).
///
/// The prefix start of each NAL is tracked separately from its payload start:
/// naively cutting at the next payload start leaves the `00 00 01` of the
/// *following* start code attached to the current NAL, which silently corrupts
/// SPS/PPS and every sample.
List<Uint8List> _splitAnnexB(Uint8List data) {
  final prefixStarts = <int>[];
  final nalStarts = <int>[];

  for (var i = 0; i + 3 < data.length; i++) {
    if (data[i] != 0 || data[i + 1] != 0) continue;
    if (data[i + 2] == 1) {
      prefixStarts.add(i);
      nalStarts.add(i + 3);
      i += 2;
    } else if (i + 4 < data.length && data[i + 2] == 0 && data[i + 3] == 1) {
      prefixStarts.add(i);
      nalStarts.add(i + 4);
      i += 3;
    }
  }
  if (nalStarts.isEmpty) return const [];

  final nals = <Uint8List>[];
  for (var k = 0; k < nalStarts.length; k++) {
    var s = nalStarts[k];
    // Skip any extra leading zero bytes of the NAL itself.
    while (s < data.length && data[s] == 0) {
      s++;
    }
    var e = k + 1 < prefixStarts.length ? prefixStarts[k + 1] : data.length;
    // Trim trailing zero padding (cabac_zero_words and friends).
    while (e > s && data[e - 1] == 0) {
      e--;
    }
    if (e > s) nals.add(Uint8List.fromList(data.sublist(s, e)));
  }
  return nals;
}

const int _kVideoTimescale = 90000;

_ElementaryTrack? _videoTrack(List<Uint8List> pesList) {
  // One TS PES carries exactly one access unit, so PES boundaries are the
  // reliable frame boundaries. Many encoders (including libopenh264) emit no
  // AUD NAL units at all, which makes AUD-based grouping collapse the whole
  // video into a single sample.
  Uint8List? sps;
  Uint8List? pps;
  final samples = <Uint8List>[];

  for (final pes in pesList) {
    final nals = _splitAnnexB(pes);
    if (nals.isEmpty) continue;
    final frame = BytesBuilder();
    for (final nal in nals) {
      final type = nal[0] & 0x1F;
      switch (type) {
        case 7:
          sps ??= nal;
        case 8:
          pps ??= nal;
        case 1: // non-IDR slice
        case 5: // IDR slice
        case 6: // SEI, carried with the picture
          frame.add(nal);
        default:
          break;
      }
    }
    if (frame.isNotEmpty) samples.add(frame.toBytes());
  }

  if (samples.isEmpty || sps == null || pps == null) return null;

  final dims = _spsDimensions(sps);
  return _ElementaryTrack(
    samples: samples,
    timescale: _kVideoTimescale,
    // Uniform timing: the remuxer only needs monotonic per-sample deltas to
    // build cluster timestamps, and every HLS segment duration is a whole
    // number of frames, so 25 fps keeps A/V in step with the AAC track.
    sampleDuration: _kVideoTimescale ~/ 25,
    width: dims.$1 == 0 ? 1280 : dims.$1,
    height: dims.$2 == 0 ? 720 : dims.$2,
    sps: sps,
    pps: pps,
  );
}

const List<int> _aacRates = [
  96000, 88200, 64000, 48000, 44100, 32000,
  24000, 22050, 16000, 12000, 11025, 8000, 7350,
];

_ElementaryTrack? _audioTrack(List<Uint8List> pesList) {
  final bytes = BytesBuilder();
  for (final pes in pesList) {
    bytes.add(pes);
  }
  final data = bytes.toBytes();
  if (data.length < 7) return null;

  final samples = <Uint8List>[];
  var i = 0;
  var rate = 0;
  var channels = 0;
  while (i + 7 <= data.length) {
    if (data[i] != 0xFF || (data[i + 1] & 0xF0) != 0xF0) {
      i++;
      continue;
    }
    final headerLength = (data[i + 1] & 0x01) != 0 ? 7 : 9;
    final frameLength =
        ((data[i + 3] & 0x03) << 11) |
        ((data[i + 4] & 0xFF) << 3) |
        ((data[i + 5] & 0xE0) >> 5);
    if (frameLength <= headerLength || i + frameLength > data.length) {
      i++;
      continue;
    }
    if (rate == 0) {
      final index = (data[i + 2] & 0x3C) >> 2;
      rate = _aacRates[index.clamp(0, _aacRates.length - 1)];
      channels = ((data[i + 2] & 0x01) << 2) | ((data[i + 3] & 0xC0) >> 6);
    }
    samples.add(Uint8List.sublistView(data, i + headerLength, i + frameLength));
    i += frameLength;
  }
  if (samples.isEmpty) return null;

  return _ElementaryTrack(
    samples: samples,
    timescale: rate == 0 ? 48000 : rate,
    sampleDuration: 1024,
    sampleRate: rate == 0 ? 48000 : rate,
    channels: channels == 0 ? 2 : channels,
  );
}

/// Reads width/height from an SPS.
(int, int) _spsDimensions(Uint8List sps) {
  try {
    final rbsp = _stripEmulation(sps.sublist(1));
    final br = _BitReader(rbsp);
    final profile = br.bits(8);
    br.bits(8);
    br.bits(8);
    br.ue();
    const highProfiles = [100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 144];
    if (highProfiles.contains(profile)) {
      final chroma = br.ue();
      if (chroma == 3) br.bits(1);
      br.ue();
      br.ue();
      br.bits(1);
      if (br.bits(1) == 1) {
        final count = chroma == 3 ? 12 : 8;
        for (var i = 0; i < count; i++) {
          if (br.bits(1) == 1) {
            final size = i < 6 ? 16 : 64;
            var last = 8;
            var next = 8;
            for (var j = 0; j < size; j++) {
              if (next != 0) {
                next = (last + br.se() + 256) % 256;
              }
              last = next == 0 ? last : next;
            }
          }
        }
      }
    }
    br.ue();
    final pocType = br.ue();
    if (pocType == 0) {
      br.ue();
    } else if (pocType == 1) {
      br.bits(1);
      br.se();
      br.se();
      final n = br.ue();
      for (var i = 0; i < n; i++) {
        br.se();
      }
    }
    br.ue();
    br.bits(1);
    final widthMbs = br.ue() + 1;
    final heightUnits = br.ue() + 1;
    final frameMbsOnly = br.bits(1);
    return (
      widthMbs * 16,
      heightUnits * 16 * (frameMbsOnly == 1 ? 1 : 2),
    );
  } catch (_) {
    return (0, 0);
  }
}

Uint8List _stripEmulation(Uint8List data) {
  final out = BytesBuilder();
  var zeros = 0;
  for (final b in data) {
    if (zeros >= 2 && b == 0x03) {
      zeros = 0;
      continue;
    }
    out.addByte(b);
    zeros = b == 0 ? zeros + 1 : 0;
  }
  return out.toBytes();
}

class _BitReader {
  _BitReader(this.data);
  final Uint8List data;
  int _pos = 0;

  int bits(int n) {
    var value = 0;
    for (var i = 0; i < n; i++) {
      final byte = data[_pos >> 3];
      value = (value << 1) | ((byte >> (7 - (_pos & 7))) & 1);
      _pos++;
    }
    return value;
  }

  int ue() {
    var zeros = 0;
    while (bits(1) == 0) {
      zeros++;
      if (zeros > 32) return 0;
    }
    var value = 1;
    for (var i = 0; i < zeros; i++) {
      value = (value << 1) | bits(1);
    }
    return value - 1;
  }

  int se() {
    final code = ue();
    final magnitude = (code + 1) >> 1;
    return (code & 1) == 1 ? magnitude : -magnitude;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal MP4 writer
// ─────────────────────────────────────────────────────────────────────────────

/// Writes a progressive (non-fragmented) MP4 whose box layout matches what the
/// MP4→MKV remuxer parses: stsd/stts/stss/stsc/stsz/stco, with one chunk per
/// sample and absolute `stco` offsets.
class _Mp4Builder {
  final _tracks = <_Track>[];

  void addVideo(_ElementaryTrack t) =>
      _tracks.add(_Track(t, isVideo: true, id: 1));
  void addAudio(_ElementaryTrack t) =>
      _tracks.add(_Track(t, isVideo: false, id: 2));

  Uint8List build() {
    final ftyp = _ftyp();
    // moov is built with zeroed stco values; the real absolute offsets depend
    // on moov's own size. Every field here is fixed-width, so the layout never
    // changes size and the slots can simply be patched afterwards.
    final moov = _moov();
    final mdatPayload = _mdatPayload();
    final mdatBox = _box('mdat', mdatPayload);

    final out = Uint8List(
      ftyp.length + moov.length + mdatBox.length,
    );
    var offset = 0;
    out.setRange(offset, offset += ftyp.length, ftyp);
    out.setRange(offset, offset += moov.length, moov);
    out.setRange(offset, offset + mdatBox.length, mdatBox);

    // Locate each stco box inside moov (in track order) and write the
    // absolute file offset of every sample.
    final mdatDataStart = ftyp.length + moov.length + 8;
    var cursor = mdatDataStart;
    var searchFrom = 0;
    for (final t in _tracks) {
      final boxStart = _findBox(moov, 'stco', searchFrom);
      if (boxStart < 0) break;
      // boxStart points at the size field; values start after
      // size(4) + type(4) + version/flags(4) + entry_count(4).
      var valueAt = boxStart + 16;
      for (var i = 0; i < t.samples.length; i++) {
        _setU32(out, ftyp.length + valueAt, cursor);
        cursor += t.samples[i].length + (t.isVideo ? 4 : 0);
        valueAt += 4;
      }
      searchFrom = valueAt;
    }
    return out;
  }

  /// Finds the next box of [type] at or after [from] inside [bytes].
  static int _findBox(Uint8List bytes, String type, int from) {
    final tag = type.codeUnits;
    for (var i = from; i + 8 <= bytes.length; i++) {
      var match = true;
      for (var k = 0; k < 4; k++) {
        if (bytes[i + 4 + k] != tag[k]) {
          match = false;
          break;
        }
      }
      if (!match) continue;
      final size =
          (bytes[i] << 24) |
          (bytes[i + 1] << 16) |
          (bytes[i + 2] << 8) |
          bytes[i + 3];
      if (size >= 8) return i;
    }
    return -1;
  }

  static void _setU32(Uint8List dst, int at, int value) {
    dst[at] = (value >> 24) & 0xFF;
    dst[at + 1] = (value >> 16) & 0xFF;
    dst[at + 2] = (value >> 8) & 0xFF;
    dst[at + 3] = value & 0xFF;
  }

  Uint8List _ftyp() => _box('ftyp', [
    ..._ascii('isom'),
    0, 0, 2, 0,
    ..._ascii('isom'),
    ..._ascii('iso2'),
    ..._ascii('avc1'),
    ..._ascii('mp41'),
  ]);

  List<int> _mdatPayload() {
    final out = BytesBuilder();
    for (final t in _tracks) {
      for (final s in t.samples) {
        // Only H.264 samples are length-prefixed NAL lists. An AAC sample in an
        // MP4 is a raw access unit — adding a 4-byte length corrupts every
        // frame and the decoder rejects the stream.
        if (t.isVideo) {
          out
            ..addByte((s.length >> 24) & 0xFF)
            ..addByte((s.length >> 16) & 0xFF)
            ..addByte((s.length >> 8) & 0xFF)
            ..addByte(s.length & 0xFF);
        }
        out.add(s);
      }
    }
    return out.toBytes();
  }

  Uint8List _moov() {
    final duration = _tracks.isEmpty
        ? 0
        : _tracks.map((t) => t.duration).reduce(max);
    final body = BytesBuilder()
      ..add(_mvhd(_tracks.first.timescale, duration))
      ..add(_trkn(_tracks));
    return _box('moov', body.toBytes());
  }

  List<int> _trkn(List<_Track> tracks) {
    final out = BytesBuilder();
    for (final t in tracks) {
      out.add(_trak(t));
    }
    return out.toBytes();
  }

  Uint8List _mvhd(int timescale, int duration) => _box('mvhd', [
    0, 0, 0, 0, // version/flags
    ..._u32(0), ..._u32(0), // creation, modification
    ..._u32(timescale),
    ..._u32(duration),
    ..._u32(0x00010000),
    ..._u16(0x0100),
    ..._u16(0),
    ..._u32(0), ..._u32(0),
    ..._unityMatrix(),
    ..._u32(0), ..._u32(0), ..._u32(0), ..._u32(0), ..._u32(0), ..._u32(0),
    ..._u32(_tracks.length + 1),
  ]);

  List<int> _unityMatrix() => [
    ..._u32(0x00010000), ..._u32(0), ..._u32(0),
    ..._u32(0), ..._u32(0x00010000), ..._u32(0),
    ..._u32(0), ..._u32(0), ..._u32(0x40000000),
  ];

  Uint8List _trak(_Track t) => _box('trak', [..._tkhd(t), ..._mdia(t)]);

  /// TrackHeader: version/flags, ids, duration, 4 u16s (layer,
  /// alternate_group, volume, reserved), the matrix, then 16.16 dimensions.
  Uint8List _tkhd(_Track t) => _box('tkhd', [
    0, 0, 0, 7, // version/flags (enabled | in movie)
    ..._u32(0), // creation
    ..._u32(0), // modification
    ..._u32(t.id), // track_ID
    ..._u32(0), // reserved
    ..._u32(t.duration),
    ..._u32(0), // reserved
    ..._u32(0), // reserved
    ..._u16(0), // layer
    ..._u16(0), // alternate_group
    ..._u16(t.isVideo ? 0 : 0x0100), // volume
    ..._u16(0), // reserved
    ..._unityMatrix(),
    ..._u32(t.isVideo ? (t.width << 16) : 0),
    ..._u32(t.isVideo ? (t.height << 16) : 0),
  ]);

  Uint8List _mdia(_Track t) =>
      _box('mdia', [..._mdhd(t), ..._hdlr(t), ..._minf(t)]);

  Uint8List _mdhd(_Track t) => _box('mdhd', [
    0, 0, 0, 0,
    ..._u32(0), ..._u32(0),
    ..._u32(t.timescale),
    ..._u32(t.duration),
    ..._u16(0x55C4),
    ..._u16(0),
  ]);

  Uint8List _hdlr(_Track t) => _box('hdlr', [
    0, 0, 0, 0,
    ..._u32(0),
    ..._ascii(t.isVideo ? 'vide' : 'soun'),
    ..._u32(0), ..._u32(0), ..._u32(0),
    ..._ascii(t.isVideo ? 'VideoHandler' : 'SoundHandler'),
    0,
  ]);

  Uint8List _minf(_Track t) => _box('minf', [
    ..._dinf(),
    ...(t.isVideo ? _vmhd() : _smhd()),
    ..._stbl(t),
  ]);

  /// DataInformation → DataReferenceBox holding one self-contained 'url ' entry.
  Uint8List _dinf() {
    final url = _box('url ', [0, 0, 0, 1]); // flags: media in same file
    return _box('dinf', [
      ..._box('dref', [
        0, 0, 0, 0, // version/flags
        ..._u32(1), // entry_count
        ...url,
      ]),
    ]);
  }

  Uint8List _vmhd() => _box('vmhd', [
    0, 0, 0, 1,
    ..._u16(0),
    ..._u16(0), ..._u16(0), ..._u16(0), ..._u16(0), ..._u16(0),
  ]);

  Uint8List _smhd() => _box('smhd', [
    0, 0, 0, 0,
    ..._u16(0),
    ..._u16(0), ..._u16(0),
  ]);

  Uint8List _stbl(_Track t) => _box('stbl', [
    ..._stsd(t),
    ..._stts(t),
    ..._stss(t),
    ..._stsc(),
    ..._stsz(t),
    ..._stco(t),
  ]);

  Uint8List _stsd(_Track t) => _box('stsd', [
    0, 0, 0, 0,
    ..._u32(1),
    ...(t.isVideo ? _avc1(t) : _mp4a(t)),
  ]);

  /// VisualSampleEntry: 6 reserved, data_reference_index, 16 pre-defined
  /// bytes, then the visual fields, then the avcC child box.
  Uint8List _avc1(_Track t) {
    final entry = BytesBuilder()
      ..add(_u32(0)) // reserved (6 bytes total)
      ..add(_u16(0))
      ..add(_u16(1)) // data_reference_index
      ..add(_u16(0)) // pre_defined
      ..add(_u16(0)) // reserved
      ..add(_u32(0)) // pre_defined[3]
      ..add(_u32(0))
      ..add(_u32(0))
      ..add(_u16(t.width))
      ..add(_u16(t.height))
      ..add(_u32(0x00480000)) // 72 dpi horizontal
      ..add(_u32(0x00480000)) // 72 dpi vertical
      ..add(_u32(0)) // reserved
      ..add(_u16(1)) // frame_count
      ..add(Uint8List(32)) // compressorname (pascal string, zero padded)
      ..add(_u16(0x0018)) // depth
      ..add(_u16(0xFFFF)) // pre_defined = -1
      ..add(_avcC(t.sps!, t.pps!));
    return _box('avc1', entry.toBytes());
  }

  Uint8List _avcC(Uint8List sps, Uint8List pps) => _box('avcC', [
    1,
    sps[1],
    sps[2],
    sps[3],
    0xFF, // lengthSizeMinusOne = 3
    0xE1, // one SPS
    ..._u16(sps.length),
    ...sps,
    1, // one PPS
    ..._u16(pps.length),
    ...pps,
  ]);

  /// AudioSampleEntry: 6 reserved, data_reference_index, 8 reserved, then the
  /// audio fields, then the esds child box.
  Uint8List _mp4a(_Track t) {
    final entry = BytesBuilder()
      ..add(_u32(0)) // reserved (6 bytes total)
      ..add(_u16(0))
      ..add(_u16(1)) // data_reference_index
      ..add(_u32(0)) // reserved (8 bytes total)
      ..add(_u32(0))
      ..add(_u16(t.channels))
      ..add(_u16(16)) // sample size
      ..add(_u16(0)) // pre_defined
      ..add(_u16(0)) // reserved
      // samplerate is 16.16 fixed point: the integer rate occupies the HIGH
      // 16 bits, so 48000 is 0xBB800000 — not 0x0000BB80.
      ..add(_u32(t.sampleRate << 16))
      ..add(_esds(t));
    return _box('mp4a', entry.toBytes());
  }

  /// esds is a FullBox, so the descriptor chain is preceded by 4 bytes of
  /// version/flags — without them the decoder never finds the
  /// DecoderSpecificInfo and falls back to a garbage AudioSpecificConfig.
  /// DecoderConfigDescriptor also has to precede SLConfigDescriptor: the mov
  /// demuxer walks these in order and stops hunting for tag 5 once it meets
  /// tag 6 first.
  Uint8List _esds(_Track t) {
    final dsi = _descriptor(0x05, _audioSpecificConfig(t));
    // Reasonable bitrate estimates; zeros are legal but real muxers fill these
    // in and some demuxers use them for stream setup.
    final bytes = t.samples.fold<int>(0, (a, s) => a + s.length);
    final avgBitrate = bytes * 8 * t.timescale ~/ (t.duration * 1000);
    final dcd = _descriptor(0x04, [
      0x40, // MPEG-4 AAC
      0x15, // audio stream
      0x00, // buffer size
      ..._u32(avgBitrate * 2), // max bitrate
      ..._u32(avgBitrate), // avg bitrate
      ...dsi,
    ]);
    final sl = _descriptor(0x06, [2]);
    final es = _descriptor(0x03, [
      ..._u16(2), // ES_ID
      0, // flags
      ...dcd,
      ...sl,
    ]);
    return _box('esds', [0, 0, 0, 0, ...es]);
  }

  /// AudioSpecificConfig:
  /// 5 bits object type, 4 bits frequency index, 4 bits channel configuration.
  /// For AAC-LC at 48 kHz mono that is 0x1188, matching ffmpeg's output.
  static Uint8List _audioSpecificConfig(_Track t) {
    final index = _aacRates.indexOf(t.sampleRate);
    final sr = index < 0 ? 4 : index;
    final value =
        (2 << 11) | (sr << 7) | (t.channels.clamp(1, 15) << 3);
    return Uint8List.fromList([(value >> 8) & 0xFF, value & 0xFF]);
  }

  /// Builds an MPEG-4 descriptor using the 4-byte expandable length form
  /// (`80 80 80 <len>`) that ffmpeg and the other mainstream muxers emit.
  /// The 1-byte form is legal, but matching the reference writer removes any
  /// doubt about how a demuxer walks the chain.
  static Uint8List _descriptor(int tag, List<int> payload) {
    final length = payload.length;
    return Uint8List.fromList([
      tag,
      0x80,
      0x80,
      0x80,
      length & 0xFF, // payload is always < 128 bytes here
      ...payload,
    ]);
  }

  Uint8List _stts(_Track t) => _box('stts', [
    0, 0, 0, 0,
    ..._u32(1),
    ..._u32(t.samples.length),
    ..._u32(t.sampleDuration),
  ]);

  Uint8List _stss(_Track t) {
    if (!t.isVideo) return Uint8List(0);
    final b = BytesBuilder()
      ..add([0, 0, 0, 0])
      ..add(_u32(t.samples.length));
    for (var i = 0; i < t.samples.length; i++) {
      b.add(_u32(i + 1));
    }
    return _box('stss', b.toBytes());
  }

  Uint8List _stsc() => _box('stsc', [
    0, 0, 0, 0,
    ..._u32(1),
    ..._u32(1), // first_chunk
    ..._u32(1), // samples_per_chunk
    ..._u32(1), // sample_description_index
  ]);

  Uint8List _stsz(_Track t) {
    final b = BytesBuilder()
      ..add([0, 0, 0, 0])
      ..add(_u32(0))
      ..add(_u32(t.samples.length));
    for (final s in t.samples) {
      // stsz stores the on-disk size, so the 4-byte NAL prefix counts only for
      // video.
      b.add(_u32(t.isVideo ? s.length + 4 : s.length));
    }
    return _box('stsz', b.toBytes());
  }

  Uint8List _stco(_Track t) {
    final b = BytesBuilder()
      ..add([0, 0, 0, 0])
      ..add(_u32(t.samples.length));
    // Reserve the value bytes; build() patches them with absolute offsets.
    for (var i = 0; i < t.samples.length; i++) {
      b.add(Uint8List(4));
    }
    return _box('stco', b.toBytes());
  }

  static List<int> _ascii(String s) => s.codeUnits;

  static Uint8List _u32(int v) => Uint8List.fromList([
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ]);

  static Uint8List _u16(int v) =>
      Uint8List.fromList([(v >> 8) & 0xFF, v & 0xFF]);

  static Uint8List _box(String type, List<int> body) {
    final out = BytesBuilder()
      ..add(_u32(8 + body.length))
      ..add(_ascii(type))
      ..add(body);
    return out.toBytes();
  }
}

/// One track in the generated MP4, with the stco slots kept addressable so the
/// absolute chunk offsets can be patched once the layout is known.
class _Track {
  _Track(this.source, {required this.isVideo, required this.id})
    : timescale = source.timescale,
      width = source.width,
      height = source.height,
      sps = source.sps,
      pps = source.pps,
      sampleRate = source.sampleRate,
      channels = source.channels;

  final _ElementaryTrack source;
  final bool isVideo;
  final int id;
  final int timescale;
  final int width;
  final int height;
  final Uint8List? sps;
  final Uint8List? pps;
  final int sampleRate;
  final int channels;

  List<Uint8List> get samples => source.samples;
  int get sampleDuration => source.sampleDuration;
  int get duration => samples.length * sampleDuration;
}
