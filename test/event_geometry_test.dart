import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/event.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';
import 'package:planner/planner_time.dart';

void main() {
  // Regression for D3 + D4 (#10): an event's canvasRect must derive its top
  // offset and height from config.blockHeight, and place minutes proportionally
  // — the old code hardcoded a 40px block (`duration / 60 * 40.0`) and snapped
  // the minute offset to the 15-min grid (`(minutes / 15).round() * 10.0`).

  Event onlyEventFor(PlannerConfig config, PlannerTime time) {
    final manager = Manager(
      config: config,
      entries: [
        PlannerEntry(
          id: 'e',
          time: time,
          title: 'event',
          content: '',
          color: const Color(0xFF112233),
        ),
      ],
    );
    return manager.events.single;
  }

  test('top and height scale with a non-default blockHeight (D3)', () {
    final rect = onlyEventFor(
      PlannerConfig(labels: const ['A', 'B'], blockHeight: 80),
      PlannerTime(day: 1, hour: 9, minutes: 30, duration: 90),
    ).canvasRect;

    // left = day * blockWidth; top = (hour - minHour) * blockHeight
    //                                + minutes / 60 * blockHeight.
    expect(rect.left, 1 * 200);
    expect(rect.top, 9 * 80 + 30 / 60 * 80); // 720 + 40 = 760
    expect(rect.width, 200);
    expect(
        rect.height, 90 / 60 * 80); // 120 — the old code gave 60 (40px block)
  });

  test('minute offset is proportional, not 15-min-quantized (D4)', () {
    // 7 minutes is below the old rounding threshold, so the buggy code snapped
    // it onto the hour line (offset 0). It must now offset proportionally, even
    // at the default 40px block.
    final rect = onlyEventFor(
      PlannerConfig(labels: const ['A'], blockHeight: 40),
      PlannerTime(day: 0, hour: 0, minutes: 7, duration: 60),
    ).canvasRect;

    expect(rect.top, 7 / 60 * 40);
    expect(rect.top, greaterThan(0)); // the old code placed it at exactly 0
  });

  test('top accounts for minHour with a non-default blockHeight', () {
    final rect = onlyEventFor(
      PlannerConfig(labels: const ['A'], minHour: 8, blockHeight: 50),
      PlannerTime(day: 0, hour: 10, minutes: 0, duration: 60),
    ).canvasRect;

    expect(rect.top, (10 - 8) * 50); // 100
    expect(rect.height, 50);
  });
}
