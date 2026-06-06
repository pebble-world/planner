import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

void main() {
  // Regression for D8 (#14): create-time (`getTimeAtPos`) and drag-time
  // (`Event.endDrag`) snapping used to apply *different* ad-hoc, zoom-dependent
  // thresholds (`zoom>2.25`/`/10*15` vs `~/30`/`~/15`/`~/5`), so creating and
  // dragging an event landed on different grids. They now share one configurable
  // interval — `PlannerConfig.snapMinutes` via `Manager.snapToInterval`.

  // blockHeight 60 makes one grid-pixel == one minute, so the y-coordinates
  // below read directly as minutes-from-minHour. blockWidth stays default (200).
  Manager makeManager({
    int snapMinutes = 15,
    int Function(double zoom)? snapMinutesForZoom,
    PlannerTime? time,
  }) =>
      Manager(
        config: PlannerConfig(
          labels: const ['A', 'B'],
          minHour: 0,
          maxHour: 23,
          blockHeight: 60,
          snapMinutes: snapMinutes,
          snapMinutesForZoom: snapMinutesForZoom,
        ),
        entries: [
          PlannerEntry(
            id: 'e',
            time: time ?? PlannerTime(day: 0, hour: 9),
            title: 'e',
            content: '',
            color: const Color(0xFF112233),
          ),
        ],
      );

  group('create-time snapping (getTimeAtPos)', () {
    test('snaps the minute offset down to the default 15-min interval', () {
      // y = 263 == hour 4 (240) + 23 raw minutes -> snaps down to 15.
      final time = makeManager().getTimeAtPos(const Offset(100, 263));
      expect(time.hour, 4);
      expect(time.minutes, 15);
    });

    test('honours a custom snapMinutes', () {
      final time =
          makeManager(snapMinutes: 30).getTimeAtPos(const Offset(100, 263));
      expect(time.hour, 4);
      expect(time.minutes, 0,
          reason: '23 raw min snaps down to the 30-min grid');
    });

    test('snapMinutes <= 1 keeps minute precision', () {
      final time =
          makeManager(snapMinutes: 1).getTimeAtPos(const Offset(100, 263));
      expect(time.hour, 4);
      expect(time.minutes, 23, reason: 'snapping disabled -> exact minute');
    });
  });

  group('drag-time snapping (Event.endDrag)', () {
    // The single entry sits at day 0 / hour 9 -> grid rect (0,540)-(200,600)
    // with blockHeight 60. Driving the Event directly keeps the top/bottom
    // handle (8px) and body hit zones unambiguous.
    test('a body drag snaps the start time and keeps the duration', () {
      final e = makeManager().events.single;
      e.startDrag(const Offset(100, 570)); // body, clear of the 8px handles
      e.updateDrag(const Offset(100, 593)); // +23 min
      e.endDrag();
      expect(e.entry.time.hour, 9);
      expect(e.entry.time.minutes, 15, reason: '+23 snaps down to +15');
      expect(e.entry.time.duration, 60, reason: 'a move keeps the duration');
    });

    test('a top-handle drag snaps the start and pins the bottom edge', () {
      final e = makeManager().events.single;
      e.startDrag(const Offset(100, 540)); // top handle
      e.updateDrag(const Offset(100, 563)); // +23 min
      e.endDrag();
      expect(e.entry.time.hour, 9);
      expect(e.entry.time.minutes, 15);
      // The bottom edge (10:00) stays put: 9:15 + 45 == 10:00.
      expect(e.entry.time.duration, 45);
    });

    test('a bottom-handle drag snaps the bottom edge and pins the start', () {
      final e = makeManager().events.single;
      e.startDrag(const Offset(100, 599)); // bottom handle
      e.updateDrag(const Offset(100, 623)); // +24 min
      e.endDrag();
      expect(e.entry.time.hour, 9, reason: 'the start stays put');
      expect(e.entry.time.minutes, 0);
      // Bottom 10:00 + 24 == 10:24 snaps down to 10:15 -> duration 75.
      expect(e.entry.time.duration, 75);
    });
  });

  test('create and drag land on the same grid for the same y (D8)', () {
    // The whole point of the issue: the create tap and a body drag must agree.
    final created = makeManager().getTimeAtPos(const Offset(100, 263));

    // Drag an hour-0 event's body so its top lands at the same absolute y (263).
    final e = makeManager(time: PlannerTime(day: 0, hour: 0)).events.single;
    e.startDrag(const Offset(100, 30)); // body of the 0..60 rect
    e.updateDrag(const Offset(100, 293)); // +263
    e.endDrag();

    expect(e.entry.time.hour, created.hour);
    expect(e.entry.time.minutes, created.minutes);
    expect(created.hour, 4);
    expect(created.minutes, 15);
  });

  group('snap interval resolution', () {
    test('activeSnapMinutes falls back to the flat snapMinutes', () {
      final m = makeManager(snapMinutes: 10);
      expect(m.activeSnapMinutes, 10);
      expect(m.snapToInterval(23), 20);
    });

    test('snapMinutesForZoom overrides the flat value at the current zoom', () {
      final m = makeManager(
        snapMinutes: 15,
        snapMinutesForZoom: (z) => z >= 2 ? 5 : 30,
      );
      expect(m.activeSnapMinutes, 30, reason: 'zoom 1 -> coarse 30-min snap');
      expect(m.snapToInterval(23), 0);

      m.controller.startZoom();
      m.controller.updateZoom(2.5);
      expect(m.activeSnapMinutes, 5, reason: 'zoomed in -> fine 5-min snap');
      expect(m.snapToInterval(23), 20);
    });
  });
}
