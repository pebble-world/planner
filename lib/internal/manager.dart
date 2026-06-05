import 'package:flutter/material.dart';
import 'package:planner/internal/event.dart';
import 'package:planner/planner.dart';

import '../planner_time.dart';
import 'controller.dart';

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

    int day = (realPos.dx / config.blockWidth).floor();
    int hour = config.minHour + (realPos.dy / config.blockHeight).floor();
    int minutes = 0;
    if (controller.zoom > 2.25) {
      minutes = ((realPos.dy.toInt() % config.blockHeight) / 10).floor() * 15;
    } else if (controller.zoom > 1.25) {
      minutes = ((realPos.dy.toInt() % config.blockHeight) / 20).floor() * 30;
    }
    return PlannerTime(day: day, hour: hour, minutes: minutes);
  }
}
