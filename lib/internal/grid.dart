import 'package:flutter/material.dart';

import 'line.dart';
import 'manager.dart';

class Grid {
  final Manager manager;

  late Paint hPaint, vPaint;
  final List<Line> hLines = [];
  final List<Line> vLines = [];

  Grid({required this.manager}) {
    // vertical lines: drawn after each day
    Offset vstart = Offset(manager.config.blockWidth.toDouble(), 0);
    Offset vend = Offset(
        manager.config.blockWidth.toDouble(),
        manager.config.blockHeight.toDouble() *
            (manager.config.maxHour - manager.config.minHour + 1));
    for (int i = 0; i < manager.config.labels.length; i++) {
      vLines
          .add(Line(start: vstart, end: vend, controller: manager.controller));
      vstart = vstart.translate(manager.config.blockWidth.toDouble(), 0);
      vend = vend.translate(manager.config.blockWidth.toDouble(), 0);
    }

    // horizontal lines: for every 15 minutes, but only drawn if zoomed out
    double step = manager.config.blockHeight.toDouble() /
        4; // vSize stands for one hour, so this step is 15 minutes

    // this is the position for the first line
    Offset hstart = Offset(0, step);
    Offset hend = Offset(
        (manager.config.blockWidth.toDouble() * (manager.config.labels.length)),
        step);
    int lines = (manager.config.maxHour - manager.config.minHour + 1) * 4;

    for (int i = 0; i < lines; i++) {
      hLines
          .add(Line(start: hstart, end: hend, controller: manager.controller));
      // increase for next 15 minute line
      hstart = hstart.translate(0, step);
      hend = hend.translate(0, step);
    }

    hPaint = Paint()
      ..color = manager.config.horizontalLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    vPaint = Paint()
      ..color = manager.config.verticalLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
  }

  void draw(Canvas canvas) {
    // vertical lines can be drawn instantly
    for (var line in vLines) {
      line.draw(canvas, vPaint);
    }

    // now we need to determine the visibility for 30 minite lines, depending on zoom factor
    double color2 = manager.controller.zoom - 1;
    if (color2 < 0) color2 = 0;
    if (color2 > 1) color2 = 1;

    // .. and set the color for this line
    Paint div2paint = Paint()
      ..color = Color.fromARGB((color2 * 60).toInt(), 255, 255, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // same for the next zoomlevel, which shows 15 and 45 minute lines
    double color3 = manager.controller.zoom - 2;
    if (color3 < 0) color3 = 0;
    if (color3 > 1) color3 = 1;

    Paint div3paint = Paint()
      ..color = Color.fromARGB((color3 * 30).toInt(), 255, 255, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // draw lines
    for (int i = 0; i < hLines.length; i++) {
      if ((i + 1) % 4 == 0) {
        // hour
        hLines[i].draw(canvas, vPaint);
      } else if ((i + 1) % 2 == 0 && color2 != 0) {
        // half an hour
        hLines[i].draw(canvas, div2paint);
      } else if (color3 != 0) {
        // 15 and 45 minutes
        hLines[i].draw(canvas, div3paint);
      }
    }
  }
}
