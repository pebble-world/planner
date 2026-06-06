import 'package:flutter/material.dart';

import 'manager.dart';

/// The top-left at which an hour label of [textSize] is painted so it sits
/// centered within the hour column: horizontally across [hourColumnWidth] and
/// vertically within its hour-row band. The band is the row's grid [rowTop]
/// mapped through the current scroll ([scrollY]) and [zoom] — the band is
/// `blockHeight * zoom` px tall, so the label stays centered in the row as the
/// time axis zooms. Kept as a pure function so the centering math is
/// unit-testable without a canvas (#28 / PROJECT_OVERVIEW D12 — labels
/// previously used a hardcoded `15` left offset and were not centered).
Offset centeredHourLabelOffset({
  required double scrollY,
  required double rowTop,
  required double hourColumnWidth,
  required double blockHeight,
  required double zoom,
  required Size textSize,
}) =>
    Offset(
      (hourColumnWidth - textSize.width) / 2,
      scrollY + rowTop * zoom + (blockHeight * zoom - textSize.height) / 2,
    );

class HourLabel {
  /// Top edge of this label's hour-row, in grid coordinates (pre-scroll/zoom).
  final double position;
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
    _tp.paint(
      canvas,
      centeredHourLabelOffset(
        scrollY: manager.controller.offset.dy,
        rowTop: position,
        hourColumnWidth: manager.config.hourColumnWidth,
        blockHeight: manager.config.blockHeight.toDouble(),
        zoom: manager.controller.zoom,
        textSize: _tp.size,
      ),
    );
  }
}
