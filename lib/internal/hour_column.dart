import 'package:flutter/cupertino.dart';

import '../planner_config.dart';
import 'hour_label.dart';
import 'manager.dart';

/// The hour-label strings shown down the left column, one per hour row from
/// [PlannerConfig.minHour] to [PlannerConfig.maxHour] **inclusive**.
///
/// Each hour is rendered with [PlannerConfig.hourLabelFormatter] when provided,
/// otherwise as the bare hour integer. Kept as a pure function (rather than
/// inlined in [HourColumn]) so the row count and formatting are unit-testable
/// without a canvas.
List<String> buildHourLabels(PlannerConfig config) {
  final format = config.hourLabelFormatter ?? (int hour) => hour.toString();
  return [
    for (int hour = config.minHour; hour <= config.maxHour; hour++)
      format(hour),
  ];
}

class HourColumn extends CustomPainter {
  final List<HourLabel> _labels = <HourLabel>[];
  final Manager manager;

  HourColumn({required this.manager, required Listenable repaint})
      : super(repaint: repaint) {
    int pos = 15;
    for (final text in buildHourLabels(manager.config)) {
      _labels.add(HourLabel(
        label: text,
        position: pos,
        manager: manager,
      ));
      pos += manager.config.blockHeight;
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
