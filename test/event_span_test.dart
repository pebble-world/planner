import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

void main() {
  // Column-spanning events (#47): a PlannerTime may set endDay after day, and
  // the event then renders across the whole day..endDay column range. The span
  // stays index-based (no DateTime; ADR 0001) and is read-only in this first
  // cut. SpanOverlap controls how it coexists with the per-column overlap split.

  const blockWidth = 200; // PlannerConfig default
  const blockHeight = 40; // PlannerConfig default

  Manager managerWith(
    List<PlannerEntry> entries, {
    SpanOverlap spanOverlap = SpanOverlap.fullWidth,
    List<String> labels = const ['A', 'B', 'C'],
  }) =>
      Manager(
        config: PlannerConfig(
          labels: labels,
          minHour: 0,
          spanOverlap: spanOverlap,
        ),
        entries: entries,
      );

  PlannerEntry entryAt(String id, PlannerTime time) => PlannerEntry(
        id: id,
        time: time,
        title: id,
        content: '',
        color: const Color(0xFF112233),
      );

  Rect rectFor(
          {required int day,
          required int endColExclusive,
          required int hour}) =>
      Rect.fromLTRB(
        day * blockWidth.toDouble(),
        hour * blockHeight.toDouble(),
        endColExclusive * blockWidth.toDouble(),
        (hour + 1) * blockHeight.toDouble(),
      );

  group('PlannerTime span helpers', () {
    test('endDay null is a single column (the default)', () {
      final t = PlannerTime(day: 1, hour: 9);
      expect(t.lastDay, 1);
      expect(t.columnSpan, 1);
      expect(t.spansColumns, isFalse);
    });

    test('endDay after day spans the inclusive range', () {
      final t = PlannerTime(day: 1, endDay: 3, hour: 9);
      expect(t.lastDay, 3);
      expect(t.columnSpan, 3);
      expect(t.spansColumns, isTrue);
    });

    test('endDay equal to or before day stays a single column', () {
      expect(PlannerTime(day: 2, endDay: 2).spansColumns, isFalse);
      final before = PlannerTime(day: 2, endDay: 1);
      expect(before.lastDay, 2); // never before day
      expect(before.spansColumns, isFalse);
    });

    test('copyWith carries endDay, and value equality includes it', () {
      final base = PlannerTime(day: 0, endDay: 2, hour: 9);
      expect(base.copyWith(hour: 10).endDay, 2);
      expect(PlannerTime(day: 0, endDay: 2),
          equals(PlannerTime(day: 0, endDay: 2)));
      expect(PlannerTime(day: 0, endDay: 2),
          isNot(equals(PlannerTime(day: 0, endDay: 3))));
      expect(PlannerTime(day: 0, endDay: 2).hashCode,
          PlannerTime(day: 0, endDay: 2).hashCode);
    });
  });

  group('fullWidth geometry (the default)', () {
    test('a spanning event is one continuous box across its columns', () {
      final event = managerWith([
        entryAt('s', PlannerTime(day: 0, endDay: 2, hour: 9, duration: 60)),
      ]).events.single;

      expect(event.segmentRects.length, 1, reason: 'one continuous box');
      expect(event.segmentRects.single,
          rectFor(day: 0, endColExclusive: 3, hour: 9));
      // canvasRect (the a11y/anchor bounding box) matches the single segment.
      expect(event.canvasRect, rectFor(day: 0, endColExclusive: 3, hour: 9));
    });

    test('a single-column event is unchanged (one full-column segment)', () {
      final event = managerWith([
        entryAt('x', PlannerTime(day: 1, hour: 9, duration: 60)),
      ]).events.single;

      expect(event.segmentRects, [event.canvasRect]);
      expect(event.canvasRect, rectFor(day: 1, endColExclusive: 2, hour: 9));
    });

    test('a concurrent single-column event keeps full width under a span', () {
      // In fullWidth the span is excluded from packing, so the single-column
      // event is NOT narrowed — it stays a full column (and may overlap the span).
      final manager = managerWith([
        entryAt('s', PlannerTime(day: 0, endDay: 2, hour: 9, duration: 60)),
        entryAt('x', PlannerTime(day: 1, hour: 9, duration: 60)),
      ]);
      final x = manager.events.firstWhere((e) => e.entry.id == 'x');
      expect(x.columnCount, 1);
      expect(x.canvasRect, rectFor(day: 1, endColExclusive: 2, hour: 9));
    });
  });

  group('split geometry', () {
    test('a span folds into each crossed column\'s overlap cluster', () {
      // Span over columns 0..2 at 09:00, plus a concurrent single-column event
      // in column 1. Column 1 splits in two; columns 0 and 2 (no neighbour) stay
      // full width — so the span draws one rect per column, narrowed only where
      // it shares the column.
      final manager = managerWith(
        [
          entryAt('s', PlannerTime(day: 0, endDay: 2, hour: 9, duration: 60)),
          entryAt('x', PlannerTime(day: 1, hour: 9, duration: 60)),
        ],
        spanOverlap: SpanOverlap.split,
      );
      final s = manager.events.firstWhere((e) => e.entry.id == 's');
      final x = manager.events.firstWhere((e) => e.entry.id == 'x');

      expect(s.segmentRects.length, 3, reason: 'one rect per covered column');
      // Column 0: full width.
      expect(s.segmentRects[0], rectFor(day: 0, endColExclusive: 1, hour: 9));
      // Column 1: left sub-column of two (the span sorts first, so takes left).
      expect(s.segmentRects[1], const Rect.fromLTRB(200, 360, 300, 400));
      // Column 2: full width.
      expect(s.segmentRects[2], rectFor(day: 2, endColExclusive: 3, hour: 9));

      // The single-column neighbour is narrowed to the right sub-column.
      expect(x.columnIndex, 1);
      expect(x.columnCount, 2);
      expect(x.canvasRect, const Rect.fromLTRB(300, 360, 400, 400));

      // The span's bounding box still covers the whole range.
      expect(s.canvasRect, rectFor(day: 0, endColExclusive: 3, hour: 9));
    });
  });

  group('hit-testing reaches a span from any column it covers', () {
    Offset at(double gridX, int hour) =>
        Offset(gridX, hour * blockHeight + blockHeight / 2);

    test('fullWidth: a tap in a non-start column resolves to the span', () {
      final manager = managerWith([
        entryAt('s', PlannerTime(day: 0, endDay: 2, hour: 9, duration: 60)),
      ]);
      // Column 2 (start column is 0): the span must still be found there.
      expect(manager.getEventAtPos(at(500, 9))?.entry.id, 's');
      expect(manager.getEventAtPos(at(100, 9))?.entry.id, 's');
    });

    test('split: each sub-column resolves to the event sitting there', () {
      final manager = managerWith(
        [
          entryAt('s', PlannerTime(day: 0, endDay: 2, hour: 9, duration: 60)),
          entryAt('x', PlannerTime(day: 1, hour: 9, duration: 60)),
        ],
        spanOverlap: SpanOverlap.split,
      );
      // Column 1 left half -> span; right half -> single-column neighbour.
      expect(manager.getEventAtPos(at(250, 9))?.entry.id, 's');
      expect(manager.getEventAtPos(at(350, 9))?.entry.id, 'x');
      // Column 2 (full-width span segment) -> span.
      expect(manager.getEventAtPos(at(500, 9))?.entry.id, 's');
    });
  });

  group('spanning events are read-only (#47)', () {
    Offset at(double gridX, int hour) =>
        Offset(gridX, hour * blockHeight + blockHeight / 2);

    test('a long-press on a span starts no drag', () {
      final manager = managerWith([
        entryAt('s', PlannerTime(day: 0, endDay: 2, hour: 9, duration: 60)),
      ]);
      manager.startDrag(at(100, 9));
      expect(manager.draggedEvent, isNull,
          reason: 'spanning events cannot be dragged/resized');
    });

    test('a single-column event still starts a drag (control)', () {
      final manager = managerWith([
        entryAt('x', PlannerTime(day: 0, hour: 9, duration: 60)),
      ]);
      manager.startDrag(at(100, 9));
      expect(manager.draggedEvent?.entry.id, 'x');
    });
  });
}
