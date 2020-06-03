import 'package:flutter/material.dart';
import 'package:planner/manager.dart';

class Lines {
  final Manager manager;

  // paint for main horizontal lines
  Paint hpaint = Paint()
    ..color = Color.fromARGB(100, 255, 255, 255)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  // paint for all vertical lines
  Paint vpaint = Paint()
    ..color = Color.fromARGB(50, 255, 255, 255)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  List<Line> hlines = List<Line>();
  List<Line> vlines = List<Line>();

  Lines({@required this.manager}) {
    // vertical lines: drawn after each day
    Offset vstart = Offset(manager.blockWidth.toDouble(), 0);
    Offset vend = Offset(
        manager.blockWidth.toDouble(), manager.blockHeight.toDouble() * 24);
    for (int i = 0; i < manager.labels.length; i++) {
      vlines.add(Line(start: vstart, end: vend, manager: manager));
      vstart = vstart.translate(manager.blockWidth.toDouble(), 0);
      vend = vend.translate(manager.blockWidth.toDouble(), 0);
    }

    // horizontal lines: for every 15 minutes, but only drawn if zoomed out
    double step = manager.blockHeight.toDouble() /
        4; // vSize stands for one hour, so this step is 15 minutes

    // this is the position for the first line
    Offset hstart = Offset(0, step);
    Offset hend =
        Offset((manager.blockWidth.toDouble() * (manager.labels.length)), step);
    int lines = (manager.maxHour - manager.minHour) * 4;

    for (int i = 0; i < lines; i++) {
      hlines.add(Line(start: hstart, end: hend, manager: manager));
      // increase for next 15 minute line
      hstart = hstart.translate(0, step);
      hend = hend.translate(0, step);
    }
  }

  void draw(Canvas canvas) {
    // vertical lines can be drawn instantly
    vlines.forEach((line) {
      line.draw(canvas, vpaint);
    });

    // now we need to determine the visibility for 30 minite lines, depending on zoom factor
    double color2 = manager.zoom - 1;
    if (color2 < 0) color2 = 0;
    if (color2 > 1) color2 = 1;

    // .. and set the color for this line
    Paint div2paint = Paint()
      ..color = Color.fromARGB((color2 * 75).toInt(), 255, 255, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // same for the next zoomlevel, which shows 15 and 45 minute lines
    double color3 = manager.zoom - 2;
    if (color3 < 0) color3 = 0;
    if (color3 > 1) color3 = 1;

    Paint div3paint = Paint()
      ..color = Color.fromARGB((color3 * 50).toInt(), 255, 255, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // draw line
    for (int i = 0; i < hlines.length; i++) {
      if ((i + 1) % 4 == 0) {
        // hour
        hlines[i].draw(canvas, hpaint);
      } else if ((i + 1) % 2 == 0 && color2 != 0) {
        // half an hour
        hlines[i].draw(canvas, div2paint);
      } else if (color3 != 0) {
        // 15 and 45 minutes
        hlines[i].draw(canvas, div3paint);
      }
    }
  }
}

class Line {
  Offset start;
  Offset end;
  Manager manager;

  Line({this.start, this.end, @required this.manager});

  void draw(Canvas canvas, Paint paint) {
    canvas.drawLine(manager.getScreenPosition(start),
        manager.getScreenPosition(end), paint);
  }
}
