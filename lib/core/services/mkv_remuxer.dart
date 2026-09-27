import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Outcome of a download-to-MKV conversion attempt.
class RemuxResult {
  const RemuxResult._({required this.success, this.outputPath, this.error});

  static RemuxResult ok(String outputPath) =>
      RemuxResult._(success: true, outputPath: outputPath);
  static RemuxResult fail(String error) =>
      RemuxResult._(success: false, error: error);

  final bool success;
  final String? outputPath;
  final String? error;

  @override
  String toString() => success ? 'OK -> $outputPath' : 'FAILED: $error';
}

/// Converts a downloaded video file into a genuine `.mkv`.
///
/// * If the file is already a Matroska/WebM container it is simply renamed to
///   `.mkv` (bytes are kept — WebM is a subset of Matroska).
/// * If it is an ISO-BMFF (MP4/MOV) file with supported codecs (H.264, HEVC,
///   AAC, MP3, AC-3, E-AC-3, Opus) it is **remuxed**: samples are copied
///   packet-for-packet into a Matroska container with no re-encoding, and A/V
///   sync from the MP4 edit/time tables is preserved.
/// * Anything else returns [RemuxResult.fail] and the original file is left
///   untouched.
///
/// Pure Dart (no FFmpeg dependency), so it can safely run in a background
/// isolate via `compute`.
Future<RemuxResult> remuxDownloadedVideoToMkv(
  String inputPath, {
  void Function(double progress)? onProgress,
}) async {
  try {
    final file = File(inputPath);
    if (!await file.exists()) return RemuxResult.fail('file does not exist');
    final length = await file.length();
    if (length < 32) return RemuxResult.fail('file too small ($length bytes)');

    final raf = await file.open(mode: FileMode.read);
    try {
      final head = await raf.read(16);

      // Matroska / WebM magic: 0x1A 0x45 0xDF 0xA3.
      if (head.length >= 4 &&
          head[0] == 0x1A &&
          head[1] == 0x45 &&
          head[2] == 0xDF &&
          head[3] == 0xA3) {
        raf.closeSync();
        return await _renameToMkv(inputPath);
      }

      // ISO-BMFF: ftyp / moov / mdat at the very top. Some files omit ftyp,
      // so accept those too and let the moov scan decide.
      final brand = String.fromCharCodes(head, 4, 8);
      if (brand != 'ftyp' && brand != 'moov' && brand != 'mdat') {
        return RemuxResult.fail('not a recognised video container');
      }
      return await _remuxMp4ToMkv(
        raf,
        length,
        inputPath,
        onProgress: onProgress,
      );
    } finally {
      try {
        raf.closeSync();
      } catch (_) {}
    }
  } catch (e) {
    return RemuxResult.fail('$e');
  }
}

/// The file is already Matroska-compatible — fix the extension only.
Future<RemuxResult> _renameToMkv(String inputPath) async {
  final lower = inputPath.toLowerCase();
  if (lower.endsWith('.mkv')) return RemuxResult.ok(inputPath);
  final out = _replaceExtension(inputPath, '.mkv');
  try {
    if (await File(out).exists()) await File(out).delete();
    await File(inputPath).rename(out);
    return RemuxResult.ok(out);
  } catch (e) {
    return RemuxResult.fail('rename to .mkv failed: $e');
  }
}

String _replaceExtension(String path, String newExt) {
  final ext = p.extension(path);
  if (ext.isEmpty) return '$path$newExt';
  return '${path.substring(0, path.length - ext.length)}$newExt';
}

// ─────────────────────────────────────────────────────────────────────────────
// Matroska element IDs (raw byte sequences, per spec)
// ─────────────────────────────────────────────────────────────────────────────

const List<int> _idEbml = [0x1A, 0x45, 0xDF, 0xA3];
const List<int> _idEBMLVersion = [0x42, 0x86];
const List<int> _idEBMLReadVersion = [0x42, 0xF7];
const List<int> _idEBMLMaxIDLength = [0x42, 0xF2];
const List<int> _idEBMLMaxSizeLength = [0x42, 0xF3];
const List<int> _idDocType = [0x42, 0x82];
const List<int> _idDocTypeVersion = [0x42, 0x87];
const List<int> _idDocTypeReadVersion = [0x42, 0x85];

const List<int> _idSegment = [0x18, 0x53, 0x80, 0x67];
const List<int> _idInfo = [0x15, 0x49, 0xA9, 0x66];
const List<int> _idTimestampScale = [0x2A, 0xD7, 0xB1];
const List<int> _idDuration = [0x44, 0x89];
const List<int> _idMuxingApp = [0x4D, 0x80];
const List<int> _idWritingApp = [0x57, 0x41];

