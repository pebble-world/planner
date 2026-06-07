# Interactions

The widget reports user actions through the `onEntry*` callbacks; it never
mutates your data itself. The gesture set adapts to the input device: a precise
pointer (mouse) gets immediate drag-to-edit, while touch reserves one-finger drag
for panning and surfaces event actions through a long-press.

## Mouse / desktop

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
| +/- buttons | Zoom the time axis (hide with `showZoomControls: false`; see [Controller](controller.md)). |
| Double-click an event | `onEntryEdit`. |
| Double-click an empty slot | `onEntryCreate`. |
| Right-click an event | Context menu → Edit / Delete (`onEntryEdit` / `onEntryDelete`). |
| Right-click an empty slot | Context menu → Create (`onEntryCreate`). |
| Long-press an event | `onEntryLongPress` — the same hook touch uses. |

One wheel notch always advances the same amount of *time* regardless of zoom;
tune the base step with `scrollStep`.

## Touch

| Gesture | Result |
|---------|--------|
| One-finger drag | Pan both axes (day + time) at once. |
| Two-finger pinch | Zoom the time axis. |
| Double-tap an event | `onEntryEdit`. |
| Double-tap an empty slot | `onEntryCreate`. |
| Long-press an event | `onEntryLongPress` with that entry. |
| Long-press an empty slot | Nothing. |

Touch has no right-click and reserves one-finger drag for panning, so
**long-press is how a touch user acts on an event**. The widget stays
presentation-only: it hands the pressed `PlannerEntry` to `onEntryLongPress` and
takes no action of its own (no built-in selection, highlight, or menu), so the
host decides the response — show an action sheet, a selection UI, a delete
confirmation, or start a move flow. To move an event by touch, drive it from this
callback; immediate drag-move/resize is a desktop-only affordance.

## Accessibility

The event canvas is a single `CustomPaint`, so each event also exposes a
semantics node for screen readers: activate to edit, dismiss to delete, and
increase/decrease to nudge it an hour later/earlier (`onEntryMove`). Only the
actions whose callback you wire are offered.

## Localizing the context menu

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

## Highlighting a column ("today" style)

`planner` is [column-based, not date-based](core-concepts.md#the-time-model-columns-not-dates),
so it has no idea which column is "today". To emphasize one — a calendar's
current day, the active room, the selected lane — set `highlightedColumn` to its
**index** into `labels`; the grid fills that column behind the lines and events:

```dart
final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

PlannerConfig(
  labels: labels,
  // A calendar consumer owns the date↔index mapping and passes the index:
  highlightedColumn: 2, // e.g. DateTime.now().weekday - 1
  highlightColumnColor: Colors.amber.withValues(alpha: 0.15), // optional
);
```

`highlightedColumn` defaults to `null` (no highlight); an out-of-range index
highlights nothing. `highlightColumnColor` defaults to a subtle translucent white
wash that reads on the default dark background — override it for a different tint
(or a darker wash on a light background). For a real week calendar,
[`CalendarWindow.todayColumn`](calendar.md) supplies the index directly.

| Field | Defaults to | Purpose |
|-------|-------------|---------|
| `highlightedColumn` | `null` | Index into `labels` of the column to emphasize. |
| `highlightColumnColor` | translucent white | Fill painted across that column. |

---

**More docs:** [Core concepts](core-concepts.md) · [Builders](builders.md) · [Calendar](calendar.md) · [Controller](controller.md) · [Interactions](interactions.md) · [README](../README.md)
