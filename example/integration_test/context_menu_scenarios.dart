import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'package:example/data.dart';
import 'package:example/main.dart' as app;

import 'planner_harness.dart';

/// Drives the *real* example app end-to-end to cover the **entry** context menu
/// (right-clicking an existing event), which the create-event smoke
/// ([app_smoke_scenarios.dart]) does not exercise. `main.dart` boots a gallery
/// home (#90), so it opens the Showcase page first via [openShowcase]. The
/// "Edit Event" / "Delete Event" items are real Text widgets, so the menu itself
/// is assertable even though event titles are painted on the canvas.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void contextMenuScenarios() {
  testWidgets('right-clicking an event opens the edit/delete menu',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await openShowcase(tester);

    // The sample data's 'Stand-up' entry sits at day 0 / 08:00 for 60 min
    // (sampleEntries). With the default 200x40 grid that is grid rect
    // (0,320)-(200,360); skipping the hour column (50), the date row (50) and the
    // all-day band (one lane: 24 + 2*2 = 28), the box centre lands at
    // planner-local (50 + 100, 50 + 28 + 340).
    final rect = tester.getRect(find.byType(Planner<ActivityMeta>));
    final at = rect.topLeft + const Offset(50 + 100, 50 + 28 + 340);

    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Right-clicking an event opens the *entry* menu (edit/delete), not the
    // empty-grid *create* menu.
    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
    expect(find.text('Create Event'), findsNothing);

    // Tapping an item closes the menu (the sample handler just logs).
    await tester.tap(find.text('Delete Event'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Event'), findsNothing);
  });
}
