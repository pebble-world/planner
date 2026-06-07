import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'package:example/data.dart';
import 'package:example/main.dart' as app;

/// Drives the *real* example app end-to-end (real entrypoint, real fonts, real
/// layout, real gestures) on the device under test. Event titles and hour/day
/// labels are painted on the CustomPaint canvas rather than rendered as Text
/// widgets, so assertions target the things that are real widgets: the app bar
/// and the context menu.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void appSmokeScenarios() {
  testWidgets('example app boots and renders a Planner', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.byType(Planner<ActivityMeta>), findsOneWidget);
    expect(find.text('Planner Demo'), findsOneWidget);
  });

  testWidgets('right-click on empty grid opens the create-event menu',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // An empty spot in column 0: +100px right (into the grid) and +120px down
    // from the grid top maps to hour 3, which the sample data leaves free
    // (column-0 entries sit at 01:00, 08:00 and 13:30). The grid top is the date
    // row (50) plus the now-enabled all-day band (one lane: 24 + 2*2 = 28). This
    // exercises the real secondary-tap gesture path the widget harness can't
    // always reach.
    final rect = tester.getRect(find.byType(Planner<ActivityMeta>));
    final at = rect.topLeft + const Offset(50 + 100, 50 + 28 + 120);

    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Create Event'), findsOneWidget);
  });
}
