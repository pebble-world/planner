import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

// A sample app-domain payload, proving PlannerEntry<T> carries typed metadata
// (#77). Equatable so an entry's == / hashCode can fold it in.
class ActivityMeta {
  final String kind;
  final int attendees;
  const ActivityMeta(this.kind, this.attendees);

  @override
  bool operator ==(Object other) =>
      other is ActivityMeta &&
      other.kind == kind &&
      other.attendees == attendees;

  @override
  int get hashCode => Object.hash(kind, attendees);
}

void main() {
  PlannerEntry<ActivityMeta> typedEntry({
    String id = 'a1',
    ActivityMeta? data = const ActivityMeta('meeting', 3),
  }) =>
      PlannerEntry<ActivityMeta>(
        id: id,
        time: PlannerTime(day: 0, hour: 9),
        title: 'Stand-up',
        content: 'Daily sync',
        color: const Color(0xFF00FF00),
        data: data,
      );

  group('PlannerEntry<T> typed payload (#77)', () {
    test('exposes a typed T? data; null when omitted', () {
      const meta = ActivityMeta('meeting', 3);
      final withData = typedEntry(data: meta);
      // The static type of `data` is ActivityMeta? — assigning it with no cast
      // is the compile-time proof of acceptance criterion 2.
      final ActivityMeta? read = withData.data;
      expect(read, same(meta));

      final withoutData = PlannerEntry<ActivityMeta>(
        id: 'b',
        time: PlannerTime(day: 0, hour: 8),
        title: 't',
        content: '',
        color: const Color(0xFF000000),
      );
      expect(withoutData.data, isNull);
    });

    test('copyWith sets/keeps data and returns PlannerEntry<T>', () {
      const a = ActivityMeta('meeting', 3);
      const b = ActivityMeta('lunch', 1);
      final entry = typedEntry(data: a);

      // Omitting data keeps it (data ?? this.data), and the result stays typed.
      final kept = entry.copyWith(title: 'Renamed');
      expect(kept, isA<PlannerEntry<ActivityMeta>>());
      expect(kept.data, same(a));
      expect(kept.title, 'Renamed');

      // Passing data replaces it.
      expect(entry.copyWith(data: b).data, same(b));

      // v1 limitation (#77): copyWith can't reset data to null (data ?? this.data).
      expect(entry.copyWith(data: null).data, same(a));
    });

    test('== and hashCode fold in data', () {
      final base = typedEntry(data: const ActivityMeta('meeting', 3));
      final equalEntry = typedEntry(data: const ActivityMeta('meeting', 3));
      final diffEntry = typedEntry(data: const ActivityMeta('meeting', 4));

      expect(base, equals(equalEntry));
      expect(base.hashCode, equalEntry.hashCode);
      expect(base, isNot(equals(diffEntry)),
          reason: 'entries differing only in data are not equal');
    });
  });

  group('untyped usage stays non-breaking (T == dynamic)', () {
    test('PlannerEntry(...) infers PlannerEntry<dynamic> with null data', () {
      final entry = PlannerEntry(
        id: 'a1',
        time: PlannerTime(day: 0, hour: 8),
        title: 'Stand-up',
        content: '',
        color: const Color(0xFF00FF00),
      );
      expect(entry, isA<PlannerEntry<dynamic>>());
      expect(entry.data, isNull);

      // Two untyped entries with the same fields still compare equal (both null
      // data), so existing host-side diffing keeps working unchanged.
      final twin = PlannerEntry(
        id: 'a1',
        time: PlannerTime(day: 0, hour: 8),
        title: 'Stand-up',
        content: '',
        color: const Color(0xFF00FF00),
      );
      expect(entry, equals(twin));
    });
  });

  group('the typed payload threads through Manager<T> (#77)', () {
    Manager<ActivityMeta> makeManager(
      void Function(PlannerEntry<ActivityMeta>)? onMove, {
      void Function(PlannerEntry<ActivityMeta>)? onEdit,
    }) =>
        Manager<ActivityMeta>(
          config: PlannerConfig<ActivityMeta>(
            labels: const ['A', 'B'],
            onEntryMove: onMove,
            onEntryEdit: onEdit,
          ),
          entries: [typedEntry(data: const ActivityMeta('meeting', 3))],
        );

    test('Event.entry keeps the typed data', () {
      final manager = makeManager(null);
      final ActivityMeta? data = manager.events.first.entry.data; // typed
      expect(data, const ActivityMeta('meeting', 3));
    });

    test('editEvent reports a PlannerEntry<ActivityMeta> with typed data', () {
      PlannerEntry<ActivityMeta>? edited;
      final manager = makeManager(null, onEdit: (e) => edited = e);
      manager.editEvent(manager.events.first);
      expect(edited, isNotNull);
      final ActivityMeta? data = edited!.data; // typed, no cast
      expect(data, const ActivityMeta('meeting', 3));
    });

    test('a drag-move carries the typed data onto the new entry', () {
      PlannerEntry<ActivityMeta>? moved;
      final manager = makeManager((e) => moved = e);
      // Default 200x40 grid: the hour-9 event occupies grid rect (0,360)-(200,400);
      // body-drag at its centre (100,380), down one block == +1 hour.
      manager.startDrag(const Offset(100, 380));
      manager.updateDrag(const Offset(100, 420));
      manager.endDrag();
      expect(moved, isNotNull);
      expect(moved!.time.hour, 10,
          reason: 'a one-block drag advances one hour');
      expect(moved!.data, const ActivityMeta('meeting', 3),
          reason: 'copyWith preserves the payload across a move');
    });
  });

  // End-to-end through the *real* composed widget: a typed Planner<ActivityMeta>
  // hands the host a typed PlannerEntry<ActivityMeta> (with typed .data) when an
  // event is double-tapped — proof the generic threads all the way through the
  // widget, not just the model.
  testWidgets('Planner<ActivityMeta> delivers typed data to onEntryEdit',
      (tester) async {
    const key = ValueKey('planner');
    const meta = ActivityMeta('meeting', 3);
    ActivityMeta? receivedData;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Planner<ActivityMeta>(
          key: key,
          config: PlannerConfig<ActivityMeta>(
            labels: const ['c1', 'c2', 'c3'],
            minHour: 0,
            maxHour: 23,
            // entry is PlannerEntry<ActivityMeta>; entry.data is ActivityMeta?
            // with no cast — the consumer-facing payoff of #77.
            onEntryEdit: (entry) => receivedData = entry.data,
          ),
          entries: [
            PlannerEntry<ActivityMeta>(
              id: 'evt',
              time: PlannerTime(day: 0, hour: 9),
              title: 'Meeting',
              content: '',
              color: const Color(0xFF2244AA),
              data: meta,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The hour-9 event's centre is planner-local (150, 430) on the default grid
    // (hour column 50 + date row 50 + grid centre 100,380). Two taps inside the
    // 250ms double-tap window fire onEntryEdit.
    final at = tester.getRect(find.byKey(key)).topLeft + const Offset(150, 430);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 300));

    expect(receivedData, same(meta),
        reason: 'the typed payload reaches the host through the real widget');
  });
}
