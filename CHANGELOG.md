# Changelog

## Unreleased

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
