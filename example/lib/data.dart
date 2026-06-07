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

/// A small set of **plain**, untyped `PlannerEntry` events (no `data` payload,
/// no custom builders) for the get-it-running basic example and its screenshot.
///
/// This is the "default look": the package paints titles and times itself, so
/// the only styling is each entry's [PlannerEntry.color]. Positions are plain
/// column indices (`day: 0` is the first label) so the demo is deterministic.
/// It still shows the essentials a newcomer wants to see at a glance — a few
/// events across the week, one **overlap** (the layout splits the column), and
/// a single **all-day** event in the band.
List<PlannerEntry> basicEntries() => [
      PlannerEntry(
        id: 'b-standup',
        time: PlannerTime(day: 0, hour: 9, duration: 45),
        title: 'Team stand-up',
        content: 'Daily sync',
        color: const Color(0xFF3A7BD5),
      ),
      PlannerEntry(
        id: 'b-focus',
        time: PlannerTime(day: 0, hour: 14, duration: 90),
        title: 'Deep work',
        content: 'No meetings',
        color: const Color(0xFF5B6BB5),
      ),
      // An overlapping pair in column 1 — the default layout splits the column
      // so both stay visible.
      PlannerEntry(
        id: 'b-coffee',
        time: PlannerTime(day: 1, hour: 11, duration: 60),
        title: 'Coffee chat',
        content: 'Catch up',
        color: const Color(0xFF12A594),
      ),
      PlannerEntry(
        id: 'b-1on1',
        time: PlannerTime(day: 1, hour: 11, minutes: 30, duration: 60),
        title: '1:1 with Sam',
        content: 'Weekly check-in',
        color: const Color(0xFFE5484D),
      ),
      PlannerEntry(
        id: 'b-workshop',
        time: PlannerTime(day: 2, hour: 10, duration: 120),
        title: 'Workshop',
        content: 'Hands-on session',
        color: const Color(0xFFD9730D),
      ),
      PlannerEntry(
        id: 'b-review',
        time: PlannerTime(day: 3, hour: 13, duration: 60),
        title: 'Design review',
        content: 'Walk the new flow',
        color: const Color(0xFF8E4EC6),
      ),
      PlannerEntry(
        id: 'b-wrapup',
        time: PlannerTime(day: 4, hour: 15, minutes: 30, duration: 90),
        title: 'Week wrap-up',
        content: 'Demo & retro',
        color: const Color(0xFF3A7BD5),
      ),
      // A single all-day event so the band shows in the basic screenshot.
      PlannerEntry(
        id: 'b-holiday',
        time: PlannerTime(day: 2, allDay: true),
        title: 'Office closed',
        content: '',
        color: const Color(0xFF12A594),
      ),
    ];

