import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'package:example/data.dart';
import 'package:example/main.dart' as app;

import 'planner_harness.dart';

/// Drives the *real* example app end-to-end to cover the **entry** context menu
/// (right-clicking an existing event), which the create-event smoke
/// ([app_smoke_scenarios.dart]) does not exercise. `main.dart` boots a gallery
/// home (#90), so it opens the Showcase page first via [openShowcase]. The
/// "Edit Event" / "Delete Event" items are real Text widgets, so the menu itself
/// is assertable even though event titles are painted on the canvas.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void contextMenuScenarios() {
  testWidgets('right-clicking an event opens the edit/delete menu',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await openShowcase(tester);

    // The sample data's 'Stand-up' entry sits at day 0 / 08:00 for 60 min
    // (sampleEntries). With the default 200x40 grid that is grid rect
    // (0,320)-(200,360); skipping the hour column (50), the date row (50) and the
    // all-day band (one lane: 24 + 2*2 = 28), the box centre lands at
    // planner-local (50 + 100, 50 + 28 + 340).
    final rect = tester.getRect(find.byType(Planner<ActivityMeta>));
    final at = rect.topLeft + const Offset(50 + 100, 50 + 28 + 340);

    final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Right-clicking an event opens the *entry* menu (edit/delete), not the
    // empty-grid *create* menu.
    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Delete Event'), findsOneWidget);
    expect(find.text('Create Event'), findsNothing);

    // Tapping an item closes the menu (the sample handler just logs).
    await tester.tap(find.text('Delete Event'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Event'), findsNothing);
  });

  group('on a phone-width planner the menu stays on-screen (#123)', () {
    // The menu used to open with its top-left at the raw click point, so a
    // right-click near the right/bottom edge of a narrow planner pushed "Edit
    // Event" off-screen, where it could not be tapped. Pinned to the iPhone's
    // 402x874 so every CI leg runs the same narrow layout.
    PlannerSpec spec({
      void Function(PlannerEntry)? onEdit,
      void Function(PlannerTime)? onCreate,
    }) =>
        PlannerSpec(
          config: PlannerConfig(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            onEntryCreate: onCreate ?? (_) {},
            onEntryEdit: onEdit ?? (_) {},
            onEntryDelete: (_) {},
          ),
          // Day 1 / 09:00 for 60 min: grid rect (200,360)-(400,400), i.e.
          // planner-local x 250..450 past the 50px hour column, so its left
          // part sits at the right edge of the 402-wide planner.
          entries: [
            PlannerEntry(
              id: 'edge',
              time: PlannerTime(day: 1, hour: 9),
              title: 'Edge',
              content: '',
              color: const Color(0xFF2244AA),
            ),
          ],
        );

    Future<void> rightClick(WidgetTester tester, Offset at) async {
      final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    void expectMenuInside(WidgetTester tester, String item, Rect planner) {
      final menu = tester.getRect(
          find.ancestor(of: find.text(item), matching: find.byType(Card)));
      expect(planner.contains(menu.topLeft), isTrue,
          reason: 'menu $menu must sit inside the planner $planner');
      expect(menu.right, lessThanOrEqualTo(planner.right));
      expect(menu.bottom, lessThanOrEqualTo(planner.bottom));
    }

    testWidgets('right-clicking an event near the right edge, Edit is tappable',
        (tester) async {
      pinPhoneSurface(tester);
      final edited = <PlannerEntry>[];
      await tester
          .pumpWidget(PlannerHarness(planners: [spec(onEdit: edited.add)]));
      await tester.pumpAndSettle();

      final planner = tester.getRect(find.byKey(PlannerHarness.keyFor(0)));
      expect(planner.width, lessThanOrEqualTo(kPhoneSurface.width));

      // 12px from the planner's right edge, on the event (date row 50 + 380).
      final at = Offset(planner.right - 12, planner.top + 50 + 380);
      await rightClick(tester, at);

      expect(find.text('Edit Event'), findsOneWidget);
      expectMenuInside(tester, 'Edit Event', planner);

      await tester.tap(find.text('Edit Event'));
      await tester.pumpAndSettle();
      expect(edited.single.id, 'edge');
      expect(find.text('Edit Event'), findsNothing);
    });

    testWidgets('right-clicking the bottom-right corner, Create is tappable',
        (tester) async {
      pinPhoneSurface(tester);
      final created = <PlannerTime>[];
      await tester
          .pumpWidget(PlannerHarness(planners: [spec(onCreate: created.add)]));
      await tester.pumpAndSettle();

      final planner = tester.getRect(find.byKey(PlannerHarness.keyFor(0)));
      await rightClick(tester, planner.bottomRight - const Offset(12, 12));

      expect(find.text('Create Event'), findsOneWidget);
      expectMenuInside(tester, 'Create Event', planner);

      await tester.tap(find.text('Create Event'));
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
    });
  });
}
