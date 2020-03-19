import 'package:flutter/material.dart';
import 'package:planner/manager.dart';
import 'package:planner/date_label.dart';

class DatePainter extends CustomPainter {
  List<DateLabel> _dates = List<DateLabel>();
  final Manager manager;

  DatePainter({@required this.manager}) {
    double xpos = 60;
    manager.labels.forEach((label) {
      _dates.add(DateLabel(
        label: label,
        position: Offset(xpos, 17),
        manager: manager,
      ));
      xpos += manager.blockWidth;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    print("paint DatePainter");
    //PlannerCam().setSize(size.width, size.height);
    canvas.drawColor(Colors.black, BlendMode.overlay);
    _dates.forEach((date) => date.paint(canvas));
  }

  @override
  bool shouldRepaint(DatePainter oldDelegate) {
    return true;
  }
}
