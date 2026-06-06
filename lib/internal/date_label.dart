import 'package:flutter/material.dart';

import 'manager.dart';

/// The top-left at which a date label of [textSize] is painted so it sits
/// centered within its day-column: horizontally across the column's
/// [blockWidth] (its left edge at [columnLeft], shifted by the current
/// horizontal scroll [scrollX]) and vertically within the [rowHeight]-tall date
/// row. Kept as a pure function so the centering math is unit-testable without a
/// canvas (#28 / PROJECT_OVERVIEW D12 — labels previously used a hardcoded `60`
/// left offset and a hardcoded `20` top offset and were not centered).
Offset centeredDateLabelOffset({
  required double scrollX,
  required double columnLeft,
  required double blockWidth,
  required double rowHeight,
  required Size textSize,
}) =>
    Offset(
      scrollX + columnLeft + (blockWidth - textSize.width) / 2,
      (rowHeight - textSize.height) / 2,
    );

class DateLabel {
  /// Left edge of this label's day-column, in the date-row's coordinate space.
  final double position;
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
    _tp.paint(
      canvas,
      centeredDateLabelOffset(
        scrollX: manager.controller.offset.dx,
        columnLeft: position,
        blockWidth: manager.config.blockWidth.toDouble(),
        rowHeight: manager.config.dateRowHeight,
        textSize: _tp.size,
      ),
    );
  }
}
