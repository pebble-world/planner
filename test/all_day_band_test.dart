import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/all_day_band.dart';
import 'package:planner/internal/all_day_event.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

// All-day band (#48): an entry flagged PlannerTime.allDay renders as a chip in
// a band above the time grid (under its column, spanning day..endDay for a
// multi-day all-day event) instead of being hour-positioned. Concurrent all-day
// events stack into lanes and the band auto-sizes to them; it's omitted at zero
// height when there are none. The flag stays index-based (no DateTime; ADR
// 0001), and the band is render-only in this first cut (mirrors the #47 span).

void main() {
  // PlannerConfig defaults the test geometry relies on.
  const hourColumnWidth = 50.0;
  const blockWidth = 200;
  const laneHeight = 24.0;

  Manager managerWith(
    List<PlannerEntry> entries, {
    List<String> labels = const ['A', 'B', 'C'],
  }) =>
      Manager(
        config: PlannerConfig(labels: labels, minHour: 0),
        entries: entries,
      );

  PlannerEntry allDayAt(String id, {required int day, int? endDay}) =>
      PlannerEntry(
        id: id,
        time: PlannerTime(day: day, endDay: endDay, allDay: true),
        title: id,
        content: '',
        color: const Color(0xFF2244AA),
      );

  PlannerEntry timedAt(String id, {required int day, required int hour}) =>
      PlannerEntry(
        id: id,
        time: PlannerTime(day: day, hour: hour, duration: 60),
        title: id,
        content: '',
        color: const Color(0xFF112233),
      );

  double bandHeightFor(int lanes) =>
      lanes == 0 ? 0 : lanes * laneHeight + 2 * allDayBandVerticalPadding;

  group('PlannerTime.allDay model', () {
    test('defaults to false (an ordinary timed event)', () {
      expect(PlannerTime(day: 0, hour: 9).allDay, isFalse);
    });

    test('copyWith carries allDay, and value equality includes it', () {
      final base = PlannerTime(day: 0, allDay: true);
      expect(base.copyWith(day: 1).allDay, isTrue);
      expect(base.copyWith(allDay: false).allDay, isFalse);

      expect(PlannerTime(day: 0, allDay: true),
          equals(PlannerTime(day: 0, allDay: true)));
      expect(PlannerTime(day: 0, allDay: true),
          isNot(equals(PlannerTime(day: 0))));
      expect(PlannerTime(day: 0, allDay: true).hashCode,
          PlannerTime(day: 0, allDay: true).hashCode);
    });

    test('toString surfaces allDay', () {
      expect(PlannerTime(day: 0, allDay: true).toString(),
          contains('allDay: true'));
    });
  });

  group('Manager partitions all-day from timed events', () {
    test('an all-day entry is kept out of the hour-grid events list', () {
      final manager = managerWith([
        allDayAt('holiday', day: 0),
        timedAt('meeting', day: 0, hour: 9),
      ]);

      expect(manager.events.map((e) => e.entry.id), ['meeting'],
          reason: 'only the timed entry is an hour-positioned Event');
      expect(manager.allDayEvents.map((e) => e.entry.id), ['holiday']);
    });

    test('an all-day entry is not hit-tested on the grid (render-only)', () {
      final manager = managerWith([allDayAt('holiday', day: 0)]);
      // A point anywhere in column 0's grid resolves to no event: the all-day
      // entry lives in the band, not the hour grid.
      expect(manager.getEventAtPos(const Offset(100, 100)), isNull);
    });
  });

  group('lane packing', () {
    int laneOf(Manager m, String id) =>
        m.allDayEvents.firstWhere((e) => e.entry.id == id).lane;

    test('a single all-day event takes lane 0', () {
      final manager = managerWith([allDayAt('a', day: 1)]);
      expect(manager.allDayLaneCount, 1);
      expect(laneOf(manager, 'a'), 0);
    });

    test('two all-day events in the same column stack into separate lanes', () {
      final manager = managerWith([
        allDayAt('a', day: 1),
        allDayAt('b', day: 1),
      ]);
      expect(manager.allDayLaneCount, 2);
      expect(laneOf(manager, 'a'), 0);
      expect(laneOf(manager, 'b'), 1);
    });

    test('all-day events in different columns share one lane', () {
      final manager = managerWith([
        allDayAt('a', day: 0),
        allDayAt('b', day: 2),
      ]);
      expect(manager.allDayLaneCount, 1);
      expect(laneOf(manager, 'a'), 0);
      expect(laneOf(manager, 'b'), 0);
    });

    test('a multi-day span and a column it covers stack', () {
      // 'span' covers columns 0..2; 'b' sits in column 1, which the span
      // crosses, so they overlap and must not share a lane.
      final manager = managerWith([
        allDayAt('span', day: 0, endDay: 2),
        allDayAt('b', day: 1),
      ]);
      expect(manager.allDayLaneCount, 2);
      expect(laneOf(manager, 'span'), 0); // sorts first (start column 0)
      expect(laneOf(manager, 'b'), 1);
    });
  });

  group('band height', () {
    test('is zero when there are no all-day events', () {
      final manager = managerWith([timedAt('m', day: 0, hour: 9)]);
      expect(manager.allDayLaneCount, 0);
      expect(manager.allDayBandHeight, 0);
    });

    test('grows by one lane height per stacked lane', () {
      final one = managerWith([allDayAt('a', day: 0)]);
      expect(one.allDayBandHeight, bandHeightFor(1));

      final two = managerWith([
        allDayAt('a', day: 0),
        allDayAt('b', day: 0),
      ]);
      expect(two.allDayBandHeight, bandHeightFor(2));
    });
  });

  group('chip geometry', () {
    test('a single-column chip lines up under its column (past the gutter)',
        () {
      // day 1: column left = hourColumnWidth + 1*blockWidth = 250, inset 2 on
      // every side; lane 0 sits below the band's top padding.
      final chip = managerWith([allDayAt('a', day: 1)]).allDayEvents.single;
      expect(chip.screenRect, const Rect.fromLTRB(252, 4, 448, 24));
    });

    test('a multi-day chip spans day..endDay columns', () {
      // day 0..2 => 3 columns wide: left = gutter + 2 inset = 52,
      // right = gutter + 3*blockWidth - 2 = 648.
      final chip = managerWith([allDayAt('span', day: 0, endDay: 2)])
          .allDayEvents
          .single;
      expect(chip.screenRect,
          const Rect.fromLTRB(52, 4, hourColumnWidth + 3 * blockWidth - 2, 24));
    });

    test('a second lane sits one lane height below the first', () {
      final manager = managerWith([
        allDayAt('a', day: 0),
        allDayAt('b', day: 0),
      ]);
      final b = manager.allDayEvents.firstWhere((e) => e.entry.id == 'b');
      // lane 1: top = padding + 1*laneHeight + inset = 2 + 24 + 2 = 28.
      expect(b.screenRect.top, 28);
      expect(b.screenRect.bottom, 28 + laneHeight - 2 * allDayChipInset);
    });
  });

  group('controller reserves the band height in the scroll clamp', () {
    // A taller header (the band) shrinks the time-grid viewport, so the bottom
    // hour stays reachable: the max downward scroll must grow by exactly the
    // band's height. Without the reservation the last row would be cut off.
    Manager sized(List<PlannerEntry> entries) {
      final m = managerWith(entries);
      m.controller.setSize(const Size(800, 500));
      return m;
    }

    double maxDownScroll(Manager m) {
      // Scroll well past the end (verticalScroll(true) moves toward later hours,
      // the way a wheel-down notch does); y clamps to the max downward offset.
      for (var i = 0; i < 200; i++) {
        m.controller.verticalScroll(true);
      }
      return m.controller.y;
    }

    test('two stacked lanes push the clamp down by the band height', () {
      final none = maxDownScroll(sized([timedAt('m', day: 0, hour: 9)]));
      final band = maxDownScroll(sized([
        allDayAt('a', day: 0),
        allDayAt('b', day: 0),
      ]));
      expect(band, none - bandHeightFor(2));
    });
  });

  group('widget rendering', () {
    Finder allDayCanvas() => find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AllDayBand,
        );
    Finder eventsCanvas() => find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is EventsPainter,
        );

    Future<void> pump(WidgetTester tester, List<PlannerEntry> entries) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Planner(
            config: PlannerConfig(
                labels: const ['c1', 'c2', 'c3'], minHour: 0, maxHour: 23),
            entries: entries,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('no band is mounted when there are no all-day events',
        (tester) async {
      await pump(tester, [timedAt('m', day: 0, hour: 9)]);
      expect(allDayCanvas(), findsNothing);
      expect(eventsCanvas(), findsOneWidget);
    });

    testWidgets('the band paints a chip under its column', (tester) async {
      await pump(tester, [allDayAt('a', day: 1)]);

      expect(allDayCanvas(), findsOneWidget);
      // Chip fill is entry.color at alpha 100 (0x642244AA), at the geometry the
      // chip-geometry unit test pins down.
      expect(
        allDayCanvas(),
        paints
          ..rect(
            rect: const Rect.fromLTRB(252, 4, 448, 24),
            color: const Color(0x642244AA),
          ),
      );
    });

    testWidgets('the band sits between the date row and the time grid',
        (tester) async {
      await pump(tester, [allDayAt('a', day: 0)]);
      final bandTop = tester.getRect(allDayCanvas()).top;
      final gridTop = tester.getRect(eventsCanvas()).top;
      // Date row default height is 50, so the band starts at y=50 and the grid
      // begins below it.
      expect(bandTop, 50);
      expect(gridTop, greaterThanOrEqualTo(bandTop + bandHeightFor(1)));
    });
  });
}
