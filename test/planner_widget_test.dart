import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';
import 'package:planner/planner_time.dart';

void main() {
  // End-to-end against the *real* composed widget (real layout, real fonts, real
  // gestures) — the layer where the static-state bug actually bit: two Planners
  // on one screen sharing a single scroll/zoom position.

  // A point inside a planner's event grid: skip the hour column (50) and date
  // row (50), then +100px right / +200px down so it lands cleanly in the grid.
  Offset gridPointFor(Rect planner) =>
      planner.topLeft + const Offset(50 + 100, 50 + 200);

  // Right-click a planner to open its context menu, then tap "Create Event". The
  // menu's time is computed from the current scroll/zoom via getTimeAtPos, so the
  // resulting onEntryCreate callback reveals where the tap mapped to. The finder
  // is scoped to [plannerKey] so two planners on screen stay unambiguous.
  Future<void> createViaMenu(
      WidgetTester tester, Key plannerKey, Offset at) async {
    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    await tester.tap(find.descendant(
      of: find.byKey(plannerKey),
      matching: find.text('Create Event'),
    ));
    await tester.pump();
  }

  Future<void> wheelScroll(WidgetTester tester, Offset at, int notches) async {
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(at));
    for (var i = 0; i < notches; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
      await tester.pump();
    }
  }

  testWidgets('two planners keep independent scroll state (D1)',
      (tester) async {
    const keyA = ValueKey('plannerA');
    const keyB = ValueKey('plannerB');
    PlannerTime? createdA;
    PlannerTime? createdB;

    PlannerConfig configFor(void Function(PlannerTime) onCreate) =>
        PlannerConfig(
          labels: const ['c1', 'c2', 'c3'],
          minHour: 0,
          maxHour: 23,
          onEntryCreate: onCreate,
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: Planner(
                key: keyA,
                config: configFor((t) => createdA = t),
                entries: const [],
              ),
            ),
            Expanded(
              child: Planner(
                key: keyB,
                config: configFor((t) => createdB = t),
                entries: const [],
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final pointA = gridPointFor(tester.getRect(find.byKey(keyA)));
    final pointB = gridPointFor(tester.getRect(find.byKey(keyB)));

    // The chosen point maps to hour 5 in an unscrolled grid (200px / 40px).
    const unscrolledHour = 5;

    // Scroll ONLY planner A (before opening any menu, which otherwise leaves a
    // lingering overlay that blocks the wheel).
    await wheelScroll(tester, pointA, 4);

    await createViaMenu(tester, keyA, pointA);
    await createViaMenu(tester, keyB, pointB);
    expect(createdA, isNotNull);
    expect(createdB, isNotNull);

    // A scrolled down, so the same screen point now maps to a later hour; B was
    // never touched and still maps to the unscrolled hour. Under the old static
    // state, scrolling A also moved B and both would report the later hour.
    expect(createdA!.hour, greaterThan(unscrolledHour),
        reason: 'scrolling A must change what A hit-tests');
    expect(createdB!.hour, unscrolledHour,
        reason: 'scrolling A must NOT change what B hit-tests');
  });

  testWidgets('scroll position survives a parent rebuild (D2)', (tester) async {
    const key = ValueKey('planner');
    PlannerTime? created;
    var tick = 0;
    late StateSetter rebuild;

    PlannerConfig makeConfig() => PlannerConfig(
          labels: const ['c1', 'c2', 'c3'],
          minHour: 0,
          maxHour: 23,
          onEntryCreate: (t) => created = t,
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            // Fresh config + entries list each build, like a real parent that
            // rebuilds for an unrelated reason. The Manager must NOT be torn down
            // and the scroll position must survive.
            return Planner(
              key: key,
              config: makeConfig(),
              entries: [
                PlannerEntry(
                  id: 'rebuild-$tick',
                  time: PlannerTime(day: 0, hour: 1),
                  title: 'e$tick',
                  content: '',
                  color: const Color(0xFF112233),
                ),
              ],
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final point = gridPointFor(tester.getRect(find.byKey(key)));

    await wheelScroll(tester, point, 4);
    await createViaMenu(tester, key, point);
    expect(created, isNotNull);
    final scrolledHour = created!.hour;
    // Confirm the scroll actually moved the grid (unscrolled this point is hour 5),
    // otherwise the persistence check below would pass trivially.
    expect(scrolledHour, greaterThan(5));

    // Force a parent rebuild with fresh config/entries.
    tick++;
    rebuild(() {});
    await tester.pumpAndSettle();

    await createViaMenu(tester, key, point);
    expect(created!.hour, scrolledHour,
        reason: 'scroll position must survive a parent rebuild');
  });
}
