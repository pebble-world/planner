import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end demonstration of the multi-planner harness on a real device:
/// two Planners on one screen must keep independent scroll positions. This is
/// the device-level counterpart of the widget-harness regression for the former
/// static controller state (#9).
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void multiPlannerScenarios() {
  testWidgets('two planners keep independent scroll state', (tester) async {
    PlannerTime? createdA;
    PlannerTime? createdB;

    PlannerConfig configFor(void Function(PlannerTime) onCreate) =>
        PlannerConfig(
          labels: const ['c1', 'c2', 'c3'],
          minHour: 0,
          maxHour: 23,
          onEntryCreate: onCreate,
        );

    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(config: configFor((t) => createdA = t)),
        PlannerSpec(config: configFor((t) => createdB = t)),
      ],
    ));
    await tester.pumpAndSettle();

    final keyA = PlannerHarness.keyFor(0);
    final keyB = PlannerHarness.keyFor(1);
    final pointA = gridPointFor(tester.getRect(find.byKey(keyA)));
    final pointB = gridPointFor(tester.getRect(find.byKey(keyB)));

    // The chosen point maps to hour 5 in an unscrolled grid (200px / 40px).
    const unscrolledHour = 5;

    // Scroll ONLY planner A (before opening any menu, which otherwise leaves a
    // lingering overlay that blocks the wheel).
    await wheelScroll(tester, pointA, 4);

    await createViaMenu(tester, find.byKey(keyA), pointA);
    await createViaMenu(tester, find.byKey(keyB), pointB);
    expect(createdA, isNotNull);
    expect(createdB, isNotNull);

    // A scrolled down, so the same screen point now maps to a later hour; B was
    // never touched and still maps to the unscrolled hour. With shared static
    // state, scrolling A would also move B and both would report the later hour.
    expect(createdA!.hour, greaterThan(unscrolledHour),
        reason: 'scrolling A must change what A hit-tests');
    expect(createdB!.hour, unscrolledHour,
        reason: 'scrolling A must NOT change what B hit-tests');
  });
}
