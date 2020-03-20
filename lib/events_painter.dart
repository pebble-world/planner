import 'package:flutter/material.dart';
import 'package:planner/lines.dart';
import 'package:planner/manager.dart';
import 'package:planner/planner_entry.dart';
import 'package:vibration/vibration.dart';

class EventsPainter extends CustomPainter {
  var _lines;
  final ManagerProvider manager;
  static PlannerEntry draggedEntry;
  final Function(PlannerEntry) onEntryChanged;

  EventsPainter({@required this.manager, @required this.onEntryChanged}) {
    _lines = Lines(manager: manager);
    debugPrint('EventsPainter created');
  }

  @override
  void paint(Canvas canvas, Size size) {
    manager.setSize(size.width, size.height);
    _lines.draw(canvas);

    if (manager.touchPos == null && draggedEntry != null) {
      draggedEntry.endDrag();
      if (onEntryChanged != null) {
        onEntryChanged(draggedEntry);
      }
      draggedEntry = null;
      debugPrint('drag removed');
    }

    manager.entries.forEach((entry) {
      if (manager.touchPos != null && draggedEntry == null && entry.canvasRect.contains(manager.touchPos)) {
        //Vibration.vibrate(duration: 50);
        draggedEntry = entry;
        draggedEntry.startDrag(manager.touchPos);
        debugPrint('drag started');
      } else if (draggedEntry == entry) {
        draggedEntry.updateDrag(manager.touchPos);
      }
      entry.paint(manager, canvas);
    });
  }

  @override
  bool shouldRepaint(EventsPainter oldDelegate) {
    return true;
  }
}
