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
| `PlannerConfig` | Sizing (`blockWidth`, `blockHeight`, `minHour`, `maxHour` — the inclusive last hour, default `23`, …), colors, text styles, an optional `hourLabelFormatter`, the optional column highlight (`highlightedColumn`, `highlightColumnColor`), the zoom controls (`showZoomControls`, `zoomButtonColor`, `zoomButtonIconColor`), the wheel `scrollStep`, the all-day band (`showAllDayBand`), and the `onEntry*` callbacks. `labels` is required. |
| `PlannerController` | Optional handle to drive/observe zoom from outside the widget — see [Controller](controller.md). |
| `PlannerEntry<T>` | One event: `id`, `time`, `title`, `content`, `color`, optional text styles, and an optional typed `data` payload (`T?`) for your own metadata — see [Builders](builders.md). |
| `PlannerTime` | `day` (index into `labels`), optional `endDay` (a column-spanning event), `hour`, `minutes`, `duration` (minutes), and `allDay`. |
| `PlannerEntryBuilder<T>` / `PlannerEntryLayout` | Build a custom widget for a timed event or all-day chip; `PlannerEntryLayout` carries the on-screen `size` (for detail-shedding), overlap column, and drag state — see [Builders](builders.md). |
| `PlannerDayHeaderBuilder` | Build a custom widget for a day/column header — see [Builders](builders.md). |

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
