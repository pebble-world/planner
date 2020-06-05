import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:planner/manager.dart';

class DateLabel {
  Offset position;
  String label;

  TextPainter _tp;

  final Manager manager;

  DateLabel(
      {@required this.label, @required this.position, @required this.manager}) {
    _tp = TextPainter(
      text: TextSpan(
      text: label,
      style: manager.config.dateLabelStyle,
    ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    _tp.layout();
  }

  void paint(Canvas canvas) {
    _tp.paint(canvas, manager.getPositionForLabel(position));
  }
}
