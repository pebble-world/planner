import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

/// The kind of activity an event represents. This is the *example app's own*
/// domain enum — the planner package knows nothing about it. It rides along on
/// each entry's typed [PlannerEntry.data] payload (#77) and the custom widgets
/// (the "Pop Block" `entryBuilder` and the all-day chip) read it back already
/// typed, with no cast and no side-map keyed by id.
enum ActivityType { focus, meeting, social }

extension ActivityTypeVisuals on ActivityType {
  /// The accent colour the custom widgets use for this type (the Pop Block's
  /// left bar, the all-day pill fill).
  Color get color => switch (this) {
        ActivityType.focus => const Color(0xFF3A7BD5),
        ActivityType.meeting => const Color(0xFF12A594),
        ActivityType.social => const Color(0xFFE5484D),
      };

  String get label => switch (this) {
        ActivityType.focus => 'Focus',
        ActivityType.meeting => 'Meeting',
        ActivityType.social => 'Social',
      };
}

/// The example app's per-event metadata, carried on
/// `PlannerEntry<ActivityMeta>.data` (#77). Everything here is app data the
/// package never inspects — it only threads it through so the builders get it
/// back typed.
class ActivityMeta {
  const ActivityMeta({
    required this.type,
    this.place = '',
    this.status = '',
    this.attendees = const [],
  });

  final ActivityType type;
  final String place;
  final String status;

  /// Attendee initials, rendered as the avatar stack in the tallest detail tier.
  final List<String> attendees;
}

/// The demo's sample entries, typed `PlannerEntry<ActivityMeta>`.
///
/// Positions are plain **column indices** (`day: 0` is the first label), not
/// real dates, so the demo is deterministic no matter what date the headers
/// show. The `dayHeaderBuilder` maps a column index back to its `DateTime` via a
/// `CalendarWindow` for display only.
List<PlannerEntry<ActivityMeta>> sampleEntries() => [
      // A 60-min event in column 0 at 08:00. Small at zoom 1 (40px), so its Pop
      // Block shows only the title until you zoom in.
      PlannerEntry<ActivityMeta>(
        id: '0',
        time: PlannerTime(day: 0, hour: 8, duration: 60),
        title: 'Stand-up',
        content: 'Daily team sync',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(
          type: ActivityType.meeting,
          place: 'Room A',
          status: 'Confirmed',
          attendees: ['AM', 'BK', 'CD'],
        ),
      ),
      // A second column-0 event early in the day (01:00). It stays near the top
      // as you zoom, so it's the one that visibly grows from a bare title to the
      // full card (place → status → time → avatar stack) by pixel height.
      PlannerEntry<ActivityMeta>(
        id: '2',
        time: PlannerTime(day: 0, hour: 1, duration: 60),
        title: 'Coffee & planning',
        content: 'Kick off the day',
        color: ActivityType.social.color,
        data: const ActivityMeta(
          type: ActivityType.social,
          place: 'The Atrium',
          status: 'Tentative',
          attendees: ['YS', 'PV', 'LM', 'RJ'],
        ),
      ),
      // A taller 90-min event later in column 0.
      PlannerEntry<ActivityMeta>(
        id: '1',
        time: PlannerTime(day: 0, hour: 13, minutes: 30, duration: 90),
        title: 'Design review',
        content: 'Walk through the new flow',
        color: ActivityType.focus.color,
        data: const ActivityMeta(
          type: ActivityType.focus,
          place: 'Studio',
          status: 'Confirmed',
          attendees: ['AM', 'CD'],
        ),
      ),
      // Something in a second column, for visual variety.
      PlannerEntry<ActivityMeta>(
        id: '3',
        time: PlannerTime(day: 1, hour: 9, duration: 120),
        title: 'Workshop',
        content: 'Hands-on session',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(
          type: ActivityType.meeting,
          place: 'Room B',
          status: 'Confirmed',
          attendees: ['AM', 'BK', 'CD', 'PV', 'RJ'],
        ),
      ),
      // Two all-day events, in distinct columns so the band stays a single lane.
      // They render through the `allDayEntryBuilder` as custom pills.
      PlannerEntry<ActivityMeta>(
        id: 'ad-0',
        time: PlannerTime(day: 2, allDay: true),
        title: 'Company offsite',
        content: '',
        color: ActivityType.social.color,
        data: const ActivityMeta(type: ActivityType.social),
      ),
      PlannerEntry<ActivityMeta>(
        id: 'ad-1',
        time: PlannerTime(day: 4, allDay: true),
        title: 'Release day',
        content: '',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(type: ActivityType.meeting),
      ),
    ];
