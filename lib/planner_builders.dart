import 'package:flutter/widgets.dart';

import 'planner_entry.dart';

/// What a single in-progress events-canvas drag/resize is doing. A press within
/// 8px of an event's top edge resizes from the top ([topHandle]), within 8px of
/// the bottom resizes from the bottom ([bottomHandle]), anywhere else moves the
/// whole event ([body]); [none] is the idle state (no drag in progress).
///
/// Public (#78) so a custom [PlannerEntryBuilder] can react to the live drag —
/// e.g. emphasise the widget while it's being moved. It is carried on
/// [PlannerEntryLayout.dragType] (and the package's own hover-cursor hit test
/// reads it too).
enum DragType {
  body,
  topHandle,
  bottomHandle,
  none,
}

/// Builds a fully custom widget for a single timed event (#78) — and, reused as
/// `allDayEntryBuilder`, for a single all-day chip (#80). Supplied to the
/// `Planner` as `entryBuilder`; when non-null the planner layers a widget
/// overlay over the canvas and calls this for every (on-screen) event, sizing
/// and positioning the returned widget at the event's current on-screen rect so
/// it tracks scroll, zoom and drag in lockstep with the grid.
///
/// The overlay is purely visual — it is wrapped in `IgnorePointer` /
/// `ExcludeSemantics`, so every gesture (tap, double-tap, drag, resize,
/// long-press, right-click) and all accessibility actions fall through to the
/// package's existing recognizers and fire the usual `onEntry*` callbacks. The
/// builder therefore decides *appearance* only; interaction stays package-owned.
///
/// [entry] is the typed entry being drawn (read `entry.data` for the host's
/// metadata payload, #77); [layout] carries the on-screen [PlannerEntryLayout]
/// facts (size, overlap column, drag state) the builder needs to shed detail or
/// reflect the drag.
typedef PlannerEntryBuilder<T> = Widget Function(
  BuildContext context,
  PlannerEntry<T> entry,
  PlannerEntryLayout layout,
);

/// The on-screen layout facts handed to a [PlannerEntryBuilder] for one event
/// (#78). Everything here is derived from the package's geometry for the current
/// frame, so the builder can lay out responsively without recomputing it.
class PlannerEntryLayout {
  /// The widget's on-screen size — the event's `screenRect` size, i.e. its
  /// (possibly overlap-narrowed) width and `durationInHours * blockHeight *
  /// zoom` height. Detail-shedding builders key their thresholds on
  /// `size.height` (e.g. show avatars only above 92px).
  final Size size;

  /// Which sub-column this event occupies within its day-column, and how many
  /// sub-columns the day-column was split into for concurrent events (#20). A
  /// non-overlapping event is `columnIndex: 0, columnCount: 1`; overlapping
  /// events render side-by-side via these and the [size] width.
  final int columnIndex;
  final int columnCount;

  /// Whether this event is the one currently being dragged or resized — a
  /// convenience for `dragType != DragType.none`.
  final bool isDragged;

  /// The live drag this event is undergoing ([DragType.none] when idle), so a
  /// builder can reflect a move vs. a top/bottom resize.
  final DragType dragType;

  /// Whether this widget is an all-day chip rather than a timed event: `false`
  /// for the timed-event overlay (#78), `true` for the all-day-chip overlay
  /// (#80). A host that wires one builder to both `entryBuilder` and
  /// `allDayEntryBuilder` branches on this to render a chip vs. a timed card.
  /// All-day chips don't sub-divide a column or drag, so their layout always
  /// carries `columnIndex: 0`, `columnCount: 1`, `dragType: DragType.none` and
  /// `isDragged: false`; the chip's stacking lane is already baked into [size]
  /// and the widget's on-screen position.
  final bool allDay;

  const PlannerEntryLayout({
    required this.size,
    required this.columnIndex,
    required this.columnCount,
    required this.isDragged,
    required this.dragType,
    required this.allDay,
  });
}

/// Builds a fully custom widget for a single day/column header (#79). Supplied
/// to the `Planner` as `dayHeaderBuilder`; when non-null the planner replaces
/// the painted `DateRow` text with a row of host-built header widgets — one per
/// column label — each sized to the column's `blockWidth` and the date row's
/// height, and offset by the live horizontal scroll so the headers stay aligned
/// with the day-columns below as the user pans (it rebuilds on the same
/// `triggerUpdate` the row repaints on).
///
/// The header row is wrapped in `IgnorePointer`, so a horizontal drag across it
/// still pans the day axis through the package's own gesture detector — the
/// builder decides *appearance* only. Header widgets keep their natural
/// semantics, so a `Text` header is read by assistive technology (unlike the
/// painted default, which exposes none).
///
/// [columnIndex] is the column's index into `config.labels`; [label] is that
/// label string (the same text the painted `DateRow` would show); [isHighlighted]
/// is `columnIndex == config.highlightedColumn`, for emphasising e.g. "today".
///
/// No `DateTime` enters the signature (ADR-0001 keeps the core date-agnostic): a
/// consumer using `lib/calendar.dart` closes over their `CalendarWindow` and
/// calls `window.dateAt(columnIndex)` inside the builder to recover the date.
typedef PlannerDayHeaderBuilder = Widget Function(
  BuildContext context,
  int columnIndex,
  String label,
  bool isHighlighted,
);
