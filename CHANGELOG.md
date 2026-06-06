# Changelog

## Unreleased

- Added optional, **non-core** calendar helpers in `package:planner/calendar.dart`
  (a separate import — *not* part of the main `planner.dart` barrel) so building an
  ordinary date-based week calendar on top of the date-agnostic widget is a few
  lines, without `DateTime` entering the widget API (ADR 0001 / #49). A
  `CalendarWindow` owns the `date ↔ column-index` mapping for a window of N days:
  build it directly or week-align it with `CalendarWindow.week(anchor: …)`, map
  dates to columns (`indexOf` / `dateAt` / `contains`), step weeks (`next` /
  `previous`), derive `PlannerConfig.labels` (`labels()`, defaulting to a localized
  `EEE d` via `intl`) and the `highlightedColumn` "today" index (`todayColumn`), and
  convert your own dated events into `PlannerEntry`/`PlannerTime` for the current
  window (`timeFor` / `entriesFor`, with column-spanning support via an `end` date).
  Adds `intl` as a dependency (used only by these helpers for the default label
  format).
- Fixed event accessibility semantics not updating when the canvas is scrolled
  or zoomed. A screen reader now reaches *every* event — not just those that were
  on screen the last time the data changed or the canvas was laid out — and each
  event's semantics node now tracks the scroll/zoom so its hit-area and focus
  highlight stay aligned as the user pans. Previously off-viewport events were
  culled and never re-exposed (the canvas has no a11y scroll action to bring them
  back), and a scrolled event kept a stale node rect.
- Added `PlannerConfig.onEntryLongPress`, fired with the long-pressed
  `PlannerEntry`. This is the primary way to act on an event by **touch** (touch
  has no right-click, and a one-finger drag now pans, so long-press is the
  freed-up gesture); a desktop long-press fires it too. The widget stays
  presentation-only — it takes no action of its own (no built-in selection,
  highlight, or menu), so the host decides the response. `null` (the default) and
  a long-press on empty space are both no-ops.
- Added column-spanning (multi-day) events. Set `PlannerTime.endDay` to a
  column index after `day` and the event renders across the whole `day..endDay`
  range; `null` (the default) or any value `<= day` is a single-column event, so
  existing entries are unaffected. The span stays index-based — no `DateTime`
  enters the model (ADR 0001). Spanning events are read-only in this first cut
  (they can't be dragged or resized) but stay tappable for edit/delete. A new
  `PlannerConfig.spanOverlap` chooses how a span coexists with the per-column
  overlap split: `SpanOverlap.fullWidth` (the default) draws it as one box across
  its columns; `SpanOverlap.split` folds it into each column's sub-column layout.
- Added an optional column highlight (a "today"-style emphasis). Set
  `PlannerConfig.highlightedColumn` to a column index (into `labels`) and the
  grid fills that column behind the lines and events; `highlightColumnColor`
  (default a subtle translucent white wash) sets the fill. The widget stays
  date-agnostic — a calendar consumer maps `DateTime.now()` to an index itself
  (ADR 0001). `null` (the default) or an out-of-range index highlights nothing.

## 0.2.0 - 2026-06-06

- Made the on-canvas zoom +/- buttons configurable: hide them with
  `PlannerConfig.showZoomControls: false`, and recolour them with
  `zoomButtonColor` (fill — falls back to the theme's secondary colour when
  unset) and `zoomButtonIconColor` (default white).
- Made mouse-wheel scrolling zoom-aware: the step now scales with the zoom level
  (configurable base via `PlannerConfig.scrollStep`, default `20`), so one wheel
  notch advances the same amount of *time* at any zoom instead of moving less the
  further you zoomed in.
- Centered the date and hour labels within their columns (and removed the
  hardcoded pixel offsets they previously used).
- Added accessibility for the event canvas: each event now exposes a `Semantics`
  node describing it (title, day-column label, time span and duration) and its
  actions to assistive technology — activate or "Edit" to edit, "Delete", and
  "Move earlier"/"Move later" (which nudge the event by an hour, the accessible
  equivalent of a drag-move). Actions route through the existing
  `onEntryEdit`/`onEntryDelete`/`onEntryMove` callbacks; only the ones the host
  wires up are offered. The single `CustomPaint` canvas was previously opaque to
  screen readers.
- Unified event-time snapping: creating an event by tapping and dragging/resizing
  one now snap to a single configurable interval, `PlannerConfig.snapMinutes`
  (default `15`), instead of separate ad-hoc, zoom-dependent thresholds. Pass
  `PlannerConfig.snapMinutesForZoom` to vary the interval with the zoom level, or
  set `snapMinutes <= 1` for minute precision. Create and drag now land on the
  same grid.
- Fixed an off-by-one in the hour column: `maxHour` now defaults to `23`
  (inclusive last hour), so the default planner no longer paints a spurious 25th
  row labelled "24", and a tap below the grid clamps to hour 23.
- Added an optional `PlannerConfig.hourLabelFormatter` to control how each hour
  renders in the left column (e.g. zero-padding, AM/PM, or `intl`).

## 0.0.4 - 2025-03-03

- Updated dependencies and raised the minimum Dart SDK to 3.0.

## 0.0.1 - 0.0.3

Initial public releases of the rewritten widget (the package was rebuilt from
scratch in 2022). Highlights:

- Day-grid planner rendered on a single `CustomPaint` canvas.
- Horizontal panning across labelled columns; vertical pan, drag, and mouse-wheel
  scrolling across hours.
- Zoom the time axis via pinch gestures or on-canvas +/- buttons, with finer grid
  lines fading in at higher zoom levels.
- Drag-to-move and handle-based drag-to-resize for events.
- Right-click / double-tap context menu to create, edit, and delete events via
  callbacks (`onEntryCreate`, `onEntryEdit`, `onEntryDelete`, `onEntryMove`).
- Customizable colors and text styles for the grid, labels, events, and menu.
