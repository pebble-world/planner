import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

/// A reusable end-to-end harness for integration tests that need more than the
/// single [Planner] the example app renders.
///
/// The example app intentionally renders one [Planner], so multi-planner
/// (independence) and multi-config (composition) flows need their own driveable
/// app. [PlannerHarness] lays out one [Planner] per [PlannerSpec] in an
/// equal-width [Row] and tags each with a stable [ValueKey] ('planner-0',
/// 'planner-1', …) so finders stay unambiguous when several are on screen.
class PlannerHarness extends StatelessWidget {
  const PlannerHarness({super.key, required this.planners});

  final List<PlannerSpec> planners;

  /// The key of the [Planner] at [index], for scoping finders.
  static Key keyFor(int index) => ValueKey('planner-$index');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            for (var i = 0; i < planners.length; i++)
              Expanded(
                child: Planner(
                  key: keyFor(i),
                  config: planners[i].config,
                  entries: planners[i].entries,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One planner's inputs for [PlannerHarness].
class PlannerSpec {
  const PlannerSpec({required this.config, this.entries = const []});

  final PlannerConfig config;
  final List<PlannerEntry> entries;
}

/// Navigates the gallery example app into the Showcase page (#90).
///
/// `main.dart` now boots a gallery home (a lazily-built list of example pages),
/// so the app-level scenarios — which assert against the all-hooks Showcase —
/// must open it first. Call right after `app.main()` and the initial
/// `pumpAndSettle()`. The Showcase is the last row, so [scrollUntilVisible]
/// scrolls it into view (and builds it) if the list is taller than the window,
/// making this work at any device size.
Future<void> openShowcase(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey('gallery-tile-showcase'));
  await tester.scrollUntilVisible(tile, 120);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// A point inside a planner's event grid: skip the hour column (default 50) and
/// the date row (default 50), then move +100px right / +[downFromGridTop] down
/// so it lands cleanly in the grid. With the default `blockHeight` of 40, the
/// vertical offset maps to hour `downFromGridTop / 40` in an unscrolled grid.
Offset gridPointFor(Rect planner, {double downFromGridTop = 200}) =>
    planner.topLeft + Offset(50 + 100, 50 + downFromGridTop);

/// Right-clicks [planner] to open its context menu, then taps "Create Event".
///
/// The menu's time is derived from the current scroll/zoom via `getTimeAtPos`,
/// so the resulting `onEntryCreate` callback reveals where [at] mapped to. The
/// "Create Event" finder is scoped to [planner] so two planners on screen stay
/// unambiguous.
Future<void> createViaMenu(
    WidgetTester tester, Finder planner, Offset at) async {
  final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
  await tester.pump();
  await gesture.up();
  await tester.pump();

  await tester.tap(find.descendant(
    of: planner,
    matching: find.text('Create Event'),
  ));
  await tester.pump();
}

/// Sends [notches] mouse-wheel scroll events at [at] (one pump each), the way a
/// user scrolls the time axis. Positive [notches] scroll the grid downward.
Future<void> wheelScroll(WidgetTester tester, Offset at, int notches) async {
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(at));
  for (var i = 0; i < notches; i++) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
    await tester.pump();
  }
}

/// Drags an event the desktop way: press at [from] with a mouse and drag by
/// [delta] immediately — a precise pointer on an event body moves it (or resizes
/// from a top/bottom edge) as soon as it moves, no long-press. The pointer-down
/// position anchors the drag, so the committed move equals [delta] (the scale
/// recognizer's start fires only past the pan slop, but the anchor is the press
/// point, so no slop distance is dropped).
Future<void> mouseDrag(WidgetTester tester, Offset from, Offset delta) async {
  final gesture =
      await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await tester.pump();
  await gesture.moveBy(delta);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}
