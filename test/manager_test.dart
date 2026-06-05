import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';
import 'package:planner/planner_time.dart';

void main() {
  PlannerConfig makeConfig() => PlannerConfig(labels: const ['A', 'B']);

  PlannerEntry makeEntry(String id, int day) => PlannerEntry(
        id: id,
        time: PlannerTime(day: day, hour: 9),
        title: 'event $id',
        content: '',
        color: const Color(0xFF112233),
      );

  test('builds one Event per entry', () {
    final manager = Manager(
      config: makeConfig(),
      entries: [makeEntry('1', 0), makeEntry('2', 1)],
    );

    expect(manager.events.length, 2);
  });

  // Regression for D2: previously a new Manager (and a new Controller) was built
  // on every parent rebuild, so scroll/zoom only survived via static state.
  // update() now refreshes the data in place while preserving the controller.
  test(
      'update() preserves the controller (and scroll/zoom) and refreshes events',
      () {
    final manager = Manager(
      config: makeConfig(),
      entries: [makeEntry('1', 0)],
    );

    final controllerBefore = manager.controller;
    manager.controller.x = -75;
    manager.controller.startZoom();
    manager.controller.updateZoom(1.5);

    manager.update(
      config: makeConfig(),
      entries: [makeEntry('1', 0), makeEntry('2', 1)],
    );

    expect(identical(manager.controller, controllerBefore), isTrue,
        reason: 'the controller must persist across an update');
    expect(manager.controller.x, -75, reason: 'scroll position is preserved');
    expect(manager.controller.zoom, 1.5, reason: 'zoom is preserved');
    expect(manager.events.length, 2, reason: 'events reflect the new entries');
  });
}
