// Composition test for the calendar helpers (#49): it drives the *real*
// Planner with inputs derived entirely from a CalendarWindow — labels,
// highlighted column, and entries built from dated events — and asserts the
// date math lands events/highlight in the right columns once the widget paints
// them. This is the end-to-end bridge from `DateTime`s to rendered geometry
// that the pure-data calendar_test.dart can't cover on its own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/events_painter.dart';

import 'package:planner/calendar.dart';
import 'package:planner/planner.dart';

void main() {
  Finder eventsCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is EventsPainter,
      );

  testWidgets(
      'a CalendarWindow drives labels, highlight, and entry geometry on the real widget',
      (tester) async {
    // A Monday-first week; Wednesday is column 2.
    final window = CalendarWindow.week(anchor: DateTime(2026, 6, 10));
    final wednesday = window.dateAt(2);

    // One dated event on Wednesday at 09:00, mapped through the helper.
    final entries = window.entriesFor(
      [(at: wednesday.add(const Duration(hours: 9)))],
      start: (e) => e.at,
      build: (e, time) => PlannerEntry(
        id: 'evt',
        time: time,
        title: 'Meeting',
        content: '',
        color: const Color(0xFF2244AA),
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: window.labels(),
            minHour: 0,
            maxHour: 23,
            // The helper says which column is "today's" Wednesday.
            highlightedColumn: window.indexOf(wednesday),
            highlightColumnColor: const Color(0xFF00FF00),
          ),
          entries: entries,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // labels() produced one header per column.
    expect(window.labels(), hasLength(7));

    // With the default 200x40 grid, column 2 occupies grid x 400..600. The
    // green highlight fills that whole column; the event (fill = colour at
    // alpha 0x64) sits in it at hour 9 -> top 360, height 40.
    expect(
      eventsCanvas(),
      paints
        ..rect(
          rect: const Rect.fromLTWH(400, 0, 200, 960),
          color: const Color(0xFF00FF00),
        )
        ..rect(
          rect: const Rect.fromLTWH(400, 360, 200, 40),
          color: const Color(0x642244AA),
        ),
    );
  });
}
