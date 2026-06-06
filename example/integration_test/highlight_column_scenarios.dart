import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for the configurable column highlight (#46): the host sets
/// `PlannerConfig.highlightedColumn` (an index into `labels`, ADR 0001 — no
/// `DateTime` in the API) and the grid painter fills that column behind the
/// lines and events.
///
/// The highlight is painted on the `CustomPaint` canvas, not in the
/// widget/semantics tree, so its render *is* the observable: this drives the
/// real composed widget on a real device and asserts what the events canvas
/// actually paints — that the right column is filled, and that the fill sits
/// *behind* an event in that column (a layer-ordering bug an isolated widget
/// test of the painter can't surface).
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void highlightColumnScenarios() {
  // The events grid is painted by EventsPainter on its own CustomPaint; scope
  // `paints` assertions to that render object so surrounding chrome can't match.
  Finder eventsCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is EventsPainter,
      );

  testWidgets('highlights the configured column behind its events',
      (tester) async {
    final entry = PlannerEntry(
      id: 'evt',
      time: PlannerTime(day: 1, hour: 9),
      title: 'Meeting',
      content: '',
      color: const Color(0xFF2244AA),
    );

    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            highlightedColumn: 1,
            highlightColumnColor: const Color(0xFF00FF00),
          ),
          entries: [entry],
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // Default 200x40 grid, hours 0..23 (24 rows), no scroll, zoom 1: column 1
    // occupies grid rect (200, 0) 200 wide and 24*40 = 960 tall. This geometry
    // is grid-content space (independent of the real window size, which only
    // clips it). The green highlight rect is painted first, then the event's
    // fill rect (entry.color at alpha 100) — the order proves the highlight
    // backs the event rather than covering it.
    expect(
      eventsCanvas(),
      paints
        ..rect(
          rect: const Rect.fromLTWH(200, 0, 200, 960),
          color: const Color(0xFF00FF00),
        )
        ..rect(color: const Color(0x642244AA)),
    );
  });
}
