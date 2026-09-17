import 'package:flutter_test/flutter_test.dart';
import 'package:mixstream/features/player/domain/playback_recovery.dart';

void main() {
  group('stallActionFor', () {
    test('none while the position advances', () {
      // position advanced → hadFrames true but not stalled
      expect(
        stallActionFor(
          stalledFor: Duration.zero,
          hadFrames: true,
          lastAction: StallAction.none,
        ),
        equals(StallAction.none),
      );
    });

    test('none before the nudge deadline', () {
      expect(
        stallActionFor(
          stalledFor: const Duration(seconds: 4),
          hadFrames: true,
          lastAction: StallAction.none,
        ),
        equals(StallAction.none),
      );
    });

    test('nudge once the nudge deadline passes with frames', () {
      expect(
        stallActionFor(
          stalledFor: const Duration(seconds: 5),
          hadFrames: true,
          lastAction: StallAction.none,
        ),
        equals(StallAction.nudge),
      );
    });

    test('nudge only once; recovers after the recovery deadline', () {
      expect(
        stallActionFor(
          stalledFor: const Duration(seconds: 20),
          hadFrames: true,
          lastAction: StallAction.nudge,
        ),
        equals(StallAction.recover),
      );
    });

    test('recover after the recovery deadline even without prior nudge', () {
      expect(
        stallActionFor(
          stalledFor: const Duration(seconds: 20),
          hadFrames: true,
          lastAction: StallAction.none,
        ),
        equals(StallAction.recover),
      );
    });

    test('recovers after the recovery deadline even with no frames', () {
      // The recovery deadline outranks the frame check: a long
      // freeze is worth a recovery attempt regardless.
      expect(
        stallActionFor(
          stalledFor: const Duration(seconds: 20),
          hadFrames: false,
          lastAction: StallAction.none,
        ),
        equals(StallAction.recover),
      );
    });

    test('recover rung fires once; repeats return none until reset', () {
      // Once recover has been returned, calling again with the same
      // lastAction returns none so the rung is not repeated for the
      // same stall window. The caller resets lastAction to none when
      // the position advances or when recovery starts.
      expect(
        stallActionFor(
          stalledFor: const Duration(seconds: 30),
          hadFrames: true,
          lastAction: StallAction.recover,
        ),
        equals(StallAction.none),
      );
    });
  });

  group('nextFailoverIndex', () {
    test('returns the next untried candidate', () {
      expect(
        nextFailoverIndex(from: 0, total: 4, tried: {0}),
        equals(1),
      );
    });

    test('wraps around', () {
      expect(
        nextFailoverIndex(from: 3, total: 4, tried: {0, 1, 2, 3}),
        isNull,
      );
    });

    test('returns null when nothing is left', () {
      expect(
        nextFailoverIndex(from: 0, total: 1, tried: {0}),
        isNull,
      );
    });
  });
}
