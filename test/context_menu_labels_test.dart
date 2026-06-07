import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

void main() {
  // Issue #22: the context-menu item labels used to be hardcoded English
  // ('Create Event' / 'Edit Event' / 'Delete Event'). They are now plain
  // strings on PlannerConfig so apps can translate/customize them. These drive
  // the *real* composed Planner: a secondary tap opens the menu and the rendered
  // item text must come from the config, not the old literals.

  // An event at day 0 / hour 9. With the default 200x40 grid it occupies grid
  // rect (0,360)-(200,400); past the hour column (50) and date row (50) its
  // centre is planner-local (150, 430) — same anchor the widget tests use.
  PlannerEntry eventAtHour9() => PlannerEntry(
        id: 'evt',
        time: PlannerTime(day: 0, hour: 9),
        title: 'Meeting',
        content: '',
        color: const Color(0xFF2244AA),
      );

  Future<Rect> pumpPlanner(
    WidgetTester tester,
    Key key, {
    List<PlannerEntry> entries = const [],
    String? createLabel,
    String? editLabel,
    String? deleteLabel,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          key: key,
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            onEntryCreate: (_) {},
            onEntryEdit: (_) {},
            onEntryDelete: (_) {},
            // Leave each label unset to exercise its default.
            contextMenuCreateLabel: createLabel ?? 'Create Event',
            contextMenuEditLabel: editLabel ?? 'Edit Event',
            contextMenuDeleteLabel: deleteLabel ?? 'Delete Event',
          ),
          entries: entries,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.getRect(find.byKey(key));
  }

  Future<void> rightClickAt(WidgetTester tester, Offset at) async {
    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('defaults to "Create Event" on an empty cell', (tester) async {
    const key = ValueKey('planner');
    final rect = await pumpPlanner(tester, key);

    await rightClickAt(tester, rect.topLeft + const Offset(50 + 100, 50 + 40));

    expect(find.text('Create Event'), findsOneWidget);
  });

  testWidgets('defaults to "Edit Event"/"Delete Event" on an event',
      (tester) async {
    const key = ValueKey('planner');
    final rect = await pumpPlanner(tester, key, entries: [eventAtHour9()]);

    await rightClickAt(tester, rect.topLeft + const Offset(150, 430));

    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
  });

  testWidgets('renders the custom create label on an empty cell',
      (tester) async {
    const key = ValueKey('planner');
    final rect =
        await pumpPlanner(tester, key, createLabel: 'Créer un événement');

    await rightClickAt(tester, rect.topLeft + const Offset(50 + 100, 50 + 40));

    expect(find.text('Créer un événement'), findsOneWidget);
    expect(find.text('Create Event'), findsNothing,
        reason: 'the hardcoded English literal must no longer be used');
  });

  testWidgets('renders the custom edit/delete labels on an event',
      (tester) async {
    const key = ValueKey('planner');
    final rect = await pumpPlanner(
      tester,
      key,
      entries: [eventAtHour9()],
      editLabel: 'Modifier',
      deleteLabel: 'Supprimer',
    );

    await rightClickAt(tester, rect.topLeft + const Offset(150, 430));

    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Edit Event'), findsNothing,
        reason: 'the hardcoded English literal must no longer be used');
    expect(find.text('Delete Event'), findsNothing,
        reason: 'the hardcoded English literal must no longer be used');
  });
}
