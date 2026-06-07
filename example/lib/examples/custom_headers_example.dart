import 'package:flutter/material.dart';
import 'package:planner/calendar.dart';
import 'package:planner/planner.dart';

import '../data.dart';
import '../widgets/day_header.dart';

/// Custom day/column headers (#79) over a real week.
///
/// The package stays date-agnostic — a `day` is just an index into
/// `config.labels` (ADR 0001) — so this page owns the `date ↔ column` mapping
/// with a [CalendarWindow] from `package:planner/calendar.dart`. The window
/// supplies the [PlannerConfig.labels] and the [PlannerConfig.highlightedColumn]
/// for "today", and the [Planner.dayHeaderBuilder] closes over it to recover
/// each column's [DateTime] and render the branded [DayHeader]. Events render in
/// the package's default style — the focus here is the header row.
class CustomHeadersExample extends StatelessWidget {
  const CustomHeadersExample({super.key});

  @override
  Widget build(BuildContext context) {
    // The current week, snapped to its Monday.
    final window = CalendarWindow.week(anchor: DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Custom headers')),
      body: Planner<ActivityMeta>(
        config: PlannerConfig<ActivityMeta>(
          labels: window.labels(),
          minHour: 0,
          maxHour: 23,
          // The window maps today to its column (null when today is off-week).
          highlightedColumn: window.todayColumn,
        ),
        entries: sampleEntries(),
        // Recover the real date for the column and render the branded header;
        // `isHighlighted` flags the today column above.
        dayHeaderBuilder: (context, columnIndex, label, isHighlighted) =>
            DayHeader(
          date: window.dateAt(columnIndex),
          highlighted: isHighlighted,
        ),
      ),
    );
  }
}
