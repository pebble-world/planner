import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for the hour-row off-by-one (#13):
/// `maxHour` defaulted to 24, so the *default* planner painted a spurious 25th
/// row ("24") and a below-grid tap could create an event at the invalid hour 24.
/// The default is now 23.
///
/// This drives the *real* composed widget on a real device with `maxHour` LEFT
/// AT ITS DEFAULT (the value under test); `minHour` 20 keeps the grid (4 rows)
/// inside the window so a low tap lands past the last hour row and exercises the
/// maxHour clamp through the real right-click "Create Event" flow.
///
/// The painted label text itself lives on a `CustomPaint` canvas (not in the
/// widget/semantics tree), so the reachable hour is the observable, e2e-testable
/// consequence of the row count; the formatting is covered by unit tests.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void hourLabelScenarios() {
  testWidgets('default maxHour clamps a below-grid tap to hour 23, not 24',
      (tester) async {
    PlannerTime? created;

    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 20, // maxHour intentionally omitted -> default (23)
            onEntryCreate: (t) => created = t,
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final planner = find.byKey(PlannerHarness.keyFor(0));
    // 300px below the grid top: column 0, raw hour 20 + floor(300/40) = 27,
    // which clamps to maxHour.
    final at = gridPointFor(tester.getRect(planner), downFromGridTop: 300);
    await createViaMenu(tester, planner, at);

    expect(created, isNotNull);
    expect(created!.hour, 23,
        reason: 'default maxHour is 23; the old default (24) produced hour 24');
  });
}
