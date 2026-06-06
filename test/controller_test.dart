import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/controller.dart';
import 'package:planner/planner.dart';

void main() {
  PlannerConfig makeConfig() => PlannerConfig(labels: const ['A', 'B', 'C']);

  group('Controller scroll/zoom state is per-instance', () {
    // Regression for D1: these fields used to be `static`, so two controllers
    // (i.e. two Planners in the same app) shared one scroll/zoom position.
    test('horizontal/vertical offset does not leak between controllers', () {
      final a = Controller(makeConfig());
      final b = Controller(makeConfig());

      a.x = -120;
      a.y = -80;

      expect(a.x, -120);
      expect(a.y, -80);
      expect(b.x, 0, reason: 'b must keep its own offset');
      expect(b.y, 0, reason: 'b must keep its own offset');
    });

    test('zoom does not leak between controllers', () {
      final a = Controller(makeConfig());
      final b = Controller(makeConfig());

      a.startZoom();
      a.updateZoom(2.0);

      expect(a.zoom, 2.0);
      expect(b.zoom, 1.0, reason: 'b must keep its own zoom');
    });

    test('drag state does not leak between controllers', () {
      final config = makeConfig();
      final a = Controller(config);
      final b = Controller(config);

      a.startHorizontalDrag(100);
      a.updateHorizontalDrag(80); // drag left by 20px

      expect(a.x, lessThan(0));
      expect(b.x, 0, reason: 'dragging a must not move b');
    });
  });

  test('updateConfig recomputes bounds but keeps current scroll/zoom', () {
    final controller = Controller(makeConfig());
    controller.x = -50;
    controller.y = -30;
    controller.startZoom();
    controller.updateZoom(1.5);

    controller.updateConfig(PlannerConfig(labels: const ['A', 'B', 'C', 'D']));

    expect(controller.x, -50);
    expect(controller.y, -30);
    expect(controller.zoom, 1.5);
  });

  // Regression for D9 (#12): updateZoom multiplied without bounds, so pinch (or
  // the zoom buttons) could drive zoom toward 0 (blocks collapse, hit-testing
  // explodes) or grow it without limit. It now clamps to [minZoom, maxZoom].
  group('updateZoom clamps to [minZoom, maxZoom] (D9, #12)', () {
    test('zooming in past maxZoom clamps to maxZoom', () {
      final controller = Controller(makeConfig()); // defaults 0.5 .. 4.0
      controller.startZoom();
      controller.updateZoom(10.0);
      expect(controller.zoom, 4.0);
    });

    test('zooming out past minZoom clamps to minZoom', () {
      final controller = Controller(makeConfig());
      controller.startZoom();
      controller.updateZoom(0.01);
      expect(controller.zoom, 0.5);
    });

    test('honours custom minZoom/maxZoom from the config', () {
      final controller = Controller(
        PlannerConfig(labels: const ['A'], minZoom: 1.0, maxZoom: 2.0),
      );
      controller.startZoom();
      controller.updateZoom(5.0);
      expect(controller.zoom, 2.0);

      controller.startZoom();
      controller.updateZoom(0.1);
      expect(controller.zoom, 1.0);
    });

    test('repeated zoom-out (as the button does) never drops below minZoom',
        () {
      final controller = Controller(makeConfig());
      // The zoom-out button runs startZoom();updateZoom(0.9) on each press.
      for (var i = 0; i < 50; i++) {
        controller.startZoom();
        controller.updateZoom(0.9);
        expect(controller.zoom, greaterThanOrEqualTo(0.5));
      }
      expect(controller.zoom, 0.5, reason: 'bottoms out exactly at minZoom');
    });
  });

  // Regression for D12 (#28): verticalScroll used a fixed 20px step, so one wheel
  // notch moved progressively less *time* the further you zoomed in (each hour
  // row is `blockHeight * zoom` px tall). The step now scales with zoom.
  // Regression for #64: when the grid is narrower than the canvas,
  // _maxXOffset was positive, so any horizontal drag snapped x to that positive
  // value — pushing columns to the far right.  The guard now clamps it to 0.
  group('horizontal pan is a no-op when grid is narrower than viewport (#64)',
      () {
    Controller wideViewport() {
      // 3 labels × blockWidth 200 = 600 px of grid; canvas is 1600 px wide.
      final c = Controller(
        PlannerConfig(labels: const ['A', 'B', 'C'], blockWidth: 200),
      );
      c.setSize(const Size(1600, 900));
      return c;
    }

    test('x stays 0 after a left drag', () {
      final c = wideViewport();
      c.startHorizontalDrag(100);
      c.updateHorizontalDrag(80); // drag left 20 px
      expect(c.x, 0, reason: 'grid is fully visible — no horizontal pan');
    });

    test('x stays 0 after a right drag', () {
      final c = wideViewport();
      c.startHorizontalDrag(100);
      c.updateHorizontalDrag(200); // drag right 100 px
      expect(c.x, 0, reason: 'cannot pan right past x=0');
    });
  });

  group('verticalScroll step scales with zoom (D12, #28)', () {
    test('at zoom 1 one notch moves by the base scrollStep (default 20)', () {
      final controller = Controller(makeConfig());
      controller.verticalScroll(true); // wheel "up" scrolls the grid downward
      expect(controller.y, -20);
    });

    test('at higher zoom one notch moves a proportionally larger pixel step',
        () {
      final controller = Controller(makeConfig());
      controller.startZoom();
      controller.updateZoom(2.0);
      controller.verticalScroll(true);
      expect(controller.y, -40, reason: 'step is scrollStep * zoom (20 * 2)');
    });

    test('honours a custom scrollStep from the config', () {
      final controller =
          Controller(PlannerConfig(labels: const ['A'], scrollStep: 50));
      controller.verticalScroll(true);
      expect(controller.y, -50);
    });

    test('one notch moves a constant amount of TIME at any zoom', () {
      // time-per-notch = step / rowHeightOnScreen
      //               = (scrollStep * zoom) / (blockHeight * zoom)
      //               = scrollStep / blockHeight, independent of zoom.
      double hoursPerNotch(double zoom) {
        final controller = Controller(makeConfig());
        if (zoom != 1.0) {
          controller.startZoom();
          controller.updateZoom(zoom);
        }
        controller.verticalScroll(true);
        return controller.y.abs() / (controller.config.blockHeight * zoom);
      }

      expect(hoursPerNotch(1.0), closeTo(0.5, 1e-9)); // 20 / 40
      expect(hoursPerNotch(2.0), closeTo(hoursPerNotch(1.0), 1e-9));
      expect(hoursPerNotch(4.0), closeTo(hoursPerNotch(1.0), 1e-9));
    });
  });

  // Shift+wheel horizontal scroll (#65). Columns are a fixed blockWidth, so —
  // unlike verticalScroll — the step does NOT scale with zoom, and it clamps to
  // the same bounds as a horizontal drag.
  group('horizontalScroll (Shift+wheel, #65)', () {
    test('a forward notch scrolls the day axis (x decreases by scrollStep)',
        () {
      final controller = Controller(makeConfig()); // default scrollStep 20
      controller.horizontalScroll(true);
      expect(controller.x, -20);
    });

    test('a backward notch reverses it', () {
      final controller = Controller(makeConfig());
      controller.horizontalScroll(true); // x -> -20
      controller.horizontalScroll(false); // x -> 0
      expect(controller.x, 0);
    });

    test('cannot scroll right past x = 0', () {
      final controller = Controller(makeConfig());
      controller.horizontalScroll(false);
      expect(controller.x, 0, reason: 'clamped to _minXOffset');
    });

    test('honours a custom scrollStep from the config', () {
      final controller = Controller(
          PlannerConfig(labels: const ['A', 'B', 'C'], scrollStep: 50));
      controller.horizontalScroll(true);
      expect(controller.x, -50);
    });

    test('does not scale with zoom (columns are a fixed width)', () {
      final controller = Controller(makeConfig());
      controller.startZoom();
      controller.updateZoom(2.0);
      controller.horizontalScroll(true);
      expect(controller.x, -20, reason: 'the day-axis step ignores zoom');
    });

    test('is a no-op when the grid is narrower than the viewport (#64 clamp)',
        () {
      // 3 labels × blockWidth 200 = 600 px of grid; canvas 1600 px wide.
      final controller =
          Controller(PlannerConfig(labels: const ['A', 'B', 'C']));
      controller.setSize(const Size(1600, 900));
      controller.horizontalScroll(true);
      expect(controller.x, 0, reason: 'grid fully visible — nothing to scroll');
    });
  });
}
