import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/event.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

void main() {
  // Regression for D11 (#20): concurrent events used to paint at full column
  // width and stack on top of each other. The Manager now splits each day-column
  // among overlapping events, so an event's canvasRect is narrowed to its
  // sub-column (left offset + width) while leaving non-overlapping events full.

  const blockWidth = 200; // PlannerConfig default

  Manager managerWith(List<PlannerTime> times) => Manager(
        config: PlannerConfig(labels: const ['A', 'B']),
        entries: [
          for (var i = 0; i < times.length; i++)
            PlannerEntry(
              id: '$i',
              time: times[i],
              title: 't$i',
              content: '',
              color: const Color(0xFF112233),
            ),
        ],
      );

  // Asserts an event sits in sub-column [index] of [count] within its day-column.
  void expectColumn(Event e,
      {required int day, required int index, required int count}) {
    final columnWidth = blockWidth / count;
    expect(e.canvasRect.left,
        closeTo(day * blockWidth + index * columnWidth, 0.001),
        reason: 'sub-column $index of $count on day $day');
    expect(e.canvasRect.width, closeTo(columnWidth, 0.001),
        reason: '1/$count of the day-column');
  }

  test('a lone event keeps the full day-column width', () {
    final manager = managerWith([PlannerTime(day: 0, hour: 9, duration: 60)]);
    expectColumn(manager.events.single, day: 0, index: 0, count: 1);
  });

  test('back-to-back events do not overlap and stay full width', () {
    // 9:00-10:00 then 10:00-11:00: the second starts exactly when the first ends,
    // so they are adjacent, not overlapping (overlap is strict).
    final manager = managerWith([
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 0, hour: 10, duration: 60),
    ]);
    expectColumn(manager.events[0], day: 0, index: 0, count: 1);
    expectColumn(manager.events[1], day: 0, index: 0, count: 1);
  });

  test('two overlapping events split the day-column in half', () {
    final manager = managerWith([
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 0, hour: 9, minutes: 30, duration: 60),
    ]);
    // Sorted by start, the earlier event takes the left sub-column.
    expectColumn(manager.events[0], day: 0, index: 0, count: 2);
    expectColumn(manager.events[1], day: 0, index: 1, count: 2);
  });

  test('three mutually overlapping events split into thirds', () {
    final manager = managerWith([
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 0, hour: 9, duration: 60),
    ]);
    expectColumn(manager.events[0], day: 0, index: 0, count: 3);
    expectColumn(manager.events[1], day: 0, index: 1, count: 3);
    expectColumn(manager.events[2], day: 0, index: 2, count: 3);
  });

  test('a transitively-connected cluster uses max concurrency, reusing columns',
      () {
    // A 9:00-10:00, B 9:30-10:30, C 10:15-11:00. A and C never overlap, but B
    // chains them into one cluster. Max concurrency is 2, so the cluster splits
    // into 2 columns and C reuses A's (now-free) left column.
    final manager = managerWith([
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 0, hour: 9, minutes: 30, duration: 60),
      PlannerTime(day: 0, hour: 10, minutes: 15, duration: 45),
    ]);
    expectColumn(manager.events[0], day: 0, index: 0, count: 2); // A — left
    expectColumn(manager.events[1], day: 0, index: 1, count: 2); // B — right
    expectColumn(manager.events[2],
        day: 0, index: 0, count: 2); // C — left again
  });

  test('overlaps are scoped per day-column', () {
    // Two events at the same time but in different columns must NOT split each
    // other — they live in independent day-columns.
    final manager = managerWith([
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 1, hour: 9, duration: 60),
    ]);
    expectColumn(manager.events[0], day: 0, index: 0, count: 1);
    expectColumn(manager.events[1], day: 1, index: 0, count: 1);
  });

  test('a fresh overlap cluster after a gap restarts the column count', () {
    // First pair overlaps (2 columns); after a gap, a second pair overlaps
    // (its own 2 columns) — the gap must reset, not accumulate, the count.
    final manager = managerWith([
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 0, hour: 9, duration: 60),
      PlannerTime(day: 0, hour: 15, duration: 60),
      PlannerTime(day: 0, hour: 15, duration: 60),
    ]);
    expectColumn(manager.events[0], day: 0, index: 0, count: 2);
    expectColumn(manager.events[1], day: 0, index: 1, count: 2);
    expectColumn(manager.events[2], day: 0, index: 0, count: 2);
    expectColumn(manager.events[3], day: 0, index: 1, count: 2);
  });
}
