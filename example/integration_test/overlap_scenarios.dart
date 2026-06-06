import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for D11 (#20): concurrent events used to paint at full
/// column width and stack on top of each other, so the rear event was both
/// invisible and unclickable — every point in the column hit-tested to the
/// first-drawn event. They now split the day-column into side-by-side
/// sub-columns, so each event occupies (and hit-tests to) its own half.
///
/// This drives the *real* composed widget (real layout, real fonts, real
/// secondary-tap gesture, real `getEventAtPos` hit-testing) with two events at
/// the same time, then right-clicks each sub-column and confirms the entry menu
/// resolves to the event that actually sits there. Under the old full-width
/// geometry the right sub-column would have resolved to the left ('left') event.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void overlapScenarios() {
  testWidgets('overlapping events lay out side by side and hit-test per column',
      (tester) async {
    final edited = <String>[];

    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['col'],
            minHour: 0,
            maxHour: 23,
            onEntryEdit: (e) => edited.add(e.id),
          ),
          entries: [
            PlannerEntry(
              id: 'left',
              time: PlannerTime(day: 0, hour: 2, duration: 60),
              title: 'Left',
              content: '',
              color: const Color(0xFF2244AA),
            ),
            PlannerEntry(
              id: 'right',
              time: PlannerTime(day: 0, hour: 2, duration: 60),
              title: 'Right',
              content: '',
              color: const Color(0xFFAA4422),
            ),
          ],
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final plannerFinder = find.byKey(PlannerHarness.keyFor(0));
    final planner = tester.getRect(plannerFinder);

    // Both events sit at day 0 / 02:00 for 60 min, so they split the 200px
    // day-column into 0..100 (left) and 100..200 (right) at grid y 80..120. Past
    // the hour column (50) and date row (50), the sub-column centres are
    // planner-local (100, 150) and (200, 150).
    final leftAt = planner.topLeft + const Offset(50 + 50, 50 + 100);
    final rightAt = planner.topLeft + const Offset(50 + 150, 50 + 100);

    // The RIGHT sub-column must open the right event's menu. Under the old
    // full-width geometry both events covered the whole column, so any click
    // resolved to the first-drawn ('left') event.
    await _rightClickEdit(tester, plannerFinder, rightAt);
    expect(edited.last, 'right',
        reason: 'the right sub-column must hit-test to the right event');

    // The LEFT sub-column must still open the left event's menu.
    await _rightClickEdit(tester, plannerFinder, leftAt);
    expect(edited.last, 'left',
        reason: 'the left sub-column must hit-test to the left event');
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
