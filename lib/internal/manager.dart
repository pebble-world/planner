import 'package:flutter/material.dart';

import '../planner.dart';
import 'controller.dart';
import 'event.dart';

class Manager {
  PlannerConfig config;
  List<PlannerEntry> entries;
  final Controller controller;
  final List<Event> events = [];

  // Bumped every time the event set is rebuilt (construct / update). Painters
  // snapshot it and compare it in shouldRepaint, so the canvas repaints — and
  // its accessibility semantics rebuild — exactly when the data changed, not on
  // every unrelated parent rebuild (#25 / D6). Scroll and zoom repaints stay on
  // the controller's repaint listenable, independent of this.
  int _revision = 0;
  int get revision => _revision;

  // Events bucketed by their day-column (entry.time.day). getEventAtPos
  // hit-tests only the tapped column's bucket instead of scanning every event
  // (#25): an event's rect lies entirely within its own day-column, so no other
  // bucket can contain the point. Rebuilt only when the event set or an event's
  // day can have changed — never per frame or per tap.
  final Map<int, List<Event>> _eventsByDay = {};

  Manager({
    required this.config,
    required this.entries,
  }) : controller = Controller(config) {
    _buildEvents();
  }

  /// Refreshes the planner data in place when the host `Planner` widget is
  /// rebuilt with new [config] or [entries]. The [controller] is preserved, so
  /// the current scroll/zoom position survives the rebuild instead of being
  /// reset — which is what the previous `static` controller state hacked around.
  void update({
    required PlannerConfig config,
    required List<PlannerEntry> entries,
  }) {
    this.config = config;
    this.entries = entries;
    controller.updateConfig(config);
    _buildEvents();
  }

  void _buildEvents() {
    events.clear();
    for (PlannerEntry entry in entries) {
      events.add(Event(entry: entry, manager: this));
    }
    _layoutOverlaps();
    _rebuildDayIndex();
    _revision++;
  }

  /// Rebuilds the [_eventsByDay] hit-test buckets from the current [events].
  /// One linear pass, called only when the event set or an event's day can have
  /// changed (build/update and after a drag commits a possible day move).
  void _rebuildDayIndex() {
    _eventsByDay.clear();
    for (final Event event in events) {
      _eventsByDay.putIfAbsent(event.entry.time.day, () => []).add(event);
    }
  }

  /// Splits each day-column among events that overlap in time (#20 /
  /// PROJECT_OVERVIEW D11). Without this, concurrent events all paint at full
  /// column width and stack unreadably. Per day we greedily pack events into the
  /// fewest sub-columns (a first-fit interval-graph colouring, so non-overlapping
  /// events reuse a column), then every event in a connected overlap cluster is
  /// narrowed to `1 / columns` of the day-column and offset to its own
  /// sub-column — the standard side-by-side calendar layout.
  void _layoutOverlaps() {
    final byDay = <int, List<Event>>{};
    for (final event in events) {
      byDay.putIfAbsent(event.entry.time.day, () => []).add(event);
    }
    for (final dayEvents in byDay.values) {
      _layoutDayColumn(dayEvents);
    }
  }

  void _layoutDayColumn(List<Event> dayEvents) {
    int startOf(Event e) => e.entry.time.hour * 60 + e.entry.time.minutes;
    int endOf(Event e) => startOf(e) + e.entry.time.duration;

    // Sort by start, then by end: first-fit packing assumes ascending starts.
    dayEvents.sort((a, b) {
      final byStart = startOf(a).compareTo(startOf(b));
      return byStart != 0 ? byStart : endOf(a).compareTo(endOf(b));
    });

    // The events of the current connected overlap cluster, the end time of the
    // last event placed in each of its sub-columns, and the cluster's latest end.
    final cluster = <Event>[];
    final columnEnds = <int>[];
    int clusterEnd = -1;

    void closeCluster() {
      for (final event in cluster) {
        event.columnCount = columnEnds.length;
        event.relayout();
      }
      cluster.clear();
      columnEnds.clear();
      clusterEnd = -1;
    }

    for (final event in dayEvents) {
      // A start at/after every event placed so far ends the cluster: its column
      // count is now final, so close it before opening the next one.
      if (cluster.isNotEmpty && startOf(event) >= clusterEnd) {
        closeCluster();
      }

      // First-fit: reuse the earliest sub-column whose previous event has ended;
      // otherwise open a new one.
      var column = columnEnds.indexWhere((end) => end <= startOf(event));
      if (column == -1) {
        column = columnEnds.length;
        columnEnds.add(endOf(event));
      } else {
        columnEnds[column] = endOf(event);
      }
      event.columnIndex =
          column; // columnCount is filled in when the cluster closes
      cluster.add(event);
      if (endOf(event) > clusterEnd) clusterEnd = endOf(event);
    }
    closeCluster();
  }

  Event? _draggedEvent;

  /// The event currently being dragged, or `null` when no drag is in progress.
  Event? get draggedEvent => _draggedEvent;

  /// Translates a pointer position in the planner's local coordinates into the
  /// grid's own coordinate space (undoing the current scroll offset and zoom).
  Offset _toGridPos(Offset localPos) => Offset(
      localPos.dx - controller.offset.dx,
      (localPos.dy - controller.offset.dy) / controller.zoom);

