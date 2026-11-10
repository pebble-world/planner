import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/context_menu.dart';
import 'package:planner/planner.dart';

void main() {
  // Issue #123: the lifted context menu (#72) opened with its top-left at the
  // raw click point, so near the planner's right or bottom edge part of it —
  // and its items — fell off-screen. It now flips left/up from the click point
  // and is clamped into the planner rect.

  group('ContextMenuLayout.positionFor', () {
    const bounds = Size(400, 800);
    const menu = Size(150, 100);

    test('opens at the click point when the menu fits', () {
      expect(
          ContextMenuLayout.positionFor(const Offset(100, 200), bounds, menu),
          const Offset(100, 200));
    });

    test('flips left of the click point near the right edge', () {
      expect(
          ContextMenuLayout.positionFor(const Offset(350, 200), bounds, menu),
          const Offset(200, 200));
    });

    test('flips above the click point near the bottom edge', () {
      expect(
          ContextMenuLayout.positionFor(const Offset(100, 750), bounds, menu),
          const Offset(100, 650));
    });

    test('clamps into the bounds when a flip would overflow the other edge',
        () {
      // Flipping left from x 120 would put the menu at -30: clamp to 0.
      expect(
          ContextMenuLayout.positionFor(
              const Offset(120, 200), const Size(260, 800), menu),
          const Offset(0, 200));
    });

    test('pins to the top-left when the menu is larger than the planner', () {
      expect(
          ContextMenuLayout.positionFor(
              const Offset(50, 50), const Size(100, 80), menu),
          Offset.zero);
    });
  });

  group('the menu on a phone-width planner stays inside it', () {
    // The narrowest CI device: an iPhone at 402x874 logical (#122).
    const surface = Size(402, 874);
    const key = ValueKey('planner');

    // An event at day 1 / hour 9. With the default 200x40 grid it spans grid x
    // 200..400, i.e. planner-local x 250..450 past the 50px hour column — its
    // left part is visible on the 402-wide planner, right at the edge.
    PlannerEntry eventInColumn1() => PlannerEntry(
          id: 'evt',
          time: PlannerTime(day: 1, hour: 9),
          title: 'Meeting',
          content: '',
          color: const Color(0xFF2244AA),
        );

    Future<Rect> pumpPlanner(
      WidgetTester tester, {
      List<PlannerEntry> entries = const [],
      void Function(PlannerEntry)? onEdit,
      void Function(PlannerTime)? onCreate,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = surface;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Planner(
            key: key,
            config: PlannerConfig(
              labels: const ['c1', 'c2', 'c3'],
              minHour: 0,
              maxHour: 23,
              onEntryCreate: onCreate ?? (_) {},
              onEntryEdit: onEdit ?? (_) {},
              onEntryDelete: (_) {},
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

    Rect menuRect(WidgetTester tester, String item) => tester.getRect(
        find.ancestor(of: find.text(item), matching: find.byType(Card)));

    void expectInside(Rect inner, Rect outer) {
      expect(inner.left, greaterThanOrEqualTo(outer.left));
      expect(inner.top, greaterThanOrEqualTo(outer.top));
      expect(inner.right, lessThanOrEqualTo(outer.right));
      expect(inner.bottom, lessThanOrEqualTo(outer.bottom));
    }

    testWidgets('near the right edge: flipped left, Edit Event is tappable',
        (tester) async {
      final edited = <PlannerEntry>[];
      final planner = await pumpPlanner(tester,
          entries: [eventInColumn1()], onEdit: edited.add);

      // Day 1 / hour 9 at planner-local (390, 50 + 360 + 20): 12px from the
      // right edge, on the event.
      final at = planner.topLeft + const Offset(390, 430);
      await rightClickAt(tester, at);

      final menu = menuRect(tester, 'Edit Event');
      expectInside(menu, planner);
      expect(menu.right, lessThanOrEqualTo(at.dx),
          reason: 'the menu flips to the left of the click point');

      await tester.tap(find.text('Edit Event'));
      await tester.pump();
      expect(edited.single.id, 'evt');
    });

    testWidgets('near the bottom-right corner: flipped up and left',
        (tester) async {
      final created = <PlannerTime>[];
      final planner = await pumpPlanner(tester, onCreate: created.add);

      final at = planner.bottomRight - const Offset(12, 12);
      await rightClickAt(tester, at);

      final menu = menuRect(tester, 'Create Event');
      expectInside(menu, planner);
      expect(menu.bottom, lessThanOrEqualTo(at.dy),
          reason: 'the menu flips above the click point');

      await tester.tap(find.text('Create Event'));
      await tester.pump();
      expect(created, hasLength(1));
    });
  });
}
