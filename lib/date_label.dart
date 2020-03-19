import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:planner/manager.dart';

class DateLabel {
  Offset position;
  String label;

  TextSpan _span;
  TextPainter _tp;

  final Manager manager;

  DateLabel({@required this.label, @required this.position, @required this.manager}) {
    _span = TextSpan(text: label, style: TextStyle(color: Colors.red));
    _tp = TextPainter(
      text: _span,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    _tp.layout();
  }

  void paint(Canvas canvas) {
    _tp.paint(canvas, manager.getPositionForLabel(position));
  }
}
