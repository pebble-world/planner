import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for column-spanning events (#47): a [PlannerEntry] whose
/// [PlannerTime.endDay] is set after [PlannerTime.day] renders across the whole
/// `day..endDay` column range, is reachable by a pointer from *any* column it
/// covers (not just the start column), and is read-only in this first cut —
/// a long-press drag must not move it.
///
/// The span is drawn on the `CustomPaint` canvas and hit-tested by
/// `getEventAtPos`, neither of which an isolated widget test exercises with real
/// layout/fonts/gestures. So this drives the real composed widget and asserts
/// what the canvas actually paints plus how real secondary-tap / long-press
/// gestures resolve.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void spanScenarios() {
  // Scope `paints` assertions to the events canvas so surrounding chrome can't
  // match (mirrors the highlight-column scenario).
  Finder eventsCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is EventsPainter,
      );

  PlannerSpec spanningPlanner({
    void Function(PlannerEntry)? onEntryEdit,
    void Function(PlannerEntry)? onEntryMove,
  }) =>
      PlannerSpec(
        config: PlannerConfig(
          labels: const ['c1', 'c2', 'c3'],
          minHour: 0,
          maxHour: 23,
          onEntryEdit: onEntryEdit,
          onEntryMove: onEntryMove,
        ),
        entries: [
          PlannerEntry(
            id: 'span',
            time: PlannerTime(day: 0, endDay: 1, hour: 2, duration: 60),
            title: 'Conference',
            content: '',
            color: const Color(0xFF2244AA),
          ),
        ],
      );

  testWidgets(
      'a span paints one box across its columns and hit-tests from each',
      (tester) async {
    final edited = <String>[];

    await tester.pumpWidget(PlannerHarness(
      planners: [spanningPlanner(onEntryEdit: (e) => edited.add(e.id))],
    ));
    await tester.pumpAndSettle();

    // Default 200x40 grid, no scroll/zoom: the span over columns 0..1 at 02:00
    // for 60 min draws ONE continuous fill box from x 0..400 at y 80..120 (its
    // colour is entry.color at alpha 100). A single-column event would only
    // reach x 200 — the 400-wide box is the spanning behaviour itself.
    expect(
      eventsCanvas(),
      paints
        ..rect(
          rect: const Rect.fromLTWH(0, 80, 400, 40),
          color: const Color(0x642244AA),
        ),
    );

    final plannerFinder = find.byKey(PlannerHarness.keyFor(0));
    final planner = tester.getRect(plannerFinder);

    // Right-click column 1 — the span's NON-start column. Past the hour column
    // (50) and date row (50), its centre is planner-local (50 + 300, 50 + 100).
    // The menu must resolve to the span, proving it hit-tests from a column it
    // covers but does not start in.
    final inColumn1 = planner.topLeft + const Offset(50 + 300, 50 + 100);
    await _rightClickEdit(tester, plannerFinder, inColumn1);
    expect(edited.last, 'span',
        reason:
            'the span must hit-test from a column it covers, not just its start');
  });

  testWidgets('a span is read-only: a long-press drag does not move it',
      (tester) async {
    final moved = <String>[];

    await tester.pumpWidget(PlannerHarness(
      planners: [spanningPlanner(onEntryMove: (e) => moved.add(e.id))],
    ));
    await tester.pumpAndSettle();

    final planner = tester.getRect(find.byKey(PlannerHarness.keyFor(0)));
    // Press on the span (column 0 centre) and try to drag it a full column
    // right. A draggable event would fire onEntryMove on release; the span must
    // not (#47 — read-only first cut).
    final onSpan = planner.topLeft + const Offset(50 + 100, 50 + 100);
    await longPressDrag(tester, onSpan, const Offset(200, 0));

    expect(moved, isEmpty,
        reason: 'spanning events cannot be dragged/resized (#47)');
  });
}

/// Right-clicks [at] to open the entry context menu, then taps "Edit Event"
/// (scoped to [planner]) so `onEntryEdit` fires with the event under the click.
Future<void> _rightClickEdit(
    WidgetTester tester, Finder planner, Offset at) async {
  final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();

  await tester.tap(find.descendant(
    of: planner,
    matching: find.text('Edit Event'),
  ));
  await tester.pumpAndSettle();
}