  /// Begins a drag at [localPos] (planner-local coordinates) if it lands on an
  /// event. Called from the widget layer's gesture handlers — never from paint.
  void startDrag(Offset localPos) {
    if (_draggedEvent != null) return;
    final event = getEventAtPos(localPos);
    if (event == null) return;
    _draggedEvent = event;
    event.startDrag(_toGridPos(localPos));
    controller.triggerUpdate.value++;
  }

  /// Updates the in-progress drag to follow [localPos]. No-op when nothing is
  /// being dragged.
  void updateDrag(Offset localPos) {
    if (_draggedEvent == null) return;
    _draggedEvent!.updateDrag(_toGridPos(localPos));
    controller.triggerUpdate.value++;
  }

  /// Commits the in-progress drag: snaps the entry to its new time and fires
  /// [PlannerConfig.onEntryMove]. No-op when nothing is being dragged.
  void endDrag() {
    if (_draggedEvent == null) return;
    final dragged = _draggedEvent!;
    _draggedEvent = null;
    dragged.endDrag();
    // A move can change the event's day-column, so refresh the hit-test buckets
    // even if the host doesn't rebuild in response to onEntryMove (#25).
    _rebuildDayIndex();
    config.onEntryMove?.call(dragged.entry);
    controller.triggerUpdate.value++;
  }

  // --- Accessibility actions (#21) --------------------------------------------
  // The event canvas is a single opaque CustomPaint, so screen-reader users
  // reach an event's actions through its semantics node, not the pointer-only
  // context menu / drag. These route to the same host callbacks the pointer UI
  // uses, so "edit"/"delete"/"move" behave identically however they're invoked.

  /// Fires [PlannerConfig.onEntryEdit] for [event] — the accessibility "Edit"
  /// action, mirroring the context menu's "Edit Event".
  void editEvent(Event event) => config.onEntryEdit?.call(event.entry);

  /// Fires [PlannerConfig.onEntryDelete] for [event] — the accessibility
  /// "Delete" action, mirroring the context menu's "Delete Event".
  void deleteEvent(Event event) => config.onEntryDelete?.call(event.entry);

  /// Shifts [event] by [hourDelta] whole hours, clamped to
  /// `[config.minHour, config.maxHour]`, then re-lays out overlaps, repaints,
  /// and fires [PlannerConfig.onEntryMove]. A screen-reader user can't drag, so
  /// the accessibility layer exposes "Move earlier"/"Move later" nudges — the
  /// keyboard-friendly equivalent of a drag-move. A nudge that would leave the
  /// hour unchanged (already at the bound) is a no-op and fires nothing.
  void nudgeEvent(Event event, int hourDelta) {
    final time = event.entry.time;
    final newHour =
        (time.hour + hourDelta).clamp(config.minHour, config.maxHour);
    if (newHour == time.hour) return;
    time.hour = newHour;
    _layoutOverlaps();
    controller.triggerUpdate.value++;
    config.onEntryMove?.call(event.entry);
  }

  Event? getEventAtPos(Offset pos) {
    final Offset realPos = _toGridPos(pos);

    // Only events in the tapped day-column can contain the point, so scan that
    // one bucket instead of every event (#25). A tap outside the grid maps to
    // an absent bucket and simply finds nothing.
    final int day = (realPos.dx / config.blockWidth).floor();
    final List<Event>? candidates = _eventsByDay[day];
    if (candidates == null) return null;

    for (final Event event in candidates) {
      if (event.canvasRect.contains(realPos)) {
        return event;
      }
    }

    return null;
  }

  PlannerTime getTimeAtPos(Offset pos) {
    Offset realPos = _toGridPos(pos);

    // Clamp to valid ranges so taps above/left of the grid (negative) or past
    // the last column/hour (grid smaller than the viewport) can't produce an
    // out-of-range day/hour.
    int day = (realPos.dx / config.blockWidth)
        .floor()
        .clamp(0, config.labels.length - 1);

    // Row index from the top of the grid, plus the proportional minute offset
    // into that row (pixels -> minutes via blockHeight, not a hardcoded 40),
    // snapped to the configured interval so a created event lands on the same
    // grid a dragged one does.
    final double rawRow = realPos.dy / config.blockHeight;
    final int row = rawRow.floor();
    int hour = config.minHour + row;
    int minutes = snapToInterval(((rawRow - row) * 60).floor());

    // A tap outside the grid clamps to a valid hour; its minute offset is
    // meaningless, so pin it to the hour boundary.
    if (hour < config.minHour) {
      hour = config.minHour;
      minutes = 0;
    } else if (hour > config.maxHour) {
      hour = config.maxHour;
      minutes = 0;
    }

    return PlannerTime(day: day, hour: hour, minutes: minutes);
  }

  /// The snap interval (in minutes) in effect right now: the zoom-aware override
  /// if the host supplied one, otherwise the flat [PlannerConfig.snapMinutes].
  int get activeSnapMinutes =>
      config.snapMinutesForZoom?.call(controller.zoom) ?? config.snapMinutes;

  /// Snaps [minutes] to a multiple of [activeSnapMinutes]. The single snapping
  /// primitive shared by create ([getTimeAtPos]) and drag/resize
  /// ([Event.endDrag]), so the two stay in lockstep. An interval `<= 1` leaves
  /// [minutes] untouched (minute precision); it truncates rather than rounds so
  /// a within-hour offset can't spill into the next hour (e.g. 58 -> 45, never
  /// 60, at a 15-minute snap).
  int snapToInterval(int minutes) {
    final step = activeSnapMinutes;
    if (step <= 1) return minutes;
    return (minutes ~/ step) * step;
  }
}
