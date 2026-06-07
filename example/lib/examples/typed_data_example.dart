import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../data.dart';
import '../widgets/pop_block.dart';

/// Typed payloads (#77) + a custom timed-event widget (#78).
///
/// The entries are `PlannerEntry<ActivityMeta>`, so each carries an app-domain
/// [ActivityMeta] on `entry.data` that the package threads through untouched.
/// The [Planner.entryBuilder] reads it back **already typed** — no cast, no
/// side-map keyed by id — to render the [PopBlock], a card that sheds detail by
/// its on-screen pixel height. Zoom in (pinch / Ctrl+wheel / the on-canvas
/// buttons) and watch the small cards reveal place, status, time, then the
/// attendee avatar stack as they grow.
class TypedDataExample extends StatefulWidget {
  const TypedDataExample({super.key});

  @override
  State<TypedDataExample> createState() => _TypedDataExampleState();
}

class _TypedDataExampleState extends State<TypedDataExample> {
  // Immutable entries (#27): a move replaces the matching one in place.
  List<PlannerEntry<ActivityMeta>> _entries = sampleEntries();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Typed data + entryBuilder')),
      body: Planner<ActivityMeta>(
        config: PlannerConfig<ActivityMeta>(
          labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          minHour: 0,
          maxHour: 23,
          onEntryMove: (entry) => setState(() {
            _entries = [
              for (final e in _entries) e.id == entry.id ? entry : e,
            ];
          }),
          onEntryEdit: (entry) => debugPrint('edit: ${entry.title}'),
        ),
        entries: _entries,
        // The typed payload comes back without a cast (#77/#78).
        entryBuilder: (context, entry, layout) =>
            PopBlock(entry: entry, layout: layout),
      ),
    );
  }
}
