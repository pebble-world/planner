import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

/// End-to-end guard for #40: the double-tap edit/create paths were dead.
///
/// The `PositionedTapDetector2` that owns `onDoubleTap` wrapped the events
/// `GestureDetector`, whose own `onTap` won the gesture arena — so the parent's
/// tap stream was never fed and `onDoubleTap` never resolved. The detector is
/// now driven from the single events detector through its controller, so a real
/// double-tap reaches `onEntryEdit` / `onEntryCreate`.
///
/// This drives the *real* composed widget (real layout, real fonts, real tap
/// recognition over the competing drag/scale/long-press recognizers) with two
/// genuine taps inside the detector's double-tap window.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void doubleTapScenarios() {
  // Two quick taps at the same point, within the detector's 250ms double-tap
  // window. The first tap is buffered on a stream and only resolves a
  // double-tap once the second arrives in time, so the gap stays well under the
  // window; the trailing pump past it flushes the (now no-op) timeout timer.
  Future<void> doubleTapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('double-tapping an event fires onEntryEdit', (tester) async {
    final edited = <PlannerEntry>[];
    final created = <PlannerTime>[];

    await tester.pumpWidget(
        _DoubleTapHostApp(onEdit: edited.add, onCreate: created.add));
    await tester.pumpAndSettle();

    // The single event sits at day 0 / hour 9 -> grid rect (0,360)-(200,400)
    // with the default 200x40 blocks. On screen it is offset by the hour column
    // (50) and date row (50); its centre is therefore at planner-local (150, 430).
    final center =
        tester.getRect(find.byType(Planner)).topLeft + const Offset(150, 430);
    await doubleTapAt(tester, center);

    expect(edited, hasLength(1),
        reason: 'double-tapping an event must fire onEntryEdit');
    expect(edited.single.id, 'evt',
        reason: 'onEntryEdit receives the double-tapped entry');
    expect(created, isEmpty,
        reason: 'a hit on an event edits it, it does not create');
  });

  testWidgets('double-tapping empty grid fires onEntryCreate', (tester) async {
    final created = <PlannerTime>[];
    final edited = <PlannerEntry>[];

    await tester.pumpWidget(
        _DoubleTapHostApp(onEdit: edited.add, onCreate: created.add));
    await tester.pumpAndSettle();

    // events-local (100, 200) past the hour column (50) and date row (50):
    // column 0, and y=200 in an unscrolled 40px grid maps to hour 5 — free,
    // since the only event sits at hour 9.
    final at = tester.getRect(find.byType(Planner)).topLeft +
        const Offset(50 + 100, 50 + 200);
    await doubleTapAt(tester, at);

    expect(created, hasLength(1),
        reason: 'double-tapping empty grid must fire onEntryCreate');
    expect(created.single.day, 0);
    expect(created.single.hour, 5,
        reason: 'the tapped point maps to day 0 / hour 5');
    expect(edited, isEmpty,
        reason: 'an empty-grid hit creates, it does not edit');
  });
}

/// A minimal real app hosting one [Planner] with a single event at day 0 /
/// hour 9, recording double-tap edit/create callbacks.
class _DoubleTapHostApp extends StatelessWidget {
  const _DoubleTapHostApp({required this.onEdit, required this.onCreate});

  final void Function(PlannerEntry) onEdit;
  final void Function(PlannerTime) onCreate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            onEntryEdit: onEdit,
            onEntryCreate: onCreate,
          ),
          entries: [
            PlannerEntry(
              id: 'evt',
              time: PlannerTime(day: 0, hour: 9),
              title: 'Meeting',
              content: '',
              color: const Color(0xFF2244AA),
            ),
          ],
        ),
      ),
    );
  }
}
