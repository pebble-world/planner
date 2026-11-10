import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guards for `PlannerConfig.initialHour` / `initialZoom` (#111):
/// the real composed planner, on a real window size, opens at the configured
/// hour and zoom. Each scenario reads the opening view back the way a user
/// would — right-click a grid point and see which time "Create Event" reports.
///
/// The window size varies by device, so the configs leave enough grid below the
/// initial hour that no viewport reaches the bottom clamp — except the clamp
/// scenario, which derives its expectation from the planner's real height.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void initialViewScenarios() {
  Future<PlannerTime> openAndCreate(WidgetTester tester,
      PlannerConfig Function(void Function(PlannerTime)) build,
      {double downFromGridTop = 200}) async {
    PlannerTime? created;
    await tester.pumpWidget(PlannerHarness(
      planners: [PlannerSpec(config: build((t) => created = t))],
    ));
    await tester.pumpAndSettle();

    final planner = find.byKey(PlannerHarness.keyFor(0));
    final at =
        gridPointFor(tester.getRect(planner), downFromGridTop: downFromGridTop);
    await createViaMenu(tester, planner, at);
    expect(created, isNotNull);
    return created!;
  }

  testWidgets('initialHour opens the grid scrolled to that hour',
      (tester) async {
    // blockHeight 80 leaves 16 * 80 = 1280px of grid below hour 8, more than
    // any test window, so the hour is not clamped. 200px down is 2.5 hours on.
    final time = await openAndCreate(
      tester,
      (onCreate) => PlannerConfig(
        labels: const ['c1', 'c2', 'c3'],
        blockHeight: 80,
        initialHour: 8,
        onEntryCreate: onCreate,
      ),
    );
    expect(time.hour, 10);
    expect(time.minutes, 30);
  });

  testWidgets('initialZoom combines with initialHour', (tester) async {
    // At zoom 2 the default 40px row is 80px: hour 8 at the top, the 200px
    // point 2.5 hours further down. Below hour 8 there is again 1280px of grid.
    final time = await openAndCreate(
      tester,
      (onCreate) => PlannerConfig(
        labels: const ['c1', 'c2', 'c3'],
        initialHour: 8,
        initialZoom: 2,
        onEntryCreate: onCreate,
      ),
    );
    expect(time.hour, 10);
    expect(time.minutes, 30);
  });

  testWidgets('a late initialHour clamps to the bottom of the grid',
      (tester) async {
    final time = await openAndCreate(
      tester,
      (onCreate) => PlannerConfig(
        labels: const ['c1', 'c2', 'c3'],
        initialHour: 23,
        onEntryCreate: onCreate,
      ),
      downFromGridTop: 20,
    );
    // The grid viewport is the planner's height minus the 50px date row; the
    // 0..23 grid is 24 * 40 = 960px tall, so clamped at the bottom the top of
    // the viewport sits at hour 24 - viewport / 40, and 20px below it is half
    // an hour later. Over-scrolled, hour 23 would sit at the top instead.
    final viewport =
        tester.getRect(find.byKey(PlannerHarness.keyFor(0))).height - 50;
    expect(viewport, lessThan(960),
        reason: 'the window must be shorter than the grid to scroll at all');
    final expectedHour = ((960 - viewport + 20) / 40).floor();
    expect(time.hour, expectedHour,
        reason: 'the grid must stop at its last hour, not over-scroll');
    expect(time.hour, lessThan(23));
  });
}
