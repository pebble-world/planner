import 'package:flutter/material.dart';
import 'package:planner/internal/date_label.dart';
import 'package:planner/internal/manager.dart';

class DateRow extends CustomPainter {
  final List<DateLabel> _labels = <DateLabel>[];
  final Manager manager;

  DateRow({required this.manager, required Listenable repaint})
      : super(repaint: repaint) {
    int _pos = 60;
    for (String element in manager.config.labels) {
      _labels.add(DateLabel(
        label: element,
        position: _pos,
        manager: manager,
      ));
      _pos += manager.config.blockWidth;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
