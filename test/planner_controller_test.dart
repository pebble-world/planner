import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/controller.dart';
import 'package:planner/planner.dart';

/// Unit + widget coverage for the public [PlannerController] (#76): the handle a
/// host constructs and hands to [Planner] to drive and observe zoom from its own
/// chrome. The "in isolation" group binds the controller straight to an internal
/// [Controller] to assert attach/detach and notification plumbing precisely; the
/// "wired into a real Planner" group drives the actual composed widget.
void main() {
  PlannerConfig makeConfig({
    double minZoom = 0.5,
    double maxZoom = 4.0,
    bool showZoomControls = true,
  }) =>
      PlannerConfig(
        labels: const ['A', 'B', 'C'],
        minZoom: minZoom,
        maxZoom: maxZoom,
        showZoomControls: showZoomControls,
      );

  group('PlannerController in isolation (attached to an internal Controller)',
      () {
    test('a fresh controller is not attached', () {
      final pc = PlannerController();
      expect(pc.isAttached, isFalse);
    });

    test('read getters throw a StateError while unattached', () {
      final pc = PlannerController();
      expect(() => pc.zoom, throwsStateError);
      expect(() => pc.minZoom, throwsStateError);
      expect(() => pc.maxZoom, throwsStateError);
      expect(() => pc.dayScroll, throwsStateError);
      expect(() => pc.timeScroll, throwsStateError);
    });

    test('zoom methods are silent no-ops while unattached', () {
      final pc = PlannerController();
      // Must not throw even though there's no planner to drive.
      expect(() => pc.zoomIn(), returnsNormally);
      expect(() => pc.zoomOut(), returnsNormally);
      expect(() => pc.zoomTo(2.0), returnsNormally);
    });

    test('attach exposes the inner zoom / bounds / scroll', () {
      final inner = Controller(makeConfig(minZoom: 0.25, maxZoom: 8.0));
      final pc = PlannerController()..attach(inner);

      expect(pc.isAttached, isTrue);
      expect(pc.zoom, 1.0);
      expect(pc.minZoom, 0.25);
      expect(pc.maxZoom, 8.0);
      expect(pc.dayScroll, 0.0);
      expect(pc.timeScroll, 0.0);

      // Scroll is read-only here but must reflect the inner controller.
      inner.x = -120;
      inner.y = -80;
      expect(pc.dayScroll, -120);
      expect(pc.timeScroll, -80);
    });

    test('zoomIn / zoomOut multiply the inner zoom', () {
      final inner = Controller(makeConfig());
      final pc = PlannerController()..attach(inner);

      pc.zoomIn(); // *1.1
      expect(pc.zoom, closeTo(1.1, 1e-9));
      expect(inner.zoom, closeTo(1.1, 1e-9), reason: 'drives the one inner');

      pc.zoomOut(); // *0.9
      expect(pc.zoom, closeTo(1.1 * 0.9, 1e-9));

      pc.zoomIn(2.0); // explicit factor
      expect(pc.zoom, closeTo(1.1 * 0.9 * 2.0, 1e-9));
    });

    test('zoomTo sets an absolute zoom and clamps to [minZoom, maxZoom]', () {
      final inner = Controller(makeConfig()); // 0.5 .. 4.0
      final pc = PlannerController()..attach(inner);

      pc.zoomTo(2.0);
      expect(pc.zoom, closeTo(2.0, 1e-9));

      pc.zoomTo(100); // past maxZoom
      expect(pc.zoom, 4.0);

      pc.zoomTo(0.001); // past minZoom
      expect(pc.zoom, 0.5);
    });

    test('zoomTo from a degenerate zoom of 0 is left untouched (no crash)', () {
      // Only reachable with a minZoom <= 0; there's no defined scale from 0 to a
      // target, so the guard leaves it where it is rather than producing NaN.
      final inner = Controller(makeConfig(minZoom: 0, maxZoom: 4));
      final pc = PlannerController()..attach(inner);

      pc.zoomTo(0); // current 1 -> scale 0 -> clamps to 0
      expect(pc.zoom, 0);

      pc.zoomTo(2); // current 0 -> guard returns
      expect(pc.zoom, 0);
    });

    test('notifies listeners on every inner view change (zoom and scroll)', () {
      final inner = Controller(makeConfig());
      final pc = PlannerController()..attach(inner);

      var notifications = 0;
      pc.addListener(() => notifications++);

      pc.zoomIn();
      expect(notifications, 1, reason: 'zoom change re-emits');

      inner.x = -50; // a scroll bumps triggerUpdate too
      expect(notifications, 2, reason: 'scroll change re-emits as well');
    });

    test('detach removes the listener so nothing leaks past the planner', () {
      final inner = Controller(makeConfig());
      final pc = PlannerController()..attach(inner);

      var notifications = 0;
      pc.addListener(() => notifications++);

      pc.zoomIn();
      expect(notifications, 1);

      pc.detach();
      expect(pc.isAttached, isFalse);

      // Further inner changes must not reach the detached controller.
      inner.startZoom();
      inner.updateZoom(1.1);
      inner.x = -30;
      expect(notifications, 1, reason: 'no notifications after detach');
    });

    test('re-attaching the same inner does not double the listener', () {
      final inner = Controller(makeConfig());
      final pc = PlannerController()
        ..attach(inner)
        ..attach(inner); // no-op

      var notifications = 0;
      pc.addListener(() => notifications++);

      inner.startZoom();
      inner.updateZoom(1.1);
      expect(notifications, 1,
          reason: 'a single listener despite double attach');
    });

    test('attaching a different inner detaches the previous one', () {
      final first = Controller(makeConfig());
      final second = Controller(makeConfig());
      final pc = PlannerController()..attach(first);

      var notifications = 0;
      pc.addListener(() => notifications++);

      // Swap to a different inner; the first must now be detached.
      pc.attach(second);

      first.startZoom();
      first.updateZoom(1.1);
      expect(notifications, 0, reason: 'previous inner was detached on swap');

      second.startZoom();
      second.updateZoom(1.1);
      expect(notifications, 1, reason: 'the new inner drives notifications');
    });

    test('dispose detaches a still-attached controller', () {
      final inner = Controller(makeConfig());
      final pc = PlannerController()..attach(inner);

      var notifications = 0;
      pc.addListener(() => notifications++);
      pc.dispose();

      // A notify after dispose would throw on a ChangeNotifier; detaching in
      // dispose means the inner's listener is gone, so this is silent.
      expect(() {
        inner.startZoom();
        inner.updateZoom(1.1);
      }, returnsNormally);
      expect(notifications, 0);
    });
  });

  group('PlannerController wired into a real Planner', () {
    Widget app(PlannerController? controller, {PlannerConfig? config}) =>
        MaterialApp(
          home: Scaffold(
            body: Planner(
              config: config ?? makeConfig(),
              entries: const [],
              controller: controller,
            ),
          ),
        );

    testWidgets('attaches on mount and exposes the live zoom / bounds',
        (tester) async {
      final pc = PlannerController();
      await tester.pumpWidget(app(pc));
      await tester.pumpAndSettle();

      expect(pc.isAttached, isTrue);
      expect(pc.zoom, 1.0);
      expect(pc.minZoom, 0.5);
      expect(pc.maxZoom, 4.0);
    });

    testWidgets('zoomIn / zoomOut / zoomTo change the grid zoom',
        (tester) async {
      final pc = PlannerController();
      await tester.pumpWidget(app(pc));
      await tester.pumpAndSettle();

      pc.zoomIn();
      await tester.pump();
      expect(pc.zoom, closeTo(1.1, 1e-9));

      pc.zoomTo(3.0);
      await tester.pump();
      expect(pc.zoom, closeTo(3.0, 1e-9));

      pc.zoomOut();
      await tester.pump();
      expect(pc.zoom, closeTo(3.0 * 0.9, 1e-9));
    });

    testWidgets('a host listener is notified when the zoom changes',
        (tester) async {
      final pc = PlannerController();
      var notifications = 0;
      pc.addListener(() => notifications++);

      await tester.pumpWidget(app(pc));
      await tester.pumpAndSettle();

      pc.zoomIn();
      await tester.pump();
      expect(notifications, greaterThan(0),
          reason: 'a toolbar can rebuild to disable + at maxZoom');
    });

    testWidgets('external controller and on-canvas buttons share one zoom',
        (tester) async {
      final pc = PlannerController();
      await tester.pumpWidget(app(pc));
      await tester.pumpAndSettle();

      // Tapping the built-in zoom-in button moves the same zoom the external
      // controller reads — proof there's a single source of truth, not a copy.
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(pc.zoom, closeTo(1.1, 1e-9));
    });

    testWidgets('detaches cleanly when the planner is unmounted',
        (tester) async {
      final pc = PlannerController();
      await tester.pumpWidget(app(pc));
      await tester.pumpAndSettle();
      expect(pc.isAttached, isTrue);

      // Replace the planner with something else -> Planner.dispose -> detach.
      await tester
          .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();

      expect(pc.isAttached, isFalse);
      expect(() => pc.zoomIn(), returnsNormally,
          reason: 'a stray call after unmount is a no-op, not a crash');
    });

    testWidgets('swapping the controller re-binds without leaking the old one',
        (tester) async {
      final a = PlannerController();
      final b = PlannerController();
      final config = makeConfig();

      await tester.pumpWidget(app(a, config: config));
      await tester.pumpAndSettle();
      expect(a.isAttached, isTrue);

      // Same Planner position, different controller -> didUpdateWidget swap.
      await tester.pumpWidget(app(b, config: config));
      await tester.pumpAndSettle();

      expect(a.isAttached, isFalse, reason: 'old controller detached');
      expect(b.isAttached, isTrue, reason: 'new controller attached');

      // The new controller drives the planner; the old one is inert.
      b.zoomTo(2.0);
      await tester.pump();
      expect(b.zoom, closeTo(2.0, 1e-9));
      expect(() => a.zoomIn(), returnsNormally);
    });

    testWidgets('a Planner with no controller behaves as before',
        (tester) async {
      // The built-in zoom buttons still work and nothing throws when no
      // controller is supplied (the opt-in default path).
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(() async {
        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
      }, returnsNormally);
    });
  });
}
