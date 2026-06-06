import 'package:flutter/material.dart';

import '../planner.dart';
import 'all_day_event.dart';
import 'controller.dart';
import 'event.dart';

class Manager {
  PlannerConfig config;
  List<PlannerEntry> entries;
  final Controller controller;
  final List<Event> events = [];

  /// The all-day events (#48), packed into stacked lanes for the all-day band.
  /// Built from entries whose [PlannerTime.allDay] is set; those are kept out of
  /// [events] (the hour-positioned grid) entirely. Empty when none are all-day,
  /// in which case the band is omitted and [allDayBandHeight] is zero.
  final List<AllDayEvent> allDayEvents = [];

  /// How many stacked lanes the all-day band needs — the height of the busiest
  /// overlap of all-day events. Zero when there are no all-day events.
  int allDayLaneCount = 0;

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
    final allDayInputs = <PlannerEntry>[];
    for (PlannerEntry entry in entries) {
      // All-day entries render in the band, not the hour grid, so they're kept
      // out of `events` (and thus out of overlap layout, hit-testing and drag).
      if (entry.time.allDay) {
        allDayInputs.add(entry);
      } else {
        events.add(Event(entry: entry, manager: this));
      }
    }
    _layoutOverlaps();
    _layoutAllDay(allDayInputs);
    _rebuildDayIndex();
    // The band reserves vertical space above the grid, so the time-axis scroll
    // clamp must account for it (else the grid can over-scroll by the band's
    // height). Re-applied whenever the all-day layout can have changed.
    controller.setReservedHeight(allDayBandHeight);
    _revision++;
  }

  /// Packs the all-day events (#48) into stacked lanes for the band. Each event
  /// covers columns `day..lastDay` (a multi-day all-day event spans columns the
  /// same index-based way #47 does), and concurrent ones — those sharing any
  /// column — must not share a lane. First-fit on the column axis (sorted by
  /// start column, then end) gives the standard side-by-side stacking with the
  /// fewest lanes, mirroring the per-column time packing in [_layoutDayColumn].
  void _layoutAllDay(List<PlannerEntry> allDayInputs) {
    allDayEvents.clear();

    final sorted = [...allDayInputs]..sort((a, b) {
        final byStart = a.time.day.compareTo(b.time.day);
        return byStart != 0
            ? byStart
            : a.time.lastDay.compareTo(b.time.lastDay);
      });

    // The last column (inclusive) used by each open lane. A lane is free for an
    // event starting at `day` once its previous occupant ended before `day`.
    final laneLastColumn = <int>[];
    for (final entry in sorted) {
      final start = entry.time.day;
      final end = entry.time.lastDay;
      var lane = laneLastColumn.indexWhere((last) => last < start);
      if (lane == -1) {
        lane = laneLastColumn.length;
        laneLastColumn.add(end);
      } else {
        laneLastColumn[lane] = end;
      }
      allDayEvents.add(AllDayEvent(entry: entry, manager: this, lane: lane));
    }

    allDayLaneCount = laneLastColumn.length;
  }

  /// The height the all-day band occupies above the time grid: enough for every
  /// stacked lane plus the band's top/bottom padding, or `0` when there are no
  /// all-day events (the band is then omitted entirely). Drives both the band
  /// widget's height and the controller's scroll-clamp reservation.
  double get allDayBandHeight => allDayLaneCount == 0
      ? 0
      : allDayLaneCount * config.allDayBandLaneHeight +
          2 * allDayBandVerticalPadding;

  /// Rebuilds the [_eventsByDay] hit-test buckets from the current [events].
  /// One linear pass, called only when the event set or an event's day can have
  /// changed (build/update and after a drag commits a possible day move). A
  /// spanning event (#47) is bucketed into every column it covers, so it
  /// hit-tests from any of them, not just its start column.
  void _rebuildDayIndex() {
    _eventsByDay.clear();
    for (final Event event in events) {
      final time = event.entry.time;
      for (int day = time.day; day <= time.lastDay; day++) {
        _eventsByDay.putIfAbsent(day, () => []).add(event);
      }
    }
  }

  /// Splits each day-column among events that overlap in time (#20 /
  /// PROJECT_OVERVIEW D11). Without this, concurrent events all paint at full
  /// column width and stack unreadably. Per day we greedily pack events into the
  /// fewest sub-columns (a first-fit interval-graph colouring, so non-overlapping
  /// events reuse a column), then every event in a connected overlap cluster is
  /// narrowed to `1 / columns` of the day-column and offset to its own
  /// sub-column — the standard side-by-side calendar layout.
  ///
  /// A column-spanning event (#47) is folded into the packing of **every column
  /// it covers** only under [SpanOverlap.split]; under [SpanOverlap.fullWidth]
  /// (the default) it is excluded so it draws across the full column width.
  /// Because a spanning event's placement is gathered across several columns, it
  /// is relaid out once at the end (single-column events relayout as each cluster
  /// closes).
  void _layoutOverlaps() {
    final split = config.spanOverlap == SpanOverlap.split;
    final byDay = <int, List<Event>>{};
    for (final event in events) {
      final time = event.entry.time;
      if (time.spansColumns) {
        // Reset any prior placement; an excluded (full-width) span keeps it
        // empty and draws across all its columns.
        event.clearSpanColumns();
        if (!split) continue;
        for (int day = time.day; day <= time.lastDay; day++) {
          byDay.putIfAbsent(day, () => []).add(event);
        }
      } else {
        byDay.putIfAbsent(time.day, () => []).add(event);
      }
    }
    for (final entry in byDay.entries) {
      _layoutDayColumn(entry.key, entry.value);
    }
    // Spanning events depend on placements gathered across all their columns, so
    // build their geometry only once every column has been packed.
    for (final event in events) {
      if (event.entry.time.spansColumns) event.relayout();
    }
  }

  void _layoutDayColumn(int day, List<Event> dayEvents) {
    int startOf(Event e) => e.entry.time.hour * 60 + e.entry.time.minutes;
    int endOf(Event e) => startOf(e) + e.entry.time.duration;

    // Sort by start, then by end: first-fit packing assumes ascending starts.
    dayEvents.sort((a, b) {
      final byStart = startOf(a).compareTo(startOf(b));
      return byStart != 0 ? byStart : endOf(a).compareTo(endOf(b));
    });

    // The events of the current connected overlap cluster, the end time of the
    // last event placed in each of its sub-columns, the sub-column each event
    // landed in, and the cluster's latest end. The sub-column is kept in a local
    // map rather than on the Event, since a spanning event is packed once per
    // column it crosses and must not clobber its other columns' placements.
    final cluster = <Event>[];
    final columnEnds = <int>[];
    final columnOf = <Event, int>{};
    int clusterEnd = -1;

    void closeCluster() {
      final count = columnEnds.length;
      for (final event in cluster) {
        _assignColumn(event, day, columnOf[event]!, count);
      }
      cluster.clear();
      columnEnds.clear();
      columnOf.clear();
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
      columnOf[event] = column; // count is filled in when the cluster closes
      cluster.add(event);
      if (endOf(event) > clusterEnd) clusterEnd = endOf(event);
    }
    closeCluster();
  }

  /// Applies the packed sub-column ([index] of [count]) to [event] for [day]. A
  /// single-column event stores it directly and relays out now; a spanning event
  /// records it per column (relayout is deferred to [_layoutOverlaps] once all
  /// its columns are packed).
  void _assignColumn(Event event, int day, int index, int count) {
    if (event.entry.time.spansColumns) {
      event.setSpanColumn(day, index, count);
    } else {
      event.columnIndex = index;
      event.columnCount = count;
      event.relayout();
    }
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
    // Spanning events are read-only in this first cut (#47): a long-press on one
    // starts no drag, so it can't be moved or resized (it stays tappable for
    // edit/delete via double-tap and the context menu).
    if (event.entry.time.spansColumns) return;
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
    // Immutable models (#27): swap in a new entry rather than mutating in place;
    // _layoutOverlaps reads the new time, and onEntryMove reports the new entry.
    event.entry = event.entry.copyWith(time: time.copyWith(hour: newHour));
    _layoutOverlaps();
    controller.triggerUpdate.value++;
    config.onEntryMove?.call(event.entry);
  }

  /// The drag a press at [localPos] (planner-local coordinates) would begin, or
  /// [DragType.none] when it lands on no draggable event. Drives the desktop
  /// hover cursor (move over an event body, resize over its top/bottom edge) and
  /// shares [Event.dragTypeForGridPoint] with [startDrag], so the cursor matches
  /// the drag a press there would start. Spanning events are read-only (#47), so
  /// they report [DragType.none] (no move/resize affordance).
  DragType dragTypeAt(Offset localPos) {
    final event = getEventAtPos(localPos);
    if (event == null || event.entry.time.spansColumns) return DragType.none;
    return event.dragTypeForGridPoint(_toGridPos(localPos));
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
      if (event.containsGridPoint(realPos)) {
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
