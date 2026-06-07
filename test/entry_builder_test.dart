import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

// Covers the entryBuilder hybrid overlay (#78): a host-supplied widget per timed
// event, layered over the canvas at the event's live screenRect, while the
// canvas keeps the grid + accessibility semantics and stops painting the default
// event bodies. The overlay is IgnorePointer/ExcludeSemantics, so all gestures
// and a11y actions still fall through to the existing recognizers.
void main() {
  PlannerConfig makeConfig({
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onMove,
  }) =>
      PlannerConfig(
        labels: const ['c1', 'c2', 'c3'],
        minHour: 0,
        maxHour: 23,
        onEntryEdit: onEdit,
        onEntryMove: onMove,
      );

  PlannerEntry entryAt(String id,
          {int day = 0, int hour = 9, int duration = 60}) =>
      PlannerEntry(
        id: id,
        time: PlannerTime(day: day, hour: hour, duration: duration),
        title: id,
        content: '',
        color: const Color(0xFF2244AA),
      );

  // The default-grid event used by the existing widget tests: day 0 / hour 9,
  // duration 60. Its grid rect is (0,360)-(200,400); past the hour column (50)
  // and date row (50) its on-screen rect is planner-local (50,410)-(250,450),
  // centre (150,430).
  PlannerEntry eventAtHour9() => entryAt('evt');

  // A builder that records the layout it was handed per entry id and renders a
  // keyed, sized box so tests can locate it and read its on-screen rect.
  ({PlannerEntryBuilder builder, Map<String, PlannerEntryLayout> layouts})
      recordingBuilder() {
    final layouts = <String, PlannerEntryLayout>{};
    Widget build(BuildContext c, PlannerEntry e, PlannerEntryLayout l) {
      layouts[e.id] = l;
      return Container(
        key: ValueKey('w-${e.id}'),
        color: const Color(0x8800FF00),
      );
    }

    return (builder: build, layouts: layouts);
  }

  Future<void> pumpBuilderPlanner(
    WidgetTester tester, {
    required List<PlannerEntry> entries,
    PlannerEntryBuilder? builder,
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onMove,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: makeConfig(onEdit: onEdit, onMove: onMove),
          entries: entries,
          entryBuilder: builder,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // Two quick taps within the double-tap window (mirrors planner_widget_test):
  // PositionedTapDetector2 only resolves a double-tap once the second tap lands
  // in time; the trailing pump past the window flushes the timeout timer.
  Future<void> doubleTapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Press with a mouse and drag immediately (the Outlook-style desktop move):
  // the pointer-down position anchors the drag so the committed move == delta.
  Future<void> mouseDrag(WidgetTester tester, Offset from, Offset delta) async {
    final gesture =
        await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveBy(delta);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  group('overlay positioning, sizing and culling (real composed Planner)', () {
    testWidgets('renders the custom widget at the event on-screen rect',
        (tester) async {
      final rec = recordingBuilder();
      await pumpBuilderPlanner(tester,
          entries: [eventAtHour9()], builder: rec.builder);

      final rect = tester.getRect(find.byKey(const ValueKey('w-evt')));
      // (0,360)-(200,400) in grid space, shifted by the hour column (50) and
      // date row (50): planner-local (50,410), 200x40.
      expect(rect.left, moreOrLessEquals(50));
      expect(rect.top, moreOrLessEquals(410));
      expect(rect.width, moreOrLessEquals(200));
      expect(rect.height, moreOrLessEquals(40));
    });

    testWidgets('the widget tracks the canvas through a zoom', (tester) async {
      final rec = recordingBuilder();
      await pumpBuilderPlanner(tester,
          entries: [eventAtHour9()], builder: rec.builder);

      // Zoom in with the built-in control (default 1.1x per tap). The y axis is
      // the only one that zooms, so the height grows by the zoom factor and the
      // top moves down proportionally while the width is unchanged.
      final before = tester.getRect(find.byKey(const ValueKey('w-evt')));
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      final after = tester.getRect(find.byKey(const ValueKey('w-evt')));

      expect(after.height, greaterThan(before.height),
          reason: 'a zoom-in must grow the widget in lockstep with the canvas');
      expect(after.width, moreOrLessEquals(before.width),
          reason: 'only the time axis zooms, so the width is unchanged');
    });

    testWidgets(
        'size.height is duration x blockHeight x zoom; overlaps sit side-by-side',
        (tester) async {
      final rec = recordingBuilder();
      // Two events at the same time overlap -> the day-column splits into two
      // sub-columns and each renders at half width.
      await pumpBuilderPlanner(tester,
          entries: [entryAt('e1'), entryAt('e2')], builder: rec.builder);

      // duration 60 / 60 * blockHeight 40 * zoom 1 == 40.
      expect(rec.layouts['e1']!.size.height, moreOrLessEquals(40));
      expect(rec.layouts['e1']!.columnCount, 2);
      expect(rec.layouts['e2']!.columnCount, 2);
      expect(rec.layouts['e1']!.size.width, moreOrLessEquals(100));

      final r1 = tester.getRect(find.byKey(const ValueKey('w-e1')));
      final r2 = tester.getRect(find.byKey(const ValueKey('w-e2')));
      // Side-by-side, no horizontal overlap: e1 in the left sub-column (x 50),
      // e2 in the right (x 150).
      expect(r1.left, moreOrLessEquals(50));
      expect(r2.left, moreOrLessEquals(150));
      expect(r1.right, lessThanOrEqualTo(r2.left + 0.5));
    });

    testWidgets('off-screen events are culled from the overlay',
        (tester) async {
      final rec = recordingBuilder();
      // hour 1 is well within the viewport; hour 23 (grid top 920) is far below
      // the ~550px-tall events canvas, so its widget must not be built.
      await pumpBuilderPlanner(tester,
          entries: [entryAt('on', hour: 1), entryAt('off', hour: 23)],
          builder: rec.builder);

      expect(find.byKey(const ValueKey('w-on')), findsOneWidget);
      expect(find.byKey(const ValueKey('w-off')), findsNothing,
          reason: 'an event outside the canvas viewport is culled (visuals)');
    });

    testWidgets('no overlay widgets when entryBuilder is null (defaults)',
        (tester) async {
      await pumpBuilderPlanner(tester, entries: [eventAtHour9()]);

      expect(find.byKey(const ValueKey('w-evt')), findsNothing,
          reason: 'with no builder, events stay canvas-painted as before');
    });
  });

  group('gesture fall-through (overlay is IgnorePointer)', () {
    testWidgets('double-tapping the custom widget still fires onEntryEdit',
        (tester) async {
      final rec = recordingBuilder();
      final edited = <PlannerEntry>[];
      await pumpBuilderPlanner(tester,
          entries: [eventAtHour9()], builder: rec.builder, onEdit: edited.add);

      // The custom widget sits at planner-local (50,410)-(250,450); tap its
      // centre (150,430). The tap must pass through the overlay to the canvas.
      await doubleTapAt(tester, const Offset(150, 430));

      expect(edited, hasLength(1),
          reason: 'the IgnorePointer overlay lets the tap reach the canvas');
      expect(edited.single.id, 'evt');
    });

    testWidgets('dragging the custom widget still fires onEntryMove',
        (tester) async {
      final rec = recordingBuilder();
      final moved = <PlannerEntry>[];
      await pumpBuilderPlanner(tester,
          entries: [eventAtHour9()], builder: rec.builder, onMove: moved.add);

      // Press the widget centre and drag down one block (40px == 1 hour).
      await mouseDrag(tester, const Offset(150, 430), const Offset(0, 40));

      expect(moved, hasLength(1),
          reason:
              'the drag falls through the overlay to the canvas recognizer');
      expect(moved.single.time.hour, 10,
          reason: 'a one-block drag advances the event one hour');
    });
  });

  // The canvas keeps exposing each event to assistive technology even with a
  // builder set (the overlay is ExcludeSemantics), so a screen reader still sees
  // a labelled node per event. Drives the real composed Planner with semantics on.
  testWidgets('semantics stay on the canvas when a builder is supplied',
      (tester) async {
    final handle = tester.ensureSemantics();
    final rec = recordingBuilder();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['Mon', 'Tue', 'Wed'],
            minHour: 0,
            maxHour: 23,
            onEntryEdit: (_) {},
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
          entryBuilder: rec.builder,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The custom widget is shown...
    expect(find.byKey(const ValueKey('w-evt')), findsOneWidget);

    // ...and the canvas's per-event semantics node is still present and labelled.
    final owner =
        tester.renderObject(find.byType(Planner)).owner!.semanticsOwner!;
    final node = _findSemanticsByLabelPrefix(owner, 'Meeting');
    expect(
        node.getSemanticsData().label, 'Meeting, Mon, 09:00 to 10:00, 1 hour');

    handle.dispose();
  });

  // The no-double-draw invariant at the painter level (#78): with drawEventBodies
  // off the canvas paints the grid but none of the event bodies, so each event is
  // drawn exactly once (by the overlay widget), not twice. Counts canvas.drawRect
  // calls: with no highlighted column the grid draws zero rects, so every counted
  // rect is an event body (fill + stroke).
  group('EventsPainter.drawEventBodies (no double-draw)', () {
    int rectsPainted({required bool drawBodies, required bool withEvent}) {
      final manager = Manager(
        config: makeConfig(),
        entries: withEvent ? [eventAtHour9()] : const [],
      );
      final painter = EventsPainter(
        manager: manager,
        repaint: manager.controller.triggerUpdate,
        drawEventBodies: drawBodies,
      );
      final canvas = _CountingCanvas();
      painter.paint(canvas, const Size(800, 600));
      return canvas.rects;
    }

    test('defaults to true', () {
      final manager = Manager(config: makeConfig(), entries: const []);
      final painter = EventsPainter(
          manager: manager, repaint: manager.controller.triggerUpdate);
      expect(painter.drawEventBodies, isTrue);
    });

    test('skips event bodies but keeps the grid when false', () {
      final gridOnly = rectsPainted(drawBodies: true, withEvent: false);
      final withBodies = rectsPainted(drawBodies: true, withEvent: true);
      final withoutBodies = rectsPainted(drawBodies: false, withEvent: true);

      // Painting the body adds exactly the fill + stroke rects of the one event.
      expect(withBodies - gridOnly, 2,
          reason: 'an event body is a fill rect plus a stroke rect');
      // With bodies off, only the grid is drawn — the event body is skipped, so
      // the event is never drawn twice (the overlay widget draws it instead).
      expect(withoutBodies, gridOnly,
          reason: 'no event body is painted when drawEventBodies is false');
    });

    test('shouldRepaint reacts to a drawEventBodies toggle (same data)', () {
      final manager = Manager(config: makeConfig(), entries: [eventAtHour9()]);
      final repaint = manager.controller.triggerUpdate;
      final withBodies = EventsPainter(
          manager: manager, repaint: repaint, drawEventBodies: true);

      // Toggling the builder on/off must repaint even though the data revision
      // is unchanged, or the canvas would keep its now-doubled bodies.
      expect(
          EventsPainter(
                  manager: manager, repaint: repaint, drawEventBodies: false)
              .shouldRepaint(withBodies),
          isTrue);
      expect(
          EventsPainter(
                  manager: manager, repaint: repaint, drawEventBodies: true)
              .shouldRepaint(withBodies),
          isFalse);
    });
  });
}

/// A [Canvas] that counts only [drawRect] calls and ignores everything else, so
/// a painter's event-body rects can be counted without a real surface.
class _CountingCanvas implements ui.Canvas {
  int rects = 0;

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => rects++;

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// Walks the live semantics tree under [owner] and returns the first node whose
/// label starts with [prefix]. CustomPaint semantics are raw `SemanticsNode`s,
/// so a widget finder can't reach them.
SemanticsNode _findSemanticsByLabelPrefix(SemanticsOwner owner, String prefix) {
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
