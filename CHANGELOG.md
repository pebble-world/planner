# Changelog

## 0.3.1 - 2026-06-08

- Fixed the README screenshots not rendering on the pub.dev package page. They
  were raw HTML `<img>` tags with **relative** `src` paths, and pub.dev's README
  sanitizer strips relative `src` from raw HTML images (it only rewrites relative
  URLs in Markdown links), so every screenshot showed as bracketed alt text. The
  `<img>` tags now use absolute `raw.githubusercontent.com` URLs. Docs/packaging
  only — no code or API change.

## 0.3.0 - 2026-06-08

- Overhauled the documentation, examples, and screenshots ahead of this release:
  a slim, screenshot-led `README.md` with the reference split into `doc/` pages,
  the example app restructured into a gallery of progressive examples over richer
  sample data, `CONTRIBUTING.md` carrying the architecture notes (retiring
  `PROJECT_OVERVIEW.md`), and the README/docs screenshots generated reproducibly
  from the example app via an integration test (#88, #89, #90, #91, #92, #93).
- Added fully custom **widget builders**, so a host can own the visuals while the
  package stays the time-grid engine (geometry, scroll, zoom, hit-testing,
  overlap, accessibility). All opt-in and non-breaking — defaults are unchanged:
  - `Planner.dayHeaderBuilder` — a custom widget per day/column header (#79). The
    signature carries no `DateTime` (the core stays date-agnostic, ADR 0001);
    close over a `CalendarWindow` to recover the date. Headers track day-axis
    pan, and a drag across them still pans.
  - `Planner.entryBuilder` — a custom widget per timed event, layered over the
    canvas at the event's live on-screen rect so it tracks scroll/zoom/drag (#78).
    `PlannerEntryLayout.size` lets a widget **shed detail by pixel height**.
  - `Planner.allDayEntryBuilder` — the same for all-day chips, with
    `PlannerEntryLayout.allDay == true` (#80).
  - The overlays are visual-only (`IgnorePointer` / `ExcludeSemantics`), so every
    gesture and accessibility action still falls through to the canvas and fires
    the usual `onEntry*` callbacks.
- Made `PlannerEntry` generic: `PlannerEntry<T>` adds an optional typed `data`
  payload for your own per-event metadata (#77). `T` threads through `Planner<T>`,
  `PlannerConfig<T>` and the `onEntry*` callbacks, so a builder reads `entry.data`
  already typed — no cast, no side-map keyed by `id`. An untyped `PlannerEntry(...)`
  infers `T == dynamic` and is unchanged, so this is backward compatible.
- Added a public `PlannerController` for driving and observing the planner's zoom
  from outside the widget — e.g. a host's own zoom toolbar. Construct one, pass it
  to `Planner(controller: …)`, and call `zoomIn([factor])`, `zoomOut([factor])` or
  `zoomTo(target)` (clamped to `minZoom`/`maxZoom`); read back `zoom`, `minZoom`,
  `maxZoom`, `dayScroll`, `timeScroll` and `isAttached`. It is a `ChangeNotifier`,
  so a toolbar can listen and rebuild (e.g. disable `+` at `maxZoom`). It attaches
  to the planner's internal zoom/scroll state — the single source of truth, no
  duplicated state — so the controller, pinch, `Ctrl`+wheel and the built-in
  buttons all move the same zoom. Pair it with `showZoomControls: false` to replace
  the on-canvas buttons. Optional and fully backward compatible: omit it and
  nothing changes.
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
