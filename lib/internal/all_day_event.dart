import 'package:flutter/material.dart';

import '../planner.dart';
import 'manager.dart';

/// Vertical inset above the first lane and below the last — the gap between the
/// band's chips and its top/bottom edge. The band's total height is
/// `laneCount * laneHeight + 2 * allDayBandVerticalPadding`.
const double allDayBandVerticalPadding = 2.0;

/// Inset applied to every chip inside its lane/column cell, so adjacent chips
/// (and stacked lanes) read as separate boxes rather than a solid block.
const double allDayChipInset = 2.0;

/// A single all-day event (#48) rendered as a chip in the all-day band above the
/// time grid. Unlike a timed [Event] it is not positioned by hour/minute: it
/// occupies the columns `entry.time.day..entry.time.lastDay` (so a multi-day
/// all-day event spans columns the same index-based way #47 events do) and the
/// [lane] it was packed into (concurrent all-day events stack into separate
/// lanes — see [Manager]'s all-day layout).
///
/// Interactive at parity with timed events (#72): a chip is hit-tested
/// ([Manager.getAllDayEventAtPos]) so it can be edited (double-tap), acted on
/// via the context menu (right-click) or [PlannerConfig.onEntryLongPress], and
/// it carries an accessibility node ([AllDayBand]) with edit/delete actions. It
/// is still not draggable/resizable — moving between columns or converting
/// to/from a timed event is out of scope (#72). Geometry tracks only the
/// horizontal scroll ([Controller.offset]'s `dx`) — the band is a fixed header
/// strip, so it neither zooms nor scrolls with the time axis.
class AllDayEvent<T> {
  final PlannerEntry<T> entry;
  final Manager<T> manager;

  /// Which stacked lane (row) within the band this chip occupies. Lane 0 is the
  /// topmost; [Manager] assigns it by first-fit packing on the column axis.
  final int lane;

  late final TextPainter _titlePainter;
  late final Paint _fillPaint, _strokePaint;

  AllDayEvent(
      {required this.entry, required this.manager, required this.lane}) {
    _fillPaint = Paint()
      ..color = entry.color.withAlpha(100)
      ..style = PaintingStyle.fill;
    _strokePaint = Paint()
      ..color = entry.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Lay the title out once, ellipsized to the chip's (scroll-independent)
    // width, so painting is allocation-free.
    final width = _gridRect.width;
    _titlePainter = TextPainter(
      text: TextSpan(text: entry.title, style: entry.titleStyle),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: (width - 10).clamp(0.0, double.infinity));
  }

  /// The chip rectangle in the band's own coordinate space (no horizontal
  /// scroll applied): spans columns `day..lastDay` horizontally and sits in its
  /// [lane] vertically, inset on every side by [allDayChipInset].
  ///
  /// The band canvas spans the full planner width (it sits above the hour column
  /// too, like the date row), so each column's left edge is offset by the hour
  /// column's width to line up with the event grid below — the same `pos`
  /// convention `DateRow`/`DateLabel` use.
  Rect get _gridRect {
    final config = manager.config;
    final blockWidth = config.blockWidth.toDouble();
    final laneHeight = config.allDayBandLaneHeight;
    final time = entry.time;

    final columnLeft = config.hourColumnWidth + time.day * blockWidth;
    final left = columnLeft + allDayChipInset;
    final right = columnLeft + time.columnSpan * blockWidth - allDayChipInset;
    final top = allDayBandVerticalPadding + lane * laneHeight + allDayChipInset;
    final bottom = top + laneHeight - 2 * allDayChipInset;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// The chip's on-screen rectangle: its [_gridRect] shifted by the current
  /// horizontal scroll only (the band doesn't move vertically or zoom). Exposed
  /// so tests can assert placement without scraping the canvas, and used to
  /// hit-test the chip ([Manager.getAllDayEventAtPos]) and to place its
  /// accessibility node ([AllDayBand]).
  Rect get screenRect => _gridRect.translate(manager.controller.offset.dx, 0);

  /// A screen-reader description of this chip — its title, the column label(s)
  /// it covers, and that it is an all-day event (#72). Mirrors
  /// [Event.semanticsLabel] but carries no time span: an all-day event isn't
  /// hour-positioned. A multi-day chip reads its first..last column labels (e.g.
  /// "Conference, Mon to Wed, all day"). English-only for now, matching the
  /// (also unlocalized) timed-event label and context-menu strings.
  String get semanticsLabel {
    final labels = manager.config.labels;
    final time = entry.time;
    String? labelAt(int i) =>
        (i >= 0 && i < labels.length && labels[i].isNotEmpty)
            ? labels[i]
            : null;

    final start = labelAt(time.day);
    final end = labelAt(time.lastDay);
    final String? dayPart;
    if (time.spansColumns && start != null && end != null) {
      dayPart = '$start to $end';
    } else {
      dayPart = start ?? end;
    }

    return [
      entry.title,
      if (dayPart != null) dayPart,
      'all day',
    ].join(', ');
  }

  void paint(Canvas canvas) {
    final rect = screenRect;
    canvas.drawRect(rect, _fillPaint);
    canvas.drawRect(rect, _strokePaint);

    canvas.save();
    canvas.clipRect(rect);
    // Left-pad the text and centre it vertically within the chip.
    final textTop = rect.top + (rect.height - _titlePainter.height) / 2;
    _titlePainter.paint(canvas, Offset(rect.left + 5, textTop));
    canvas.restore();
  }
}
