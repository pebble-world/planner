import 'package:flutter/material.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

enum DragType {
  body,
  topHandle,
  bottomHandle,
  none,
}

class Event {
  final PlannerEntry entry;
  final Manager manager;

  late Rect canvasRect;
  late TextPainter _titlePainter;
  late TextPainter _contentPainter;
  late Paint _fillPaint, _draggedFillPaint;
  late Paint _strokePaint, _draggedStrokePaint;

  late Offset _dragStartPos;
  late Offset _dragOffset;
  late DragType _dragType = DragType.none;

  Event({required this.entry, required this.manager}) {
    _createPainters();
  }

  static Paint _linePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  void _createPainters() {
    _calculateCanvasRect();

    _titlePainter = TextPainter(
      text: TextSpan(text: entry.title, style: entry.titleStyle),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: "...",
    );
    _titlePainter.layout(maxWidth: manager.config.blockWidth - 10);

    _contentPainter = TextPainter(
      text: TextSpan(text: entry.content, style: entry.textStyle),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 4,
      ellipsis: "...",
    );
    _contentPainter.layout(maxWidth: manager.config.blockWidth - 20);

    _fillPaint = Paint()
      ..color = entry.color.withAlpha(100)
      ..style = PaintingStyle.fill;
    _strokePaint = Paint()
      ..color = entry.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _draggedFillPaint = Paint()
      ..color = entry.color
      ..style = PaintingStyle.fill;
    _draggedStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
  }

  void _calculateCanvasRect() {
    Offset a = Offset(
        (entry.time.day * manager.config.blockWidth).toDouble(),
        (entry.time.hour - manager.config.minHour) *
                manager.config.blockHeight +
            ((entry.time.minutes / 15).round() * 10.0));
    Offset b = a.translate(
        manager.config.blockWidth.toDouble(), entry.time.duration / 60 * 40.0);
    canvasRect = Rect.fromPoints(a, b);
  }

  void _paintHandle(Canvas canvas, Offset topLeft) {
    Paint paint = Paint()
      ..color =
          _dragType == DragType.none ? entry.color.withAlpha(255) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    Offset left = topLeft.translate(manager.config.blockWidth * 0.5 - 20, 0.0);
    Offset right = left.translate(40.0, 0.0);

    canvas.drawLine(
      Offset(manager.controller.offset.dx + left.dx,
          manager.controller.offset.dy + left.dy * manager.controller.zoom),
      Offset(manager.controller.offset.dx + right.dx,
          manager.controller.offset.dy + right.dy * manager.controller.zoom),
      paint,
    );
  }

  void paint(Canvas canvas) {
    Rect rect = _getCurrentRect();
    Rect screenRect = Rect.fromPoints(
      Offset(
          manager.controller.offset.dx + rect.topLeft.dx,
          manager.controller.offset.dy +
              rect.topLeft.dy * manager.controller.zoom),
      Offset(
          manager.controller.offset.dx + rect.bottomRight.dx,
          manager.controller.offset.dy +
              rect.bottomRight.dy * manager.controller.zoom),
    );

    canvas.drawRect(screenRect,
        _dragType == DragType.none ? _fillPaint : _draggedFillPaint);
    canvas.drawRect(screenRect,
        _dragType == DragType.none ? _strokePaint : _draggedStrokePaint);

    _paintHandle(canvas, rect.topLeft.translate(0.0, 1));
    _paintHandle(canvas, rect.bottomLeft.translate(0.0, -1));

    Rect clipRect = Rect.fromPoints(
        screenRect.topLeft.translate(2,
            entry.titleStyle.fontSize != null ? entry.titleStyle.fontSize! : 8),
        screenRect.bottomRight.translate(
            -2,
            entry.titleStyle.fontSize != null
                ? -entry.titleStyle.fontSize!
                : -8));

    canvas.save();
    canvas.clipRect(clipRect);
    Offset cpos = screenRect.topLeft;
    cpos = cpos.translate(5.0, 10.0);
    _titlePainter.paint(canvas, cpos);
    cpos = cpos.translate(0.0, 15.0);
    _contentPainter.paint(canvas, cpos);
    canvas.restore();
  }

  Rect _getCurrentRect() {
    Rect result;
    switch (_dragType) {
      case DragType.body:
        {
          result = Rect.fromPoints(canvasRect.topLeft + _dragOffset,
              canvasRect.bottomRight + _dragOffset);
          break;
        }
      case DragType.topHandle:
        {
          result = Rect.fromPoints(
              Offset(canvasRect.topLeft.dx,
                  canvasRect.topLeft.dy + _dragOffset.dy),
              canvasRect.bottomRight);
          break;
        }
      case DragType.bottomHandle:
        {
          result = Rect.fromPoints(
            canvasRect.topLeft,
            Offset(canvasRect.bottomRight.dx,
                canvasRect.bottomRight.dy + _dragOffset.dy),
          );
          break;
        }
      default:
        {
          result = canvasRect;
          break;
        }
    }
    return result;
  }

  void startDrag(Offset pos) {
    if ((pos.dy - canvasRect.top).abs() < 8) {
      _dragType = DragType.topHandle;
    } else if ((pos.dy - canvasRect.bottom).abs() < 8) {
      _dragType = DragType.bottomHandle;
    } else {
      _dragType = DragType.body;
    }
    _dragStartPos = pos;
    _dragOffset = Offset.zero;
  }

  void updateDrag(Offset pos) {
    _dragOffset = pos - _dragStartPos;
  }

  void endDrag() {
    if (_dragType == DragType.body) {
      int newDay =
          ((canvasRect.topLeft.dx + _dragOffset.dx) / manager.config.blockWidth)
              .round();
      double newHour = ((canvasRect.topLeft.dy + _dragOffset.dy) /
              manager.config.blockHeight) +
          manager.config.minHour;
      entry.time.day = newDay;
      entry.time.hour = newHour.floor();
      entry.time.minutes = ((newHour - newHour.floor()) * 60).floor();
    } else if (_dragType == DragType.topHandle) {
      double newHour = (((canvasRect.topLeft.dy + _dragOffset.dy) /
                      manager.config.blockHeight)
                  .round() +
              manager.config.minHour)
          .toDouble();
      int newMinutes =
          _roundedMinutes(((newHour - newHour.floor()) * 60).floor());
      entry.time.duration += ((entry.time.hour - newHour.floor()) * 60) -
          (newMinutes - entry.time.minutes);
      entry.time.hour = newHour.floor();
      entry.time.minutes = newMinutes;
    } else if (_dragType == DragType.bottomHandle) {
      entry.time.duration +=
          (_dragOffset.dy / (manager.config.blockHeight * 0.25)).round() * 15;
      entry.time.duration = _roundedMinutes(entry.time.duration);
    }

    _calculateCanvasRect();

    _dragOffset = Offset.zero;
    _dragType = DragType.none;
  }

  int _roundedMinutes(int minutes) {
    if (manager.controller.zoom <= 1) {
      return (minutes ~/ 30) * 30;
    } else if (manager.controller.zoom <= 2) {
      return (minutes ~/ 15) * 15;
    } else if (manager.controller.zoom < 3) {
      return (minutes ~/ 5) * 5;
    } else {
      return minutes;
    }
  }
}
