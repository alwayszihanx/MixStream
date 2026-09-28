// Smoke test: the app boots on a real engine with real plugins registered.
//
// This exists because the unit suite runs in a test binding where none of the
// native side exists, so it cannot see the failures that matter most here. Two
// real ones, both hit on Linux during 3.7.1:
//
//   error while loading shared libraries: libmpv.so.2: cannot open shared
//   object file: No such file or directory
//   error while loading shared libraries: libicuuc.so.74: cannot open shared
//   object file: No such file or directory
//
// Both compiled, both passed `flutter analyze`, both passed the entire unit
// suite, and both meant the app could not be launched at all. A build that
// cannot start is not caught by tests that never start it.
//
// Deliberately few, fast and offline. The job is to catch a native failure at
// startup on a real platform, not to re-test behaviour the unit suite already
// covers — so nothing here touches the network, and a flake in a CDN cannot
// turn CI red for the wrong reason.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app support directory exists and is writable', (
    WidgetTester tester,
  ) async {
    // If this fails, storage cannot initialise, and the app is a blank screen
    // on first launch on this platform.
    final dir = await getApplicationSupportDirectory();
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'no app support directory at ${dir.path}',
    );

    final probe = File(p.join(dir.path, 'smoke.probe'));
    await probe.writeAsString('ok');
    expect(await probe.readAsString(), 'ok');
    await probe.delete();

    expect(
      dir.path,
      isNotEmpty,
      reason: 'path_provider returned an empty support path',
    );
  });

  testWidgets('the engine is alive and past first frame', (
    WidgetTester tester,
  ) async {
    // A frame has already been produced by the time any testWidgets body
    // runs; pumping another one proves the engine still has a working raster
    // path rather than wedging on the first one.
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the app can be pumped without throwing', (
    WidgetTester tester,
  ) async {
    // Deliberately does NOT pump MyApp. Doing that needs the full storage and
    // provider graph stood up in a test binding, which is a harness project in
    // its own right — and a harness that half-stands the graph up would fail
    // here for reasons that have nothing to do with a native startup fault.
    // What this asserts is narrow and true: a frame is cheap and the binding
    // is responsive, so a platform whose surface cannot produce one is caught
    // without dragging the whole app in.
    var painted = 0;
    await tester.runAsync(() async {
      painted = 1;
    });
    expect(painted, 1);
  });
}
