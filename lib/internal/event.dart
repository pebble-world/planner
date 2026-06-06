import 'package:flutter/material.dart';

import '../planner.dart';
import 'manager.dart';

enum DragType {
  body,
  topHandle,
  bottomHandle,
  none,
}

class Event {
  /// The entry this event draws. Reassigned (never mutated) when a drag/resize
  /// or nudge commits, since [PlannerEntry]/[PlannerTime] are immutable (#27):
  /// the new instance is what flows on to [PlannerConfig.onEntryMove].
  PlannerEntry entry;
  final Manager manager;

  /// The event's bounding rectangle in grid space — for a single-column event
  /// this is its drawn rect; for a spanning event it is the bounding box of all
  /// its [segmentRects]. Used for the accessibility node's rect and as the drag
  /// anchor (single-column events only).
  late Rect canvasRect;

  /// The rectangles actually drawn and hit-tested, in grid space. A
  /// single-column event has exactly one (`== canvasRect`); a spanning event
  /// (#47) has one per covered column — a single continuous box in
  /// [SpanOverlap.fullWidth], or one narrowed sub-column box per column in
  /// [SpanOverlap.split].
  late List<Rect> segmentRects;

  /// Per-column sub-column placement for a spanning event in
  /// [SpanOverlap.split], keyed by column index: which sub-column the event got
  /// in that column's overlap cluster and how many that column was split into.
  /// Empty for single-column events and for [SpanOverlap.fullWidth] spans (which
  /// draw across the full column width); [Manager] fills it during layout.
  final Map<int, ({int index, int count})> _spanColumns = {};

  late TextPainter _titlePainter;
  late TextPainter _contentPainter;
  late Paint _fillPaint, _draggedFillPaint;
  late Paint _strokePaint, _draggedStrokePaint;

  late Offset _dragStartPos;
  late Offset _dragOffset;
  late DragType _dragType = DragType.none;

  /// Which sub-column this event occupies within its day-column, and how many
  /// sub-columns the day-column is split into. They default to a single
  /// full-width column; [Manager] overwrites them with the day's overlap layout
  /// (#20 / PROJECT_OVERVIEW D11) and then calls [relayout].
  int columnIndex = 0;
  int columnCount = 1;

  Event({required this.entry, required this.manager}) {
    _createPaints();
    relayout();
  }

  /// Recomputes the geometry and text wrapping after [columnIndex]/[columnCount]
  /// (or, for a spanning event, its [_spanColumns] placement) change. [Manager]
  /// calls this once a day's overlap layout is known, so the event occupies its
  /// narrowed sub-column instead of the full day-column.
  void relayout() {
    _calculateCanvasRect();
    _layoutText();
  }

  /// Records the sub-column ([index] of [count]) this spanning event was given
  /// in [column]'s overlap cluster ([SpanOverlap.split]). [Manager] calls this
  /// per covered column while packing; [relayout] then rebuilds the geometry.
  void setSpanColumn(int column, int index, int count) =>
      _spanColumns[column] = (index: index, count: count);

  /// Clears any recorded span placement, so the next [relayout] draws the span
  /// at full column width ([SpanOverlap.fullWidth]). [Manager] calls this before
  /// re-laying out overlaps.
  void clearSpanColumns() => _spanColumns.clear();

