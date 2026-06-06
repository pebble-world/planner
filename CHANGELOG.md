# Changelog

## Unreleased

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
