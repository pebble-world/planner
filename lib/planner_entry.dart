import 'package:flutter/material.dart';
import 'package:planner/manager.dart';

enum DragType {
  body,
  topHandle,
  bottomHandle,
  none,
}

class PlannerEntry {
  int day;
  int hour;
  int minutes;
  int duration;
  int minHour;

  Paint fillPaint;
  Paint strokePaint;
  Color color;

  String title;
  String content;

  Rect canvasRect;
  TextPainter titlePainter;
  TextPainter contentPainter;

  Offset dragStartPos;
  Offset dragOffset;
  DragType dragType = DragType.none;

  PlannerEntry(
      {@required this.day, @required this.hour, this.title, this.content, @required this.color, this.minutes = 0, this.duration = 60});

  void createPainters(int minHour) {
    this.minHour = minHour;
    Offset a = Offset(day * 200.0, (hour - minHour) * 40.0 + ((minutes / 15).round() * 10));
    Offset b = a.translate(200.0, duration / 60 * 40.0);
    canvasRect = Rect.fromPoints(a, b);

    if (title != null) {
      var span = TextSpan(text: title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.red));
      titlePainter = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
      titlePainter.maxLines = 1;
    }
    if (content != null) {
      var span = TextSpan(text: content, style: TextStyle(fontSize: 8));
      contentPainter = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
    }

    fillPaint = Paint()
      ..color = color.withAlpha(100)
      ..style = PaintingStyle.fill;
    strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
  }

  void paint(ManagerProvider manager, Canvas canvas) {
    Rect rect = getCurrentRect();
    Rect screenRect = Rect.fromPoints(
      manager.getScreenPosition(rect.topLeft),
      manager.getScreenPosition(rect.bottomRight),
    );

    canvas.drawRect(screenRect, fillPaint);
    canvas.drawRect(screenRect, strokePaint);

    _paintHandle(manager, canvas, rect.topLeft.translate(0, 1));
    _paintHandle(manager, canvas, rect.bottomLeft.translate(0, -1));

    canvas.save();
    Offset cpos = rect.topLeft;
    cpos = cpos.translate(5.0, 2.0);
    cpos = manager.getScreenPosition(cpos);
    if (titlePainter != null) {
      titlePainter.layout(maxWidth: 190 * manager.getScale());
      titlePainter.paint(canvas, cpos);
      cpos = cpos.translate(0.0, 15.0);
    }
    if (contentPainter != null && duration > 15) {
      //2 lines per 15 Minutes
      contentPainter.maxLines = ((duration - 15) ~/ 7);
      contentPainter.layout(maxWidth: 180 * manager.getScale());
      contentPainter.paint(canvas, cpos);
    }
    canvas.restore();
  }

  void _paintHandle(ManagerProvider manager, Canvas canvas, Offset topLeft) {
    Paint handlerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // draw lines
    Offset left = topLeft.translate(80.0, 0.0);
    Offset right = left.translate(40.0, 0.0);
    canvas.drawLine(manager.getScreenPosition(left), manager.getScreenPosition(right), handlerPaint);

  }

  void startDrag(Offset pos) {
    if ((pos.dy - canvasRect.top).abs() < 8) {
      dragType = DragType.topHandle;
    } else if ((pos.dy - canvasRect.bottom).abs() < 8) {
      dragType = DragType.bottomHandle;
    } else {
      dragType = DragType.body;
    }
    dragStartPos = pos;
    dragOffset = Offset.zero;
  }

  void updateDrag(Offset pos) {
    dragOffset = pos - dragStartPos;
  }

  void endDrag() {
    if (dragType == DragType.body) {
      int newDay = ((canvasRect.topLeft.dx + dragOffset.dx) / 200.0).round();
      // 10 pixels is 15 minutes
      double newHour = (((canvasRect.topLeft.dy + dragOffset.dy) / 10.0).round() / 4) + minHour;
      day = newDay;
      hour = newHour.floor();
      minutes = ((newHour - newHour.floor()) * 60).floor();
    } else if (dragType == DragType.topHandle) {
      double newHour = (((canvasRect.topLeft.dy + dragOffset.dy) / 10.0).round() / 4) + minHour;
      int newMinutes = ((newHour - newHour.floor()) * 60).floor();
      duration += ((hour - newHour.floor()) * 60) - (newMinutes - minutes);
      hour = newHour.floor();
      minutes = newMinutes;
    } else if (dragType == DragType.bottomHandle) {
      duration += (dragOffset.dy / 10.0).round() * 15;
    }

    Offset a = Offset(day * 200.0, (hour - minHour) * 40.0 + ((minutes / 15).round() * 10));
    Offset b = a.translate(200.0, duration / 60 * 40.0);
    canvasRect = Rect.fromPoints(a, b);

    dragOffset = Offset.zero;
    dragType = DragType.none;
  }

  Rect getCurrentRect() {
    Rect result;
    switch (dragType) {
      case DragType.none:
        {
          result = canvasRect;
          break;
        }
      case DragType.body:
        {
          result = Rect.fromPoints(
            canvasRect.topLeft + dragOffset,
            canvasRect.bottomRight + dragOffset,
          );
          break;
        }
      case DragType.topHandle:
        {
          result = Rect.fromPoints(
            Offset(canvasRect.topLeft.dx, canvasRect.topLeft.dy + dragOffset.dy),
            canvasRect.bottomRight,
          );
          break;
        }
      case DragType.bottomHandle:
        {
          result = Rect.fromPoints(
            canvasRect.topLeft,
            Offset(canvasRect.bottomRight.dx, canvasRect.bottomRight.dy + dragOffset.dy),
          );
          break;
        }
    }
    return result;
  }

  @override
  String toString() {
    return 'PlannerEntry{day: $day, hour: $hour, minutes: $minutes, duration: $duration, minHour: $minHour, fillPaint: $fillPaint, strokePaint: $strokePaint, color: $color, title: $title, content: $content, canvasRect: $canvasRect, titlePainter: $titlePainter, contentPainter: $contentPainter, dragStartPos: $dragStartPos, dragOffset: $dragOffset, dragType: $dragType}';
  }
}
