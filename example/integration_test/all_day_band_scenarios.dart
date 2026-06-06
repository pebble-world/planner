import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/all_day_band.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for the all-day band (#48): an entry flagged
/// [PlannerTime.allDay] renders as a chip in a band *between* the date row and
/// the time grid — under its column, spanning `day..endDay` for a multi-day
/// all-day event — instead of being hour-positioned. The band auto-sizes to its
/// stacked lanes and is omitted entirely when there are no all-day events.
///
/// The band is painted on its own `CustomPaint` canvas and its placement falls
/// out of the real `Column`/`Row` composition, neither of which an isolated
/// widget test exercises with real layout/fonts. So this drives the real
/// composed widget and asserts both what the band canvas paints and where it
/// lands relative to the date row and grid.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void allDayBandScenarios() {
  // Scope `paints` assertions to each canvas so surrounding chrome can't match.
  Finder allDayCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is AllDayBand,
      );
  Finder eventsCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is EventsPainter,
      );

  PlannerSpec withEntries(List<PlannerEntry> entries) => PlannerSpec(
        config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            showAllDayBand: true),
        entries: entries,
      );

  PlannerEntry allDay(String id, {required int day, int? endDay}) =>
      PlannerEntry(
        id: id,
        time: PlannerTime(day: day, endDay: endDay, allDay: true),
        title: id,
        content: '',
        color: const Color(0xFF2244AA),
      );

  // Default geometry (gutter 50, 200-wide columns, 24px lane, 2px band padding):
  // an all-day chip for `day` sits in the band at planner-local y≈64 (date row 50
  // + lane-0 centre 14). The column-1 chip used by these scenarios spans
  // planner-local x 252..448, so its centre is x≈350; empty column 0 is x≈150.
  Offset chipPoint(Rect planner) => planner.topLeft + const Offset(350, 64);
  Offset emptyBandPoint(Rect planner) =>
      planner.topLeft + const Offset(150, 64);

  // A planner whose all-day band is enabled and wired to the given callbacks, so
  // a scenario can observe which entry/time an interaction routed to.
  PlannerSpec wired({
    required List<PlannerEntry> entries,
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onDelete,
    void Function(PlannerTime)? onCreate,
    void Function(PlannerEntry)? onLongPress,
  }) =>
      PlannerSpec(
        config: PlannerConfig(
          labels: const ['c1', 'c2', 'c3'],
          minHour: 0,
          maxHour: 23,
          showAllDayBand: true,
          onEntryEdit: onEdit,
          onEntryDelete: onDelete,
          onEntryCreate: onCreate,
          onEntryLongPress: onLongPress,
        ),
        entries: entries,
      );

  testWidgets('an all-day chip paints in a band between the date row and grid',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(
      planners: [
        withEntries([allDay('holiday', day: 1)])
      ],
    ));
    await tester.pumpAndSettle();

    // Default geometry: hour column 50 wide, 200-wide columns, 24px lane, 2px
    // band padding + 2px chip inset. Column 1's chip is therefore the box
    // x 252..448, y 4..24 in the band canvas, filled with entry.color at alpha
    // 100 (0x642244AA). A timed event would instead paint down in the grid.
    expect(
      allDayCanvas(),
      paints
        ..rect(
          rect: const Rect.fromLTRB(252, 4, 448, 24),
          color: const Color(0x642244AA),
        ),
    );

    // The band sits below the 50px date row and the grid begins below the band
    // (its height is one lane + padding = 28) — proving the band is inserted
    // between them in the real composition, not overlaid on either.
    final bandRect = tester.getRect(allDayCanvas());
    final gridTop = tester.getRect(eventsCanvas()).top;
    expect(bandRect.top, 50);
    expect(gridTop, greaterThanOrEqualTo(bandRect.bottom));
  });

  testWidgets('a multi-day all-day event spans its columns in the band',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(
      planners: [
        withEntries([allDay('conf', day: 0, endDay: 1)])
      ],
    ));
    await tester.pumpAndSettle();

    // Columns 0..1 => one chip two columns wide: x 52..448 (gutter 50 + 2 inset
    // .. gutter + 2*200 - 2), still in lane 0. A single-column chip would only
    // reach x 248 — the 396-wide box is the spanning behaviour.
    expect(
      allDayCanvas(),
      paints
        ..rect(
          rect: const Rect.fromLTRB(52, 4, 448, 24),
          color: const Color(0x642244AA),
        ),
    );
  });

  testWidgets('no band is shown and the grid is flush when none are all-day',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(
      planners: [
        withEntries([
          PlannerEntry(
            id: 'meeting',
            time: PlannerTime(day: 0, hour: 9, duration: 60),
            title: 'Meeting',
            content: '',
            color: const Color(0xFF2244AA),
          ),
        ]),
      ],
    ));
    await tester.pumpAndSettle();

    expect(allDayCanvas(), findsNothing);
    // With no band the grid is flush under the 50px date row — the band reclaims
    // its space rather than leaving an empty strip.
    expect(tester.getRect(eventsCanvas()).top, 50);
  });

  // --- Interaction parity (#72) ---------------------------------------------
  // These drive real gestures on the real composed band (its own GestureDetector
  // sharing an arena with the day-axis horizontal drag, and the context menu
  // lifted to the planner-wide Stack so it can overflow the thin band over the
  // grid). An isolated widget test exercises none of that composition.

  testWidgets('double-tapping an all-day chip fires onEntryEdit',
      (tester) async {
    final edited = <PlannerEntry>[];
    await tester.pumpWidget(PlannerHarness(planners: [
      wired(entries: [allDay('holiday', day: 1)], onEdit: edited.add),
    ]));
    await tester.pumpAndSettle();

    await _doubleTapAt(tester, chipPoint(tester.getRect(find.byType(Planner))));

    expect(edited.single.id, 'holiday',
        reason: 'a chip double-tap edits, mirroring the timed grid');
  });

  testWidgets('double-tapping empty band space creates an all-day event',
      (tester) async {
    final created = <PlannerTime>[];
    await tester.pumpWidget(PlannerHarness(planners: [
      wired(entries: [allDay('holiday', day: 1)], onCreate: created.add),
    ]));
    await tester.pumpAndSettle();

    // Empty column 0 (the chip is in column 1).
    await _doubleTapAt(
        tester, emptyBandPoint(tester.getRect(find.byType(Planner))));

    expect(created.single.allDay, isTrue);
    expect(created.single.day, 0,
        reason: 'create maps to the tapped column, flagged all-day');
  });

  testWidgets('right-clicking a chip opens edit/delete; Edit fires onEntryEdit',
      (tester) async {
    final edited = <PlannerEntry>[];
    await tester.pumpWidget(PlannerHarness(planners: [
      wired(
          entries: [allDay('holiday', day: 1)],
          onEdit: edited.add,
          onDelete: (_) {}),
    ]));
    await tester.pumpAndSettle();

    await _rightClickAt(
        tester, chipPoint(tester.getRect(find.byType(Planner))));

    // The chip opens the entry menu (edit/delete), not the create menu — proof
    // the band-local right-click hit-tested the chip and the lifted menu renders.
    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
    expect(find.text('Create Event'), findsNothing);

    await tester.tap(find.text('Edit Event'));
    await tester.pumpAndSettle();
    expect(edited.single.id, 'holiday');
  });

  testWidgets('right-clicking empty band space offers Create (all-day)',
      (tester) async {
    final created = <PlannerTime>[];
    await tester.pumpWidget(PlannerHarness(planners: [
      wired(entries: [allDay('holiday', day: 1)], onCreate: created.add),
    ]));
    await tester.pumpAndSettle();

    await _rightClickAt(
        tester, emptyBandPoint(tester.getRect(find.byType(Planner))));

    expect(find.text('Create Event'), findsOneWidget);
    expect(find.text('Edit Event'), findsNothing);

    await tester.tap(find.text('Create Event'));
    await tester.pumpAndSettle();
    expect(created.single.allDay, isTrue);
    expect(created.single.day, 0);
  });

  testWidgets('long-pressing an all-day chip fires onEntryLongPress',
      (tester) async {
    final longPressed = <PlannerEntry>[];
    await tester.pumpWidget(PlannerHarness(planners: [
      wired(entries: [allDay('holiday', day: 1)], onLongPress: longPressed.add),
    ]));
    await tester.pumpAndSettle();

    await tester.longPressAt(chipPoint(tester.getRect(find.byType(Planner))));
    await tester.pumpAndSettle();

    expect(longPressed.single.id, 'holiday',
        reason: 'long-press is the touch path to act on a chip');
  });

  testWidgets('the band exposes each chip and its actions to a11y',
      (tester) async {
    final handle = tester.ensureSemantics();
    final edited = <PlannerEntry>[];
    final deleted = <PlannerEntry>[];
    await tester.pumpWidget(PlannerHarness(planners: [
      wired(
          entries: [allDay('Holiday', day: 1)],
          onEdit: edited.add,
          onDelete: deleted.add),
    ]));
    await tester.pumpAndSettle();

    final owner =
        tester.renderObject(find.byType(Planner)).owner!.semanticsOwner!;
    final node = _findByLabelPrefix(owner, 'Holiday');
    // Label reads title, column ('c2' is column index 1), and "all day".
    expect(node.getSemanticsData().label, 'Holiday, c2, all day');

    owner.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(edited.single.id, 'Holiday');

    owner.performAction(node.id, SemanticsAction.dismiss);
    await tester.pump();
    expect(deleted.single.id, 'Holiday');

    handle.dispose();
  });

  testWidgets('no band is shown when disabled, even with all-day entries',
      (tester) async {
    await tester.pumpWidget(PlannerHarness(planners: [
      PlannerSpec(
        // showAllDayBand defaults to false — the opt-in gate is off.
        config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'], minHour: 0, maxHour: 23),
        entries: [allDay('holiday', day: 1)],
      ),
    ]));
    await tester.pumpAndSettle();

    expect(allDayCanvas(), findsNothing);
    expect(tester.getRect(eventsCanvas()).top, 50,
        reason: 'with the band off the grid is flush under the date row');
  });
}

/// Double-taps at [at]: two primary taps within the double-tap window, the way
/// the GestureDetector's double-tap recognizer expects them.
Future<void> _doubleTapAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

/// Right-clicks (secondary press) at [at] and settles, opening the context menu
/// via `onSecondaryTapDown`.
Future<void> _rightClickAt(WidgetTester tester, Offset at) async {
  final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Returns the first semantics node under [owner] whose label starts with
/// [prefix]. CustomPaint semantics are raw `SemanticsNode`s, so a widget finder
/// can't reach them — the tree is walked directly.
SemanticsNode _findByLabelPrefix(SemanticsOwner owner, String prefix) {
  SemanticsNode? found;
  void visit(SemanticsNode node) {
    if (found == null && node.getSemanticsData().label.startsWith(prefix)) {
      found = node;
    }
    node.visitChildren((child) {
      visit(child);
      return found == null;
    });
  }

  visit(owner.rootSemanticsNode!);
  expect(found, isNotNull,
      reason: 'no semantics node labelled "$prefix…" was found');
  return found!;
}
