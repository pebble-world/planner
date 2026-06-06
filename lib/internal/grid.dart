import 'package:flutter/material.dart';

import 'line.dart';
import 'manager.dart';

class Grid {
  final Manager manager;

  late Paint hPaint, vPaint;

  // The half-hour and quarter-hour line paints fade in with zoom; their colour
  // is a pure function of the current zoom, so they're cached and only
  // recoloured when the zoom changes rather than reallocated every frame
  // (#25 / D7).
  final Paint div2Paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint div3Paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  double _cachedZoom = double.nan;

  final List<Line> hLines = [];
  final List<Line> vLines = [];

  // Optional "today"-style column emphasis (#46). When the host sets a valid
  // [PlannerConfig.highlightedColumn] we fill that column behind the grid lines
  // and events. Resolved once here (index + Paint) rather than per frame; both
  // stay null when nothing is highlighted or the index is out of range, so
  // [draw] skips the highlight entirely.
  int? highlightColumn;
  Paint? highlightPaint;

  Grid({required this.manager}) {
    final config = manager.config;
    final highlighted = config.highlightedColumn;
    if (highlighted != null &&
        highlighted >= 0 &&
        highlighted < config.labels.length) {
      highlightColumn = highlighted;
      highlightPaint = Paint()
        ..color = config.highlightColumnColor
        ..style = PaintingStyle.fill;
    }

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
    // The highlighted column is filled first so the grid lines and events draw
    // on top of it (it emphasizes the column without obscuring its content).
    _drawHighlight(canvas);

    // vertical lines can be drawn instantly
    for (var line in vLines) {
      line.draw(canvas, vPaint);
    }

    // The 30-minute lines fade in past zoom 1, the 15/45-minute lines past
    // zoom 2. These thresholds are cheap to recompute each frame and also gate
    // line visibility below.
    final double zoom = manager.controller.zoom;
    final double color2 = (zoom - 1).clamp(0.0, 1.0).toDouble();
    final double color3 = (zoom - 2).clamp(0.0, 1.0).toDouble();

    // Recolour the cached paints only when the zoom actually changed, reusing
    // the same Paint objects across frames instead of allocating two per frame
    // (#25 / D7).
    if (zoom != _cachedZoom) {
      div2Paint.color = Color.fromARGB((color2 * 60).toInt(), 255, 255, 255);
      div3Paint.color = Color.fromARGB((color3 * 30).toInt(), 255, 255, 255);
      _cachedZoom = zoom;
    }

    // draw lines
    for (int i = 0; i < hLines.length; i++) {
      if ((i + 1) % 4 == 0) {
        // hour
        hLines[i].draw(canvas, vPaint);
      } else if ((i + 1) % 2 == 0 && color2 != 0) {
        // half an hour
        hLines[i].draw(canvas, div2Paint);
      } else if (color3 != 0) {
        // 15 and 45 minutes
        hLines[i].draw(canvas, div3Paint);
      }
    }
  }

  // Fills the highlighted column (if any) across the full hour range. The rect
  // is mapped through the controller's scroll [offset] and time-axis [zoom] the
  // same way the grid lines are (see [Line.draw]), so the highlight tracks the
  // column as the user pans/zooms. A no-op when no column is highlighted.
  void _drawHighlight(Canvas canvas) {
    final column = highlightColumn;
    final paint = highlightPaint;
    if (column == null || paint == null) return;

    final config = manager.config;
    final offset = manager.controller.offset;
    final zoom = manager.controller.zoom;
    final blockWidth = config.blockWidth.toDouble();
    final gridHeight =
        config.blockHeight.toDouble() * (config.maxHour - config.minHour + 1);

    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx + column * blockWidth,
        offset.dy,
        blockWidth,
        gridHeight * zoom,
      ),
      paint,
    );
  }
}