  void _createPaints() {
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

  void _layoutText() {
    // Text wraps/ellipsizes within the event's actual (possibly narrowed) width,
    // not the full day-column, so a split event still reads correctly. For a
    // spanning event that is the start-column segment it renders in, not the
    // full multi-column bounding box.
    final width = segmentRects.first.width;

    _titlePainter = TextPainter(
      text: TextSpan(text: entry.title, style: entry.titleStyle),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: "...",
    );
    _titlePainter.layout(maxWidth: (width - 10).clamp(0.0, double.infinity));

    _contentPainter = TextPainter(
      text: TextSpan(text: entry.content, style: entry.textStyle),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 4,
      ellipsis: "...",
    );
    _contentPainter.layout(maxWidth: (width - 20).clamp(0.0, double.infinity));
  }

  void _calculateCanvasRect() {
    final config = manager.config;
    final blockHeight = config.blockHeight;
    final fullWidth = config.blockWidth.toDouble();
    final time = entry.time;

    // The vertical extent is the same whatever the column layout: the start
    // offset derives from blockHeight (not a hardcoded 40, D3) and the minute
    // offset is proportional (D4).
    final top = (time.hour - config.minHour) * blockHeight +
        time.minutes / 60 * blockHeight;
    final bottom = top + time.duration / 60 * blockHeight;

    if (!time.spansColumns) {
      // Single column: concurrent events share it by splitting into
      // [columnCount] equal sub-columns; this event sits in the [columnIndex]th.
      final columnWidth = fullWidth / columnCount;
      final left = time.day * fullWidth + columnIndex * columnWidth;
      canvasRect = Rect.fromLTRB(left, top, left + columnWidth, bottom);
      segmentRects = [canvasRect];
      return;
    }

    // Spanning event (#47). With no recorded placement ([SpanOverlap.fullWidth])
    // it draws as one continuous box across columns day..lastDay; otherwise
    // ([SpanOverlap.split]) it draws one rect per column, each narrowed to the
    // sub-column the day's overlap cluster assigned it.
    if (_spanColumns.isEmpty) {
      final left = time.day * fullWidth;
      final right = (time.lastDay + 1) * fullWidth;
      segmentRects = [Rect.fromLTRB(left, top, right, bottom)];
    } else {
      segmentRects = [
        for (int day = time.day; day <= time.lastDay; day++)
          _columnSegment(day, fullWidth, top, bottom),
      ];
    }
    canvasRect = segmentRects.reduce((a, b) => a.expandToInclude(b));
  }

  /// The sub-column rectangle for [day] in a split spanning event: narrowed to
  /// the placement the day's overlap cluster gave it, defaulting to the full
  /// column when the day carries no concurrent neighbours.
  Rect _columnSegment(int day, double fullWidth, double top, double bottom) {
    final placement = _spanColumns[day];
    final count = placement?.count ?? 1;
    final index = placement?.index ?? 0;
    final columnWidth = fullWidth / count;
    final left = day * fullWidth + index * columnWidth;
    return Rect.fromLTRB(left, top, left + columnWidth, bottom);
  }

  /// Whether [point] (grid space) falls inside any of this event's drawn
  /// rectangles — the hit-test primitive [Manager.getEventAtPos] uses. For a
  /// single-column event this is just [canvasRect]; for a spanning event it is
  /// any covered column's segment, so the event is reachable from any column it
  /// crosses.
  bool containsGridPoint(Offset point) =>
      segmentRects.any((rect) => rect.contains(point));

  /// Maps a rect from the grid's coordinate space to on-screen (canvas-local)
  /// coordinates, applying the current scroll offset and time-axis zoom. The
  /// single source of truth shared by [paint] and [screenRect].
  Rect _toScreen(Rect gridRect) {
    final offset = manager.controller.offset;
    final zoom = manager.controller.zoom;
    return Rect.fromPoints(
      Offset(offset.dx + gridRect.topLeft.dx,
          offset.dy + gridRect.topLeft.dy * zoom),
      Offset(offset.dx + gridRect.bottomRight.dx,
          offset.dy + gridRect.bottomRight.dy * zoom),
    );
  }

  /// This event's current on-screen rectangle — its grid rect (including any
  /// live drag offset) mapped through the controller's scroll/zoom. Used by
  /// [paint] to draw it and by the accessibility layer to place the event's
  /// semantics node (#21).
  Rect get screenRect => _toScreen(_getCurrentRect());

  /// A screen-reader description of this event — its title, day-column label,
  /// time span and duration — so the otherwise-opaque `CustomPaint` canvas
  /// exposes each event to assistive technology (#21). English-only for now,
  /// matching the (also unlocalized) context-menu strings.
  String get semanticsLabel {
    final time = entry.time;
    final labels = manager.config.labels;
    final dayLabel =
        (time.day >= 0 && time.day < labels.length) ? labels[time.day] : null;
    final start = _formatClock(time.hour, time.minutes);
    final endTotal = time.hour * 60 + time.minutes + time.duration;
    final end = _formatClock(endTotal ~/ 60, endTotal % 60);

    return [
      entry.title,
      if (dayLabel != null && dayLabel.isNotEmpty) dayLabel,
      '$start to $end',
      _formatDuration(time.duration),
    ].join(', ');
  }

  static String _formatClock(int hour, int minutes) =>
      '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

  static String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final parts = <String>[
      if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
      if (minutes > 0) '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
    ];
    return parts.isEmpty ? '0 minutes' : parts.join(' ');
  }

