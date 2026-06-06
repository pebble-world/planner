import 'package:flutter/material.dart';

import '../planner.dart';
import 'controller.dart';
import 'event.dart';

class Manager {
  PlannerConfig config;
  List<PlannerEntry> entries;
  final Controller controller;
  final List<Event> events = [];

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
    config.onEntryMove?.call(dragged.entry);
    controller.triggerUpdate.value++;
  }

  Event? getEventAtPos(Offset pos) {
    Offset realPos = _toGridPos(pos);

    for (Event event in events) {
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
