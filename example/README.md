# planner examples

A gallery of focused examples for the [`planner`](../) package, ordered basic →
advanced. The app boots into a list ([`lib/main.dart`](lib/main.dart)); tap a row
to open that example. Each page demonstrates **one** feature on its own; the
final Showcase wires them all together.

## Examples

| # | Example | Shows |
|---|---------|-------|
| 1 | [Basic](lib/examples/basic_example.dart) | A minimal `Planner` with the default look (painted titles, times, grid, all-day chips) and the `onEntry*` callbacks. The get-it-running starting point. |
| 2 | [Typed data + entryBuilder](lib/examples/typed_data_example.dart) | A typed `PlannerEntry<ActivityMeta>` payload (#77) read back without a cast in an `entryBuilder` (#78) — a custom card that sheds detail by on-screen height. |
| 3 | [Custom headers](lib/examples/custom_headers_example.dart) | A `CalendarWindow` (from `package:planner/calendar.dart`) feeding `dayHeaderBuilder` (#79) and a `highlightedColumn` "today" highlight. |
| 4 | [All-day band](lib/examples/all_day_example.dart) | Opting the all-day band in (`showAllDayBand: true`, #48) and drawing custom chips with `allDayEntryBuilder` (#80). |
| 5 | [Host zoom toolbar](lib/examples/host_zoom_example.dart) | Driving zoom from your own chrome via a `PlannerController` (#76), with the on-canvas buttons hidden (`showZoomControls: false`). |
| 6 | [Week calendar](lib/examples/week_calendar_example.dart) | A real week with prev/next navigation built on `calendar.dart`: `CalendarWindow` stepping, `entriesFor`, and `todayColumn`. |
| 7 | [Showcase](lib/examples/showcase_example.dart) | Every customization hook on one screen (#81): custom headers, an all-day band of custom chips, a custom-card event overlay, and a host zoom toolbar. |

The custom widgets shared across pages live in
[`lib/widgets/`](lib/widgets/): the detail-shedding
[`PopBlock`](lib/widgets/pop_block.dart) card, the branded
[`DayHeader`](lib/widgets/day_header.dart), and the
[`AllDayChip`](lib/widgets/all_day_chip.dart) pill. The sample data is in
[`lib/data.dart`](lib/data.dart).

## A minimal planner

The smallest amount of code that gives you a working planner (see the Basic
example for the runnable version):

```dart
import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

Planner(
  config: PlannerConfig(
    labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    onEntryCreate: (time) => debugPrint('create at ${time.day} ${time.hour}h'),
  ),
  entries: [
    PlannerEntry(
      id: 'standup',
      time: PlannerTime(day: 0, hour: 9, duration: 45),
      title: 'Team stand-up',
      content: 'Daily sync',
      color: Colors.blue,
    ),
  ],
);
```

## Running

```sh
flutter run                 # pick a device when prompted
flutter run -d windows      # or target one explicitly
```

## Tests

End-to-end tests drive the real app on a device; see
[`integration_test/README.md`](integration_test/README.md). The app-level
scenarios open the Showcase page first (the gallery home has no planner of its
own).

```sh
flutter test                                  # widget tests
flutter test integration_test -d windows      # integration tests (what CI runs)
```
