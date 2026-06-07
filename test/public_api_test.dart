// Regression test for issue #15: the public umbrella import must expose the
// whole public surface. This file deliberately imports ONLY
// `package:planner/planner.dart` — if any of these types were not re-exported,
// the file would fail to compile and this test would never run.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/planner.dart';

void main() {
  group('public API surface (single umbrella import)', () {
    test('PlannerTime is reachable via package:planner/planner.dart', () {
      final time =
          PlannerTime(day: 1, endDay: 3, hour: 9, minutes: 30, duration: 45);
      expect(time.day, 1);
      expect(time.endDay, 3); // column span (#47)
      expect(time.hour, 9);
      expect(time.minutes, 30);
      expect(time.duration, 45);
    });

    test('SpanOverlap and the config field are reachable', () {
      final config =
          PlannerConfig(labels: const ['Mon'], spanOverlap: SpanOverlap.split);
      expect(config.spanOverlap, SpanOverlap.split);
      expect(SpanOverlap.values, hasLength(2));
    });

    test('PlannerEntry, PlannerConfig and Planner are reachable too', () {
      final entry = PlannerEntry(
        id: 'a1',
        time: PlannerTime(day: 0, hour: 8),
        title: 'Stand-up',
        content: 'Daily sync',
        color: const Color(0xFF00FF00),
      );
      final config = PlannerConfig(labels: const ['Mon']);

      expect(entry, isA<PlannerEntry>());
      expect(config, isA<PlannerConfig>());
      expect(Planner.new, isA<Function>());
    });

    test('PlannerController is reachable (#76)', () {
      final controller = PlannerController();
      addTearDown(controller.dispose);
      // A freshly built controller isn't bound to any Planner yet.
      expect(controller.isAttached, isFalse);
      expect(controller, isA<ChangeNotifier>());
    });

    test('PlannerEntry<T>.data carries a typed payload (#77)', () {
      final entry = PlannerEntry<int>(
        id: 'a1',
        time: PlannerTime(day: 0, hour: 8),
        title: 'Stand-up',
        content: '',
        color: const Color(0xFF00FF00),
        data: 42,
      );
      // `data` is typed `int?`, reachable with no cast.
      expect(entry.data, 42);
      expect(entry.copyWith(data: 7).data, 7);
    });

    test('the builder hook types are reachable (#78/#79/#80)', () {
      // PlannerEntryLayout + DragType (#78).
      const layout = PlannerEntryLayout(
        size: Size(120, 40),
        columnIndex: 0,
        columnCount: 1,
        isDragged: false,
        dragType: DragType.none,
        allDay: false,
      );
      expect(layout.size.height, 40);
      expect(layout.allDay, isFalse);
      expect(DragType.values, contains(DragType.body));

      // The builder typedefs (#78/#80 share PlannerEntryBuilder; #79 has its own).
      Widget entryBuilder(BuildContext context, PlannerEntry<int> entry,
              PlannerEntryLayout l) =>
          const SizedBox.shrink();
      Widget headerBuilder(BuildContext context, int columnIndex, String label,
              bool isHighlighted) =>
          const SizedBox.shrink();
      expect(entryBuilder, isA<PlannerEntryBuilder<int>>());
      expect(headerBuilder, isA<PlannerDayHeaderBuilder>());

      // The generic Planner constructor accepts the typed payload.
      expect(Planner<int>.new, isA<Function>());
    });
  });
}
