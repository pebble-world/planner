import 'package:flutter/material.dart';
import 'package:planner/internal/manager.dart';

import 'event.dart';
import 'grid.dart';

class EventsPainter extends CustomPainter {
  final Grid _grid;
  final Manager manager;

  Event? draggedEvent;

  EventsPainter({required this.manager, required Listenable repaint})
      : _grid = Grid(manager: manager),
        super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    _grid.draw(canvas);

    if (manager.controller.touchPos == null && draggedEvent != null) {
      draggedEvent!.endDrag();
      if (manager.config.onEntryMove != null) {
        manager.config.onEntryMove!(draggedEvent!.entry);
      }
      draggedEvent = null;
    }
    for (Event event in manager.events) {
      if (manager.controller.touchPos != null && draggedEvent == null) {
        Offset realPos = Offset(
            manager.controller.touchPos!.dx - manager.controller.offset.dx,
            (manager.controller.touchPos!.dy - manager.controller.offset.dy) /
                manager.controller.zoom);

        if (event.canvasRect.contains(realPos)) {
          draggedEvent = event;
          draggedEvent!.startDrag(realPos);
        }
      } else if (manager.controller.touchPos != null && draggedEvent == event) {
        Offset realPos = Offset(
            manager.controller.touchPos!.dx - manager.controller.offset.dx,
            (manager.controller.touchPos!.dy - manager.controller.offset.dy) /
                manager.controller.zoom);
        draggedEvent!.updateDrag(realPos);
      }
      event.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
