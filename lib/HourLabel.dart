import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:planner/Manager.dart';

class HourLabel {
  Offset position;
  String label;

  TextSpan _span;
  TextPainter _tp; 

  final Manager manager;

  HourLabel({@required this.label, @required this.position, @required this.manager}) {
    _span = TextSpan(text: label);
    _tp = TextPainter(text: _span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
    _tp.layout();
  }

  void paint(Canvas canvas) {
    _tp.paint(canvas, manager.getPositionForHour(position));
  }
}