import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../data.dart';

/// The get-it-running example: a minimal [Planner] with the **default** look.
///
/// Plain [PlannerEntry]s (no typed `data`, no custom builders) over a Mon–Fri
/// set of column labels — the package paints the titles, times, grid and
/// all-day chips itself, so the only styling is each entry's
/// [PlannerEntry.color]. The `onEntry*` callbacks are wired so a drag commits a
/// move (entries are immutable, #27) and the other interactions log.
///
/// This is the smallest amount of code that gives you a working planner; every
/// other gallery page layers one feature on top of it.
class BasicExample extends StatefulWidget {
  const BasicExample({super.key});

  @override
  State<BasicExample> createState() => _BasicExampleState();
}

class _BasicExampleState extends State<BasicExample> {
  // Immutable entries (#27): a move replaces the matching one in place.
  List<PlannerEntry> _entries = basicEntries();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic')),
      body: Planner(
        config: PlannerConfig(
          labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          minHour: 7,
          maxHour: 19,
          // Enable the band so the single all-day entry has somewhere to show,
          // still with the package's default (painted) chip — no custom builder.
          showAllDayBand: true,
          onEntryMove: (entry) => setState(() {
            _entries = [
              for (final e in _entries) e.id == entry.id ? entry : e,
            ];
          }),
          onEntryEdit: (entry) => debugPrint('edit: ${entry.title}'),
          onEntryCreate: (time) => debugPrint(
              'create at day ${time.day} ${time.hour}:${time.minutes}'),
          onEntryDelete: (entry) => debugPrint('delete: ${entry.title}'),
        ),
        entries: _entries,
      ),
    );
  }
}
