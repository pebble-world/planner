import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for the `entryBuilder` hybrid overlay (#78): a host renders
/// fully custom widgets for timed events, layered over the canvas at each event's
/// live on-screen rect. This drives the *real* app (real layout, real fonts, real
/// gestures over the competing pan/zoom/tap recognizers) — the layer where the
/// widget harness (Ahem font, fixed surface) can miss real composition/geometry:
///   * the custom widget is positioned at the event's on-screen rect,
///   * a real double-tap and a real mouse drag on the widget still fall through
///     the `IgnorePointer` overlay to the canvas and fire `onEntryEdit` /
///     `onEntryMove`, and
///   * the widget sheds detail by pixel height as the real grid zooms — the
///     headline use case the overlay exists for.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void entryBuilderScenarios() {
  // Above this on-screen height the card shows its extra detail; below it the
  // detail is shed. The hour-4/60-min event is 40px tall at zoom 1 (< threshold)
  // and clears it once zoomed in.
  const detailThreshold = 56.0;

  // The host's custom widget for one event: a coloured card whose avatar-style
  // detail only renders when the card is tall enough (responsive shedding, #78).
  Widget eventCard(
      BuildContext context, PlannerEntry entry, PlannerEntryLayout layout) {
    return ClipRect(
      child: Container(
        key: ValueKey('card-${entry.id}'),
        color: entry.color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              key: ValueKey('title-${entry.id}'),
              style: const TextStyle(fontSize: 9, color: Colors.white),
            ),
            if (layout.size.height >= detailThreshold)
              Icon(Icons.people,
                  key: ValueKey('details-${entry.id}'),
                  size: 8,
                  color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget hostApp({
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onMove,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: _BuilderHost(
            onEdit: onEdit,
            onMove: onMove,
            builder: eventCard,
          ),
        ),
      );

  testWidgets('a custom widget paints over the grid at the event rect (#78)',
      (tester) async {
    await tester.pumpWidget(hostApp());
    await tester.pumpAndSettle();

    final plannerRect = tester.getRect(find.byType(Planner));
    final card = find.byKey(const ValueKey('card-evt'));
    expect(card, findsOneWidget,
        reason: 'the builder renders a widget for the on-screen event');

    // The event sits at day 0 / hour 4 -> grid rect (0,160)-(200,200) with the
    // default 200x40 blocks; offset by the hour column (50) and date row (50) it
    // is planner-local (50,210)-(250,250).
    final cardRect = tester.getRect(card);
    expect(
        cardRect.left - plannerRect.left, moreOrLessEquals(50, epsilon: 0.5));
    expect(cardRect.top - plannerRect.top, moreOrLessEquals(210, epsilon: 0.5));
    expect(cardRect.width, moreOrLessEquals(200, epsilon: 0.5));
    expect(cardRect.height, moreOrLessEquals(40, epsilon: 0.5));
  });

  testWidgets('a double-tap on the custom widget falls through and edits (#78)',
      (tester) async {
    final edited = <PlannerEntry>[];
    await tester.pumpWidget(hostApp(onEdit: edited.add));
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byKey(const ValueKey('card-evt')));

    // Two real taps within the double-tap window, on the custom widget: the
    // IgnorePointer overlay must let them reach the canvas's tap recognizer.
    await tester.tapAt(cardRect.center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(cardRect.center);
    await tester.pump(const Duration(milliseconds: 300));

    expect(edited, hasLength(1),
        reason: 'the tap fell through the overlay to onEntryEdit');
    expect(edited.single.id, 'evt');
  });

  testWidgets('a mouse drag on the custom widget moves the event (#78)',
      (tester) async {
    final moved = <PlannerEntry>[];
    await tester.pumpWidget(hostApp(onMove: moved.add));
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byKey(const ValueKey('card-evt')));

    // Drag the widget down one block (40px == 1 hour): hour 4 -> hour 5. The
    // drag must fall through the overlay to the move/resize recognizer.
    await mouseDrag(tester, cardRect.center, const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'onEntryMove must not fire during paint');
    expect(moved, hasLength(1), reason: 'the drag committed exactly one move');
    expect(moved.single.time.hour, 5,
        reason: 'a one-block drag advances the event one hour');
  });

  testWidgets(
      'the custom widget sheds detail by pixel height as it zooms (#78)',
      (tester) async {
    await tester.pumpWidget(hostApp());
    await tester.pumpAndSettle();

    final details = find.byKey(const ValueKey('details-evt'));
    // At zoom 1 the card is 40px tall — below the detail threshold, so the
    // avatar-style detail is shed while the card itself still renders.
    expect(find.byKey(const ValueKey('card-evt')), findsOneWidget);
    expect(details, findsNothing,
        reason: 'a 40px card is below the detail threshold');

    // Zoom in with the on-canvas + button until the card clears the threshold
    // (40 * 1.1^n >= 56 -> n >= 4). The overlay rebuilds on the same zoom tick as
    // the canvas, so the builder re-runs with the taller size and shows the detail.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
    }

    expect(details, findsOneWidget,
        reason: 'the taller card now renders its detail (responsive shedding)');
  });
}

/// A minimal real host for one [Planner] driven by an `entryBuilder`. Its
/// `onEntryMove` rebuilds via [setState] (the everyday host pattern), so the move
/// fall-through is exercised against a real rebuilding host.
class _BuilderHost extends StatefulWidget {
  const _BuilderHost({this.onEdit, this.onMove, required this.builder});

  final void Function(PlannerEntry)? onEdit;
  final void Function(PlannerEntry)? onMove;
  final PlannerEntryBuilder builder;

  @override
  State<_BuilderHost> createState() => _BuilderHostState();
}

class _BuilderHostState extends State<_BuilderHost> {
  final List<PlannerEntry> _entries = [
    PlannerEntry(
      id: 'evt',
      time: PlannerTime(day: 0, hour: 4),
      title: 'Standup',
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
        onEntryEdit: widget.onEdit,
        onEntryMove: widget.onMove == null
            ? null
            : (e) => setState(() => widget.onMove!(e)),
      ),
      entries: _entries,
      entryBuilder: widget.builder,
    );
  }
}