const List<int> _idTracks = [0x16, 0x54, 0xAE, 0x6B];
const List<int> _idTrackEntry = [0xAE];
const List<int> _idTrackNumber = [0xD7];
const List<int> _idTrackUID = [0x73, 0xC5];
const List<int> _idTrackType = [0x83];
const List<int> _idFlagLacing = [0x9C];
const List<int> _idCodecID = [0x86];
const List<int> _idCodecPrivate = [0x63, 0xA2];
const List<int> _idLanguage = [0x22, 0xB5, 0x9C];
const List<int> _idDefaultDuration = [0x23, 0xE3, 0x83];
const List<int> _idVideo = [0xE0];
const List<int> _idPixelWidth = [0xB0];
const List<int> _idPixelHeight = [0xBA];
const List<int> _idAudio = [0xE1];
const List<int> _idSamplingFrequency = [0xB5];
const List<int> _idChannels = [0x9F];
const List<int> _idBitDepth = [0x62, 0x64];

const List<int> _idCluster = [0x1F, 0x43, 0xB6, 0x75];
const List<int> _idTimestamp = [0xE7];
const List<int> _idSimpleBlock = [0xA3];

const List<int> _idCues = [0x1C, 0x53, 0xBB, 0x6B];
const List<int> _idCuePoint = [0xBB];
const List<int> _idCueTime = [0xB3];
const List<int> _idCueTrackPositions = [0xF7];
const List<int> _idCueTrack = [0xF1];
const List<int> _idCueClusterPosition = [0xF3];

// ─────────────────────────────────────────────────────────────────────────────
// MP4 parsing
// ─────────────────────────────────────────────────────────────────────────────

class _Box {
  final String type;
  final int dataStart; // absolute file offset of payload (after box header)
  final int dataEnd;
  int get dataLen => dataEnd - dataStart;
  _Box(this.type, this.dataStart, this.dataEnd);
}

/// A box described by offsets relative to the buffer that contains it.
class _LocalBox {
  final String type;
  final int start; // payload start (after 8/16 byte header)
  final int end;
  _LocalBox(this.type, this.start, this.end);
  int get len => end - start;
}

class _Sample {
  final int offset; // absolute file offset
  final int size;
  final int pts; // presentation time, track timescale units
  final bool key;
  _Sample(this.offset, this.size, this.pts, this.key);
}

class _CodecInfo {
  final String codecId;
  final bool supported;
  final Uint8List? private;
  const _CodecInfo(this.codecId, this.supported, this.private);
}

class _Track {
  String handler = '';
  int timescale = 1;
  String language = 'eng';
  int displayWidth = 0;
  int displayHeight = 0;
  String format = '';
  _CodecInfo codec = const _CodecInfo('', false, null);
  int? defaultDuration; // track timescale units, if constant
  int lastSampleDuration = 0; // track timescale units of the final sample
  int? sampleRate;
  int? channels;
  int? bitDepth;
  int editMediaTime = 0; // elst media_time (track time units)
  bool hasEdit = false;
  final List<_Sample> samples = [];

  bool get isVideo => handler == 'vide';
  bool get isAudio => handler == 'soun';
}

class _Block {
  final int trackIndex; // index into parsed tracks list
  final _Sample sample;
  final bool isVideo;
  int ptsMs;
  _Block(this.trackIndex, this.sample, this.isVideo, this.ptsMs);
}

Future<_Box?> _findTopLevelBox(
  RandomAccessFile raf,
  int length,
  String want,
) async {
  var pos = 0;
  while (pos + 8 <= length) {
    await raf.setPosition(pos);
    final h = await raf.read(16);
    if (h.length < 8) break;
    final size = _u32(h, 0);
    final type = String.fromCharCodes(h, 4, 8);
    if (size == 1) {
      if (h.length < 16) break;
      final size64 = _u64(h, 8);
      if (size64 < 16) break;
      final dataStart = pos + 16;
      final dataEnd = dataStart + (size64 - 16);
      if (type == want) return _Box(type, dataStart, dataEnd);
      pos = dataEnd;
    } else if (size == 0) {
      if (type == want) return _Box(type, pos + 8, length);
      break;
    } else {
      if (size < 8) break;
      final dataStart = pos + 8;
      final dataEnd = pos + size;
      if (type == want) return _Box(type, dataStart, dataEnd);
      pos = dataEnd;
    }
    if (pos <= 0 || pos > length) break;
  }
  return null;
}

