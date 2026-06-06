import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/internal/manager.dart';
import 'package:planner/planner.dart';

void main() {
  // #21: the planner is drawn on a single CustomPaint canvas, which is one opaque
  // node to a screen reader. EventsPainter now provides a semanticsBuilder that
  // emits one node per visible event — describing it (title/day/time/duration)
  // and exposing its actions via first-class semantics callbacks (activate=edit,
  // dismiss=delete, increase/decrease=move later/earlier; customSemanticsActions
  // are not used because RenderCustomPaint drops them). These tests drive that
  // builder directly: a unit-level guard on the labels, action gating, the rect,
  // and the move/clamp behaviour.

  PlannerEntry entryAt({
    String id = 'e',
    int day = 0,
    int hour = 9,
    int minutes = 0,
    int duration = 60,
    String title = 'Event',
  }) =>
      PlannerEntry(
        id: id,
        time: PlannerTime(
            day: day, hour: hour, minutes: minutes, duration: duration),
        title: title,
        content: '',
        color: const Color(0xFF112233),
      );

  Manager managerWith({
    required List<PlannerEntry> entries,
    void Function(PlannerEntry)? onEdit,
    void Function(PlannerEntry)? onDelete,
    void Function(PlannerEntry)? onMove,
  }) =>
      Manager(
        config: PlannerConfig(
          labels: const ['Mon', 'Tue', 'Wed'],
          minHour: 0,
          maxHour: 23,
          onEntryEdit: onEdit,
          onEntryDelete: onDelete,
          onEntryMove: onMove,
        ),
        entries: entries,
      );

  // A viewport tall enough to reach any hour 0..23 (24 * 40px = 960), so the
  // off-screen filter never hides the event under test unless that's the point.
  List<CustomPainterSemantics> buildFor(Manager manager,
      [Size size = const Size(800, 1000)]) {
    final painter = EventsPainter(
        manager: manager, repaint: manager.controller.triggerUpdate);
    return painter.semanticsBuilder(size);
  }

  test('emits one node per event with a title/day/time/duration label', () {
    final manager = managerWith(entries: [
      entryAt(
          id: 'a', day: 0, hour: 9, minutes: 0, duration: 60, title: 'Standup'),
    ]);

    final nodes = buildFor(manager);

    expect(nodes, hasLength(1));
    expect(
        nodes.single.properties.label, 'Standup, Mon, 09:00 to 10:00, 1 hour');
  });

  test('label uses the entry day-column label and a precise time span', () {
    final manager = managerWith(entries: [
      entryAt(
          id: 'a', day: 1, hour: 9, minutes: 30, duration: 90, title: 'Review'),
    ]);

    expect(buildFor(manager).single.properties.label,
        'Review, Tue, 09:30 to 11:00, 1 hour 30 minutes');
  });

  test('a sub-hour event reports a minutes-only duration', () {
    final manager = managerWith(entries: [
      entryAt(hour: 14, minutes: 0, duration: 15, title: 'Sync'),
    ]);

    expect(buildFor(manager).single.properties.label,
        'Sync, Mon, 14:00 to 14:15, 15 minutes');
  });

  test('the node rect matches the event on-screen rect', () {
    final manager = managerWith(entries: [entryAt()]);
    expect(buildFor(manager).single.rect, manager.events.single.screenRect);
  });

  test('exposes only the actions the host wired', () {
    final all = managerWith(
      entries: [entryAt()],
      onEdit: (_) {},
      onDelete: (_) {},
      onMove: (_) {},
    );
    final props = buildFor(all).single.properties;
    expect(props.button, isTrue);
    expect(props.onTap, isNotNull, reason: 'activate -> edit');
    expect(props.onDismiss, isNotNull, reason: 'dismiss -> delete');
    expect(props.onIncrease, isNotNull, reason: 'increase -> move later');
    expect(props.onDecrease, isNotNull, reason: 'decrease -> move earlier');

    final editOnly = managerWith(entries: [entryAt()], onEdit: (_) {});
    final editProps = buildFor(editOnly).single.properties;
    expect(editProps.onTap, isNotNull);
    expect(editProps.onDismiss, isNull);
    expect(editProps.onIncrease, isNull);
    expect(editProps.onDecrease, isNull);

    final none = managerWith(entries: [entryAt()]);
    final noneProps = buildFor(none).single.properties;
    expect(noneProps.button, isFalse);
    expect(noneProps.onTap, isNull);
    expect(noneProps.onDismiss, isNull);
    expect(noneProps.onIncrease, isNull);
    expect(noneProps.onDecrease, isNull);
  });

  test('activating the node fires onEntryEdit with the entry', () {
    final edited = <PlannerEntry>[];
    final entry = entryAt(id: 'a');
    final manager = managerWith(entries: [entry], onEdit: edited.add);

    buildFor(manager).single.properties.onTap!();

    expect(edited, hasLength(1));
    expect(identical(edited.single, entry), isTrue);
  });

  test('dismissing the node fires onEntryDelete with the entry', () {
    final deleted = <PlannerEntry>[];
    final entry = entryAt(id: 'a');
    final manager = managerWith(entries: [entry], onDelete: deleted.add);

    buildFor(manager).single.properties.onDismiss!();

    expect(deleted, hasLength(1));
    expect(identical(deleted.single, entry), isTrue);
  });

  test('increase / decrease nudge the event one hour and fire onEntryMove', () {
    final moved = <PlannerEntry>[];
    final entry = entryAt(id: 'a', hour: 9);
    final manager = managerWith(entries: [entry], onMove: moved.add);

    buildFor(manager).single.properties.onIncrease!();
    expect(entry.time.hour, 10, reason: 'increase advances one hour');

    buildFor(manager).single.properties.onDecrease!();
    expect(entry.time.hour, 9, reason: 'decrease rewinds one hour');

    expect(moved, hasLength(2));
    expect(moved.every((e) => identical(e, entry)), isTrue);
  });

  test('a move clamped at the hour bound is a no-op and fires nothing', () {
    final moved = <PlannerEntry>[];
    final entry = entryAt(id: 'a', hour: 23); // maxHour
    final manager = managerWith(entries: [entry], onMove: moved.add);

    buildFor(manager).single.properties.onIncrease!();

    expect(entry.time.hour, 23, reason: 'clamped to maxHour, unchanged');
    expect(moved, isEmpty, reason: 'a no-op nudge must not fire onEntryMove');
  });

  test('events scrolled out of the viewport emit no semantics node', () {
    // Day 0 / hour 9 -> grid rect (0,360)-(200,400). With no scroll the rect is
    // unchanged; a viewport only 100px tall cannot overlap it, so it is omitted.
    final manager = managerWith(entries: [entryAt(hour: 9)]);
    expect(buildFor(manager, const Size(800, 100)), isEmpty);
    // The same event is reported once the viewport is tall enough to reach it.
    expect(buildFor(manager, const Size(800, 600)), hasLength(1));
  });
}
