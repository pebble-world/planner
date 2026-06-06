import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

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
    expect(moved.single.id, 'standup');
    expect(entry.time.hour, 10);

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
