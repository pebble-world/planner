import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/planner.dart';

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

    // #27: the model is immutable, so copyWith is the only way to "change" it.
    test('copyWith replaces only the given fields and leaves the original', () {
      final time = PlannerTime(day: 1, hour: 9, minutes: 30, duration: 90);
      final moved = time.copyWith(day: 2, hour: 10);

      expect(moved.day, 2);
      expect(moved.hour, 10);
      expect(moved.minutes, 30, reason: 'unspecified fields are carried over');
      expect(moved.duration, 90);
      expect(time.day, 1, reason: 'the original is untouched (immutable)');
      expect(time.hour, 9);
    });

    test('has value equality: same fields are equal, differing ones are not',
        () {
      final a = PlannerTime(day: 1, hour: 9, minutes: 30, duration: 90);
      final b = PlannerTime(day: 1, hour: 9, minutes: 30, duration: 90);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(a.copyWith(minutes: 0))));
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

    PlannerEntry sample() => PlannerEntry(
          id: 'a1',
          time: PlannerTime(day: 1, hour: 8),
          title: 'Stand-up',
          content: 'Daily sync',
          color: const Color(0xFF00FF00),
        );

    // #27: drag/resize/nudge produce a new entry via copyWith rather than
    // mutating in place.
    test('copyWith replaces only the given fields and leaves the original', () {
      final entry = sample();
      final moved = entry.copyWith(time: PlannerTime(day: 2, hour: 9));

      expect(moved.time.day, 2);
      expect(moved.time.hour, 9);
      expect(moved.id, 'a1', reason: 'unspecified fields are carried over');
      expect(moved.title, 'Stand-up');
      expect(moved.color, const Color(0xFF00FF00));
      expect(entry.time.day, 1,
          reason: 'the original is untouched (immutable)');
      expect(identical(entry, moved), isFalse);
    });

    test('has value equality, including its nested PlannerTime', () {
      final a = sample();
      final b = sample();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      // A changed nested time breaks equality (PlannerTime has value equality).
      expect(a, isNot(equals(a.copyWith(time: PlannerTime(day: 2, hour: 8)))));
      expect(a, isNot(equals(a.copyWith(title: 'Other'))));
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
      expect(config.snapMinutes, 15);
      expect(config.snapMinutesForZoom, isNull);
    });
  });
}