List<_LocalBox> _childBoxes(Uint8List b, int start, int end) {
  final out = <_LocalBox>[];
  var p = start;
  while (p + 8 <= end) {
    final size = _u32(b, p);
    final type = _fourcc(b, p + 4);
    if (size == 1) {
      if (p + 16 > end) break;
      final size64 = _u64(b, p + 8);
      if (size64 < 16) break;
      final ds = p + 16;
      final de = ds + (size64 - 16);
      out.add(_LocalBox(type, ds, de));
      p = de;
    } else if (size == 0) {
      out.add(_LocalBox(type, p + 8, end));
      p = end;
    } else {
      if (size < 8) break;
      out.add(_LocalBox(type, p + 8, p + size));
      p += size;
    }
  }
  return out;
}

List<_Track> _parseMoov(Uint8List moov) {
  final traks = <_Track>[];
  for (final b in _childBoxes(moov, 0, moov.length)) {
    if (b.type == 'trak') {
      final t = _parseTrak(moov, b);
      if (t != null) traks.add(t);
    }
  }
  return traks;
}

_Track? _parseTrak(Uint8List m, _LocalBox trakBox) {
  _LocalBox? tkhd;
  _LocalBox? mdhd;
  _LocalBox? hdlr;
  _LocalBox? stbl;
  _LocalBox? elst;

  for (final b in _childBoxes(m, trakBox.start, trakBox.end)) {
    switch (b.type) {
      case 'tkhd':
        tkhd = b;
      case 'mdia':
        for (final mb in _childBoxes(m, b.start, b.end)) {
          if (mb.type == 'mdhd') {
            mdhd = mb;
          } else if (mb.type == 'hdlr') {
            hdlr = mb;
          } else if (mb.type == 'minf') {
            for (final minfb in _childBoxes(m, mb.start, mb.end)) {
              if (minfb.type == 'stbl') stbl = minfb;
            }
          }
        }
      case 'edts':
        for (final eb in _childBoxes(m, b.start, b.end)) {
          if (eb.type == 'elst') elst = eb;
        }
    }
  }

  if (tkhd == null || mdhd == null || hdlr == null || stbl == null) {
    return null;
  }

  final t = _Track();
  final tkhdVersion = m[tkhd.start];
  t.displayWidth = (tkhdVersion == 1
          ? _u32(m, tkhd.start + 88)
          : _u32(m, tkhd.start + 76)) >>
      16;
  t.displayHeight = (tkhdVersion == 1
          ? _u32(m, tkhd.start + 92)
          : _u32(m, tkhd.start + 80)) >>
      16;

  final mdhdVersion = m[mdhd.start];
  t.timescale = mdhdVersion == 1
      ? _u32(m, mdhd.start + 20)
      : _u32(m, mdhd.start + 12);
  final langPacked = mdhdVersion == 1
      ? _u16(m, mdhd.start + 28)
      : _u16(m, mdhd.start + 20);
  t.language = _unpackLanguage(langPacked);

  t.handler = _fourcc(m, hdlr.start + 8);

  // Edit list → presentation start offset (skip empty edits marked -1).
  if (elst != null) {
    final v = m[elst.start];
    final count = _u32(m, elst.start + 4);
    var entryPos = elst.start + 8;
    for (var i = 0; i < count; i++) {
      if (v == 1) {
        final mediaTime = _i64(m, entryPos + 8); // seg(8) media(8)
        if (mediaTime >= 0) {
          t.editMediaTime = mediaTime;
          t.hasEdit = true;
          break;
        }
        entryPos += 20;
      } else {
        final mediaTime = _i32(m, entryPos + 4); // seg(4) media(4)
        if (mediaTime >= 0) {
          t.editMediaTime = mediaTime;
          t.hasEdit = true;
          break;
        }
        entryPos += 12;
      }
    }
  }

  // ── stbl ────────────────────────────────────────────────────────────────
  _LocalBox? stsd, stts, ctts, stsc, stsz, stco, co64, stss;
  for (final b in _childBoxes(m, stbl.start, stbl.end)) {
    switch (b.type) {
      case 'stsd':
        stsd = b;
      case 'stts':
        stts = b;
      case 'ctts':
        ctts = b;
      case 'stsc':
        stsc = b;
      case 'stsz':
        stsz = b;
      case 'stco':
        stco = b;
      case 'co64':
        co64 = b;
      case 'stss':
        stss = b;
    }
  }
  if (stsd == null || stts == null || stsc == null || stsz == null) return null;
  if (stco == null && co64 == null) return null;

  // Sample entry → codec + parameters.
  if (!_parseSampleEntry(m, stsd, t)) return null;

  // Chunk offsets.
  final chunkOffsets = <int>[];
  if (co64 != null) {
    final c = _u32(m, co64.start + 4);
    for (var i = 0; i < c; i++) {
      chunkOffsets.add(_u64(m, co64.start + 8 + i * 8));
    }
  } else {
    final c = _u32(m, stco!.start + 4);
    for (var i = 0; i < c; i++) {
      chunkOffsets.add(_u32(m, stco.start + 8 + i * 4));
    }
  }

  // Samples per chunk (stsc).
  final stscEntries = <(int first, int spc)>[];
  final c0 = _u32(m, stsc.start + 4);
  for (var i = 0; i < c0; i++) {
    stscEntries.add((
      _u32(m, stsc.start + 8 + i * 12),
      _u32(m, stsc.start + 12 + i * 12),
    ));
  }
  if (stscEntries.isEmpty) return null;

  // Sample sizes.
  final sizes = <int>[];
  final uniform = _u32(m, stsz.start + 4);
  final sampleCount = _u32(m, stsz.start + 8);
  if (uniform != 0) {
    sizes.addAll(List.filled(sampleCount, uniform));
  } else {
    for (var i = 0; i < sampleCount; i++) {
      sizes.add(_u32(m, stsz.start + 12 + i * 4));
    }
  }

  // Per-sample decode durations (stts).
  final durations = <int>[];
  final sttsCount = _u32(m, stts.start + 4);
  for (var i = 0; i < sttsCount; i++) {
    final dc = _u32(m, stts.start + 8 + i * 8);
    final delta = _u32(m, stts.start + 12 + i * 8);
    durations.addAll(List.filled(dc, delta));
  }
  if (durations.length == sampleCount && sttsCount == 1) {
    t.defaultDuration = durations.isNotEmpty ? durations[0] : null;
  }

  // Composition offsets (ctts) — presentation offset over decode time.
  final cttsOffsets = <int>[];
  if (ctts != null) {
    final v = m[ctts.start];
    final c = _u32(m, ctts.start + 4);
    for (var i = 0; i < c; i++) {
      final sc = _u32(m, ctts.start + 8 + i * 8);
      final off = v == 1
          ? _i32(m, ctts.start + 12 + i * 8)
          : _u32(m, ctts.start + 12 + i * 8);
      for (var k = 0; k < sc; k++) {
        cttsOffsets.add(off);
      }
    }
  } else {
    cttsOffsets.addAll(List.filled(sampleCount, 0));
  }

  // Sync sample set (stss). Absent → every sample is a sync sample.
  final syncSet = <int>{};
  if (stss != null) {
    final c = _u32(m, stss.start + 4);
    for (var i = 0; i < c; i++) {
      syncSet.add(_u32(m, stss.start + 8 + i * 4));
    }
  }

  if (durations.length != sampleCount ||
      cttsOffsets.length != sampleCount ||
      sizes.length != sampleCount) {
    return null;
  }

  // Assemble samples in decode order (chunk → sample).
  final samples = <_Sample>[];
  var sizeIdx = 0;
  var dts = 0;
  var stscIdx = 0;
  for (var ci = 0; ci < chunkOffsets.length && sizeIdx < sampleCount; ci++) {
    while (stscIdx + 1 < stscEntries.length &&
        stscEntries[stscIdx + 1].$1 <= ci + 1) {
      stscIdx++;
    }
    final spc = stscEntries[stscIdx].$2;
    var off = chunkOffsets[ci];
    for (var s = 0; s < spc && sizeIdx < sampleCount; s++) {
      final size = sizes[sizeIdx];
      final key = syncSet.isEmpty || syncSet.contains(sizeIdx + 1);
      samples.add(_Sample(off, size, dts + cttsOffsets[sizeIdx], key));
      off += size;
      dts += durations[sizeIdx];
      sizeIdx++;
    }
  }
  if (sizeIdx != sampleCount) return null;
  if (durations.isNotEmpty) {
    t.lastSampleDuration = durations[durations.length - 1];
  }
  t.samples.addAll(samples);
  return t;
}

