import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/all_day_band.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for the all-day band (#48): an entry flagged
/// [PlannerTime.allDay] renders as a chip in a band *between* the date row and
/// the time grid — under its column, spanning `day..endDay` for a multi-day
/// all-day event — instead of being hour-positioned. The band auto-sizes to its
/// stacked lanes and is omitted entirely when there are no all-day events.
///
/// The band is painted on its own `CustomPaint` canvas and its placement falls
/// out of the real `Column`/`Row` composition, neither of which an isolated
/// widget test exercises with real layout/fonts. So this drives the real
/// composed widget and asserts both what the band canvas paints and where it
/// lands relative to the date row and grid.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void allDayBandScenarios() {
  // Scope `paints` assertions to each canvas so surrounding chrome can't match.
  Finder allDayCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is AllDayBand,
      );
  Finder eventsCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is EventsPainter,
      );

  PlannerSpec withEntries(List<PlannerEntry> entries) => PlannerSpec(
        config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'], minHour: 0, maxHour: 23),
        entries: entries,
      );

  PlannerEntry allDay(String id, {required int day, int? endDay}) =>
      PlannerEntry(
        id: id,
        time: PlannerTime(day: day, endDay: endDay, allDay: true),
        title: id,
        content: '',
        color: const Color(0xFF2244AA),
      );

  testWidgets('an all-day chip paints in a band between the date row and grid',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(
      planners: [
        withEntries([allDay('holiday', day: 1)])
      ],
    ));
    await tester.pumpAndSettle();

    // Default geometry: hour column 50 wide, 200-wide columns, 24px lane, 2px
    // band padding + 2px chip inset. Column 1's chip is therefore the box
    // x 252..448, y 4..24 in the band canvas, filled with entry.color at alpha
    // 100 (0x642244AA). A timed event would instead paint down in the grid.
    expect(
      allDayCanvas(),
      paints
        ..rect(
          rect: const Rect.fromLTRB(252, 4, 448, 24),
          color: const Color(0x642244AA),
        ),
    );

    // The band sits below the 50px date row and the grid begins below the band
    // (its height is one lane + padding = 28) — proving the band is inserted
    // between them in the real composition, not overlaid on either.
    final bandRect = tester.getRect(allDayCanvas());
    final gridTop = tester.getRect(eventsCanvas()).top;
    expect(bandRect.top, 50);
    expect(gridTop, greaterThanOrEqualTo(bandRect.bottom));
  });

  testWidgets('a multi-day all-day event spans its columns in the band',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(
      planners: [
        withEntries([allDay('conf', day: 0, endDay: 1)])
      ],
    ));
    await tester.pumpAndSettle();

    // Columns 0..1 => one chip two columns wide: x 52..448 (gutter 50 + 2 inset
    // .. gutter + 2*200 - 2), still in lane 0. A single-column chip would only
    // reach x 248 — the 396-wide box is the spanning behaviour.
    expect(
      allDayCanvas(),
      paints
        ..rect(
          rect: const Rect.fromLTRB(52, 4, 448, 24),
          color: const Color(0x642244AA),
        ),
    );
  });

  testWidgets('no band is shown and the grid is flush when none are all-day',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(
      planners: [
        withEntries([
          PlannerEntry(
            id: 'meeting',
            time: PlannerTime(day: 0, hour: 9, duration: 60),
            title: 'Meeting',
            content: '',
            color: const Color(0xFF2244AA),
          ),
        ]),
      ],
    ));
    await tester.pumpAndSettle();

    expect(allDayCanvas(), findsNothing);
    // With no band the grid is flush under the 50px date row — the band reclaims
    // its space rather than leaving an empty strip.
    expect(tester.getRect(eventsCanvas()).top, 50);
  });
}
