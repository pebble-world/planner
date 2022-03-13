import 'package:flutter/cupertino.dart';

import 'hour_label.dart';
import 'manager.dart';

class HourColumn extends CustomPainter {
  final List<HourLabel> _labels = <HourLabel>[];
  final Manager manager;

  HourColumn({required this.manager, required Listenable repaint})
      : super(repaint: repaint) {
    int _pos = 15;
    for (int i = manager.config.minHour; i < manager.config.maxHour; i++) {
      _labels.add(HourLabel(
        label: i.toString(),
        position: _pos,
        manager: manager,
      ));
      _pos += manager.config.blockHeight;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (HourLabel label in _labels) {
      label.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
