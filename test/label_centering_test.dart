import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/date_label.dart';
import 'package:planner/internal/hour_label.dart';

void main() {
  // Regression for D12 (#28): date/hour labels used hardcoded offsets (60/15)
  // and weren't centered in their columns. The painted text lives on a
  // CustomPaint canvas (not in the widget/semantics tree), so the centering math
  // is extracted into these pure helpers and tested directly with synthetic text
  // sizes — font-independent and assertable without a canvas.

  group('centeredDateLabelOffset', () {
    test('centers the text within its day-column (h) and the date row (v)', () {
      final offset = centeredDateLabelOffset(
        scrollX: 0,
        columnLeft:
            50, // first column starts at hourColumnWidth, not a magic 60
        blockWidth: 200,
        rowHeight: 50,
        textSize: const Size(40, 16),
      );

      expect(offset.dx, 50 + (200 - 40) / 2, reason: 'centered in the column');
      expect(offset.dy, (50 - 16) / 2, reason: 'centered in the date row');
    });

    test('applies the horizontal scroll offset to the column position', () {
      final offset = centeredDateLabelOffset(
        scrollX: -120,
        columnLeft: 50,
        blockWidth: 200,
        rowHeight: 50,
        textSize: const Size(40, 16),
      );

      expect(offset.dx, -120 + 50 + (200 - 40) / 2);
    });
  });

  group('centeredHourLabelOffset', () {
    test('centers horizontally in the hour column and vertically in the row',
        () {
      final offset = centeredHourLabelOffset(
        scrollY: 0,
        rowTop: 40, // grid-space top of the second hour row
        hourColumnWidth: 50,
        blockHeight: 40,
        zoom: 1,
        textSize: const Size(14, 16),
      );

      expect(offset.dx, (50 - 14) / 2, reason: 'centered in the hour column');
      expect(offset.dy, 40 + (40 - 16) / 2,
          reason: 'centered in the (zoom 1) hour-row band');
    });

    test('the row band grows with zoom so the label stays centered', () {
      final offset = centeredHourLabelOffset(
        scrollY: 0,
        rowTop: 40,
        hourColumnWidth: 50,
        blockHeight: 40,
        zoom: 2,
        textSize: const Size(14, 16),
      );

      // rowTop and the band both scale by zoom: 40*2 + (40*2 - 16)/2.
      expect(offset.dy, 40 * 2 + (40 * 2 - 16) / 2);
    });

    test('applies the vertical scroll offset', () {
      final offset = centeredHourLabelOffset(
        scrollY: -100,
        rowTop: 0,
        hourColumnWidth: 50,
        blockHeight: 40,
        zoom: 1,
        textSize: const Size(14, 16),
      );

      expect(offset.dy, -100 + (40 - 16) / 2);
    });
  });
}
