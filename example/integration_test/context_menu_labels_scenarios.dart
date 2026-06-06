import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'planner_harness.dart';

/// End-to-end on a real device: the context-menu labels are configurable
/// (#22). The example app uses the English defaults, so customised labels need
/// their own driveable app — [PlannerHarness] renders a Planner whose
/// `contextMenu*Label`s are overridden, and we assert the *translated* text is
/// what the real composed menu paints (and the old English literals are gone).
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void contextMenuLabelsScenarios() {
  testWidgets('the context menu renders the configured (translated) labels',
      (tester) async {
    final entry = PlannerEntry(
      id: 'evt',
      time: PlannerTime(day: 0, hour: 9),
      title: 'Réunion',
      content: '',
      color: const Color(0xFF2244AA),
    );

    await tester.pumpWidget(PlannerHarness(
      planners: [
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['lun', 'mar', 'mer'],
            minHour: 0,
            maxHour: 23,
            onEntryCreate: (_) {},
            onEntryEdit: (_) {},
            onEntryDelete: (_) {},
            contextMenuCreateLabel: 'Créer un événement',
            contextMenuEditLabel: 'Modifier l’événement',
            contextMenuDeleteLabel: 'Supprimer l’événement',
          ),
          entries: [entry],
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final key = PlannerHarness.keyFor(0);
    final rect = tester.getRect(find.byKey(key));

    // Right-click the event (day 0 / hour 9 -> centre at planner-local
    // (150, 430) with the default 200x40 grid) to open the *entry* menu.
    final gesture = await tester.startGesture(
        rect.topLeft + const Offset(150, 430),
        buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Modifier l’événement'), findsOneWidget);
    expect(find.text('Supprimer l’événement'), findsOneWidget);
    expect(find.text('Edit Event'), findsNothing);
    expect(find.text('Delete Event'), findsNothing);
  });
}
