import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/date_row.dart';

import 'package:planner/calendar.dart';
import 'package:planner/planner.dart';

// Covers the dayHeaderBuilder (#79): a host-supplied widget per day/column
// header, laid out as a row of blockWidth-wide cells offset by the live
// horizontal scroll so each header sits above its column and tracks a pan. The
// row is IgnorePointer, so a horizontal drag across it still pans the day axis
// through the same GestureDetector the painted DateRow uses. When no builder is
// supplied the painted DateRow stays the default.
void main() {
  PlannerConfig makeConfig({
    List<String> labels = const ['c1', 'c2', 'c3'],
    int? highlightedColumn,
  }) =>
      PlannerConfig(
        labels: labels,
        minHour: 0,
        maxHour: 23,
        highlightedColumn: highlightedColumn,
      );

  // A builder that records, per column index, the label and isHighlighted it was
  // handed (last write wins across rebuilds) and renders a keyed, full-cell box
  // so tests can locate it and read its on-screen rect.
  ({
    PlannerDayHeaderBuilder builder,
    Map<int, String> labels,
    Map<int, bool> highlighted,
  }) recordingHeaders() {
    final labels = <int, String>{};
    final highlighted = <int, bool>{};
    Widget build(BuildContext c, int i, String label, bool isHighlighted) {
      labels[i] = label;
      highlighted[i] = isHighlighted;
      return Container(key: ValueKey('h-$i'), color: const Color(0x8800FF00));
    }

    return (builder: build, labels: labels, highlighted: highlighted);
  }

  Future<void> pumpHeaderPlanner(
    WidgetTester tester, {
    required PlannerConfig config,
    PlannerDayHeaderBuilder? builder,
    PlannerController? controller,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config: config,
          entries: const [],
          controller: controller,
          dayHeaderBuilder: builder,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder dateRowCanvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DateRow,
      );

  group('custom day headers (real composed Planner)', () {
    testWidgets('renders one header per label at its column position and width',
        (tester) async {
      final rec = recordingHeaders();
      await pumpHeaderPlanner(tester,
          config: makeConfig(), builder: rec.builder);

      // One header widget per config.labels entry, and the painted DateRow is
      // replaced (no longer in the tree).
      expect(find.byKey(const ValueKey('h-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('h-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('h-2')), findsOneWidget);
      expect(dateRowCanvas(), findsNothing,
          reason: 'a builder replaces the painted DateRow');

      // Default geometry: hourColumnWidth 50, blockWidth 200, dateRowHeight 50.
      // Header i sits at planner-local x = 50 + i*200, full column width, and
      // fills the date row height (top 0, height 50) via the cross-axis stretch.
      final r0 = tester.getRect(find.byKey(const ValueKey('h-0')));
      final r1 = tester.getRect(find.byKey(const ValueKey('h-1')));
      final r2 = tester.getRect(find.byKey(const ValueKey('h-2')));
      expect(r0.left, moreOrLessEquals(50));
      expect(r0.top, moreOrLessEquals(0));
      expect(r0.width, moreOrLessEquals(200));
      expect(r0.height, moreOrLessEquals(50));
      expect(r1.left, moreOrLessEquals(250));
      expect(r2.left, moreOrLessEquals(450));

      // The label handed to the builder is the same text the painted DateRow
      // would show, in column order.
      expect(rec.labels, {0: 'c1', 1: 'c2', 2: 'c3'});
    });

    testWidgets('painted DateRow stays the default when no builder is supplied',
        (tester) async {
      await pumpHeaderPlanner(tester, config: makeConfig());

      expect(dateRowCanvas(), findsOneWidget,
          reason: 'with no builder, headers stay painted by DateRow');
      expect(find.byKey(const ValueKey('h-0')), findsNothing);
    });

    testWidgets('isHighlighted is true only for the highlightedColumn',
        (tester) async {
      final rec = recordingHeaders();
      await pumpHeaderPlanner(tester,
          config: makeConfig(highlightedColumn: 1), builder: rec.builder);

      expect(rec.highlighted, {0: false, 1: true, 2: false});
    });

    testWidgets('no header is highlighted when highlightedColumn is null',
        (tester) async {
      final rec = recordingHeaders();
      await pumpHeaderPlanner(tester,
          config: makeConfig(), builder: rec.builder);

      expect(rec.highlighted.values, everyElement(isFalse));
    });

    testWidgets('dragging the header pans the day axis and repositions headers',
        (tester) async {
      // Ten columns (2000px) wider than the 800px test viewport, so there is
      // day-axis scroll room to pan into.
      final controller = PlannerController();
      addTearDown(controller.dispose);
      final rec = recordingHeaders();
      await pumpHeaderPlanner(
        tester,
        config: makeConfig(
          labels: const [
            'd0',
            'd1',
            'd2',
            'd3',
            'd4',
            'd5',
            'd6',
            'd7',
            'd8',
            'd9'
          ],
        ),
        builder: rec.builder,
        controller: controller,
      );

      final before = tester.getRect(find.byKey(const ValueKey('h-0')));
      expect(controller.dayScroll, moreOrLessEquals(0));

      // Drag horizontally at the header's location. The header overlay is
      // IgnorePointer, so the pointer falls through to the day-axis pan
      // GestureDetector behind it (dragFrom dispatches at the raw coordinate).
      await tester.dragFrom(before.center, const Offset(-100, 0));
      await tester.pump();

      // The day axis panned by the drag delta...
      expect(controller.dayScroll, moreOrLessEquals(-100),
          reason: 'the drag fell through the header to the day-axis pan');
      // ...and the headers tracked it: header 0 moved left by the same amount.
      final after = tester.getRect(find.byKey(const ValueKey('h-0')));
      expect(after.left, moreOrLessEquals(before.left - 100),
          reason: 'headers reposition with controller.x on a pan');
      expect(after.top, moreOrLessEquals(before.top),
          reason: 'a day-axis pan does not move headers vertically');
    });
  });

  // The ADR-0001 pattern end-to-end (#79): no DateTime enters the builder
  // signature, so a calendar consumer closes over its CalendarWindow and calls
  // window.dateAt(columnIndex) inside the builder to recover each column's date.
  // Drives the real composed Planner to prove the bridge from column index to a
  // rendered, dated header.
  testWidgets('a header builder recovers the date via CalendarWindow.dateAt',
      (tester) async {
    // A Monday-first week; column 2 is Wednesday 2026-06-10.
    final window = CalendarWindow.week(anchor: DateTime(2026, 6, 10));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner(
          config:
              PlannerConfig(labels: window.labels(), minHour: 0, maxHour: 23),
          entries: const [],
          dayHeaderBuilder: (context, columnIndex, label, isHighlighted) {
            final date = window.dateAt(columnIndex);
            return Center(
              child: Text(
                '${date.month}/${date.day}',
                key: ValueKey('cal-$columnIndex'),
              ),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Column 2's header shows Wednesday's date, recovered from the window the
    // builder closed over — not from anything the package passed in.
    final wednesday = window.dateAt(2);
    final header = tester.widget<Text>(find.byKey(const ValueKey('cal-2')));
    expect(header.data, '${wednesday.month}/${wednesday.day}');
  });
}
