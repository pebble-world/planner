import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

/// End-to-end guard for the `allDayEntryBuilder` hybrid overlay (#80): a host
/// renders fully custom widgets for all-day chips, layered over the band canvas
/// at each chip's live on-screen rect — the all-day twin of the `entryBuilder`
/// overlay (#78). This drives the *real* app (real Column/Row composition, real
/// fonts, real gestures over the band's own GestureDetector and the lifted
/// context menu) — the layer where an isolated widget test (Ahem font, fixed
/// surface) can miss real composition/geometry:
///   * the custom chip is positioned at the chip's on-screen rect in the band,
///   * the layout the builder receives carries `allDay: true`, and
///   * a real double-tap, right-click and long-press on the chip still fall
///     through the `IgnorePointer` overlay to the band and fire `onEntryEdit` /
///     open the menu / fire `onEntryLongPress`.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void allDayBuilderScenarios() {
  // The day-1 chip's band-local rect is (252,4)-(448,24); the band sits below the
  // 50px date row, so planner-local its centre is (350, 64).
  Offset chipCentre(Rect planner) => planner.topLeft + const Offset(350, 64);

  // The host's custom all-day chip: a rounded pill, branching on layout.allDay so
  // one builder could serve both surfaces. Records the layout's allDay flag.
  bool? lastAllDay;
  Widget chipPill(
      BuildContext context, PlannerEntry entry, PlannerEntryLayout layout) {
    lastAllDay = layout.allDay;
    return Container(
      key: ValueKey('pill-${entry.id}'),
      decoration: BoxDecoration(
        color: entry.color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        entry.title,
        key: ValueKey('pill-title-${entry.id}'),
        style: const TextStyle(fontSize: 9, color: Colors.white),
      ),
    );
  }

  Widget hostApp({
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onDelete,
    void Function(PlannerEntry)? onLongPress,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: _AllDayBuilderHost(
            onEdit: onEdit,
            onDelete: onDelete,
            onLongPress: onLongPress,
            builder: chipPill,
          ),
        ),
      );

  testWidgets('a custom chip paints over the band at the chip rect (#80)',
      (tester) async {
    lastAllDay = null;
    await tester.pumpWidget(hostApp());
    await tester.pumpAndSettle();

    final plannerRect = tester.getRect(find.byType(Planner));
    final pill = find.byKey(const ValueKey('pill-holiday'));
    expect(pill, findsOneWidget,
        reason: 'the builder renders a widget for the on-screen chip');

    // Day-1 chip: band-local (252,4)-(448,24); offset by the 50px date row it is
    // planner-local (252,54)-(448,74), 196x20.
    final pillRect = tester.getRect(pill);
    expect(
        pillRect.left - plannerRect.left, moreOrLessEquals(252, epsilon: 0.5));
    expect(pillRect.top - plannerRect.top, moreOrLessEquals(54, epsilon: 0.5));
    expect(pillRect.width, moreOrLessEquals(196, epsilon: 0.5));
    expect(pillRect.height, moreOrLessEquals(20, epsilon: 0.5));

    expect(lastAllDay, isTrue,
        reason: 'the all-day overlay hands the builder layout.allDay == true');
  });

  testWidgets('a double-tap on the custom chip falls through and edits (#80)',
      (tester) async {
    final edited = <PlannerEntry>[];
    await tester.pumpWidget(hostApp(onEdit: edited.add));
    await tester.pumpAndSettle();

    final at = chipCentre(tester.getRect(find.byType(Planner)));
    // Two real taps within the double-tap window on the custom widget: the
    // IgnorePointer overlay must let them reach the band's recognizer.
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();

    expect(edited, hasLength(1),
        reason: 'the tap fell through the overlay to onEntryEdit');
    expect(edited.single.id, 'holiday');
  });

  testWidgets(
      'a right-click on the custom chip opens the edit/delete menu (#80)',
      (tester) async {
    await tester.pumpWidget(hostApp(onEdit: (_) {}, onDelete: (_) {}));
    await tester.pumpAndSettle();

    final at = chipCentre(tester.getRect(find.byType(Planner)));
    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // The chip opens the entry menu (edit/delete), not the create menu — proof
    // the band-local right-click hit-tested the chip through the overlay and the
    // lifted menu renders over the grid.
    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
    expect(find.text('Create Event'), findsNothing);
  });

  testWidgets('a long-press on the custom chip fires onEntryLongPress (#80)',
      (tester) async {
    final longPressed = <PlannerEntry>[];
    await tester.pumpWidget(hostApp(onLongPress: longPressed.add));
    await tester.pumpAndSettle();

    await tester.longPressAt(chipCentre(tester.getRect(find.byType(Planner))));
    await tester.pumpAndSettle();

    expect(longPressed, hasLength(1),
        reason: 'the long-press falls through the overlay to the band');
    expect(longPressed.single.id, 'holiday');
  });
}

/// A minimal real host for one [Planner] driven by an `allDayEntryBuilder`. Its
/// band is enabled and carries one all-day chip; callbacks are wired through so a
/// scenario can observe which entry an interaction routed to.
class _AllDayBuilderHost extends StatefulWidget {
  const _AllDayBuilderHost({
    this.onEdit,
    this.onDelete,
    this.onLongPress,
    required this.builder,
  });

  final void Function(PlannerEntry)? onEdit;
  final void Function(PlannerEntry)? onDelete;
  final void Function(PlannerEntry)? onLongPress;
  final PlannerEntryBuilder builder;

  @override
  State<_AllDayBuilderHost> createState() => _AllDayBuilderHostState();
}

class _AllDayBuilderHostState extends State<_AllDayBuilderHost> {
  final List<PlannerEntry> _entries = [
    PlannerEntry(
      id: 'holiday',
      time: PlannerTime(day: 1, allDay: true),
      title: 'Holiday',
      content: '',
      color: const Color(0xFF2244AA),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Planner(
      config: PlannerConfig(
        labels: const ['c1', 'c2', 'c3'],
        minHour: 0,
        maxHour: 23,
        showAllDayBand: true,
        onEntryEdit: widget.onEdit,
        onEntryDelete: widget.onDelete,
        onEntryLongPress: widget.onLongPress,
      ),
      entries: _entries,
      allDayEntryBuilder: widget.builder,
    );
  }
}