bool _parseSampleEntry(Uint8List m, _LocalBox stsd, _Track t) {
  final count = _u32(m, stsd.start + 4);
  if (count == 0) return false;
  final entryStart = stsd.start + 8;
  final format = _fourcc(m, entryStart + 4);
  t.format = format;
  final entrySize = _u32(m, entryStart);
  final childrenEnd = entrySize == 0 ? m.length : entryStart + entrySize;

  if (t.isVideo) {
    // VisualSampleEntry: width @32, height @34, child boxes from @86.
    final wRaw = _u16(m, entryStart + 32);
    final hRaw = _u16(m, entryStart + 34);
    if (wRaw != 0 && hRaw != 0) {
      if (t.displayWidth == 0) t.displayWidth = wRaw;
      if (t.displayHeight == 0) t.displayHeight = hRaw;
    }
    Uint8List? private;
    for (final c in _childBoxes(m, entryStart + 86, childrenEnd)) {
      if (c.type == 'avcC' || c.type == 'hvcC') {
        private = m.sublist(c.start, c.end);
      }
    }
    t.codec = _codecFor(format, private: private);
    return t.codec.supported;
  }

  if (t.isAudio) {
    // AudioSampleEntry: channelcount @24, samplesize @26, samplerate @32.
    t.channels = _u16(m, entryStart + 24);
    t.bitDepth = _u16(m, entryStart + 26);
    t.sampleRate = _u32(m, entryStart + 32) >> 16;

    Uint8List? private;
    var objectType = 0;
    for (final c in _childBoxes(m, entryStart + 36, childrenEnd)) {
      if (c.type == 'esds') {
        final info = _parseEsds(m.sublist(c.start, c.end));
        objectType = info.$1;
        private = info.$2;
      } else if (c.type == 'dac3' || c.type == 'dec3' || c.type == 'dOps') {
        private = m.sublist(c.start, c.end);
      }
    }
    t.codec = _codecFor(format, objectType: objectType, private: private);
    return t.codec.supported;
  }

  // Non video/audio (subtitle etc.) — not an error; the track is skipped.
  return true;
}

