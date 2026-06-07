# Fully custom widgets (builders)

By default the planner paints everything on a canvas. Three opt-in **builders**
let you replace any of those surfaces with real Flutter widgets — branded
headers, rich event cards, custom chips — while the package stays the engine
(geometry, scroll, zoom, hit-testing, overlap, accessibility). Each builder is
**visual-only**: the widget overlay is wrapped in `IgnorePointer` /
`ExcludeSemantics`, so every gesture and accessibility action still falls through
to the canvas and fires the usual `onEntry*` callbacks. Everything is opt-in —
pass `null` (the default) and the painted look is unchanged.

Runnable versions of everything here live in the example gallery:
[`typed_data_example.dart`](../example/lib/examples/typed_data_example.dart),
[`custom_headers_example.dart`](../example/lib/examples/custom_headers_example.dart),
[`all_day_example.dart`](../example/lib/examples/all_day_example.dart), and the
combined [`showcase_example.dart`](../example/lib/examples/showcase_example.dart).

## Typed metadata: `PlannerEntry<T>.data`

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

## `entryBuilder` — custom timed-event widgets

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

## `dayHeaderBuilder` — custom day/column headers

Supplies one widget per column header — e.g. a multi-part branded header with the
weekday, day number and a "today" tint. The signature carries **no `DateTime`**
(the core stays date-agnostic — [ADR 0001](decisions/0001-time-model-day-index.md));
a consumer using the [calendar helpers](calendar.md) closes over their
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

## `allDayEntryBuilder` — custom all-day chips

The all-day twin of `entryBuilder` — same `PlannerEntryBuilder<T>` signature,
applied to the all-day band (needs `showAllDayBand: true`). The
`PlannerEntryLayout` carries `allDay: true`, so one builder can serve both
surfaces and branch on it:

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

A demo wiring **all four** hooks together (host zoom toolbar, branded headers,
detail-shedding event cards, and all-day chips) lives in the
[Showcase example](../example/lib/examples/showcase_example.dart).

---

**More docs:** [Core concepts](core-concepts.md) · [Builders](builders.md) · [Calendar](calendar.md) · [Controller](controller.md) · [Interactions](interactions.md) · [README](../README.md)
