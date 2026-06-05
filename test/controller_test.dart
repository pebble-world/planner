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
}
