import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../data.dart';
import '../widgets/all_day_chip.dart';

/// The all-day band (#48) with fully custom chips (#80).
///
/// Setting [PlannerConfig.showAllDayBand] to `true` opts the band in: it appears
/// above the time grid whenever there is at least one [PlannerTime.allDay]
/// entry, and its chips become interactive and accessible. The
/// [Planner.allDayEntryBuilder] then replaces the painted chips with the custom
/// [AllDayChip] pills, reusing the same typed [ActivityMeta] payload (#77) for
/// their accent colour. Timed events keep the package's default rendering, so
/// the band is the star.
class AllDayExample extends StatefulWidget {
  const AllDayExample({super.key});

  @override
  State<AllDayExample> createState() => _AllDayExampleState();
}

class _AllDayExampleState extends State<AllDayExample> {
  // Immutable entries (#27): a move replaces the matching one in place.
  List<PlannerEntry<ActivityMeta>> _entries = sampleEntries();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All-day band')),
      body: Planner<ActivityMeta>(
        config: PlannerConfig<ActivityMeta>(
          labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          minHour: 0,
          maxHour: 23,
          // Opt the band in (#48); it appears once there's an all-day entry.
          showAllDayBand: true,
          onEntryMove: (entry) => setState(() {
            _entries = [
              for (final e in _entries) e.id == entry.id ? entry : e,
            ];
          }),
        ),
        entries: _entries,
        // Fully custom chips for the band (#80); timed events stay default.
        allDayEntryBuilder: (context, entry, layout) =>
            AllDayChip(entry: entry),
      ),
    );
  }
}
