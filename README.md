# planner

A Flutter widget that renders a scrollable, zoomable day-grid of events on a
custom-painted canvas. Show several labelled columns side by side, each split into
hours, and let users pan, zoom, and drag events to move or resize them.

> **Note on the model:** `planner` is column-based, not date-based. A "day" is an
> *index* into the `labels` list you provide — there are no real calendar dates in
> the core. This keeps it a flexible scheduler for any set of columns (days, rooms,
> machines, lanes …). For an ordinary date-based week calendar, the optional
> [calendar helpers](#building-a-date-based-week-calendar) map dates ↔ columns on
> top of this model; the core stays date-agnostic by design (see
> [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)).

<!-- TODO: add a screenshot or GIF of the widget here, e.g. -->
<!-- ![planner demo](doc/demo.gif) -->

## Features

- Multiple labelled columns with an hour grid drawn on a single `CustomPaint`.
- 2D panning (drag the empty canvas) plus single-axis pan via the date row / hour
  gutter, and mouse-wheel scroll with `Shift` / `Ctrl` modifiers.
- Zoom the time axis with pinch, `Ctrl`+wheel, or the built-in +/- buttons; finer
  grid lines fade in as you zoom. Drive and observe zoom from your own chrome with
  a `PlannerController` (see [Driving zoom from a host toolbar](#driving-zoom-from-a-host-toolbar)).
- Desktop drag-to-edit: press an event to move it or drag its top/bottom edge to
  resize, with hover cursors as cues. Touch keeps one-finger drag for panning and
  exposes a long-press hook (`onEntryLongPress`) for host-defined event actions.
- Create / edit / delete via double-tap or a right-click context menu.
- Per-event accessibility semantics (edit / delete / move) for screen readers.
- Customizable colors and text styles for the grid, labels, events, and menu.
- **Fully custom widgets** via opt-in builders: branded day/column headers
  (`dayHeaderBuilder`), real-widget events that shed detail by pixel height
  (`entryBuilder`), and custom all-day chips (`allDayEntryBuilder`) — each reads
  a typed `PlannerEntry<T>.data` payload. See
  [Fully custom widgets (builders)](#fully-custom-widgets-builders).

See [Interactions](#interactions) below for the full mouse and touch gesture map.

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
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

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
| `Planner` | The widget. Takes a `config`, a list of `entries`, and an optional `controller`. |
| `PlannerConfig` | Sizing (`blockWidth`, `blockHeight`, `minHour`, `maxHour` — the inclusive last hour, default `23`, …), colors, text styles, an optional `hourLabelFormatter`, the optional column highlight (`highlightedColumn`, `highlightColumnColor`), the zoom controls (`showZoomControls`, `zoomButtonColor`, `zoomButtonIconColor`), the wheel `scrollStep`, and the `onEntry*` callbacks. `labels` is required. |
| `PlannerController` | Optional handle to drive/observe zoom from outside the widget (e.g. your own toolbar) — see [Driving zoom from a host toolbar](#driving-zoom-from-a-host-toolbar). |
| `PlannerEntry<T>` | One event: `id`, `time`, `title`, `content`, `color`, optional text styles, and an optional typed `data` payload (`T?`) for your own metadata — see [Fully custom widgets (builders)](#fully-custom-widgets-builders). |
| `PlannerTime` | `day` (index into `labels`), `hour`, `minutes`, and `duration` (in minutes). |
| `PlannerEntryBuilder<T>` / `PlannerEntryLayout` | Build a custom widget for a timed event or all-day chip; `PlannerEntryLayout` carries the on-screen `size` (for detail-shedding), overlap column, and drag state. |
| `PlannerDayHeaderBuilder` | Build a custom widget for a day/column header. |

### Callbacks

| Callback | Fires when |
|----------|-----------|
| `onEntryCreate(PlannerTime)` | An empty slot is double-tapped or "Create Event" is chosen. |
| `onEntryEdit(PlannerEntry)` | An event is double-tapped or "Edit Event" is chosen. |
| `onEntryDelete(PlannerEntry)` | "Delete Event" is chosen from the context menu. |
| `onEntryMove(PlannerEntry)` | A drag-move or handle-resize finishes; the entry's `time` is already updated. |
| `onEntryLongPress(PlannerEntry)` | An event is long-pressed — the touch hook for host-defined actions (see [Interactions](#interactions)). |

> Your callbacks own the data. Update your own list of entries (and call
> `setState`) in response — the widget reports interactions but does not persist them.

### Driving zoom from a host toolbar

By default zoom lives entirely inside the widget (pinch, `Ctrl`+wheel, the
built-in +/- buttons). To drive it from your own chrome — a toolbar, a slider,
keyboard shortcuts — construct a `PlannerController`, hand it to the `Planner`,
and (usually) hide the on-canvas buttons with `showZoomControls: false`:

```dart
class ZoomablePlanner extends StatefulWidget {
  const ZoomablePlanner({super.key});
  @override
  State<ZoomablePlanner> createState() => _ZoomablePlannerState();
}

class _ZoomablePlannerState extends State<ZoomablePlanner> {
  final _zoom = PlannerController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // A host toolbar that listens to the controller so it can disable
        // a button once the zoom hits a bound.
        AnimatedBuilder(
          animation: _zoom,
          builder: (context, _) => Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: !_zoom.isAttached || _zoom.zoom <= _zoom.minZoom
                    ? null
                    : _zoom.zoomOut,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: !_zoom.isAttached || _zoom.zoom >= _zoom.maxZoom
                    ? null
                    : _zoom.zoomIn,
              ),
            ],
          ),
        ),
        Expanded(
          child: Planner(
            controller: _zoom,
            config: PlannerConfig(
              labels: const ['Mon', 'Tue', 'Wed'],
              showZoomControls: false, // the host owns the controls now
            ),
            entries: const [],
          ),
        ),
      ],
    );
  }
}
```

`PlannerController` is a `ChangeNotifier` and deals only with zoom (plus scroll
read-back):

| Member | Purpose |
|--------|---------|
| `zoomIn([factor = 1.1])` / `zoomOut([factor = 0.9])` | Multiply the current zoom; clamped to `minZoom`/`maxZoom`. |
| `zoomTo(target)` | Set an absolute zoom; clamped to `minZoom`/`maxZoom`. |
| `zoom`, `minZoom`, `maxZoom` | Read the current zoom and its bounds. |
| `dayScroll`, `timeScroll` | Read the current day-axis / time-axis scroll offset. |
| `isAttached` | Whether it's bound to a mounted `Planner`. |

It attaches to the planner's internal zoom/scroll state — the single source of
truth — so the controller, pinch, `Ctrl`+wheel and the built-in buttons all move
the *same* zoom; there's no duplicated state to keep in sync. The read getters
throw while not `isAttached` (before the `Planner` mounts or after it's gone), so
read them in response to a notification or guard with `isAttached`; the zoom
methods are no-ops then. Dispose the controller like any other `ChangeNotifier`.

### Fully custom widgets (builders)

By default the planner paints everything on a canvas. Three opt-in **builders**
let you replace any of those surfaces with real Flutter widgets — branded
headers, rich event cards, custom chips — while the package stays the engine
(geometry, scroll, zoom, hit-testing, overlap, accessibility). Each builder is
**visual-only**: the widget overlay is wrapped in `IgnorePointer` /
`ExcludeSemantics`, so every gesture and accessibility action still falls through
to the canvas and fires the usual `onEntry*` callbacks. Everything is opt-in —
pass `null` (the default) and the painted look is unchanged.

#### Typed metadata: `PlannerEntry<T>.data`

To render a rich widget you usually need your app's own data on each event —
type, place, attendees, status. Make the entry generic and hang it on `data`:

```dart
class ActivityMeta {
  const ActivityMeta({required this.type, this.place = '', this.attendees = const []});
  final String type;
  final String place;
  final List<String> attendees;
}

final entry = PlannerEntry<ActivityMeta>(
  id: '1',
  time: PlannerTime(day: 0, hour: 9, duration: 60),
  title: 'Stand-up',
  content: '',
  color: Colors.teal,
  data: const ActivityMeta(type: 'meeting', place: 'Room A', attendees: ['AM', 'BK']),
);
```

`T` threads through `Planner<T>`, `PlannerConfig<T>` and the `onEntry*`
callbacks, so the builder (and your callbacks) read `entry.data` already typed —
no cast, no side-map keyed by `id`. An untyped `PlannerEntry(...)` infers
`T == dynamic` and behaves exactly as before, so this is non-breaking.

#### `entryBuilder` — custom timed-event widgets

When set, the planner layers one widget per on-screen event over the canvas,
positioned and sized at the event's live on-screen rect so it tracks scroll,
zoom and drag in lockstep with the grid. The `PlannerEntryLayout` carries the
on-screen facts — crucially `size.height`, so a card can **shed detail by pixel
height** as the user zooms:

```dart
Planner<ActivityMeta>(
  config: PlannerConfig<ActivityMeta>(labels: const ['Mon', 'Tue', 'Wed']),
  entries: entries,
  entryBuilder: (context, entry, layout) {
    final meta = entry.data;
    return Card(
      color: entry.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title),
          // Only show the place when the event is tall enough on screen.
          if (layout.size.height >= 52 && meta != null) Text(meta.place),
          // …and the avatar stack only when it's taller still.
          if (layout.size.height >= 92 && meta != null)
            Row(children: [for (final a in meta.attendees) CircleAvatar(child: Text(a))]),
        ],
      ),
    );
  },
)
```

Tapping, double-tapping, dragging or right-clicking the custom widget still
fires `onEntryEdit` / `onEntryMove` / `onEntryLongPress` (the overlay is
`IgnorePointer`). Overlapping events are placed side-by-side automatically via
`layout.columnIndex` / `layout.columnCount`, and `layout.dragType` reflects a
live move/resize.

#### `dayHeaderBuilder` — custom day/column headers

Supplies one widget per column header — e.g. a multi-part branded header with the
weekday, day number and a "today" tint. The signature carries **no `DateTime`**
(the core stays date-agnostic — ADR 0001); a consumer using the
[calendar helpers](#building-a-date-based-week-calendar) closes over their
`CalendarWindow` to recover the date:

```dart
final window = CalendarWindow.week(anchor: DateTime.now());

Planner(
  config: PlannerConfig(labels: window.labels()),
  entries: entries,
  dayHeaderBuilder: (context, columnIndex, label, isHighlighted) {
    final date = window.dateAt(columnIndex); // map index → real date
    return Container(
      color: isHighlighted ? Colors.blue : null, // `isHighlighted` == highlightedColumn
      child: Column(children: [Text('${date.day}'), Text(label)]),
    );
  },
)
```

Headers reposition on a day-axis pan and a horizontal drag across them still pans
the day axis.

#### `allDayEntryBuilder` — custom all-day chips

The all-day twin of `entryBuilder` — same `PlannerEntryBuilder<T>` signature, applied
to the all-day band (needs `showAllDayBand: true`). The `PlannerEntryLayout` carries
`allDay: true`, so one builder can serve both surfaces and branch on it:

```dart
Planner<ActivityMeta>(
  config: PlannerConfig<ActivityMeta>(labels: const ['Mon', 'Tue'], showAllDayBand: true),
  entries: entries, // some with PlannerTime(..., allDay: true)
  allDayEntryBuilder: (context, entry, layout) => Container(
    decoration: BoxDecoration(color: entry.color, borderRadius: BorderRadius.circular(10)),
    child: Text(entry.title),
  ),
)
```

A complete demo wiring **all four** hooks together (host zoom toolbar, branded
headers, detail-shedding event cards, and all-day chips) lives in
[`example/lib/main.dart`](example/lib/main.dart).

### Localizing the context menu

The context-menu item labels default to English but are plain `String`s on
`PlannerConfig`, so you can translate or rename them:

```dart
PlannerConfig(
  labels: const ['Lun', 'Mar', 'Mer'],
  contextMenuCreateLabel: 'Créer un événement',
  contextMenuEditLabel: 'Modifier l’événement',
  contextMenuDeleteLabel: 'Supprimer l’événement',
);
```

| Field | Defaults to | Item |
|-------|-------------|------|
| `contextMenuCreateLabel` | `'Create Event'` | Shown on an empty grid cell. |
| `contextMenuEditLabel` | `'Edit Event'` | Shown on an existing event. |
| `contextMenuDeleteLabel` | `'Delete Event'` | Shown on an existing event. |

### Highlighting a column ("today" style)

`planner` is column-based, not date-based (see the note above), so it has no idea
which column is "today". To emphasize one — a calendar's current day, the active
room, the selected lane — set `highlightedColumn` to its **index** into `labels`;
the grid fills that column behind the lines and events:

```dart
final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

PlannerConfig(
  labels: labels,
  // A calendar consumer owns the date↔index mapping and passes the index:
  highlightedColumn: 2, // e.g. DateTime.now().weekday - 1
  highlightColumnColor: Colors.amber.withOpacity(0.15), // optional
);
```

`highlightedColumn` defaults to `null` (no highlight); an out-of-range index
highlights nothing. `highlightColumnColor` defaults to a subtle translucent white
wash that reads on the default dark background — override it for a different tint
(or a darker wash on a light background).

| Field | Defaults to | Purpose |
|-------|-------------|---------|
| `highlightedColumn` | `null` | Index into `labels` of the column to emphasize. |
| `highlightColumnColor` | translucent white | Fill painted across that column. |

## Building a date-based week calendar

The core widget is date-agnostic, but most calendars want real `DateTime`s. The
optional, **non-core** helpers in `package:planner/calendar.dart` own the
`date ↔ column-index` mapping for you, so the common week-calendar case stays a few
lines without `DateTime` ever entering the widget API. Import it explicitly — it is
**not** part of the main `planner.dart` barrel:

```dart
import 'package:planner/planner.dart';
import 'package:planner/calendar.dart'; // opt-in calendar helpers
```

A `CalendarWindow` is a window of N consecutive days. Hold one in your state, derive
the widget inputs from it, and step weeks with `next` / `previous`:

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

`labels()` defaults to a localized `EEE d` (e.g. `Mon 8`) via `intl`; pass your own
`String Function(DateTime)` for a different format or locale. `todayColumn` returns
`null` when today isn't in the window, which `highlightedColumn` already treats as
"no highlight".

| `CalendarWindow` member | Purpose |
|-------------------------|---------|
| `CalendarWindow({start, dayCount})` / `.week({anchor, firstWeekday, dayCount})` | A window of `dayCount` days from `start`, or the week containing `anchor`. |
| `dateAt(i)` / `indexOf(date)` / `offsetOf(date)` / `contains(date)` | Map between dates and column indices. |
| `dates` / `next` / `previous` | The column dates; step one window forward / back. |
| `labels([format])` | Column headers for `PlannerConfig.labels` (default `intl` `EEE d`). |
| `todayColumn` | Index for `PlannerConfig.highlightedColumn` (today, or `null`). |
| `timeFor(start, {duration, end})` | A `PlannerTime` for a dated event, or `null` if outside the window. |
| `entriesFor(events, {start, build, duration, end})` | Build the `PlannerEntry` list from your own dated events. |

## Interactions

The widget reports user actions through the `onEntry*` callbacks; it never mutates
your data itself. The gesture set adapts to the input device: a precise pointer
(mouse) gets immediate drag-to-edit, while touch reserves one-finger drag for
panning and surfaces event actions through a long-press.

### Mouse / desktop

| Gesture | Result |
|---------|--------|
| Drag the empty canvas | Pan both axes (day + time) at once. |
| Drag the date row | Pan the day axis only. |
| Drag the hour gutter | Pan the time axis only. |
| Press an event body + drag | Move the event immediately (no long-press); fires `onEntryMove` on release. |
| Press an event's top/bottom edge + drag | Resize the event; fires `onEntryMove` on release. |
| Hover an event | Cursor hints the action: `move` over the body, `resizeUpDown` over an edge. |
| Mouse wheel | Scroll the time axis. |
| `Shift` + wheel | Scroll the day axis. |
| `Ctrl` + wheel | Zoom the time axis. |
| +/- buttons | Zoom the time axis (hide with `showZoomControls: false`). |
| Double-click an event | `onEntryEdit`. |
| Double-click an empty slot | `onEntryCreate`. |
| Right-click an event | Context menu → Edit / Delete (`onEntryEdit` / `onEntryDelete`). |
| Right-click an empty slot | Context menu → Create (`onEntryCreate`). |
| Long-press an event | `onEntryLongPress` — the same hook touch uses. |

One wheel notch always advances the same amount of *time* regardless of zoom; tune
the base step with `scrollStep`.

### Touch

| Gesture | Result |
|---------|--------|
| One-finger drag | Pan both axes (day + time) at once. |
| Two-finger pinch | Zoom the time axis. |
| Double-tap an event | `onEntryEdit`. |
| Double-tap an empty slot | `onEntryCreate`. |
| Long-press an event | `onEntryLongPress` with that entry. |
| Long-press an empty slot | Nothing. |

Touch has no right-click and reserves one-finger drag for panning, so **long-press
is how a touch user acts on an event**. The widget stays presentation-only: it
hands the pressed `PlannerEntry` to `onEntryLongPress` and takes no action of its
own (no built-in selection, highlight, or menu), so the host decides the response —
show an action sheet, a selection UI, a delete confirmation, or start a move flow.
To move an event by touch, drive it from this callback; immediate drag-move/resize
is a desktop-only affordance.

### Accessibility

The event canvas is a single `CustomPaint`, so each event also exposes a semantics
node for screen readers: activate to edit, dismiss to delete, and increase/decrease
to nudge it an hour later/earlier (`onEntryMove`). Only the actions whose callback
you wire are offered.

## Additional information

- **Roadmap & known issues:** [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md).
- **Issues / contributions:** https://github.com/pebble-world/planner/issues — PRs welcome.

## License

[MIT](LICENSE) © yvan vander sanden

This package vendors third-party source code under its own license; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
