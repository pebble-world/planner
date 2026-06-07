import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guards for the 2D pan and mouse-wheel modifiers of the
/// direct-manipulation model (#65):
///
///  * dragging empty canvas pans **both** axes (the day axis used to be the only
///    one a body drag could pan);
///  * plain wheel scrolls the time axis (unchanged), Shift+wheel scrolls the day
///    axis, Ctrl+wheel zooms.
///
/// Each effect is observed through the real create-menu time mapping
/// (`getTimeAtPos`, which reads the live scroll/zoom): where a fixed screen point
/// lands *after* the gesture reveals how the view moved. The gesture runs
/// *before* any menu is opened — a context menu leaves a lingering overlay that
/// would otherwise swallow the drag/wheel (see `multi_planner_scenarios`). This
/// drives the real composed widget so the gesture routing (recognizer + wheel
/// modifiers) is exercised, not just the controller maths.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void panZoomScenarios() {
  // A grid much larger than any test window in both axes, so panning/scrolling
  // is never clamped to zero: blockWidth 200 × 40 columns and blockHeight 60 ×
  // 24 hours.
  PlannerSpec bigGrid({void Function(PlannerTime)? onEntryCreate}) =>
      PlannerSpec(
        config: PlannerConfig(
          labels: List.generate(40, (i) => 'c$i'),
          minHour: 0,
          maxHour: 23,
          blockHeight: 60,
          onEntryCreate: onEntryCreate,
        ),
      );

  testWidgets('dragging empty canvas pans both the day and time axes',
      (tester) async {
    PlannerTime? created;
    await tester.pumpWidget(
        PlannerHarness(planners: [bigGrid(onEntryCreate: (t) => created = t)]));
    await tester.pumpAndSettle();

    final planner = find.byKey(PlannerHarness.keyFor(0));
    final rect = tester.getRect(planner);

    // At rest a fixed probe maps to a known cell. Events-local (150,150):
    // day floor(150/200)=0, hour floor(150/60)=2. We assert against that
    // analytic baseline rather than an extra create (which would open a menu and
    // block the drag below).
    final probe = rect.topLeft + const Offset(50 + 150, 50 + 150);

    // Drag empty canvas up-and-left so later columns and later hours scroll into
    // view. Several small steps: the scale recognizer starts only after the pan
    // slop, so the first step seeds the drag and the rest pan ~150px per axis.
    final from = rect.topLeft + const Offset(50 + 500, 50 + 350);
    final gesture =
        await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await gesture.moveBy(const Offset(-10, -10));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // The same screen point now maps to a later column AND a later hour — proof
    // both axes panned (a horizontal-only pan would leave the hour at 2).
    await createViaMenu(tester, planner, probe);
    expect(created!.day, greaterThan(0), reason: 'the day axis panned');
    expect(created!.hour, greaterThan(2), reason: 'the time axis panned');
  });

  testWidgets('Shift+wheel scrolls the day axis', (tester) async {
    PlannerTime? created;
    await tester.pumpWidget(
        PlannerHarness(planners: [bigGrid(onEntryCreate: (t) => created = t)]));
    await tester.pumpAndSettle();

    final planner = find.byKey(PlannerHarness.keyFor(0));
    final rect = tester.getRect(planner);
    // At rest this probe maps to day 0 (x 100 / 200) and hour 1 (y 60 / 60).
    final probe = rect.topLeft + const Offset(50 + 100, 50 + 60);

    // Hold Shift and wheel 10 notches: the day axis scrolls 10 × scrollStep (20)
    // = 200px == one column, so the probe now maps to day 1; the time axis is
    // untouched. Done before any menu so the wheel isn't swallowed by an overlay.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(probe));
    for (var i = 0; i < 10; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    await createViaMenu(tester, planner, probe);
    expect(created!.day, 1, reason: 'Shift+wheel scrolled the day axis');
    expect(created!.hour, 1,
        reason: 'Shift+wheel leaves the time axis where it was');
  });

  testWidgets('Ctrl+wheel zooms the time axis', (tester) async {
    PlannerTime? created;
    await tester.pumpWidget(PlannerHarness(planners: [
      PlannerSpec(
        config: PlannerConfig(
          labels: const ['c1', 'c2', 'c3'],
          minHour: 0,
          maxHour: 23,
          onEntryCreate: (t) => created = t,
        ),
      ),
    ]));
    await tester.pumpAndSettle();

    final planner = find.byKey(PlannerHarness.keyFor(0));
    final rect = tester.getRect(planner);
    // At rest, default blockHeight 40: events-local y 160 -> hour 4.
    final probe = gridPointFor(rect, downFromGridTop: 160);

    // Hold Ctrl and wheel up several notches to zoom in (each notch ×1.1). Rows
    // grow taller, so the same screen point maps to an earlier hour. Done before
    // any menu so the wheel reaches the canvas.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(probe));
    for (var i = 0; i < 5; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -20)));
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    await createViaMenu(tester, planner, probe);
    expect(created!.hour, lessThan(4),
        reason:
            'Ctrl+wheel zoomed in, so a fixed point maps to an earlier hour');
  });
}
