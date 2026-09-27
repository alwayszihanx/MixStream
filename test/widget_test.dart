// The `flutter create` template test, kept but disabled.
//
// It pumps MyApp and looks for a counter. MixStream has no counter, and MyApp
// is a ConsumerStatefulWidget whose first build reads SettingsRepository,
// which throws UnimplementedError("StorageService must be initialized") -
// so this fails twice over: the assertions are about a UI that does not
// exist, and the widget cannot be built in a plain test binding.
//
// Left in place rather than deleted because it marks the one piece of missing
// coverage a widget test would buy: booting the real app. Making it pass means
// standing up a harness (Hive in a temp dir, a path_provider mock, whatever
// else MyApp's init touches), which is a piece of work in its own right.
//
// Remove this file once that harness exists and something asserts real UI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mixstream/main.dart';

void main() {
  testWidgets(
    'Counter increments smoke test',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    },
    // testWidgets takes a bool here, not the String reason package:test's
    // test() takes, so the reason lives in the header rather than here.
    skip: true,
  );
}
