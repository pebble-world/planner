import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/date_row.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/internal/grid.dart';
import 'package:planner/internal/hour_column.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

// Covers the three painter-performance fixes in #25:
//   D6 — shouldRepaint compares a data revision instead of always returning true
//   D7 — Grid caches the zoom-dependent line paints instead of allocating them
//        every frame
//   hit-testing — getEventAtPos scans only the tapped day-column's bucket
void main() {
  PlannerConfig makeConfig() => PlannerConfig(labels: const ['A', 'B']);

  PlannerEntry makeEntry(String id, int day) => PlannerEntry(
        id: id,
        time: PlannerTime(day: day, hour: 9),
        title: 'event $id',
        content: '',
        color: const Color(0xFF112233),
      );

  // Sets the controller to an absolute [zoom]: updateZoom multiplies the zoom
  // captured at startZoom by its scale argument.
  void setZoom(Manager manager, double zoom) {
    final current = manager.controller.zoom;
    manager.controller.startZoom();
    manager.controller.updateZoom(zoom / current);
  }

  group('D6 — painters repaint only when the data revision changes', () {
    test('Manager.revision bumps each time the events are (re)built', () {
      final manager =
          Manager(config: makeConfig(), entries: [makeEntry('1', 0)]);
      final before = manager.revision;

      manager.update(config: makeConfig(), entries: [makeEntry('1', 0)]);

      expect(manager.revision, greaterThan(before));
    });

    test('shouldRepaint is false for unchanged data, true after an update', () {
      final manager =
          Manager(config: makeConfig(), entries: [makeEntry('1', 0)]);
      final repaint = manager.controller.triggerUpdate;

      final events0 = EventsPainter(manager: manager, repaint: repaint);
      final hours0 = HourColumn(manager: manager, repaint: repaint);
      final dates0 = DateRow(manager: manager, repaint: repaint);

      // A fresh delegate built from the same, unchanged data must not force a
      // repaint — the old code returned true unconditionally, defeating the
      // optimization, so this fails without the revision comparison.
      expect(
          EventsPainter(manager: manager, repaint: repaint)
              .shouldRepaint(events0),
          isFalse);
      expect(
          HourColumn(manager: manager, repaint: repaint).shouldRepaint(hours0),
          isFalse);
      expect(DateRow(manager: manager, repaint: repaint).shouldRepaint(dates0),
          isFalse);

      manager.update(
          config: makeConfig(),
          entries: [makeEntry('1', 0), makeEntry('2', 1)]);

      // After the data changed the new delegate's revision differs -> repaint
      // (and, via the default shouldRebuildSemantics, semantics rebuild too).
      expect(
          EventsPainter(manager: manager, repaint: repaint)
              .shouldRepaint(events0),
          isTrue);
      expect(
          HourColumn(manager: manager, repaint: repaint).shouldRepaint(hours0),
          isTrue);
      expect(DateRow(manager: manager, repaint: repaint).shouldRepaint(dates0),
          isTrue);
    });
  });

  group('D7 — Grid caches the zoom-dependent line paints', () {
    test('reuses the same Paint objects across frames and recolours on zoom',
        () {
      final manager = Manager(config: makeConfig(), entries: const []);
      final grid = Grid(manager: manager);
      final canvas = ui.Canvas(ui.PictureRecorder());

      // At zoom 1.5 the 30-min lines are half-faded (alpha 0.5*60=30) and the
      // 15/45-min lines are still invisible (alpha 0).
      // Colours are compared as quantized 32-bit ARGB ints: modern Flutter
      // stores Color channels as floats, so Paint.color == Color.fromARGB can
      // fail on float ULPs even when the values are equal.
      setZoom(manager, 1.5);
      grid.draw(canvas);
      final div2 = grid.div2Paint;
      final div3 = grid.div3Paint;
      expect(div2.color.toARGB32(),
          const Color.fromARGB(30, 255, 255, 255).toARGB32());
      expect(div3.color.toARGB32(),
          const Color.fromARGB(0, 255, 255, 255).toARGB32());

      // Same zoom, next frame: identical Paint instances, unchanged colour —
      // i.e. no per-frame allocation.
      grid.draw(canvas);
      expect(identical(grid.div2Paint, div2), isTrue);
      expect(identical(grid.div3Paint, div3), isTrue);
      expect(grid.div2Paint.color.toARGB32(),
          const Color.fromARGB(30, 255, 255, 255).toARGB32());

      // Zoom in to 2.5: the same instances are recoloured (30-min fully on at
      // alpha 60, 15/45-min fading in at alpha 0.5*30=15).
      setZoom(manager, 2.5);
      grid.draw(canvas);
      expect(identical(grid.div2Paint, div2), isTrue);
      expect(identical(grid.div3Paint, div3), isTrue);
      expect(grid.div2Paint.color.toARGB32(),
          const Color.fromARGB(60, 255, 255, 255).toARGB32());
      expect(grid.div3Paint.color.toARGB32(),
          const Color.fromARGB(15, 255, 255, 255).toARGB32());
    });
  });

  group('#25 — getEventAtPos hit-tests only the tapped day-column', () {
    // Default config: blockWidth 200, blockHeight 40, minHour 0. An entry at
    // day d / hour 9 (duration 60) occupies grid rect
    // (d*200, 360) - (d*200+200, 400).
    test('finds the event in the tapped column', () {
      final manager = Manager(
        config: makeConfig(),
        entries: [makeEntry('a', 0), makeEntry('b', 1)],
      );

      expect(manager.getEventAtPos(const Offset(100, 380))?.entry.id, 'a');
      expect(manager.getEventAtPos(const Offset(300, 380))?.entry.id, 'b');
    });

    test('returns null when the tap misses every event', () {
      final manager =
          Manager(config: makeConfig(), entries: [makeEntry('a', 0)]);

      expect(
          manager.getEventAtPos(const Offset(100, 50)), isNull); // wrong time
      expect(
          manager.getEventAtPos(const Offset(300, 380)), isNull); // empty day
      expect(manager.getEventAtPos(const Offset(-50, 380)), isNull); // off-grid
    });

    test('a drag that changes the day re-buckets the event', () {
      final manager =
          Manager(config: makeConfig(), entries: [makeEntry('a', 0)]);

      // Long-press the event in day 0, drag one column right, release.
      manager.startDrag(const Offset(100, 380));
      manager.updateDrag(const Offset(300, 380));
      manager.endDrag();

      // It is now hit-testable in day 1 and no longer in day 0 — which only
      // holds because endDrag rebuilds the day index.
      expect(manager.getEventAtPos(const Offset(300, 380))?.entry.id, 'a');
      expect(manager.getEventAtPos(const Offset(100, 380)), isNull);
    });
  });
}
