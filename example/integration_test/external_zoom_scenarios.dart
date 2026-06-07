import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for the public [PlannerController] (#76): a host drives the
/// planner's zoom from its **own** toolbar (the built-in on-canvas buttons hidden
/// via `showZoomControls: false`), exercising the real attach lifecycle, real
/// Material buttons, real layout and real gesture/menu flow — the composition a
/// widget test in isolation can't cover.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void externalZoomScenarios() {
  const plannerKey = ValueKey('external-zoom-planner');
  const zoomInKey = ValueKey('host-zoom-in');
  const zoomOutKey = ValueKey('host-zoom-out');

  // The recommended external-zoom recipe: a host toolbar with its own +/- buttons
  // wired to a PlannerController, and the planner's on-canvas controls hidden.
  Widget hostApp(
    PlannerController controller,
    ValueChanged<PlannerTime> onCreate,
  ) =>
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: zoomOutKey,
                    icon: const Icon(Icons.remove),
                    onPressed: controller.zoomOut,
                  ),
                  IconButton(
                    key: zoomInKey,
                    icon: const Icon(Icons.add),
                    onPressed: controller.zoomIn,
                  ),
                ],
              ),
              Expanded(
                child: Planner(
                  key: plannerKey,
                  controller: controller,
                  config: PlannerConfig(
                    labels: const ['c1', 'c2', 'c3'],
                    minHour: 0,
                    maxHour: 23,
                    showZoomControls: false,
                    onEntryCreate: onCreate,
                  ),
                  entries: const [],
                ),
              ),
            ],
          ),
        ),
      );

  testWidgets('a host toolbar drives the real grid zoom (#76)', (tester) async {
    PlannerTime? created;
    final controller = PlannerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(hostApp(controller, (t) => created = t));
    await tester.pumpAndSettle();

    // showZoomControls:false hands zoom entirely to the host: no on-canvas
    // buttons, and the external controller is bound to the live planner.
    expect(find.byIcon(Icons.zoom_in), findsNothing);
    expect(find.byIcon(Icons.zoom_out), findsNothing);
    expect(controller.isAttached, isTrue);
    expect(controller.zoom, 1.0);

    final planner = find.byKey(plannerKey);
    final at = gridPointFor(tester.getRect(planner), downFromGridTop: 200);

    // At zoom 1 a point 200px below the grid top maps to hour 5 (200 / 40px row).
    await createViaMenu(tester, planner, at);
    expect(created, isNotNull);
    final baseHour = created!.hour;
    expect(baseHour, 5);

    // Zoom in via the host's *own* button. It must move the live grid, not just
    // the controller's number.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(zoomInKey));
      await tester.pump();
    }
    expect(controller.zoom, greaterThan(1.0),
        reason: 'the host button drove the real grid zoom');

    // Each hour row is now taller, so the same screen point covers fewer hours —
    // observable proof the grid actually re-zoomed end-to-end.
    created = null;
    await createViaMenu(tester, planner, at);
    final zoomedInHour = created!.hour;
    expect(zoomedInHour, lessThan(baseHour),
        reason: 'zoom enlarged the rows, so a fixed pixel maps to fewer hours');

    // Zooming back out via the other host button reverses the mapping.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(zoomOutKey));
      await tester.pump();
    }
    created = null;
    await createViaMenu(tester, planner, at);
    expect(created!.hour, greaterThan(zoomedInHour),
        reason: 'zoomOut shrank the rows again, mapping back toward hour 5');
  });

  testWidgets('the external controller and the grid share one zoom (#76)',
      (tester) async {
    final controller = PlannerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(hostApp(controller, (_) {}));
    await tester.pumpAndSettle();

    // A host listener (e.g. to enable/disable + at maxZoom) fires on a real tap.
    var notifications = 0;
    controller.addListener(() => notifications++);

    await tester.tap(find.byKey(zoomInKey));
    await tester.pump();

    expect(controller.zoom, closeTo(1.1, 1e-9));
    expect(notifications, greaterThan(0),
        reason: 'the controller re-emits so a toolbar can react');
  });
}
