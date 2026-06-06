import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';
import 'package:planner/planner_time.dart';

import 'planner_harness.dart';

/// End-to-end guard for D8 (#14): create-time and drag-time snapping used to
/// apply different ad-hoc, zoom-dependent thresholds, so creating and dragging
/// an event landed on different sub-hour grids. Both now share one configurable
/// interval (`PlannerConfig.snapMinutes`).
///
/// These drive the *real* composed widget (real layout, real fonts, real
/// secondary-tap and long-press gestures). `blockHeight` is set to 60 so one
/// grid pixel equals one minute, making the snapped result read directly off the
/// pixel offset. With `snapMinutes` at its default (15), a 23-minute offset must
/// land on 15, not 23 — and create and drag must agree.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void snappingScenarios() {
  testWidgets('creating via the menu snaps the minute offset to snapMinutes',
      (tester) async {
    PlannerTime? created;

    await tester.pumpWidget(PlannerHarness(planners: [
      PlannerSpec(
        config: PlannerConfig(
          labels: const ['c1', 'c2'],
          minHour: 0,
          maxHour: 23,
          blockHeight: 60,
          onEntryCreate: (t) => created = t,
        ),
      ),
    ]));
    await tester.pumpAndSettle();

    // Grid y 143 == hour 2 (120) + 23 raw minutes; the +100px x lands in column 0.
    final planner = find.byKey(PlannerHarness.keyFor(0));
    final at =
        tester.getRect(planner).topLeft + const Offset(50 + 100, 50 + 143);
    await createViaMenu(tester, planner, at);

    expect(created, isNotNull);
    expect(created!.day, 0);
    expect(created!.hour, 2);
    expect(created!.minutes, 15,
        reason: '23 raw minutes snap down to the 15-min grid');
  });

  testWidgets('long-press dragging snaps the moved start to the same grid',
      (tester) async {
    final moved = <PlannerEntry>[];

    // An event at day 0 / hour 4 -> grid rect (0,240)-(200,300) with blockHeight
    // 60; its centre is a body drag (clear of the 8px handle zones).
    final entry = PlannerEntry(
      id: 'evt',
      time: PlannerTime(day: 0, hour: 4),
      title: 'Snap me',
      content: '',
      color: const Color(0xFF2244AA),
    );

    await tester.pumpWidget(PlannerHarness(planners: [
      PlannerSpec(
        config: PlannerConfig(
          labels: const ['c1', 'c2'],
          minHour: 0,
          maxHour: 23,
          blockHeight: 60,
          onEntryMove: moved.add,
        ),
        entries: [entry],
      ),
    ]));
    await tester.pumpAndSettle();

    // On screen the event centre is offset by the hour column (50) and date row
    // (50): grid (100, 270) -> planner-local (150, 320).
    final from = tester.getRect(find.byKey(PlannerHarness.keyFor(0))).topLeft +
        const Offset(150, 320);

    // Drag down 23px == 23 minutes: top 4:00 -> 4:23, snapped down to 4:15.
    await longPressDrag(tester, from, const Offset(0, 23));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(moved, hasLength(1), reason: 'the drag committed exactly one move');
    expect(moved.single.time.day, 0);
    expect(moved.single.time.hour, 4);
    expect(moved.single.time.minutes, 15,
        reason: 'a 23-minute drag snaps to the same 15-min grid as create');
  });
}
