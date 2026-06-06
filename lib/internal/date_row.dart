import 'package:flutter/material.dart';

import 'date_label.dart';
import 'manager.dart';

class DateRow extends CustomPainter {
  final List<DateLabel> _labels = <DateLabel>[];
  final Manager manager;

  // The manager's data revision when this delegate was built; compared in
  // shouldRepaint so the row repaints only when the data changed, not on every
  // unrelated parent rebuild (#25 / D6).
  final int _revision;

  DateRow({required this.manager, required Listenable repaint})
      : _revision = manager.revision,
        super(repaint: repaint) {
    int pos = 60;
    for (String element in manager.config.labels) {
      _labels.add(DateLabel(
        label: element,
        position: pos,
        manager: manager,
      ));
      pos += manager.config.blockWidth;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    //canvas.drawColor(Colors.white, BlendMode.overlay);
    for (DateLabel date in _labels) {
      date.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant DateRow oldDelegate) =>
      _revision != oldDelegate._revision;
}
