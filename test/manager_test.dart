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

  // Regression for D5 (#11): drag detection, the Event drag mutations, and the
  // onEntryMove callback used to live inside EventsPainter.paint(). They now live
  // on the Manager and are driven by the widget's gesture handlers, so the
  // lifecycle is exercisable directly and the painter stays pure.
  group('drag lifecycle', () {
    // Default config: blockWidth 200, blockHeight 40, minHour 0. An entry at
    // day 0 / hour 9 occupies grid rect (0,360)-(200,400); its centre (100,380)
    // is a body-drag (clear of the 8px top/bottom handle zones). With no scroll
    // or zoom, planner-local coordinates equal grid coordinates.
    Manager makeManager(void Function(PlannerEntry)? onMove) => Manager(
          config: PlannerConfig(labels: const ['A', 'B'], onEntryMove: onMove),
          entries: [makeEntry('1', 0)],
        );

    test('start/update/end moves the entry and fires onEntryMove once', () {
      final moved = <PlannerEntry>[];
      final manager = makeManager(moved.add);
      final entry = manager.events.first.entry;
      expect(entry.time.hour, 9);

      manager.startDrag(const Offset(100, 380));
      expect(manager.draggedEvent, isNotNull);

      manager.updateDrag(const Offset(100, 420)); // drag down one block (1h)
      expect(moved, isEmpty, reason: 'no callback fires mid-drag');

      manager.endDrag();
      expect(manager.draggedEvent, isNull);
      expect(entry.time.hour, 10, reason: 'a one-block drag advances one hour');
      expect(moved, hasLength(1),
          reason: 'onEntryMove fires exactly once, on end');
      expect(identical(moved.single, entry), isTrue);
    });

    test('startDrag on empty space is a no-op and never fires onEntryMove', () {
      var moves = 0;
      final manager = makeManager((_) => moves++);

      manager.startDrag(const Offset(100, 50)); // above the event (grid y<360)
      expect(manager.draggedEvent, isNull);

      manager.updateDrag(const Offset(100, 90)); // nothing is being dragged
      manager.endDrag();
      expect(moves, 0, reason: 'no event was picked up, so nothing moved');
    });
  });
}
