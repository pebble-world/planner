import 'package:flutter/material.dart';
import 'package:planner/calendar.dart';
import 'package:planner/planner.dart';

/// A real week calendar built on `package:planner/calendar.dart`.
///
/// The package itself never sees a `DateTime` (ADR 0001); a [CalendarWindow]
/// owns the whole `date ↔ column` bridge. This page holds the current window as
/// state and steps it with [CalendarWindow.previous] / [CalendarWindow.next] for
/// prev/next-week navigation. Each build derives the widget inputs from the
/// window: [CalendarWindow.labels] for the headers, [CalendarWindow.todayColumn]
/// for the "today" highlight, and [CalendarWindow.entriesFor] to turn the host's
/// own dated events into `PlannerEntry`s — dropping any outside the visible week.
class WeekCalendarExample extends StatefulWidget {
  const WeekCalendarExample({super.key});

  @override
  State<WeekCalendarExample> createState() => _WeekCalendarExampleState();
}

class _WeekCalendarExampleState extends State<WeekCalendarExample> {
  // The visible week, snapped to its Monday; stepped by the prev/next buttons.
  CalendarWindow _window = CalendarWindow.week(anchor: DateTime.now());

  // The host's own dated events — a plain domain model the package knows
  // nothing about. `entriesFor` maps the ones inside the current week onto
  // columns; anchoring to this week's Monday keeps the initial view populated.
  late final List<_Meeting> _meetings = _sampleMeetings();

  static List<_Meeting> _sampleMeetings() {
    final monday = CalendarWindow.week(anchor: DateTime.now()).start;
    DateTime at(int dayOffset, int hour, [int minute = 0]) =>
        monday.add(Duration(days: dayOffset, hours: hour, minutes: minute));
    return [
      _Meeting('Sprint kickoff', at(0, 9), const Duration(minutes: 90),
          const Color(0xFF3A7BD5)),
      _Meeting('Design sync', at(1, 11), const Duration(hours: 1),
          const Color(0xFF12A594)),
      _Meeting('1:1 with Sam', at(2, 14), const Duration(minutes: 30),
          const Color(0xFFE5484D)),
      _Meeting('Workshop', at(3, 10), const Duration(hours: 2),
          const Color(0xFFD9730D)),
      _Meeting('Sprint demo', at(4, 16), const Duration(hours: 1),
          const Color(0xFF8E4EC6)),
      // Two events one week out, so "next" isn't an empty grid.
      _Meeting('Planning', at(7, 10), const Duration(hours: 1),
          const Color(0xFF3A7BD5)),
      _Meeting('Review', at(9, 13), const Duration(hours: 1),
          const Color(0xFF12A594)),
    ];
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _label(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  @override
  Widget build(BuildContext context) {
    // Build this week's column entries from the dated model. `entriesFor` drops
    // events whose start date falls outside the window, so stepping weeks shows
    // only that week's events.
    final entries = _window.entriesFor<_Meeting>(
      _meetings,
      start: (m) => m.start,
      duration: (m) => m.duration,
      build: (m, time) => PlannerEntry(
        id: m.title,
        time: time,
        title: m.title,
        content: '',
        color: m.color,
      ),
    );

    final first = _window.dates.first;
    final last = _window.dates.last;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_label(first)} – ${_label(last)}'),
        actions: [
          IconButton(
            tooltip: 'Previous week',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _window = _window.previous),
          ),
          IconButton(
            tooltip: 'Next week',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _window = _window.next),
          ),
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today),
            onPressed: () => setState(
                () => _window = CalendarWindow.week(anchor: DateTime.now())),
          ),
        ],
      ),
      body: Planner(
        config: PlannerConfig(
          labels: _window.labels(),
          minHour: 7,
          maxHour: 19,
          // The window maps today to its column (null when today is off-week).
          highlightedColumn: _window.todayColumn,
        ),
        entries: entries,
      ),
    );
  }
}

/// A plain dated event in the host's own model — the package never sees this
/// type; [CalendarWindow.entriesFor] maps it onto planner columns.
class _Meeting {
  const _Meeting(this.title, this.start, this.duration, this.color);

  final String title;
  final DateTime start;
  final Duration duration;
  final Color color;
}
