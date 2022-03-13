import 'package:flutter/material.dart';
import 'package:planner/internal/manager.dart';

class DateLabel {
  final int position;
  final String label;
  final Manager manager;

  late TextPainter _tp;

  DateLabel({
    required this.label,
    required this.position,
    required this.manager,
  }) {
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
    Offset pos = Offset(
      manager.controller.offset.dx + position,
      20,
    );
    _tp.paint(canvas, pos);
  }
}