/// The demo's rich sample entries, typed `PlannerEntry<ActivityMeta>` — the set
/// the customization showcase and the documentation screenshots use.
///
/// Positions are plain **column indices** (`day: 0` is the first label), not
/// real dates, so the demo is deterministic no matter what date the headers
/// show. The `dayHeaderBuilder` maps a column index back to its `DateTime` via a
/// `CalendarWindow` for display only.
///
/// The set is deliberately full — ~Mon–Fri with several **overlapping** events
/// (column-split layout), a **column-spanning** event (`endDay`), and a busy
/// **all-day band** — so the grid looks like a real week.
///
/// Some ids are *anchors* the integration suite pins to fixed positions and
/// must not move or renumber: `0` (Stand-up, day 0 / 08:00 / 60 min,
/// un-overlapped), `2` (Coffee & planning, day 0 / 01:00 / 60 min, ≥3
/// attendees), `1` (day 0 / 13:30), `ad-0` (day 2 all-day), `ad-1` (day 4
/// all-day). Day 0 stays exactly these three timed entries (03:00 free, 08:00
/// un-overlapped), and every all-day event sits in its own column so the band
/// stays a single lane. New events go around them.
List<PlannerEntry<ActivityMeta>> sampleEntries() => [
      // ── Column 0 (Mon): the integration anchors. Left untouched. ──────────
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

      // ── Column 1 (Tue): an overlapping cluster (column-split layout). ─────
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
      // Overlaps the Workshop above (10:00–11:30 vs 09:00–11:00) — the two share
      // the column, each rendered at half width.
      PlannerEntry<ActivityMeta>(
        id: '4',
        time: PlannerTime(day: 1, hour: 10, duration: 90),
        title: 'Pair programming',
        content: 'Drive the refactor',
        color: ActivityType.focus.color,
        data: const ActivityMeta(
          type: ActivityType.focus,
          place: 'Desk 4',
          status: 'Confirmed',
          attendees: ['LM', 'RJ'],
        ),
      ),
      PlannerEntry<ActivityMeta>(
        id: '5',
        time: PlannerTime(day: 1, hour: 12, minutes: 30, duration: 60),
        title: 'Lunch & learn',
        content: 'Talk: layout internals',
        color: ActivityType.social.color,
        data: const ActivityMeta(
          type: ActivityType.social,
          place: 'Café',
          status: 'Tentative',
          attendees: ['AM', 'BK', 'CD', 'YS', 'PV'],
        ),
      ),
      PlannerEntry<ActivityMeta>(
        id: '6',
        time: PlannerTime(day: 1, hour: 15, duration: 30),
        title: '1:1 with Sam',
        content: 'Weekly check-in',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(
          type: ActivityType.meeting,
          place: 'Room A',
          status: 'Confirmed',
          attendees: ['YS'],
        ),
      ),

      // ── Column 2 (Wed): a morning block + the start of a spanning event. ──
      PlannerEntry<ActivityMeta>(
        id: '7',
        time: PlannerTime(day: 2, hour: 9, minutes: 30, duration: 120),
        title: 'Sprint planning',
        content: 'Scope the next sprint',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(
          type: ActivityType.meeting,
          place: 'Room B',
          status: 'Confirmed',
          attendees: ['AM', 'BK', 'CD', 'PV'],
        ),
      ),
      // A multi-column event (#47): spans Wed→Thu across the same hours. Its
      // rows (14:00–17:00) are left clear on both columns so it renders as one
      // wide block rather than splitting.
      PlannerEntry<ActivityMeta>(
        id: '8',
        time: PlannerTime(day: 2, endDay: 3, hour: 14, duration: 180),
        title: 'Design conference',
        content: 'Two-day offsite track',
        color: ActivityType.focus.color,
        data: const ActivityMeta(
          type: ActivityType.focus,
          place: 'Auditorium',
          status: 'Confirmed',
          attendees: ['AM', 'BK', 'CD', 'YS', 'PV', 'LM'],
        ),
      ),

      // ── Column 3 (Thu): morning meetings + an evening retro. ──────────────
      PlannerEntry<ActivityMeta>(
        id: '9',
        time: PlannerTime(day: 3, hour: 10, duration: 60),
        title: 'Client call',
        content: 'Status & next steps',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(
          type: ActivityType.meeting,
          place: 'Zoom',
          status: 'Confirmed',
          attendees: ['AM', 'RJ'],
        ),
      ),
      PlannerEntry<ActivityMeta>(
        id: '10',
        time: PlannerTime(day: 3, hour: 11, minutes: 30, duration: 90),
        title: 'Focus block',
        content: 'Ship the API docs',
        color: ActivityType.focus.color,
        data: const ActivityMeta(
          type: ActivityType.focus,
          place: 'Desk 4',
          status: 'Confirmed',
          attendees: ['LM'],
        ),
      ),
      PlannerEntry<ActivityMeta>(
        id: '11',
        time: PlannerTime(day: 3, hour: 17, minutes: 30, duration: 60),
        title: 'Retrospective',
        content: 'What went well',
        color: ActivityType.social.color,
        data: const ActivityMeta(
          type: ActivityType.social,
          place: 'Room A',
          status: 'Confirmed',
          attendees: ['AM', 'BK', 'CD', 'YS', 'PV', 'LM', 'RJ'],
        ),
      ),

      // ── Column 4 (Fri): an overlapping pair + the day winds down. ─────────
      PlannerEntry<ActivityMeta>(
        id: '12',
        time: PlannerTime(day: 4, hour: 9, duration: 90),
        title: 'Demo prep',
        content: 'Dry-run the build',
        color: ActivityType.focus.color,
        data: const ActivityMeta(
          type: ActivityType.focus,
          place: 'Studio',
          status: 'Confirmed',
          attendees: ['AM', 'CD'],
        ),
      ),
      // Overlaps Demo prep (09:30–10:30 vs 09:00–10:30) — column-split on Fri.
      PlannerEntry<ActivityMeta>(
        id: '13',
        time: PlannerTime(day: 4, hour: 9, minutes: 30, duration: 60),
        title: 'Team demo',
        content: 'Show & tell',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(
          type: ActivityType.meeting,
          place: 'Room B',
          status: 'Confirmed',
          attendees: ['AM', 'BK', 'CD', 'YS', 'PV'],
        ),
      ),
      PlannerEntry<ActivityMeta>(
        id: '14',
        time: PlannerTime(day: 4, hour: 13, duration: 60),
        title: 'Release checklist',
        content: 'Final sign-off',
        color: ActivityType.focus.color,
        data: const ActivityMeta(
          type: ActivityType.focus,
          place: 'Desk 4',
          status: 'Tentative',
          attendees: ['AM'],
        ),
      ),
      PlannerEntry<ActivityMeta>(
        id: '15',
        time: PlannerTime(day: 4, hour: 17, duration: 120),
        title: 'Happy hour',
        content: 'Celebrate the release',
        color: ActivityType.social.color,
        data: const ActivityMeta(
          type: ActivityType.social,
          place: 'The Atrium',
          status: 'Tentative',
          attendees: ['AM', 'BK', 'CD', 'YS', 'PV', 'LM', 'RJ'],
        ),
      ),

      // ── All-day band: one event per column, so the band stays a single lane
      //    (the integration tests bake in a 28px one-lane band). ─────────────
      PlannerEntry<ActivityMeta>(
        id: 'ad-2',
        time: PlannerTime(day: 0, allDay: true),
        title: 'Crunch week',
        content: '',
        color: ActivityType.focus.color,
        data: const ActivityMeta(type: ActivityType.focus),
      ),
      PlannerEntry<ActivityMeta>(
        id: 'ad-3',
        time: PlannerTime(day: 1, allDay: true),
        title: 'Jordan out (PTO)',
        content: '',
        color: ActivityType.meeting.color,
        data: const ActivityMeta(type: ActivityType.meeting),
      ),
      PlannerEntry<ActivityMeta>(
        id: 'ad-0',
        time: PlannerTime(day: 2, allDay: true),
        title: 'Company offsite',
        content: '',
        color: ActivityType.social.color,
        data: const ActivityMeta(type: ActivityType.social),
      ),
      PlannerEntry<ActivityMeta>(
        id: 'ad-4',
        time: PlannerTime(day: 3, allDay: true),
        title: 'Hack day',
        content: '',
        color: ActivityType.focus.color,
        data: const ActivityMeta(type: ActivityType.focus),
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
