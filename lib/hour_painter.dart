import 'package:flutter/material.dart';
import 'package:planner/manager.dart';
import 'package:planner/hour_label.dart';

class HourPainter extends CustomPainter {
  var _hours = List<HourLabel>();
  final Manager manager;

  HourPainter({@required this.manager}) {
    double ypos = 0;
    for (int i = manager.config.minHour; i < manager.config.maxHour; i++) {
      _hours.add(HourLabel(
          label: i.toString(), position: Offset(10, ypos), manager: manager));
      ypos += manager.config.blockHeight;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    //debugPrint('canvas width ${size.width} height ${size.height}');

    //PlannerCam().setSize(size.width, size.height);
    _hours.forEach((hour) => hour.paint(canvas));
  }

  @override
  bool shouldRepaint(HourPainter oldDelegate) {
    //if(oldDelegate.vScroll != vScroll) return true;
    //if(oldDelegate.hScroll != hScroll) return true;
    //return false;
    return true;
  }
}
