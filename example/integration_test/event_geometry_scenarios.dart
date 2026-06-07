import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for event geometry (#10): an
/// event's painted rectangle — and therefore where it hit-tests — must derive
/// from `config.blockHeight` and place minutes proportionally. The buggy code
/// hardcoded a 40px block and snapped the minute offset to the 15-min grid, so
/// with any other `blockHeight` every event mis-sized and mis-positioned.
///
/// This drives the *real* composed widget (real layout, real fonts, real
/// secondary-tap gesture) with a non-default `blockHeight` and right-clicks a
/// point that lands inside the event ONLY under the correct geometry. Right-
/// clicking an event opens its menu ("Edit Event" / "Delete Event"); empty grid
/// shows "Create Event" — which is what the buggy geometry produced at this
/// point, because the event there was sized at 40px and its minute offset was
/// quantized.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void eventGeometryScenarios() {
  testWidgets(
      'event hit-area derives from blockHeight and proportional minutes',
      (tester) async {
    PlannerEntry? edited;
    PlannerTime? created;

    final entry = PlannerEntry(
      id: 'evt',
      time: PlannerTime(day: 0, hour: 2, minutes: 30, duration: 60),
      title: 'Geometry',
      content: '',
      color: const Color(0xFF2244AA),
    );

    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['col'],
            minHour: 0,
            maxHour: 23,
            blockHeight: 80,
            onEntryEdit: (e) => edited = e,
            onEntryCreate: (t) => created = t,
          ),
          entries: [entry],
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // The event occupies, in grid coords (blockHeight 80):
    //   correct:  top = 2*80 + 30/60*80 = 200, bottom = 200 + 60/60*80 = 280
    //   buggy:    top = 2*80 + round(30/15)*10 = 180, bottom = 180 + 60/60*40 = 220
    // y = 250 (grid) sits inside the correct rect but below the buggy one. Skip
    // the hour column (50) and date row (50); +100px right lands in column 0.
    final planner = tester.getRect(find.byKey(PlannerHarness.keyFor(0)));
    final at = planner.topLeft + const Offset(50 + 100, 50 + 250);

    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Edit Event'), findsOneWidget,
        reason: 'y=250 must fall inside the event under blockHeight-derived '
            'geometry; the buggy 40px/quantized geometry left it empty');
    expect(find.text('Create Event'), findsNothing);

    await tester.tap(find.text('Edit Event'));
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.id, 'evt');
    expect(created, isNull);
  });
}