  void _paintHandle(Canvas canvas, Offset topLeft, double width) {
    Paint paint = Paint()
      ..color = _dragType == DragType.none ? entry.color : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Centre the handle within the event's own width so a split event's handles
    // stay inside its narrowed box (the 40px handle shrinks to fit if narrower).
    final handleWidth = width < 40 ? width : 40.0;
    Offset left = topLeft.translate((width - handleWidth) * 0.5, 0.0);
    Offset right = left.translate(handleWidth, 0.0);

    canvas.drawLine(
      Offset(manager.controller.offset.dx + left.dx,
          manager.controller.offset.dy + left.dy * manager.controller.zoom),
      Offset(manager.controller.offset.dx + right.dx,
          manager.controller.offset.dy + right.dy * manager.controller.zoom),
      paint,
    );
  }

  void paint(Canvas canvas) {
    final fillPaint =
        _dragType == DragType.none ? _fillPaint : _draggedFillPaint;
    final strokePaint =
        _dragType == DragType.none ? _strokePaint : _draggedStrokePaint;

    // Fill + stroke every segment. A single-column event has exactly one (its
    // live rect, carrying any drag offset); a spanning event has one per covered
    // column (#47) and never drags.
    final segments = _currentSegments();
    for (final segment in segments) {
      final screenSegment = _toScreen(segment);
      canvas.drawRect(screenSegment, fillPaint);
      canvas.drawRect(screenSegment, strokePaint);
    }

    // Resize handles are a drag/resize affordance; spanning events are read-only
    // in this first cut (#47), so only single-column events draw them.
    if (!entry.time.spansColumns) {
      final rect = segments.first;
      _paintHandle(canvas, rect.topLeft.translate(0.0, 1), rect.width);
      _paintHandle(canvas, rect.bottomLeft.translate(0.0, -1), rect.width);
    }

    // Title/content render in the start-column segment.
    final Rect screenRect = _toScreen(segments.first);
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

  /// The rectangles to draw this frame, in grid space. While a single-column
  /// event is being dragged its live rect carries the drag offset; otherwise
  /// every event uses its static [segmentRects] (a spanning event never drags,
  /// so it always does).
  List<Rect> _currentSegments() =>
      _dragType == DragType.none ? segmentRects : [_getCurrentRect()];

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
    final config = manager.config;
    final blockHeight = config.blockHeight;

    // Absolute minutes from minHour for an event edge at grid-y [y], snapped to
    // the configured interval — the same primitive create uses, so a dragged
    // edge lands on the same grid as a freshly created event.
    int minutesAt(double y) =>
        manager.snapToInterval((y / blockHeight * 60).round());

    // The models are immutable (#27): each branch computes the new time and
    // swaps in a fresh entry via copyWith rather than mutating in place. The new
    // instance is what Manager.endDrag reports to onEntryMove.
    final time = entry.time;
    switch (_dragType) {
      case DragType.body:
        // Move: the column snaps to the nearest day, the start time snaps to the
        // configured interval, and the duration is unchanged. The day shifts by
        // the horizontal drag in whole columns — measured from the current day,
        // not canvasRect.left, which now carries a sub-column offset when the
        // event is split across overlapping neighbours (#20).
        final day = time.day + (_dragOffset.dx / config.blockWidth).round();
        final start = minutesAt(canvasRect.top + _dragOffset.dy);
        entry = entry.copyWith(
          time: time.copyWith(
            day: day,
            hour: config.minHour + start ~/ 60,
            minutes: start % 60,
          ),
        );
        break;
      case DragType.topHandle:
        // Resize from the top: the bottom edge stays put, so the snapped start
        // time is absorbed by the duration.
        final bottom =
            (time.hour - config.minHour) * 60 + time.minutes + time.duration;
        final start = minutesAt(canvasRect.top + _dragOffset.dy);
        entry = entry.copyWith(
          time: time.copyWith(
            hour: config.minHour + start ~/ 60,
            minutes: start % 60,
            duration: bottom - start,
          ),
        );
        break;
      case DragType.bottomHandle:
        // Resize from the bottom: the start stays put, the bottom edge snaps.
        final start = (time.hour - config.minHour) * 60 + time.minutes;
        entry = entry.copyWith(
          time: time.copyWith(
            duration: minutesAt(canvasRect.bottom + _dragOffset.dy) - start,
          ),
        );
        break;
      case DragType.none:
        break;
    }

    _calculateCanvasRect();

    _dragOffset = Offset.zero;
    _dragType = DragType.none;
  }
}
