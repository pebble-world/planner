import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end guard for #21 (PROJECT_OVERVIEW D12): the planner is drawn on a
/// single `CustomPaint` canvas, which is one opaque node to a screen reader, so
/// events were neither perceivable nor actionable by assistive technology.
/// `EventsPainter` now emits a semantics node per event describing it (title,
/// day, time span, duration) and exposing its edit/delete/move actions.
///
/// This drives the *real* composed widget with semantics turned on (real layout,
/// real fonts, the live `RenderCustomPaint` and `SemanticsOwner`) and confirms
/// the event's node exists, reads correctly, and that each action routes to the
/// matching host callback — proof the painter's `semanticsBuilder` is actually
/// wired in, not merely unit-correct.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void accessibilityScenarios() {
  testWidgets('the event canvas exposes each event and its actions to a11y',
      (tester) async {
    final handle = tester.ensureSemantics();
    final edited = <PlannerEntry>[];
    final deleted = <PlannerEntry>[];
    final moved = <PlannerEntry>[];

    final entry = PlannerEntry(
      id: 'standup',
      time: PlannerTime(day: 0, hour: 9),
      title: 'Standup',
      content: '',
      color: const Color(0xFF2244AA),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['Mon', 'Tue', 'Wed'],
            minHour: 0,
            maxHour: 23,
            onEntryEdit: edited.add,
            onEntryDelete: deleted.add,
            onEntryMove: moved.add,
          ),
          entries: [entry],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final owner =
        tester.renderObject(find.byType(Planner)).owner!.semanticsOwner!;
    final node = _findByLabelPrefix(owner, 'Standup');
    final data = node.getSemanticsData();

    // The event is announced with its title, day, time span and duration, and
    // reads as an actionable button.
    expect(data.label, 'Standup, Mon, 09:00 to 10:00, 1 hour');
    expect(data.flagsCollection.isButton, isTrue);

    // Activating the node edits the event (mirrors double-tap-to-edit).
    owner.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(edited.single.id, 'standup');

    // Dismissing the node deletes the event (the standard "remove" gesture).
    owner.performAction(node.id, SemanticsAction.dismiss);
    await tester.pump();
    expect(deleted.single.id, 'standup');

    // Increasing the node moves the event one hour later and fires onEntryMove —
    // the accessible equivalent of a drag-move (a screen reader can't drag).
    owner.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    // Immutable models (#27): the nudge reports a new entry rather than mutating
    // the one we constructed, so read the moved hour off the reported instance.
    expect(moved.single.id, 'standup');
    expect(moved.single.time.hour, 10);

    handle.dispose();
  });

  testWidgets('an event below the viewport is still exposed to a11y (#56)',
      (tester) async {
    // The events canvas has no accessibility scroll-into-view action, so an event
    // off the bottom of the viewport must still get a (non-hidden) semantics node
    // — otherwise a screen-reader user could never reach it. With the default
    // ~550px-tall canvas, hour 20 (grid y=800) starts well below the fold.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['Mon', 'Tue', 'Wed'],
            minHour: 0,
            maxHour: 23,
          ),
          entries: [
            PlannerEntry(
              id: 'late',
              time: PlannerTime(day: 0, hour: 20),
              title: 'Late',
              content: '',
              color: const Color(0xFF2244AA),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final owner =
        tester.renderObject(find.byType(Planner)).owner!.semanticsOwner!;
    final node = _findByLabelPrefix(owner, 'Late');
    final data = node.getSemanticsData();
    expect(data.label, startsWith('Late, Mon, 20:00'));
    expect(data.flagsCollection.isHidden, isFalse,
        reason: 'an off-viewport event must stay reachable, not hidden');

    handle.dispose();
  });

  testWidgets('scrolling the canvas updates an event node rect (#56)',
      (tester) async {
    // RenderCustomPaint repaints on scroll but never rebuilds semantics on its
    // own, so without the widget-layer poke an event node keeps the rect it had
    // when last built. Scroll the time axis and confirm the node's rect actually
    // moves up — proof the semantics were rebuilt against the new scroll offset.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: PlannerConfig(
            labels: const ['Mon', 'Tue', 'Wed'],
            minHour: 0,
            maxHour: 23,
          ),
          entries: [
            PlannerEntry(
              id: 'standup',
              time: PlannerTime(day: 0, hour: 9),
              title: 'Standup',
              content: '',
              color: const Color(0xFF2244AA),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final owner =
        tester.renderObject(find.byType(Planner)).owner!.semanticsOwner!;
    final before = _findByLabelPrefix(owner, 'Standup').rect.top;

    // Five wheel notches down the time axis (20px each at zoom 1 = 100px up).
    await wheelScroll(tester, tester.getCenter(find.byType(Planner)), 5);
    await tester.pumpAndSettle();

    final after = _findByLabelPrefix(owner, 'Standup').rect.top;
    expect(after, lessThan(before),
        reason: 'the node rect must track the scroll, not stay frozen');
    expect(before - after, closeTo(100, 0.5),
        reason: 'five 20px notches move the event up by 100px');

    handle.dispose();
  });
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
