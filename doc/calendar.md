# Building a date-based week calendar

The [core widget is date-agnostic](core-concepts.md#the-time-model-columns-not-dates),
but most calendars want real `DateTime`s. The optional, **non-core** helpers in
`package:planner/calendar.dart` own the `date ↔ column-index` mapping for you, so
the common week-calendar case stays a few lines without `DateTime` ever entering
the widget API. Import it explicitly — it is **not** part of the main
`planner.dart` barrel:

```dart
import 'package:planner/planner.dart';
import 'package:planner/calendar.dart'; // opt-in calendar helpers
```

A `CalendarWindow` is a window of N consecutive days. Hold one in your state,
derive the widget inputs from it, and step weeks with `next` / `previous`:

```dart
class WeekCalendar extends StatefulWidget {
  const WeekCalendar({super.key, required this.meetings});
  final List<Meeting> meetings; // your own dated event model

  @override
  State<WeekCalendar> createState() => _WeekCalendarState();
}

class _WeekCalendarState extends State<WeekCalendar> {
  // The current week, snapped to its Monday.
  CalendarWindow window = CalendarWindow.week(anchor: DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          IconButton(
            onPressed: () => setState(() => window = window.previous),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: () => setState(() => window = window.next),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        Expanded(
          child: Planner(
            config: PlannerConfig(
              labels: window.labels(), // e.g. ['Mon 8', 'Tue 9', … ] via intl
              highlightedColumn: window.todayColumn, // "today", or null off-week
            ),
            // Map your dated events into the window; ones outside it are dropped.
            entries: window.entriesFor(
              widget.meetings,
              start: (m) => m.startsAt,
              duration: (m) => m.length,
              build: (m, time) => PlannerEntry(
                id: m.id,
                time: time,
                title: m.title,
                content: '',
                color: m.color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

`labels()` defaults to a localized `EEE d` (e.g. `Mon 8`) via `intl`; pass your
own `String Function(DateTime)` for a different format or locale. `todayColumn`
returns `null` when today isn't in the window, which `highlightedColumn` already
treats as "no highlight".

A runnable version with prev/next/today navigation is the
[Week calendar example](../example/lib/examples/week_calendar_example.dart).

## `CalendarWindow` API

| Member | Purpose |
|--------|---------|
| `CalendarWindow({start, dayCount})` / `.week({anchor, firstWeekday, dayCount})` | A window of `dayCount` days from `start`, or the week containing `anchor`. |
| `dateAt(i)` / `indexOf(date)` / `offsetOf(date)` / `contains(date)` | Map between dates and column indices. |
| `dates` / `next` / `previous` | The column dates; step one window forward / back. |
| `labels([format])` | Column headers for `PlannerConfig.labels` (default `intl` `EEE d`). |
| `todayColumn` | Index for `PlannerConfig.highlightedColumn` (today, or `null`). |
| `timeFor(start, {duration, end})` | A `PlannerTime` for a dated event, or `null` if outside the window. |
| `entriesFor(events, {start, build, duration, end})` | Build the `PlannerEntry` list from your own dated events. |

To recover the date inside a [`dayHeaderBuilder`](builders.md#dayheaderbuilder--custom-daycolumn-headers),
close over the window and call `window.dateAt(columnIndex)`.

---

**More docs:** [Core concepts](core-concepts.md) · [Builders](builders.md) · [Calendar](calendar.md) · [Controller](controller.md) · [Interactions](interactions.md) · [README](../README.md)
