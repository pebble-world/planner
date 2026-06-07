import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

/// A branded, multi-part day/column header for a [Planner.dayHeaderBuilder]
/// (#79): the weekday in a small-caps style above a large day number, tinted
/// when it's today.
///
/// The package stays date-agnostic (ADR 0001) — its builder hands back only a
/// column index, label and `isHighlighted` flag — so the host recovers the real
/// [DateTime] from its own `CalendarWindow` and passes it here for display.
///
/// Shared across the custom-headers and showcase example pages.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.date, required this.highlighted});

  final DateTime date;
  final bool highlighted;

  static const _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? Colors.white : Colors.black87;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF3A7BD5) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      // OverflowBox + ClipRect lets the stacked text lay out at its natural
      // height and be trimmed rather than throw an overflow when a cell is short
      // (mirrors how the package lays the header row out).
      child: ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdays[date.weekday - 1],
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: highlighted ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
