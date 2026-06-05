# Changelog

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
