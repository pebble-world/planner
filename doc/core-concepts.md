# Core concepts

The types you wire together to render a planner, and how the time model works.
See the [README](../README.md) for the quick start, and the other guides for
each feature: [builders](builders.md), [calendar](calendar.md),
[controller](controller.md), [interactions](interactions.md).

## The time model: columns, not dates

`planner` is **column-based, not date-based**. A "day" is an *index* into the
`labels` list you provide — there are no real calendar dates in the core. This
keeps it a flexible scheduler for any set of columns (days, rooms, machines,
lanes …), not just a week.

For an ordinary date-based week calendar, the optional
[calendar helpers](calendar.md) map dates ↔ column indices on top of this model;
the core stays date-agnostic by design (see
[ADR 0001](decisions/0001-time-model-day-index.md)). No `DateTime` ever enters
the widget API.

## Core types

| Type | Purpose |
|------|---------|
| `Planner` | The widget. Takes a `config`, a list of `entries`, and optional `controller` / builders. |
| `PlannerConfig` | Sizing (`blockWidth`, `blockHeight`, `minHour`, `maxHour` — the inclusive last hour, default `23`, …), colors, text styles, an optional `hourLabelFormatter`, the optional column highlight (`highlightedColumn`, `highlightColumnColor`), the zoom controls (`showZoomControls`, `zoomButtonColor`, `zoomButtonIconColor`), the opening view (`initialHour`, `initialZoom` — see [Opening view](#opening-view)), the wheel `scrollStep`, the all-day band (`showAllDayBand`), and the `onEntry*` callbacks. `labels` is required. |
| `PlannerController` | Optional handle to drive/observe zoom from outside the widget — see [Controller](controller.md). |
| `PlannerEntry<T>` | One event: `id`, `time`, `title`, `content`, `color`, optional text styles, and an optional typed `data` payload (`T?`) for your own metadata — see [Builders](builders.md). |
| `PlannerTime` | `day` (index into `labels`), optional `endDay` (a column-spanning event), `hour`, `minutes`, `duration` (minutes), and `allDay`. |
| `PlannerEntryBuilder<T>` / `PlannerEntryLayout` | Build a custom widget for a timed event or all-day chip; `PlannerEntryLayout` carries the on-screen `size` (for detail-shedding), overlap column, and drag state — see [Builders](builders.md). |
| `PlannerDayHeaderBuilder` | Build a custom widget for a day/column header — see [Builders](builders.md). |

## Opening view

By default a planner opens scrolled to the top of the grid (`minHour`) at zoom
`1.0`. Set `initialHour` and/or `initialZoom` on `PlannerConfig` to open it
elsewhere — for example on a schedule that rarely starts before 08:00:

```dart
PlannerConfig(
  labels: const ['Mon', 'Tue', 'Wed'],
  initialHour: 8,    // 08:00 at the top of the grid; fractions allowed (8.5)
  initialZoom: 0.75, // clamped to [minZoom, maxZoom]
)
```

`initialHour` is clamped to `[minHour, maxHour]` and to the furthest the grid can
scroll, so a late hour opens with the last hour at the bottom rather than past
the end of the grid. Both are applied **once**, on the planner's first layout;
later rebuilds — even with a different `initialHour`/`initialZoom` — leave the
user's scroll and zoom alone. To change the zoom afterwards, use a
[`PlannerController`](controller.md).

## Callbacks

The widget reports interactions through `PlannerConfig`'s `onEntry*` callbacks;
it never mutates your data itself.

| Callback | Fires when |
|----------|-----------|
| `onEntryCreate(PlannerTime)` | An empty slot is double-tapped or "Create Event" is chosen. |
| `onEntryEdit(PlannerEntry)` | An event is double-tapped or "Edit Event" is chosen. |
| `onEntryDelete(PlannerEntry)` | "Delete Event" is chosen from the context menu. |
| `onEntryMove(PlannerEntry)` | A drag-move or handle-resize finishes; the entry's `time` is already updated. |
| `onEntryLongPress(PlannerEntry)` | An event is long-pressed — the touch hook for host-defined actions (see [Interactions](interactions.md)). |

> Your callbacks own the data. Update your own list of entries (and call
> `setState`) in response — the widget reports interactions but does not persist
> them.

---

**More docs:** [Core concepts](core-concepts.md) · [Builders](builders.md) · [Calendar](calendar.md) · [Controller](controller.md) · [Interactions](interactions.md) · [README](../README.md)
