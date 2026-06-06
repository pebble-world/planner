import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for D5 (#11): dragging an event used to be detected, applied
/// to the `Event`, and reported via `onEntryMove` *inside* `EventsPainter.paint()`.
/// Firing a host callback during paint is fragile — a host's `onEntryMove`
/// almost always updates state (`setState`), which is illegal mid-paint and
/// throws "setState() called during build". Drag now lives in the widget layer's
/// gesture handlers, so the same flow is safe.
///
/// This drives the *real* composed widget (real layout, real fonts, real
/// long-press recognition over the competing pan/scale recognizers) and uses a
/// stateful host whose `onEntryMove` rebuilds — exactly the pattern that crashed
/// on the old paint-side-effect code.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void dragScenarios() {
  testWidgets('long-press dragging an event moves it and fires onEntryMove',
      (tester) async {
    final moved = <PlannerEntry>[];

    await tester.pumpWidget(_DragHostApp(onMoved: moved.add));
    await tester.pumpAndSettle();

    // The single event sits at day 0 / hour 4 -> grid rect (0,160)-(200,200)
    // with the default 200x40 blocks. On screen it is offset by the hour column
    // (50) and date row (50); its centre is therefore at planner-local (150, 230)
    // — a body drag, clear of the 8px handle zones at the top/bottom edges.
    final center =
        tester.getRect(find.byType(Planner)).topLeft + const Offset(150, 230);

    // Drag down exactly one block (40px == 1 hour): hour 4 -> hour 5.
    await longPressDrag(tester, center, const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'the move callback must not fire during paint');
    expect(moved, hasLength(1), reason: 'the drag committed exactly one move');
    expect(moved.single.id, 'evt');
    expect(moved.single.time.day, 0);
    expect(moved.single.time.hour, 5,
        reason: 'a one-block drag advances the event one hour');
  });
}

/// A minimal real app hosting one [Planner], whose [onEntryMove] both records the
/// move and rebuilds via [setState] — the everyday host pattern that exposed the
/// old paint-phase callback bug.
class _DragHostApp extends StatefulWidget {
  const _DragHostApp({required this.onMoved});

  final void Function(PlannerEntry) onMoved;

  @override
  State<_DragHostApp> createState() => _DragHostAppState();
}

class _DragHostAppState extends State<_DragHostApp> {
  final List<PlannerEntry> _entries = [
    PlannerEntry(
      id: 'evt',
      time: PlannerTime(day: 0, hour: 4),
      title: 'Drag me',
      content: '',
      color: const Color(0xFF2244AA),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            onEntryMove: (entry) => setState(() => widget.onMoved(entry)),
          ),
          entries: _entries,
        ),
      ),
    );
  }
}
