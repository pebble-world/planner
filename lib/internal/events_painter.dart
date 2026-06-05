import 'package:flutter/material.dart';
import 'package:planner/internal/manager.dart';

import 'event.dart';
import 'grid.dart';

class EventsPainter extends CustomPainter {
  final Grid _grid;
  final Manager manager;

  EventsPainter({required this.manager, required Listenable repaint})
      : _grid = Grid(manager: manager),
        super(repaint: repaint);

  // Pure rendering only: draw the grid, then each event using its own drag
  // state. Drag detection and the onEntryMove callback live in the widget layer
  // (gesture handlers -> Manager.start/update/endDrag), never here — a painter
  // must not mutate state or fire callbacks while painting.
  @override
  void paint(Canvas canvas, Size size) {
    _grid.draw(canvas);
    for (Event event in manager.events) {
      event.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
