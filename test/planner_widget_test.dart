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

  // Press and hold past the long-press timeout (so the long-press recognizer
  // wins the gesture arena over pan/scale, exactly as a real user dragging an
  // event), then move and release.
  Future<void> longPressDrag(
      WidgetTester tester, Offset from, Offset delta) async {
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(delta);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  // Pumps a single full-screen Planner (3 columns, hours 0..23) for the zoom
  // tests and returns its on-screen rect. These read the *effective* zoom back
  // out through getTimeAtPos: with no scroll, a fixed screen point at events-
  // local y maps to hour floor(y / (zoom * blockHeight)). Tapping high enough
  // that the mapped hour stays in [minHour, maxHour] keeps the hour clamp out of
  // it, so the resulting hour is determined solely by the (clamped) zoom.
  Future<Rect> pumpZoomPlanner(
      WidgetTester tester, Key key, void Function(PlannerTime) onCreate) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          key: key,
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            onEntryCreate: onCreate,
          ),
          entries: const [],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.getRect(find.byKey(key));
  }

  Future<void> tapButton(
      WidgetTester tester, Key key, IconData icon, int times) async {
    final button =
        find.descendant(of: find.byKey(key), matching: find.byIcon(icon));
    for (var i = 0; i < times; i++) {
      await tester.tap(button);
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

  // Regression for D5 (#11): drag detection and the onEntryMove callback used to
  // run *inside* EventsPainter.paint(). A host's onEntryMove almost always
  // updates app state (setState), and calling setState during paint throws
  // "setState() called during build". Driving a real long-press drag whose
  // handler rebuilds therefore crashes on the old paint-side-effect code and
  // succeeds now that drag lives in the gesture layer.
  testWidgets('long-press drag moves an event without painting side effects',
      (tester) async {
    const key = ValueKey('planner');
    final moved = <PlannerEntry>[];

    // The event sits at day 0 / hour 9 -> grid rect (0,360)-(200,400) with the
    // default 200x40 blocks. On screen it is offset by the hour column (50) and
    // date row (50); its centre is therefore at planner-local (150, 430).
    final entry = PlannerEntry(
      id: 'evt',
      time: PlannerTime(day: 0, hour: 9),
      title: 'Drag me',
      content: '',
      color: const Color(0xFF2244AA),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return Planner(
              key: key,
              config: PlannerConfig(
                labels: const ['c1', 'c2', 'c3'],
                minHour: 0,
                maxHour: 23,
                // A real host handler: record the move and rebuild. Under the old
                // code this setState ran during paint and threw.
                onEntryMove: (e) => setState(() => moved.add(e)),
              ),
              entries: [entry],
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final center =
        tester.getRect(find.byKey(key)).topLeft + const Offset(150, 430);

    // Drag down exactly one block (40px == 1 hour).
    await longPressDrag(tester, center, const Offset(0, 40));

    expect(tester.takeException(), isNull,
        reason: 'onEntryMove must not fire during paint');
    expect(moved, hasLength(1), reason: 'the drag committed exactly one move');
    expect(entry.time.hour, 10, reason: 'a one-block drag advances one hour');
  });

  // Regression for D9 (#12): getTimeAtPos returned an overshoot day/hour for a
  // real tap past the last column/hour — reachable whenever the grid is smaller
  // than the viewport (few days/hours), leaving empty space the tap lands in.
  // Driven end-to-end through the real right-click "Create Event" flow.
  testWidgets('tapping past the grid clamps the created day/hour (D9)',
      (tester) async {
    const key = ValueKey('planner');
    PlannerTime? created;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          key: key,
          // 2 columns (days 0..1) and hours 0..5: a 400x240px grid, far smaller
          // than the 800x600 viewport, so a low/right tap lands in empty space
          // past the grid rather than on a cell.
          config: PlannerConfig(
            labels: const ['c1', 'c2'],
            minHour: 0,
            maxHour: 5,
            onEntryCreate: (t) => created = t,
          ),
          entries: const [],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Right of the last column AND below the last hour row: events-local
    // (450, 300) -> raw day floor(450/200)=2, raw hour floor(300/40)=7. (Kept
    // clear of the right edge so the context menu still fits on screen.)
    final at = tester.getRect(find.byKey(key)).topLeft +
        const Offset(50 + 450, 50 + 300);
    await createViaMenu(tester, key, at);

    expect(created, isNotNull);
    expect(created!.day, 1,
        reason: 'clamped to the last column (labels.length - 1)');
    expect(created!.hour, 5, reason: 'clamped to maxHour');
  });

  // Regression for D9 (#12): updateZoom multiplied without bounds, so the real
  // zoom-in button could grow zoom indefinitely. After zooming in well past
  // maxZoom (4.0), a fixed screen point still maps through the *capped* zoom: at
  // events-local y=350, floor(350 / (4.0 * 40)) = hour 2. Unbounded (~1.1^30 =
  // 17x) the same point would collapse to hour 0 — so this fails without the cap
  // and the hour clamp never masks it (2 and 0 are both in range).
  testWidgets('zooming in past maxZoom stays bounded (D9)', (tester) async {
    const key = ValueKey('planner');
    PlannerTime? created;
    final rect = await pumpZoomPlanner(tester, key, (t) => created = t);

    await tapButton(tester, key, Icons.zoom_in, 30);
    await createViaMenu(
        tester, key, rect.topLeft + const Offset(50 + 100, 50 + 350));

    expect(created, isNotNull);
    expect(created!.hour, 2,
        reason:
            'zoom is capped at maxZoom (4.0); unbounded it would be hour 0');
  });

  // Regression for D9 (#12): the real zoom-out button could shrink zoom toward 0,
  // blowing up getTimeAtPos's divide-by-zoom. After zooming out well past minZoom
  // (0.5), a fixed screen point maps through the *floored* zoom: at events-local
  // y=50, floor(50 / (0.5 * 40)) = hour 2. Unbounded (~0.9^40 = 0.015) the divide
  // would send the raw hour to ~84 (clamped away to maxHour 23) — so asserting an
  // exact in-range hour 2 isolates the minZoom floor from the hour clamp.
  testWidgets('zooming out past minZoom stays bounded (D9)', (tester) async {
    const key = ValueKey('planner');
    PlannerTime? created;
    final rect = await pumpZoomPlanner(tester, key, (t) => created = t);

    await tapButton(tester, key, Icons.zoom_out, 40);
    await createViaMenu(
        tester, key, rect.topLeft + const Offset(50 + 100, 50 + 50));

    expect(created, isNotNull);
    expect(created!.hour, 2,
        reason:
            'zoom is floored at minZoom (0.5); unbounded it would hit maxHour');
  });
}
