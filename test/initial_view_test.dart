import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

/// Widget coverage for `PlannerConfig.initialHour` / `initialZoom` (#111),
/// driving the real composed [Planner]. Each test reads the opening view back
/// out the way a user would: right-click a fixed grid point and see which time
/// "Create Event" reports (getTimeAtPos maps through the live scroll and zoom).
///
/// The default 800x600 test surface gives a 600px planner; past the 50px date
/// row the grid viewport is 550px, and the 0..23 grid is 24 * 40 = 960px tall at
/// zoom 1, so the time axis can scroll at most 410px.
void main() {
  const key = ValueKey('planner');

  // Past the hour column (50) and date row (50), 100px right and 200px down.
  // Unscrolled at zoom 1 this is hour 200 / 40 = 5.
  Offset gridPoint(WidgetTester tester) =>
      tester.getRect(find.byKey(key)).topLeft +
      const Offset(50 + 100, 50 + 200);

  Future<PlannerTime> createAt(
      WidgetTester tester, Offset at, List<PlannerTime> created) async {
    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.tap(find.text('Create Event'));
    await tester.pump();
    expect(created, isNotEmpty);
    return created.last;
  }

  Future<List<PlannerTime>> pumpPlanner(
    WidgetTester tester, {
    double? initialHour,
    double initialZoom = 1.0,
    PlannerController? controller,
  }) async {
    final created = <PlannerTime>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          key: key,
          controller: controller,
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            initialHour: initialHour,
            initialZoom: initialZoom,
            onEntryCreate: created.add,
          ),
          entries: const [],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return created;
  }

  testWidgets('with no initialHour/initialZoom the grid opens at the top',
      (tester) async {
    final created = await pumpPlanner(tester);
    final time = await createAt(tester, gridPoint(tester), created);
    expect(time.hour, 5);
  });

  testWidgets('initialHour opens the grid scrolled to that hour',
      (tester) async {
    final created = await pumpPlanner(tester, initialHour: 8);
    final time = await createAt(tester, gridPoint(tester), created);
    expect(time.hour, 8 + 5, reason: 'hour 8 is at the top of the grid');
  });

  testWidgets('a late initialHour clamps to the bottom of the grid',
      (tester) async {
    // Hour 23 at the top would over-scroll; it clamps to the max scroll of
    // 410px, so the 200px point maps to (410 + 200) / 40 = hour 15.25.
    final created = await pumpPlanner(tester, initialHour: 23);
    final time = await createAt(tester, gridPoint(tester), created);
    expect(time.hour, 15,
        reason: 'over-scrolled, the point would clamp to hour 23');
  });

  testWidgets('initialZoom combines with initialHour', (tester) async {
    // At zoom 2 an hour row is 80px: hour 8 at the top, and the 200px point is
    // 2.5 hours further down — 10:30.
    final created = await pumpPlanner(tester, initialHour: 8, initialZoom: 2);
    final time = await createAt(tester, gridPoint(tester), created);
    expect(time.hour, 10);
    expect(time.minutes, 30);
  });

  testWidgets('a PlannerController sees the initial view after the first frame',
      (tester) async {
    final controller = PlannerController();
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);

    await pumpPlanner(tester,
        initialHour: 8, initialZoom: 2, controller: controller);

    expect(controller.zoom, 2.0);
    expect(controller.timeScroll, -8 * 80);
    expect(notified, greaterThan(0),
        reason: 'listeners hear about the initial view once it is laid out');
  });

  testWidgets('the initial view is not re-applied on a rebuild',
      (tester) async {
    final created = <PlannerTime>[];
    late StateSetter rebuild;
    var initialHour = 8.0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          // A fresh config each build, as a real parent would pass.
          return Planner(
            key: key,
            config: PlannerConfig(
              labels: const ['c1', 'c2', 'c3'],
              initialHour: initialHour,
              onEntryCreate: created.add,
            ),
            entries: const [],
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();

    // The user scrolls 4 wheel notches (4 * 20px = 2 hours) further down.
    final at = gridPoint(tester);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(at));
    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
      await tester.pump();
    }
    expect((await createAt(tester, at, created)).hour, 8 + 2 + 5);

    // The parent rebuilds — even with a different initialHour.
    initialHour = 2;
    rebuild(() {});
    await tester.pumpAndSettle();

    expect((await createAt(tester, at, created)).hour, 8 + 2 + 5,
        reason: 'a rebuild must not jump the scroll back');
  });
}
