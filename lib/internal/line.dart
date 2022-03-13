import 'package:flutter/material.dart';
import 'controller.dart';

class Line {
  final Offset start;
  final Offset end;
  final Controller controller;

  Line({required this.start, required this.end, required this.controller});

  void draw(Canvas canvas, Paint paint) {
    canvas.drawLine(
        Offset(controller.offset.dx + start.dx,
            controller.offset.dy + start.dy * controller.zoom),
        Offset(controller.offset.dx + end.dx,
            controller.offset.dy + end.dy * controller.zoom),
        paint);
  }
}