/// Parses an `esds` payload (after the box header; includes the 4-byte
/// fullbox) and returns `(objectTypeIndication, audioSpecificConfig)`.
(int, Uint8List?) _parseEsds(Uint8List esds) {
  var p = 4; // skip version/flags
  (int, int, int)? es;
  while (p < esds.length) {
    final d = _readDescriptor(esds, p);
    if (d.$1 == 0x03) {
      es = d;
      break;
    }
    p = d.$3;
  }
  if (es == null) return (0, null);
  p = es.$2;
  if (p + 3 > es.$3) return (0, null);
  final flags = esds[p + 2];
  p += 3; // ES_ID(2) + flags(1)
  if (flags & 0x80 != 0) p += 2;
  if (flags & 0x40 != 0) {
    if (p >= es.$3) return (0, null);
    final l = esds[p];
    p += 1 + l;
  }
  if (flags & 0x20 != 0) p += 2;

  var objectType = 0;
  Uint8List? asc;
  while (p < es.$3) {
    final d = _readDescriptor(esds, p);
    if (d.$1 == 0x04 && d.$2 < d.$3) {
      objectType = esds[d.$2];
    } else if (d.$1 == 0x05) {
      asc = esds.sublist(d.$2, d.$3);
    }
    p = d.$3;
  }
  return (objectType, asc);
}

/// Reads an MPEG-4 descriptor: tag + variable length; returns
/// `(tag, dataStart, dataEnd)`.
(int, int, int) _readDescriptor(Uint8List b, int pos) {
  final tag = b[pos];
  var p = pos + 1;
  var len = 0;
  while (p < b.length) {
    final x = b[p];
    p++;
    len = (len << 7) | (x & 0x7F);
    if (x & 0x80 == 0) break;
  }
  final ds = p;
  final de = ds + len;
  return (tag, ds, de);
}

