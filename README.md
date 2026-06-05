# planner

A Flutter widget that renders a scrollable, zoomable day-grid of events on a
custom-painted canvas. Show several labelled columns side by side, each split into
hours, and let users pan, zoom, and drag events to move or resize them.

> **Note on the model:** `planner` is column-based, not date-based. A "day" is an
> *index* into the `labels` list you provide — there are no real calendar dates yet.
> This makes it a flexible scheduler for any set of columns (days, rooms, machines,
> lanes …). See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for the roadmap toward
> full `DateTime` support.

<!-- TODO: add a screenshot or GIF of the widget here, e.g. -->
<!-- ![planner demo](doc/demo.gif) -->

## Features

- Multiple labelled columns with an hour grid drawn on a single `CustomPaint`.
- Horizontal panning across columns; vertical pan + mouse-wheel scroll across hours.
- Zoom the time axis with pinch gestures or the built-in +/- buttons; finer grid
  lines fade in as you zoom.
- Drag an event to move it, or drag its top/bottom handle to resize it.
- Context menu (right-click or double-tap) to create, edit, and delete events.
- Customizable colors and text styles for the grid, labels, events, and menu.

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  planner:
    git: https://github.com/pebble-world/planner.git
```

(Once published, this becomes `planner: ^<version>` from pub.dev.)

Then import it:

```dart
import 'package:planner/planner.dart';
import 'package:planner/planner_time.dart';
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:planner/planner.dart';
import 'package:planner/planner_time.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = [
      PlannerEntry(
        id: '1',
        time: PlannerTime(day: 0, hour: 8, minutes: 0, duration: 60),
        title: 'Stand-up',
        content: 'Daily team sync',
        color: Colors.green,
      ),
      PlannerEntry(
        id: '2',
        time: PlannerTime(day: 1, hour: 13, minutes: 30, duration: 90),
        title: 'Design review',
        content: 'Walk through the new flow',
        color: Colors.blue,
      ),
    ];

    return Planner(
      entries: entries,
      config: PlannerConfig(
        labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        minHour: 0,
        maxHour: 23,
        onEntryCreate: (time) {
          // A user asked to create an event at this slot.
        },
        onEntryEdit: (entry) {
          // A user double-tapped / chose "Edit" on an event.
        },
        onEntryDelete: (entry) {
          // A user chose "Delete" on an event.
        },
        onEntryMove: (entry) {
          // A user finished dragging/resizing; entry.time is updated.
        },
      ),
    );
  }
}
```

A complete, runnable demo lives in [`example/`](example/lib/main.dart).

### Core types

| Type | Purpose |
|------|---------|
| `Planner` | The widget. Takes a `config` and a list of `entries`. |
| `PlannerConfig` | Sizing (`blockWidth`, `blockHeight`, `minHour`, `maxHour`, …), colors, text styles, and the `onEntry*` callbacks. `labels` is required. |
| `PlannerEntry` | One event: `id`, `time`, `title`, `content`, `color`, and optional text styles. |
| `PlannerTime` | `day` (index into `labels`), `hour`, `minutes`, and `duration` (in minutes). |

### Callbacks

| Callback | Fires when |
|----------|-----------|
| `onEntryCreate(PlannerTime)` | An empty slot is double-tapped or "Create Event" is chosen. |
| `onEntryEdit(PlannerEntry)` | An event is double-tapped or "Edit Event" is chosen. |
| `onEntryDelete(PlannerEntry)` | "Delete Event" is chosen from the context menu. |
| `onEntryMove(PlannerEntry)` | A drag-move or handle-resize finishes; the entry's `time` is already updated. |

> Your callbacks own the data. Update your own list of entries (and call
> `setState`) in response — the widget reports interactions but does not persist them.

## Additional information

- **Roadmap & known issues:** [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md).
- **Issues / contributions:** https://github.com/pebble-world/planner/issues — PRs welcome.

## License

[MIT](LICENSE) © yvan vander sanden
