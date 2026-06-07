import 'package:flutter/material.dart';
import 'package:planner/calendar.dart';
import 'package:planner/planner.dart';

import '../data.dart';
import '../widgets/all_day_chip.dart';
import '../widgets/day_header.dart';
import '../widgets/pop_block.dart';

/// The full showcase: every customization hook wired together on one screen
/// (#81). A [dayHeaderBuilder] row above an all-day band of [allDayEntryBuilder]
/// chips above an [entryBuilder] overlay of detail-shedding [PopBlock]s, with
/// zoom driven from the host's own [PlannerController] toolbar (the on-canvas
/// controls hidden via `showZoomControls: false`).
///
/// This is the relocated original single-screen demo; the gallery's other pages
/// break these same hooks out one at a time. Its [ValueKey]s (`pop-block-*`,
/// `pop-avatars-*`, `day-header-*`, `all-day-chip-*`, `demo-zoom-*`) and the
/// `Planner Demo` title are pinned by the integration suite.
class ShowcaseExample extends StatefulWidget {
  const ShowcaseExample({super.key});

  @override
  State<ShowcaseExample> createState() => _ShowcaseExampleState();
}

class _ShowcaseExampleState extends State<ShowcaseExample> {
  // Drives zoom from the host's own toolbar (#76). The built-in on-canvas
  // buttons are hidden via `showZoomControls: false` below, so this is the only
  // way to zoom besides pinch / Ctrl+wheel.
  final PlannerController _controller = PlannerController();

  // The week shown, snapped to its Monday. The `dayHeaderBuilder` closes over
  // this to turn a column index into its real date — the package itself stays
  // date-agnostic (ADR 0001), so no `DateTime` enters its API.
  final CalendarWindow _window = CalendarWindow.week(anchor: DateTime.now());

  // The entries are immutable (#27); a move replaces the matching one in place.
  List<PlannerEntry<ActivityMeta>> _entries = sampleEntries();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner Demo'),
        // The host's own zoom toolbar (#76). It listens to the controller so the
        // buttons disable once zoom hits a bound; the controller's read getters
        // throw before the planner has attached, so guard on `isAttached`.
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final atMin = _controller.isAttached &&
                  _controller.zoom <= _controller.minZoom;
              final atMax = _controller.isAttached &&
                  _controller.zoom >= _controller.maxZoom;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('demo-zoom-out'),
                    tooltip: 'Zoom out',
                    icon: const Icon(Icons.zoom_out),
                    onPressed: atMin ? null : _controller.zoomOut,
                  ),
                  IconButton(
                    key: const ValueKey('demo-zoom-in'),
                    tooltip: 'Zoom in',
                    icon: const Icon(Icons.zoom_in),
                    onPressed: atMax ? null : _controller.zoomIn,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Planner<ActivityMeta>(
        controller: _controller,
        config: PlannerConfig<ActivityMeta>(
          // Week-style headers, one label per column. The builder below ignores
          // the painted label and renders its own multi-part header instead.
          labels: _window.labels(),
          minHour: 0,
          maxHour: 23,
          // Hand zoom to the host toolbar above.
          showZoomControls: false,
          // Show the all-day band so the custom chips have somewhere to live.
          showAllDayBand: true,
          // Emphasize today's column ("today" style); null off-week.
          highlightedColumn: _window.todayColumn,
          onEntryMove: (entry) => setState(() {
            _entries = [
              for (final e in _entries) e.id == entry.id ? entry : e,
            ];
          }),
          onEntryEdit: (entry) => debugPrint('edit: ${entry.title}'),
          onEntryCreate: (time) => debugPrint(
              'create at day ${time.day} ${time.hour}:${time.minutes}'),
          onEntryDelete: (entry) => debugPrint('delete: ${entry.title}'),
          // Presentation-only: the host decides what a long-press does (#66).
          onEntryLongPress: (entry) => debugPrint('long-press: ${entry.title}'),
        ),
        entries: _entries,
        // #79 — a branded, multi-part header per column. It reads the real date
        // from the closed-over CalendarWindow; `isHighlighted` flags today.
        dayHeaderBuilder: (context, columnIndex, label, isHighlighted) =>
            DayHeader(
          key: ValueKey('day-header-$columnIndex'),
          date: _window.dateAt(columnIndex),
          highlighted: isHighlighted,
        ),
        // #78 — fully custom timed-event widgets, reading the typed `entry.data`
        // and shedding detail by on-screen pixel height.
        entryBuilder: (context, entry, layout) => PopBlock(
          key: ValueKey('pop-block-${entry.id}'),
          entry: entry,
          layout: layout,
        ),
        // #80 — fully custom all-day chips, same typed payload.
        allDayEntryBuilder: (context, entry, layout) => AllDayChip(
          key: ValueKey('all-day-chip-${entry.id}'),
          entry: entry,
        ),
      ),
    );
  }
}