_CodecInfo _codecFor(
  String format, {
  Uint8List? private,
  int objectType = 0,
}) {
  switch (format) {
    case 'avc1':
    case 'avc3':
      return _CodecInfo('V_MPEG4/ISO/AVC', true, private);
    case 'hvc1':
    case 'hev1':
      return _CodecInfo('V_MPEGH/ISO/HEVC', true, private);
    case 'mp4a':
      // MPEG-4/MPEG-2 AAC (carries an AudioSpecificConfig).
      if (objectType == 0x40 ||
          objectType == 0x66 ||
          objectType == 0x67 ||
          objectType == 0x68) {
        return _CodecInfo('A_AAC', true, private);
      }
      // MPEG-2 Layer 3 / MPEG-1 Layer 3 (MP3).
      if (objectType == 0x69 || objectType == 0x6C) {
        return const _CodecInfo('A_MPEG/L3', true, null);
      }
      return const _CodecInfo('', false, null);
    case 'ac-3':
      return _CodecInfo('A_AC3', true, private);
    case 'ec-3':
      return _CodecInfo('A_EAC3', true, private);
    case 'Opus':
      return _CodecInfo('A_OPUS', true, private);
    default:
      return const _CodecInfo('', false, null);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Remux
// ─────────────────────────────────────────────────────────────────────────────

Future<RemuxResult> _remuxMp4ToMkv(
  RandomAccessFile raf,
  int length,
  String inputPath, {
  void Function(double progress)? onProgress,
}) async {
  final moov = await _findTopLevelBox(raf, length, 'moov');
  if (moov == null) {
    return RemuxResult.fail('no moov atom (fragmented/DRM MP4?)');
  }
  await raf.setPosition(moov.dataStart);
  final moovBytes = await raf.read(moov.dataLen);
  final tracks = _parseMoov(moovBytes);

  final video = tracks.where((t) => t.isVideo).toList();
  if (video.isEmpty) return RemuxResult.fail('no video track found');
  if (tracks.where((t) => t.isAudio).length > 1) {
    return RemuxResult.fail('multiple audio tracks not supported');
  }
  for (final t in tracks) {
    if (!t.isVideo && !t.isAudio) continue; // subtitles etc. are skipped
    if (!t.codec.supported) {
      return RemuxResult.fail('unsupported track ${t.handler}/${t.format}');
    }
    if (t.samples.isEmpty) return RemuxResult.fail('track ${t.format} is empty');
    if (t.timescale <= 0) return RemuxResult.fail('bad timescale');
  }

  // Resolve presentation timestamps (ms) and shift so the earliest sample is 0.
  final blocks = <_Block>[];
  var minMs = 0x7FFFFFFFFFFFFFFF;
  var segmentEndMs = 0;
  for (var ti = 0; ti < tracks.length; ti++) {
    final t = tracks[ti];
    if (!t.isVideo && !t.isAudio) continue;
    final start = t.hasEdit ? t.editMediaTime : 0;
    for (final s in t.samples) {
      final ms = ((s.pts - start) * 1000) ~/ t.timescale;
      final b = _Block(ti, s, t.isVideo, ms);
      blocks.add(b);
      if (ms < minMs) minMs = ms;
    }
    if (t.samples.isNotEmpty && t.lastSampleDuration > 0) {
      final endMs = ((t.samples.last.pts - start + t.lastSampleDuration) * 1000) ~/
          t.timescale;
      if (endMs > segmentEndMs) segmentEndMs = endMs;
    }
  }
  if (minMs != 0) {
    for (final b in blocks) {
      b.ptsMs -= minMs;
    }
  }

  blocks.sort((a, b) {
    final c = a.ptsMs.compareTo(b.ptsMs);
    return c != 0 ? c : a.trackIndex.compareTo(b.trackIndex);
  });
  if (blocks.isEmpty) return RemuxResult.fail('no samples to write');

  final outputPath = _replaceExtension(inputPath, '.mkv');
  final tmpPath = '$outputPath.part';
  if (await File(tmpPath).exists()) await File(tmpPath).delete();
  final sink = File(tmpPath).openWrite();
  var done = false;
  try {
    var pos = 0;
    void put(List<int> bytes) {
      sink.add(bytes);
      pos += bytes.length;
    }

    // EBML header + Segment (unknown size — streamed without buffering).
    put(_element(_idEbml, _ebmlHeaderBody()));
    put(_element(_idSegment, null));
    final segmentDataStart = pos;

    // Info.
    final info = <int>[];
    info.addAll(_elementBytes(_idTimestampScale, _uintBytes(1000000)));
    info.addAll(_elementString(_idMuxingApp, 'MixStream'));
    info.addAll(_elementString(_idWritingApp, 'MixStream'));
    if (segmentEndMs > 0) {
      // Matroska Duration is a Float in TimestampScale units (1 ms/tick),
      // written as an IEEE-754 double.
      info.addAll(_elementBytes(_idDuration, _float64Bytes(segmentEndMs.toDouble())));
    }
    put(_elementBytes(_idInfo, info));

    // Tracks.
    final mkvTrackNum = <int, int>{};
    final entries = <int>[];
    var trackNum = 0;
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      if (!t.isVideo && !t.isAudio) continue;
      trackNum++;
      mkvTrackNum[i] = trackNum;
      entries.addAll(_elementBytes(_idTrackEntry, _trackEntry(t, trackNum)));
    }
    put(_elementBytes(_idTracks, entries));

    // Clusters (unknown-size Cluster elements streamed one-by-one).
    final cues = <(int time, int clusterDataStart)>[];
    var clusterTs = -1;
    var clusterDataStart = -1;
    var clusterBytes = 0;
    var samplesDone = 0;
    var buf = Uint8List(1 << 20);

    for (final block in blocks) {
      final s = block.sample;
      final rel = clusterTs < 0 ? 0 : block.ptsMs - clusterTs;
      final split = clusterTs >= 0 &&
          (rel >= 30000 ||
              (block.isVideo && s.key && rel >= 4000) ||
              clusterBytes > 16 * 1024 * 1024);
      if (clusterTs < 0 || split) {
        if (clusterTs >= 0) cues.add((clusterTs, clusterDataStart));
        clusterTs = block.ptsMs;
        clusterBytes = 0;
        clusterDataStart = pos;
        put(_element(_idCluster, null));
        put(_elementBytes(_idTimestamp, _uintBytes(clusterTs)));
      }

      if (buf.length < s.size) buf = Uint8List(s.size);
      raf.setPositionSync(s.offset);
      final n = raf.readIntoSync(buf, 0, s.size);
      if (n != s.size) throw StateError('short read at ${s.offset}');

      final relTs = block.ptsMs - clusterTs;
      if (relTs < 0 || relTs > 30000) {
        throw StateError('block timestamp out of cluster range');
      }
      final flags = s.key ? 0x80 : 0x00;
      final tvint = _vint(mkvTrackNum[block.trackIndex]!);
      final payloadHead = <int>[
        ...tvint,
        (relTs >> 8) & 0xFF,
        relTs & 0xFF,
        flags,
      ];

      put(_idSimpleBlock); // SimpleBlock
      put(_vint(payloadHead.length + s.size));
      put(payloadHead);
      // Must be a copy: `buf` is reused for the next sample while the sink
      // still holds queued views.
      put(buf.sublist(0, s.size));
      clusterBytes += payloadHead.length + s.size;

      // Byte-based progress so a multi-GB conversion isn't a blank wait.
      if (onProgress != null) {
        samplesDone++;
        if ((samplesDone & 0x1f) == 0 && blocks.isNotEmpty) {
          onProgress((samplesDone / blocks.length).clamp(0.0, 1.0));
        }
      }
    }
    if (clusterTs >= 0) cues.add((clusterTs, clusterDataStart));
    onProgress?.call(1.0);

    // Cues (positioned on the video track).
    final videoTrackNum = mkvTrackNum[tracks.indexOf(video.first)]!;
    final cuesBody = <int>[];
    for (final cue in cues) {
      final tp = <int>[];
      tp.addAll(_elementBytes(_idCueTrack, _uintBytes(videoTrackNum)));
      tp.addAll(_elementBytes(
        _idCueClusterPosition,
        _uintBytes(cue.$2 - segmentDataStart),
      ));
      final cp = <int>[];
      cp.addAll(_elementBytes(_idCueTime, _uintBytes(cue.$1)));
      cp.addAll(_elementBytes(_idCueTrackPositions, tp));
      cuesBody.addAll(_elementBytes(_idCuePoint, cp));
    }
    put(_elementBytes(_idCues, cuesBody));

    await sink.flush();
    await sink.close();
    done = true;

    // Atomically swap in the MKV and drop the original MP4.
    if (await File(outputPath).exists()) await File(outputPath).delete();
    await File(tmpPath).rename(outputPath);
    await File(inputPath).delete();
    return RemuxResult.ok(outputPath);
  } catch (e) {
    return RemuxResult.fail('$e');
  } finally {
    if (!done) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (await File(tmpPath).exists()) await File(tmpPath).delete();
      } catch (_) {}
    }
  }
}

