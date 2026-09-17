import 'package:flutter_test/flutter_test.dart';

void main() {
  group('video view buffered-ahead ratio', () {
    /// Mirrors the computation in `_buildVideoViewBar`.
    double bufferedAheadRatio(int bufferEndMs, int durationMs) {
      final durationMsD = durationMs.toDouble();
      return durationMsD > 0
          ? (bufferEndMs / durationMsD).clamp(0.0, 1.0)
          : 0.0;
    }

    test('zero when nothing is buffered', () {
      expect(bufferedAheadRatio(0, 10000), equals(0.0));
    });

    test('linear with the buffered end', () {
      expect(bufferedAheadRatio(5000, 10000), equals(0.5));
    });

    test('full when buffered to the end', () {
      expect(bufferedAheadRatio(10000, 10000), equals(1.0));
    });

    test('clamped at 1.0 when buffer extends past duration', () {
      expect(bufferedAheadRatio(15000, 10000), equals(1.0));
    });

    test('zero when duration is unknown', () {
      expect(bufferedAheadRatio(5000, 0), equals(0.0));
    });
  });
}
