import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/all_day_band.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

// Covers the allDayEntryBuilder hybrid overlay (#80): a host-supplied widget per
// all-day chip, layered over the band canvas at the chip's live screenRect, while
// the canvas keeps the per-chip accessibility semantics and stops painting the
// default chip bodies. The overlay is IgnorePointer/ExcludeSemantics, so all
// gestures (double-tap edit/create, right-click, long-press) and a11y actions
// still fall through to the band's existing recognizers. Reuses #78's
// PlannerEntryBuilder/PlannerEntryLayout, with layout.allDay == true.
void main() {
  PlannerConfig makeConfig({
    List<String> labels = const ['c1', 'c2', 'c3'],
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onDelete,
    void Function(PlannerTime)? onCreate,
    void Function(PlannerEntry)? onLongPress,
  }) =>
      PlannerConfig(
        labels: labels,
        minHour: 0,
        maxHour: 23,
        showAllDayBand: true,
        onEntryEdit: onEdit,
        onEntryDelete: onDelete,
        onEntryCreate: onCreate,
        onEntryLongPress: onLongPress,
      );

  PlannerEntry allDayAt(String id, {required int day, int? endDay}) =>
      PlannerEntry(
        id: id,
        time: PlannerTime(day: day, endDay: endDay, allDay: true),
        title: id,
        content: '',
        color: const Color(0xFF2244AA),
      );

  // A builder that records the layout it was handed per entry id and renders a
  // keyed, sized box so tests can locate it and read its on-screen rect.
  ({PlannerEntryBuilder builder, Map<String, PlannerEntryLayout> layouts})
      recordingBuilder() {
    final layouts = <String, PlannerEntryLayout>{};
    Widget build(BuildContext c, PlannerEntry e, PlannerEntryLayout l) {
      layouts[e.id] = l;
      return Container(
        key: ValueKey('chip-${e.id}'),
        color: const Color(0x8800FF00),
      );
    }

    return (builder: build, layouts: layouts);
  }

  Future<void> pumpBandPlanner(
    WidgetTester tester, {
    required List<PlannerEntry> entries,
    PlannerEntryBuilder? builder,
    List<String> labels = const ['c1', 'c2', 'c3'],
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onDelete,
    void Function(PlannerTime)? onCreate,
    void Function(PlannerEntry)? onLongPress,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: makeConfig(
            labels: labels,
            onEdit: onEdit,
            onDelete: onDelete,
            onCreate: onCreate,
            onLongPress: onLongPress,
          ),
          entries: entries,
          allDayEntryBuilder: builder,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // Two quick taps within the double-tap window (mirrors the band scenarios):
  // the band's GestureDetector resolves a double-tap once the second tap lands.
  Future<void> doubleTapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
  }

  group('overlay positioning, sizing and culling (real composed Planner)', () {
    testWidgets('renders the custom chip at the all-day event on-screen rect',
        (tester) async {
      final rec = recordingBuilder();
      await pumpBandPlanner(tester,
          entries: [allDayAt('a', day: 1)], builder: rec.builder);

      final rect = tester.getRect(find.byKey(const ValueKey('chip-a')));
      // Day-1 chip band-local rect is (252,4)-(448,24); the band sits below the
      // 50px date row, so planner-local it is (252,54)-(448,74), 196x20.
      expect(rect.left, moreOrLessEquals(252));
      expect(rect.top, moreOrLessEquals(54));
      expect(rect.width, moreOrLessEquals(196));
      expect(rect.height, moreOrLessEquals(20));
    });

    testWidgets('a multi-day chip spans its columns', (tester) async {
      final rec = recordingBuilder();
      await pumpBandPlanner(tester,
          entries: [allDayAt('conf', day: 0, endDay: 1)], builder: rec.builder);

      // Columns 0..1 => one chip two columns wide: band-local x 52..448.
      final rect = tester.getRect(find.byKey(const ValueKey('chip-conf')));
      expect(rect.left, moreOrLessEquals(52));
      expect(rect.width, moreOrLessEquals(396));
    });

    testWidgets(
        'the layout carries allDay: true with fixed overlap/drag fields',
        (tester) async {
      final rec = recordingBuilder();
      await pumpBandPlanner(tester,
          entries: [allDayAt('a', day: 1)], builder: rec.builder);

      final layout = rec.layouts['a']!;
      expect(layout.allDay, isTrue,
          reason: 'a shared builder branches on layout.allDay');
      expect(layout.columnIndex, 0);
      expect(layout.columnCount, 1);
      expect(layout.isDragged, isFalse);
      expect(layout.dragType, DragType.none);
      // size is the chip's on-screen size (196x20 at default geometry).
      expect(layout.size.width, moreOrLessEquals(196));
      expect(layout.size.height, moreOrLessEquals(20));
    });

    testWidgets('the chip tracks the band through a horizontal scroll',
        (tester) async {
      final rec = recordingBuilder();
      // Ten columns (2000px) overflow the 800px viewport, so there is day-axis
      // scroll room to pan into.
      await pumpBandPlanner(
        tester,
        entries: [allDayAt('a', day: 1)],
        builder: rec.builder,
        labels: const [
          'd0',
          'd1',
          'd2',
          'd3',
          'd4',
          'd5',
          'd6',
          'd7',
          'd8',
          'd9'
        ],
      );

      final before = tester.getRect(find.byKey(const ValueKey('chip-a')));
      // Pan the day axis by dragging the date row (y≈25) — a clean -100 with no
      // competing recognizer to eat slop. The chip overlay tracks the same
      // controller scroll, so it must reposition by the same amount.
      await tester.dragFrom(const Offset(350, 25), const Offset(-100, 0));
      await tester.pump();

      final after = tester.getRect(find.byKey(const ValueKey('chip-a')));
      expect(after.left, moreOrLessEquals(before.left - 100),
          reason: 'the chip repositions with the horizontal scroll on a pan');
      expect(after.top, moreOrLessEquals(before.top),
          reason: 'the band does not move vertically');
    });

    testWidgets('off-screen chips are culled from the overlay', (tester) async {
      final rec = recordingBuilder();
      // Ten columns; the day-9 chip (band-local x ~1850) is well past the 800px
      // viewport, so its widget must not be built. The day-0 chip is on-screen.
      await pumpBandPlanner(
        tester,
        entries: [allDayAt('on', day: 0), allDayAt('off', day: 9)],
        builder: rec.builder,
        labels: const [
          'd0',
          'd1',
          'd2',
          'd3',
          'd4',
          'd5',
          'd6',
          'd7',
          'd8',
          'd9'
        ],
      );

      expect(find.byKey(const ValueKey('chip-on')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-off')), findsNothing,
          reason: 'a chip outside the band viewport is culled (visuals)');
    });

    testWidgets('no overlay chips when allDayEntryBuilder is null (defaults)',
        (tester) async {
      await pumpBandPlanner(tester, entries: [allDayAt('a', day: 1)]);

      expect(find.byKey(const ValueKey('chip-a')), findsNothing,
          reason: 'with no builder, chips stay canvas-painted as before');
    });
  });

  group('gesture fall-through (overlay is IgnorePointer)', () {
    // The day-1 chip's planner-local centre: band-local (252..448, 4..24) shifted
    // down past the 50px date row -> centre (350, 64).
    const chipCentre = Offset(350, 64);
    // Empty column 0 (no chip) at the band's vertical centre.
    const emptyBandPoint = Offset(150, 64);

    testWidgets('double-tapping the custom chip still fires onEntryEdit',
        (tester) async {
      final rec = recordingBuilder();
      final edited = <PlannerEntry>[];
      await pumpBandPlanner(tester,
          entries: [allDayAt('a', day: 1)],
          builder: rec.builder,
          onEdit: edited.add);

      await doubleTapAt(tester, chipCentre);

      expect(edited, hasLength(1),
          reason: 'the IgnorePointer overlay lets the tap reach the band');
      expect(edited.single.id, 'a');
    });

    testWidgets('double-tapping empty band space still fires onEntryCreate',
        (tester) async {
      final rec = recordingBuilder();
      final created = <PlannerTime>[];
      await pumpBandPlanner(tester,
          entries: [allDayAt('a', day: 1)],
          builder: rec.builder,
          onCreate: created.add);

      await doubleTapAt(tester, emptyBandPoint);

      expect(created, hasLength(1),
          reason: 'a tap on empty band space falls through to create');
      expect(created.single.allDay, isTrue);
      expect(created.single.day, 0,
          reason: 'create maps to the tapped column, flagged all-day');
    });

    testWidgets('long-pressing the custom chip still fires onEntryLongPress',
        (tester) async {
      final rec = recordingBuilder();
      final longPressed = <PlannerEntry>[];
      await pumpBandPlanner(tester,
          entries: [allDayAt('a', day: 1)],
          builder: rec.builder,
          onLongPress: longPressed.add);

      await tester.longPressAt(chipCentre);
      await tester.pumpAndSettle();

      expect(longPressed, hasLength(1),
          reason: 'the long-press falls through the overlay to the band');
      expect(longPressed.single.id, 'a');
    });

    testWidgets(
        'right-clicking the custom chip still opens the edit/delete menu',
        (tester) async {
      final rec = recordingBuilder();
      final edited = <PlannerEntry>[];
      await pumpBandPlanner(tester,
          entries: [allDayAt('a', day: 1)],
          builder: rec.builder,
          onEdit: edited.add,
          onDelete: (_) {});

      final gesture =
          await tester.startGesture(chipCentre, buttons: kSecondaryButton);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // The chip opens the entry menu (edit/delete), not the create menu — proof
      // the band-local right-click hit-tested the chip through the overlay.
      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.text('Delete Event'), findsOneWidget);
      expect(find.text('Create Event'), findsNothing);
    });
  });

  // The canvas keeps exposing each chip to assistive technology even with a
  // builder set (the overlay is ExcludeSemantics), so a screen reader still sees
  // a labelled node per chip with its edit/delete actions.
  testWidgets('chip semantics stay on the canvas when a builder is supplied',
      (tester) async {
    final handle = tester.ensureSemantics();
    final rec = recordingBuilder();
    final edited = <PlannerEntry>[];
    await pumpBandPlanner(tester,
        entries: [allDayAt('Holiday', day: 1)],
        builder: rec.builder,
        labels: const ['Mon', 'Tue', 'Wed'],
        onEdit: edited.add,
        onDelete: (_) {});

    // The custom chip is shown...
    expect(find.byKey(const ValueKey('chip-Holiday')), findsOneWidget);

    // ...and the band's per-chip semantics node is still present and labelled.
    final owner =
        tester.renderObject(find.byType(Planner)).owner!.semanticsOwner!;
    final node = _findByLabelPrefix(owner, 'Holiday');
    expect(node.getSemanticsData().label, 'Holiday, Tue, all day');

    // Activate still routes to edit, proving the canvas node is live.
    owner.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(edited.single.id, 'Holiday');

    handle.dispose();
  });

  // The no-double-draw invariant at the painter level (#80): with drawChipBodies
  // off the band paints none of the chip bodies, so each chip is drawn exactly
  // once (by the overlay widget), not twice. The band draws nothing but chips, so
  // every counted rect is a chip body (fill + stroke).
  group('AllDayBand.drawChipBodies (no double-draw)', () {
    Manager managerWith(List<PlannerEntry> entries) => Manager(
          config: makeConfig(),
          entries: entries,
        );

    int rectsPainted({required bool drawBodies, required bool withChip}) {
      final manager =
          managerWith(withChip ? [allDayAt('a', day: 1)] : const []);
      final painter = AllDayBand(
        manager: manager,
        repaint: manager.controller.triggerUpdate,
        drawChipBodies: drawBodies,
      );
      final canvas = _CountingCanvas();
      painter.paint(canvas, const Size(800, 28));
      return canvas.rects;
    }

    test('defaults to true', () {
      final manager = managerWith([allDayAt('a', day: 1)]);
      final painter = AllDayBand(
          manager: manager, repaint: manager.controller.triggerUpdate);
      expect(painter.drawChipBodies, isTrue);
    });

    test('skips chip bodies when false', () {
      final withBodies = rectsPainted(drawBodies: true, withChip: true);
      final withoutBodies = rectsPainted(drawBodies: false, withChip: true);
      final empty = rectsPainted(drawBodies: true, withChip: false);

      // A chip body is a fill rect plus a stroke rect.
      expect(withBodies, 2,
          reason: 'one chip paints a fill rect plus a stroke rect');
      // With bodies off nothing is painted — the chip is never drawn twice (the
      // overlay widget draws it instead).
      expect(withoutBodies, 0,
          reason: 'no chip body is painted when drawChipBodies is false');
      expect(empty, 0);
    });

    test('shouldRepaint reacts to a drawChipBodies toggle (same data)', () {
      final manager = managerWith([allDayAt('a', day: 1)]);
      final repaint = manager.controller.triggerUpdate;
      final withBodies =
          AllDayBand(manager: manager, repaint: repaint, drawChipBodies: true);

      // Toggling the builder on/off must repaint even though the data revision
      // is unchanged, or the canvas would keep its now-doubled bodies.
      expect(
          AllDayBand(manager: manager, repaint: repaint, drawChipBodies: false)
              .shouldRepaint(withBodies),
          isTrue);
      expect(
          AllDayBand(manager: manager, repaint: repaint, drawChipBodies: true)
              .shouldRepaint(withBodies),
          isFalse);
    });
  });
}

/// A [Canvas] that counts only [drawRect] calls and ignores everything else, so
/// a painter's chip-body rects can be counted without a real surface.
class _CountingCanvas implements ui.Canvas {
  int rects = 0;

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => rects++;

  @override
  void noSuchMethod(Invocation invocation) {}
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
