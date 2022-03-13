import 'package:flutter/material.dart';

import 'manager.dart';

class HourLabel {
  final int position;
  final String label;
  final Manager manager;

  late TextPainter _tp;

  HourLabel({
    required this.label,
    required this.position,
    required this.manager,
  }) {
    _tp = TextPainter(
      text: TextSpan(
        text: label,
        style: manager.config.hourLabelStyle,
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    _tp.layout();
  }

  void paint(Canvas canvas) {
    Offset pos = Offset(
      15,
      manager.controller.offset.dy + (position * manager.controller.zoom),
    );
    _tp.paint(canvas, pos);
  }
}