List<int> _trackEntry(_Track t, int trackNum) {
  final e = <int>[];
  e.addAll(_elementBytes(_idTrackNumber, _uintBytes(trackNum)));
  // TrackUID — deterministic per track so output is reproducible.
  final rnd = Random(0x5EED + trackNum * 0x101);
  final uid = Uint8List(8);
  for (var i = 0; i < 8; i++) {
    uid[i] = rnd.nextInt(256);
  }
  e.addAll(_elementBytes(_idTrackUID, uid));
  e.addAll(_elementBytes(_idTrackType, _uintBytes(t.isVideo ? 1 : 2)));
  e.addAll(_elementBytes(_idFlagLacing, _uintBytes(0)));
  e.addAll(_elementString(_idCodecID, t.codec.codecId));
  final private = t.codec.private;
  if (private != null && private.isNotEmpty) {
    e.addAll(_elementBytes(_idCodecPrivate, private));
  }
  e.addAll(_elementString(_idLanguage, t.language));

  final defaultDurNs = t.defaultDuration == null || t.timescale <= 0
      ? null
      : ((t.defaultDuration! * 1000000000) ~/ t.timescale);
  if (defaultDurNs != null && defaultDurNs > 0) {
    e.addAll(_elementBytes(_idDefaultDuration, _uintBytes(defaultDurNs)));
  }

  if (t.isVideo) {
    final v = <int>[];
    v.addAll(_elementBytes(
      _idPixelWidth,
      _uintBytes(t.displayWidth > 0 ? t.displayWidth : 0),
    ));
    v.addAll(_elementBytes(
      _idPixelHeight,
      _uintBytes(t.displayHeight > 0 ? t.displayHeight : 0),
    ));
    e.addAll(_elementBytes(_idVideo, v));
  } else {
    final a = <int>[];
    a.addAll(_elementBytes(
      _idSamplingFrequency,
      _float64Bytes((t.sampleRate ?? 48000).toDouble()),
    ));
    a.addAll(_elementBytes(_idChannels, _uintBytes(t.channels ?? 2)));
    final bd = t.bitDepth;
    if (bd != null && bd > 0) {
      a.addAll(_elementBytes(_idBitDepth, _uintBytes(bd)));
    }
    e.addAll(_elementBytes(_idAudio, a));
  }
  return e;
}

