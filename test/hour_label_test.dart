import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/hour_column.dart';
import 'package:planner/planner.dart';

void main() {
  // Regression for D10 (#13): maxHour defaulted to 24 and the row loop runs
  // `i <= maxHour`, so the default planner painted 25 rows including a spurious
  // "24" (not a valid hour-of-day). The default is now 23, and an optional
  // formatter controls how each hour renders.
  group('buildHourLabels', () {
    test('default config yields 24 rows, 0..23, with no spurious "24"', () {
      final labels = buildHourLabels(PlannerConfig(labels: const ['A']));

      expect(labels.length, 24, reason: 'a full day is 24 hour rows, not 25');
      expect(labels.first, '0');
      expect(labels.last, '23');
      expect(labels, isNot(contains('24')),
          reason: 'hour 24 is not a valid hour-of-day');
    });

    test('honours a minHour..maxHour subrange (inclusive)', () {
      final labels = buildHourLabels(
        PlannerConfig(labels: const ['A'], minHour: 8, maxHour: 17),
      );

      expect(
          labels, ['8', '9', '10', '11', '12', '13', '14', '15', '16', '17']);
    });

    test('falls back to the bare integer when no formatter is set', () {
      final labels = buildHourLabels(
        PlannerConfig(labels: const ['A'], minHour: 0, maxHour: 2),
      );

      expect(labels, ['0', '1', '2']);
    });

    test('applies hourLabelFormatter to every row (e.g. zero-pad)', () {
      final labels = buildHourLabels(
        PlannerConfig(
          labels: const ['A'],
          minHour: 8,
          maxHour: 10,
          hourLabelFormatter: (h) => h.toString().padLeft(2, '0'),
        ),
      );

      expect(labels, ['08', '09', '10']);
    });
  });
}
