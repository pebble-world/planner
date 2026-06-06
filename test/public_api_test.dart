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
  });
}
