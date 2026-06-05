import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/planner.dart';
import 'package:planner/planner_time.dart';

void main() {
  group('PlannerTime', () {
    test('has sensible defaults', () {
      final time = PlannerTime();
      expect(time.day, 0);
      expect(time.hour, 0);
      expect(time.minutes, 0);
      expect(time.duration, 60);
    });

    test('stores provided values', () {
      final time = PlannerTime(day: 2, hour: 9, minutes: 30, duration: 90);
      expect(time.day, 2);
      expect(time.hour, 9);
      expect(time.minutes, 30);
      expect(time.duration, 90);
    });
  });

  group('PlannerEntry', () {
    test('stores its fields', () {
      final entry = PlannerEntry(
        id: 'a1',
        time: PlannerTime(day: 1, hour: 8),
        title: 'Stand-up',
        content: 'Daily sync',
        color: const Color(0xFF00FF00),
      );

      expect(entry.id, 'a1');
      expect(entry.time.day, 1);
      expect(entry.time.hour, 8);
      expect(entry.title, 'Stand-up');
      expect(entry.content, 'Daily sync');
      expect(entry.color, const Color(0xFF00FF00));
    });
  });

  group('PlannerConfig', () {
    test('applies documented defaults', () {
      final config = PlannerConfig(labels: const ['Mon', 'Tue']);
      expect(config.labels, ['Mon', 'Tue']);
      expect(config.minHour, 0);
      expect(config.maxHour, 23);
      expect(config.blockWidth, 200);
      expect(config.blockHeight, 40);
    });
  });
}
