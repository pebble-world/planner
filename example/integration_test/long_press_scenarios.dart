import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

/// End-to-end coverage for #66: long-press exposes a host hook for acting on an
/// event by touch.
///
/// Touch has no right-click, and with the #65 interaction overhaul a one-finger
/// drag pans — so long-press is the freed-up gesture. `PlannerConfig` surfaces it
/// as `onEntryLongPress`; the widget stays presentation-only and just hands the
/// pressed entry to the host (no built-in selection/menu).
///
/// This drives the *real* composed widget (real layout, real fonts, real gesture
/// recognition over the competing scale/tap recognizers in the shared arena)
/// with a genuine touch long-press, so it exercises the wiring a widget test on
/// the recognizer in isolation can't.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void longPressScenarios() {
  testWidgets('long-pressing an event fires onEntryLongPress with the entry',
      (tester) async {
    final longPressed = <PlannerEntry>[];

    await tester.pumpWidget(_LongPressHostApp(onLongPress: longPressed.add));
    await tester.pumpAndSettle();

    // The single event sits at day 0 / hour 9 -> grid rect (0,360)-(200,400)
    // with the default 200x40 blocks. On screen it is offset by the hour column
    // (50) and date row (50); its centre is therefore planner-local (150, 430).
    final center =
        tester.getRect(find.byType(Planner)).topLeft + const Offset(150, 430);
    await tester.longPressAt(center);
    await tester.pumpAndSettle();

    expect(longPressed, hasLength(1),
        reason: 'long-pressing an event must fire onEntryLongPress');
    expect(longPressed.single.id, 'evt',
        reason: 'onEntryLongPress receives the long-pressed entry');
  });

  testWidgets('long-pressing empty grid does not fire onEntryLongPress',
      (tester) async {
    final longPressed = <PlannerEntry>[];

    await tester.pumpWidget(_LongPressHostApp(onLongPress: longPressed.add));
    await tester.pumpAndSettle();

    // events-local (100, 200) past the hour column (50) and date row (50):
    // column 0, hour 5 in the unscrolled grid — clear of the hour-9 event.
    final at = tester.getRect(find.byType(Planner)).topLeft +
        const Offset(50 + 100, 50 + 200);
    await tester.longPressAt(at);
    await tester.pumpAndSettle();

    expect(longPressed, isEmpty,
        reason: 'a long-press on empty space is a no-op (#66)');
  });
}

/// A minimal real app hosting one [Planner] with a single event at day 0 /
/// hour 9, recording long-press callbacks.
class _LongPressHostApp extends StatelessWidget {
  const _LongPressHostApp({required this.onLongPress});

  final void Function(PlannerEntry) onLongPress;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            onEntryLongPress: onLongPress,
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
