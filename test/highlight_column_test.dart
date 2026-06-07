import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/planner.dart';

// Issue #46: a configurable "today"-style column highlight. The widget stays
// date-agnostic (ADR 0001) — the host passes a column *index* into `labels`
// plus a colour, and the grid painter fills that column behind the lines and
// events. These tests drive the real composed Planner and inspect what the
// events CustomPaint actually paints.
void main() {
  // The events grid is painted by EventsPainter on its own CustomPaint; scope
  // `paints` assertions to that render object so the surrounding chrome (date
  // row, hour column, Material internals) can't match by accident.
  Finder eventsCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is EventsPainter,
      );

  // A full-screen Planner with the given highlight settings and no entries, so
  // the only rect the grid can paint is the highlight itself.
  Future<void> pumpHighlight(
    WidgetTester tester, {
    int? highlightedColumn,
    Color? highlightColumnColor,
    List<PlannerEntry> entries = const [],
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            highlightedColumn: highlightedColumn,
            highlightColumnColor:
                highlightColumnColor ?? const Color(0xFF00FF00),
          ),
          entries: entries,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('PlannerConfig highlight defaults', () {
    test('highlightedColumn is null and the colour is a translucent wash', () {
      final c = PlannerConfig(labels: const ['A']);
      expect(c.highlightedColumn, isNull);
      expect(c.highlightColumnColor, const Color.fromARGB(40, 255, 255, 255));
    });
  });

  group('column highlight rendering', () {
    // With the default 200x40 grid, hours 0..23 (24 rows), no scroll and zoom 1,
    // column 1 occupies grid rect (200, 0) 200 wide and 24*40 = 960 tall.
    testWidgets('fills the configured column at the right geometry/colour',
        (tester) async {
      await pumpHighlight(tester, highlightedColumn: 1);

      expect(
        eventsCanvas(),
        paints
          ..rect(
            rect: const Rect.fromLTWH(200, 0, 200, 960),
            color: const Color(0xFF00FF00),
          ),
      );
    });

    testWidgets('column 0 is filled flush with the grid origin',
        (tester) async {
      await pumpHighlight(tester, highlightedColumn: 0);

      expect(
        eventsCanvas(),
        paints
          ..rect(
            rect: const Rect.fromLTWH(0, 0, 200, 960),
            color: const Color(0xFF00FF00),
          ),
      );
    });

    testWidgets('paints nothing when highlightedColumn is null (the default)',
        (tester) async {
      await pumpHighlight(tester); // highlightedColumn omitted -> null

      // No entries either, so an unhighlighted grid paints only lines (drawLine),
      // never a rect.
      expect(eventsCanvas(), isNot(paints..rect()));
    });

    testWidgets('an out-of-range index highlights nothing', (tester) async {
      // 3 labels -> valid indices 0..2; index 5 must be ignored, not clamped.
      await pumpHighlight(tester, highlightedColumn: 5);

      expect(eventsCanvas(), isNot(paints..rect()));
    });

    testWidgets('a negative index highlights nothing', (tester) async {
      await pumpHighlight(tester, highlightedColumn: -1);

      expect(eventsCanvas(), isNot(paints..rect()));
    });

    // The highlight is a backdrop: it must be painted *before* the events so it
    // emphasizes the column without occluding the events sitting in it.
    testWidgets('is painted behind the events in its column', (tester) async {
      final entry = PlannerEntry(
        id: 'evt',
        time: PlannerTime(day: 1, hour: 9),
        title: 'Meeting',
        content: '',
        color: const Color(0xFF2244AA),
      );
      await pumpHighlight(tester, highlightedColumn: 1, entries: [entry]);

      // The green highlight rect, then the event's fill rect (entry.color at
      // alpha 100) — the order proves the highlight sits underneath.
      expect(
        eventsCanvas(),
        paints
          ..rect(color: const Color(0xFF00FF00))
          ..rect(color: const Color(0x642244AA)),
      );
    });
  });
}
