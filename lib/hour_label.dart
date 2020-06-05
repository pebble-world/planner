import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:planner/manager.dart';

class HourLabel {
  final Offset position;
  final String label;
  final Manager manager;

  TextPainter _tp;

  HourLabel(
      {@required this.label, @required this.position, @required this.manager}) {
    _tp = TextPainter(
        text: TextSpan(
          text: label, 
          style: manager.config.hourLabelStyle,
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    _tp.layout();
  }

  void paint(Canvas canvas) {
    _tp.paint(canvas, manager.getPositionForHour(position));
  }
}