// ─────────────────────────────────────────────────────────────────────────────
// EBML primitives
// ─────────────────────────────────────────────────────────────────────────────

Uint8List _ebmlHeaderBody() {
  final body = <int>[];
  body.addAll(_elementBytes(_idEBMLVersion, _uintBytes(1)));
  body.addAll(_elementBytes(_idEBMLReadVersion, _uintBytes(1)));
  body.addAll(_elementBytes(_idEBMLMaxIDLength, _uintBytes(4)));
  body.addAll(_elementBytes(_idEBMLMaxSizeLength, _uintBytes(8)));
  body.addAll(_elementString(_idDocType, 'matroska'));
  body.addAll(_elementBytes(_idDocTypeVersion, _uintBytes(4)));
  body.addAll(_elementBytes(_idDocTypeReadVersion, _uintBytes(2)));
  return Uint8List.fromList(body);
}

Uint8List _element(List<int> id, List<int>? data) {
  final out = BytesBuilder(copy: false);
  out.add(id);
  if (data == null) {
    // Unknown size marker: 8-byte VINT of all ones.
    out.add(const [0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
  } else {
    out.add(_vint(data.length));
    out.add(data);
  }
  return out.takeBytes();
}

Uint8List _elementBytes(List<int> id, List<int> data) => _element(id, data);

Uint8List _elementString(List<int> id, String s) =>
    _element(id, Uint8List.fromList(s.codeUnits));

Uint8List _uintBytes(int v) {
  if (v <= 0xFF) return Uint8List.fromList([v & 0xFF]);
  if (v <= 0xFFFF) {
    final b = Uint8List(2);
    ByteData.sublistView(b).setUint16(0, v);
    return b;
  }
  if (v <= 0xFFFFFFFF) {
    final b = Uint8List(4);
    ByteData.sublistView(b).setUint32(0, v);
    return b;
  }
  final b = Uint8List(8);
  ByteData.sublistView(b).setUint64(0, v);
  return b;
}

/// IEEE-754 double, big-endian (Matroska Float elements).
Uint8List _float64Bytes(double v) {
  final b = Uint8List(8);
  ByteData.sublistView(b).setFloat64(0, v);
  return b;
}

/// Variable-length integer for element sizes / track numbers.
Uint8List _vint(int v) {
  var len = 1;
  while (len < 8 && v > ((1 << (7 * len)) - 2)) {
    len++;
  }
  final b = Uint8List(len);
  for (var i = 0; i < len; i++) {
    b[i] = (v >> (8 * (len - 1 - i))) & 0xFF;
  }
  b[0] |= 0x80 >> (len - 1);
  return b;
}

// ─────────────────────────────────────────────────────────────────────────────
// Byte helpers
// ─────────────────────────────────────────────────────────────────────────────

int _u32(Uint8List b, int o) => ByteData.sublistView(b).getUint32(o);
int _u64(Uint8List b, int o) => ByteData.sublistView(b).getUint64(o);
int _u16(Uint8List b, int o) => ByteData.sublistView(b).getUint16(o);
int _i32(Uint8List b, int o) => ByteData.sublistView(b).getInt32(o);
int _i64(Uint8List b, int o) => ByteData.sublistView(b).getInt64(o);

String _fourcc(Uint8List b, int o) => String.fromCharCodes(b, o, o + 4);

String _unpackLanguage(int packed) {
  final c1 = ((packed >> 10) & 0x1F) + 0x60;
  final c2 = ((packed >> 5) & 0x1F) + 0x60;
  final c3 = (packed & 0x1F) + 0x60;
  final s = String.fromCharCodes([c1, c2, c3]);
  return s == 'und' ? 'eng' : s;
}