// Unit tests for the optional, non-core calendar helpers (lib/calendar.dart,
// #49). These are pure data: a `date <-> column-index` window, week alignment,
// label/"today" derivation, and dated-event -> PlannerTime/PlannerEntry mapping.
// They exercise the helper in isolation; calendar_planner_test.dart then drives
// the real Planner with this output.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:planner/calendar.dart';
import 'package:planner/planner.dart';

void main() {
  // A concrete window used across the mapping tests: 7 days from 2026-06-08.
  CalendarWindow week() => CalendarWindow(start: DateTime(2026, 6, 8));

  group('construction', () {
    test('normalizes start to date-only (drops the time component)', () {
      final w = CalendarWindow(start: DateTime(2026, 6, 8, 17, 45, 30));
      expect(w.start, DateTime(2026, 6, 8));
      expect(w.dayCount, 7); // default
    });

    test('rejects a non-positive dayCount', () {
      expect(() => CalendarWindow(start: DateTime(2026, 6, 8), dayCount: 0),
          throwsA(isA<AssertionError>()));
    });
  });

  group('date <-> index mapping', () {
    test('dateAt walks consecutive calendar days from the start', () {
      final w = week();
      expect(w.dateAt(0), DateTime(2026, 6, 8));
      expect(w.dateAt(3), DateTime(2026, 6, 11));
      expect(w.dateAt(6), DateTime(2026, 6, 14));
    });

    test('dateAt normalizes across month and year boundaries', () {
      expect(
        CalendarWindow(start: DateTime(2026, 1, 30), dayCount: 5).dates,
        [
          DateTime(2026, 1, 30),
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 1),
          DateTime(2026, 2, 2),
          DateTime(2026, 2, 3),
        ],
      );
      expect(
        CalendarWindow(start: DateTime(2025, 12, 31), dayCount: 2).dates,
        [DateTime(2025, 12, 31), DateTime(2026, 1, 1)],
      );
    });

    test('indexOf returns the column inside the window, null outside', () {
      final w = week();
      expect(w.indexOf(DateTime(2026, 6, 8)), 0);
      expect(w.indexOf(DateTime(2026, 6, 11, 23, 59)), 3); // time ignored
      expect(w.indexOf(DateTime(2026, 6, 14)), 6);
      expect(w.indexOf(DateTime(2026, 6, 7)), isNull); // day before
      expect(w.indexOf(DateTime(2026, 6, 15)), isNull); // day after
    });

    test('offsetOf is the unclamped offset (negative / past the edge)', () {
      final w = week();
      expect(w.offsetOf(DateTime(2026, 6, 8)), 0);
      expect(w.offsetOf(DateTime(2026, 6, 5)), -3);
      expect(w.offsetOf(DateTime(2026, 6, 20)), 12);
    });

    test('contains matches indexOf', () {
      final w = week();
      expect(w.contains(DateTime(2026, 6, 10)), isTrue);
      expect(w.contains(DateTime(2026, 6, 1)), isFalse);
    });

    test('dates has one entry per column', () {
      expect(week().dates, hasLength(7));
      expect(CalendarWindow(start: DateTime(2026, 6, 8), dayCount: 5).dates,
          hasLength(5));
    });
  });

  group('week alignment', () {
    test('snaps any day to its Monday by default', () {
      // 2026-06-10 is a Wednesday; the Monday-first week starts 2026-06-08.
      final w = CalendarWindow.week(anchor: DateTime(2026, 6, 10, 14, 0));
      expect(w.start.weekday, DateTime.monday);
      expect(w.start, DateTime(2026, 6, 8));
      expect(w.contains(DateTime(2026, 6, 10)), isTrue);
      expect(w.offsetOf(DateTime(2026, 6, 10)), inInclusiveRange(0, 6));
    });

    test('honours a Sunday-first week', () {
      final w = CalendarWindow.week(
          anchor: DateTime(2026, 6, 10), firstWeekday: DateTime.sunday);
      expect(w.start.weekday, DateTime.sunday);
      expect(w.start, DateTime(2026, 6, 7));
    });

    test('an anchor already on the first weekday returns itself', () {
      final monday = CalendarWindow.week(anchor: DateTime(2026, 6, 10)).start;
      expect(CalendarWindow.week(anchor: monday).start, monday);
    });

    test('supports a shorter work week', () {
      final w = CalendarWindow.week(anchor: DateTime(2026, 6, 10), dayCount: 5);
      expect(w.dayCount, 5);
      expect(w.dates.last, DateTime(2026, 6, 12)); // Mon..Fri
    });
  });

  group('stepping', () {
    test('next / previous shift by a whole window', () {
      final w = week();
      expect(w.next.start, DateTime(2026, 6, 15));
      expect(w.next.dayCount, 7);
      expect(w.previous.start, DateTime(2026, 6, 1));
    });

    test('a 5-day window steps by 5 days', () {
      final w = CalendarWindow(start: DateTime(2026, 6, 8), dayCount: 5);
      expect(w.next.start, DateTime(2026, 6, 13));
    });
  });

  group('labels', () {
    test('uses a custom formatter for every column', () {
      final w = week();
      expect(
        w.labels((d) => '${d.month}/${d.day}'),
        ['6/8', '6/9', '6/10', '6/11', '6/12', '6/13', '6/14'],
      );
    });

    test('defaults to a localized "EEE d" via intl', () {
      Intl.defaultLocale = 'en_US';
      final w = CalendarWindow.week(anchor: DateTime(2026, 6, 10)); // Mon start
      final labels = w.labels();
      expect(labels, hasLength(7));
      expect(labels.first, DateFormat('EEE d', 'en_US').format(w.start));
      expect(labels.first, startsWith('Mon')); // 2026-06-08 is a Monday
    });
  });

  group('todayColumn', () {
    test('is the column of today when today is in the window', () {
      final today = DateTime.now();
      final w = CalendarWindow(start: today, dayCount: 7);
      expect(w.todayColumn, 0);
    });

    test('is null when today is outside the window', () {
      final lastWeek = CalendarWindow(start: DateTime(2000, 1, 1), dayCount: 7);
      expect(lastWeek.todayColumn, isNull);
    });
  });

  group('timeFor', () {
    test('places a dated event in its column at its wall-clock time', () {
      final w = week();
      final t = w.timeFor(DateTime(2026, 6, 10, 9, 30));
      expect(t, isNotNull);
      expect(t!.day, 2);
      expect(t.hour, 9);
      expect(t.minutes, 30);
      expect(t.duration, 60); // default one hour
      expect(t.endDay, isNull);
    });

    test('returns null for a date outside the window', () {
      final w = week();
      expect(w.timeFor(DateTime(2026, 6, 7, 9)), isNull);
      expect(w.timeFor(DateTime(2026, 6, 15, 9)), isNull);
    });

    test('uses the given duration, rounded to a 1-minute minimum', () {
      final w = week();
      expect(
          w
              .timeFor(DateTime(2026, 6, 8, 9),
                  duration: Duration(minutes: 90))!
              .duration,
          90);
      expect(
          w.timeFor(DateTime(2026, 6, 8, 9), duration: Duration.zero)!.duration,
          1);
    });

    test('an end date after the start column spans columns (#47)', () {
      final w = week();
      final t = w.timeFor(DateTime(2026, 6, 9, 8), end: DateTime(2026, 6, 11));
      expect(t!.day, 1);
      expect(t.endDay, 3);
      expect(t.spansColumns, isTrue);
    });

    test('an end date past the window clamps to the last column', () {
      final w = week();
      final t = w.timeFor(DateTime(2026, 6, 9, 8), end: DateTime(2026, 7, 1));
      expect(t!.day, 1);
      expect(t.endDay, 6); // dayCount - 1
    });

    test('an end not after the start column is ignored', () {
      final w = week();
      expect(
          w.timeFor(DateTime(2026, 6, 9, 8), end: DateTime(2026, 6, 9))!.endDay,
          isNull);
      expect(
          w.timeFor(DateTime(2026, 6, 9, 8), end: DateTime(2026, 6, 8))!.endDay,
          isNull);
    });
  });

  group('entriesFor', () {
    test('maps dated events and drops those outside the window', () {
      final w = week();
      final events = [
        (id: 'a', at: DateTime(2026, 6, 8, 9), len: Duration(minutes: 30)),
        (id: 'b', at: DateTime(2026, 6, 10, 14), len: Duration(hours: 2)),
        (
          id: 'c',
          at: DateTime(2026, 6, 99),
          len: Duration(hours: 1)
        ), // 6/99 -> out
      ];

      final entries = w.entriesFor(
        events,
        start: (e) => e.at,
        duration: (e) => e.len,
        build: (e, time) => PlannerEntry(
          id: e.id,
          time: time,
          title: e.id,
          content: '',
          color: const Color(0xFF2244AA),
        ),
      );

      expect(entries, hasLength(2)); // 'c' dropped
      expect(entries[0].id, 'a');
      expect(entries[0].time.day, 0);
      expect(entries[0].time.duration, 30);
      expect(entries[1].id, 'b');
      expect(entries[1].time.day, 2);
      expect(entries[1].time.hour, 14);
      expect(entries[1].time.duration, 120);
    });

    test('defaults the duration to one hour when no callback is given', () {
      final w = week();
      final entries = w.entriesFor(
        [DateTime(2026, 6, 8, 9)],
        start: (d) => d,
        build: (d, time) => PlannerEntry(
            id: 'x', time: time, title: 'x', content: '', color: Colors.red),
      );
      expect(entries.single.time.duration, 60);
    });

    test('passes an end callback through to span columns', () {
      final w = week();
      final entries = w.entriesFor(
        [(start: DateTime(2026, 6, 9), end: DateTime(2026, 6, 11))],
        start: (e) => e.start,
        end: (e) => e.end,
        build: (e, time) => PlannerEntry(
            id: 'span',
            time: time,
            title: 'span',
            content: '',
            color: Colors.green),
      );
      expect(entries.single.time.day, 1);
      expect(entries.single.time.endDay, 3);
    });
  });

  group('value semantics', () {
    test('== and hashCode compare start and dayCount', () {
      final a = CalendarWindow(start: DateTime(2026, 6, 8, 12), dayCount: 7);
      final b = CalendarWindow(start: DateTime(2026, 6, 8), dayCount: 7);
      final c = CalendarWindow(start: DateTime(2026, 6, 8), dayCount: 5);
      expect(a, b); // time-of-day normalized away
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString is readable', () {
      expect(CalendarWindow(start: DateTime(2026, 6, 8)).toString(),
          contains('dayCount: 7'));
    });
  });
}
