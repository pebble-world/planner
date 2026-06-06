import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guards for the Outlook-style direct-manipulation model (#65):
///
///  * a desktop mouse hovering an event shows the cursor that matches what a
///    press would do — `move` over the body, `resizeUpDown` over the top/bottom
///    edge, `basic` over empty space (the discoverability cue for drag/resize);
///  * a one-finger **touch** drag pans rather than moving the event, so
///    scrolling stays possible and touch move/resize is left to the companion
///    long-press callback (#66) — it must not fire `onEntryMove`.
///
/// Hover cursors and gesture-kind routing live in the real composed widget
/// (MouseRegion hit-testing, the scale recognizer's device check), which an
/// isolated widget test with no real pointer devices can miss, so these drive
/// the real app.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void directManipulationScenarios() {
  // The events-canvas MouseRegion is the closest MouseRegion ancestor of the
  // events CustomPaint, so its cursor is the one the planner drives on hover.
  MouseCursor canvasCursor(WidgetTester tester) {
    final region = find
        .ancestor(
          of: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is EventsPainter,
          ),
          matching: find.byType(MouseRegion),
        )
        .first;
    return tester.widget<MouseRegion>(region).cursor;
  }

  PlannerSpec hostWith({void Function(PlannerEntry)? onEntryMove}) =>
      PlannerSpec(
        config: PlannerConfig(
          labels: const ['c1', 'c2', 'c3'],
          minHour: 0,
          maxHour: 23,
          onEntryMove: onEntryMove,
        ),
        entries: [
          PlannerEntry(
            id: 'evt',
            time: PlannerTime(day: 0, hour: 4),
            title: 'Touch me',
            content: '',
            color: const Color(0xFF2244AA),
          ),
        ],
      );

  testWidgets('hovering shows move over the body and resize over the edges',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(planners: [hostWith()]));
    await tester.pumpAndSettle();

    // The event sits at day 0 / hour 4 -> grid rect (0,160)-(200,200) with the
    // default 200x40 blocks. On screen it is offset by the hour column (50) and
    // date row (50).
    final origin = tester.getRect(find.byType(Planner)).topLeft;
    final body = origin + const Offset(50 + 100, 50 + 180); // 20px inside top
    final topEdge = origin + const Offset(50 + 100, 50 + 162); // <8px from top
    final empty = origin + const Offset(50 + 100, 50 + 20); // above the event

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: empty);
    await tester.pump();
    expect(canvasCursor(tester), SystemMouseCursors.basic,
        reason: 'empty space gets the default cursor');

    await mouse.moveTo(body);
    await tester.pump();
    expect(canvasCursor(tester), SystemMouseCursors.move,
        reason: 'the body offers a move');

    await mouse.moveTo(topEdge);
    await tester.pump();
    expect(canvasCursor(tester), SystemMouseCursors.resizeUpDown,
        reason: 'the top edge offers a resize');

    await mouse.moveTo(empty);
    await tester.pump();
    expect(canvasCursor(tester), SystemMouseCursors.basic,
        reason: 'leaving the event restores the default cursor');
  });

  testWidgets('a one-finger touch drag pans and does not move the event',
      (tester) async {
    final moved = <PlannerEntry>[];

    await tester.pumpWidget(
        PlannerHarness(planners: [hostWith(onEntryMove: moved.add)]));
    await tester.pumpAndSettle();

    // Press the event body (its centre) and drag with a finger. On touch a
    // one-finger drag always pans (move/resize is reserved for #66), so the
    // event must not move.
    final center =
        tester.getRect(find.byType(Planner)).topLeft + const Offset(150, 230);
    final gesture =
        await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(moved, isEmpty,
        reason: 'a touch drag pans the canvas; it does not move the event');
  });
}
