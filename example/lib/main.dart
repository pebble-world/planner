import 'package:example/data.dart';
import 'package:flutter/material.dart';
import 'package:planner/calendar.dart';
import 'package:planner/planner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MyHomePage(title: 'Planner Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
        title: Text(widget.title),
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
            _DayHeader(
          key: ValueKey('day-header-$columnIndex'),
          date: _window.dateAt(columnIndex),
          highlighted: isHighlighted,
        ),
        // #78 — fully custom timed-event widgets, reading the typed `entry.data`
        // and shedding detail by on-screen pixel height.
        entryBuilder: _buildPopBlock,
        // #80 — fully custom all-day chips, same typed payload.
        allDayEntryBuilder: _buildAllDayChip,
      ),
    );
  }

  /// The "Pop Block" (#78): a fully custom timed-event widget that reads the
  /// typed [PlannerEntry.data] (#77) and **sheds detail by pixel height** —
  /// `layout.size.height` is the event's live on-screen height, so as you zoom
  /// the same event reveals more. Thresholds: place ≥52, status ≥56, time ≥60,
  /// avatar stack ≥92.
  Widget _buildPopBlock(
    BuildContext context,
    PlannerEntry<ActivityMeta> entry,
    PlannerEntryLayout layout,
  ) =>
      _PopBlock(
        key: ValueKey('pop-block-${entry.id}'),
        entry: entry,
        layout: layout,
      );

  /// A fully custom all-day chip (#80). Reuses the typed payload for its accent
  /// colour; `layout.allDay` is `true` here, so a single builder wired to both
  /// hooks could branch on it instead.
  Widget _buildAllDayChip(
    BuildContext context,
    PlannerEntry<ActivityMeta> entry,
    PlannerEntryLayout layout,
  ) {
    final accent = entry.data?.type.color ?? entry.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        key: ValueKey('all-day-chip-${entry.id}'),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A branded, multi-part day/column header (#79): the weekday in a small caps
/// style above a large day number, tinted when it's today. Built from a real
/// `DateTime` the host recovered from its `CalendarWindow`.
class _DayHeader extends StatelessWidget {
  const _DayHeader({super.key, required this.date, required this.highlighted});

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

/// The Pop Block widget itself: a dark card with a type-coloured left bar and a
/// hard-offset shadow, revealing more of the entry's metadata as it grows.
class _PopBlock extends StatelessWidget {
  const _PopBlock({super.key, required this.entry, required this.layout});

  final PlannerEntry<ActivityMeta> entry;
  final PlannerEntryLayout layout;

  @override
  Widget build(BuildContext context) {
    final meta = entry.data;
    final h = layout.size.height;
    final accent = meta?.type.color ?? entry.color;

    final showPlace = h >= 52 && (meta?.place.isNotEmpty ?? false);
    final showStatus = h >= 56 && (meta?.status.isNotEmpty ?? false);
    final showTime = h >= 60;
    final showAvatars = h >= 92 && (meta?.attendees.isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2430),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), offset: Offset(3, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The type-coloured left bar.
              Container(width: 4, color: accent),
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: double.infinity,
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (showStatus)
                                _StatusBadge(text: meta!.status, color: accent),
                            ],
                          ),
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 11, color: Colors.white60),
                                  const SizedBox(width: 3),
                                  Text(
                                    _timeRange(entry.time),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (showPlace)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                meta!.place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          if (showAvatars)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _AvatarStack(
                                key: ValueKey('pop-avatars-${entry.id}'),
                                initials: meta!.attendees,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `HH:MM–HH:MM` for the entry's start and computed end time.
  static String _timeRange(PlannerTime time) {
    String hhmm(int totalMinutes) {
      final h = (totalMinutes ~/ 60) % 24;
      final m = totalMinutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    final start = time.hour * 60 + time.minutes;
    return '${hhmm(start)}–${hhmm(start + time.duration)}';
  }
}

/// A small status pill shown once the card clears the 56px tier.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The attendee avatar stack, shown only in the tallest (≥92px) tier.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({super.key, required this.initials});

  final List<String> initials;

  @override
  Widget build(BuildContext context) {
    const maxShown = 3;
    final shown = initials.take(maxShown).toList();
    final extra = initials.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final i in shown)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _avatar(i, const Color(0xFF3A7BD5)),
          ),
        if (extra > 0) _avatar('+$extra', const Color(0xFF55607A)),
      ],
    );
  }

  Widget _avatar(String text, Color color) => Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 7),
        ),
      );
}
