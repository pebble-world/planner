import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guards for the configurable zoom controls and zoom-aware scrolling
/// (#28 / PROJECT_OVERVIEW D12), driving the *real* composed widget.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void zoomScenarios() {
  testWidgets('showZoomControls: false hides the on-canvas zoom buttons',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            showZoomControls: false,
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.zoom_in), findsNothing);
    expect(find.byIcon(Icons.zoom_out), findsNothing);
  });

  // Regression for D12 (#28): a fixed 20px scroll step moved less *time* the
  // further you zoomed in. With the step scaled by zoom, one wheel notch always
  // advances the same amount of time, so the hour reached is independent of zoom.
  testWidgets('one wheel notch advances the same amount of time at any zoom',
      (tester) async {
    PlannerTime? created;
    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            onEntryCreate: (t) => created = t,
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final planner = find.byKey(PlannerHarness.keyFor(0));
    final rect = tester.getRect(planner);

    // Zoom in well past 1x (8 presses of the 1.1x button ~= 2.1x). The exact
    // factor is irrelevant: with zoom-aware scrolling the time advanced by a
    // notch is zoom-independent, so the asserted hour holds at any zoom > 1.
    final zoomIn =
        find.descendant(of: planner, matching: find.byIcon(Icons.zoom_in));
    for (var i = 0; i < 8; i++) {
      await tester.tap(zoomIn);
      await tester.pump();
    }

    // Scroll 10 notches near the grid top, then create there. With blockHeight
    // 40 and scrollStep 20, 10 notches advance 10 * 20 / 40 = 5 hours regardless
    // of zoom; the old fixed-20px step advanced 5 / zoom hours (~2 at this zoom).
    final at = gridPointFor(rect, downFromGridTop: 5);
    await wheelScroll(tester, at, 10);
    await createViaMenu(tester, planner, at);

    expect(created, isNotNull);
    expect(created!.hour, 5,
        reason: 'a notch moves a constant amount of time; the old fixed '
            'step would have reached ~hour 2 at this zoom');
  });
}
