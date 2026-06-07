/// Optional, **non-core** calendar helpers for building an ordinary week-style
/// calendar on top of the date-agnostic [Planner] widget.
///
/// The widget itself has no notion of calendar dates: a `day` is just an index
/// into `PlannerConfig.labels` (ADR 0001 / #19). That keeps it a flexible
/// "N labelled columns × hours" grid, but it leaves a consumer building a real
/// week-calendar to own the `date ↔ column-index` mapping, week-stepping, and
/// "today" detection. This library ships those as a small, self-contained
/// utility so the common case is easy **without** changing the core model.
///
/// It is intentionally a *separate* import — it is **not** re-exported from
/// `package:planner/planner.dart`. Pull it in explicitly when you want it:
///
/// ```dart
/// import 'package:planner/planner.dart';
/// import 'package:planner/calendar.dart';
/// ```
///
/// Everything here is pure data: it produces `PlannerConfig.labels`, a
/// `highlightedColumn` index, and `PlannerEntry`/`PlannerTime` values that you
/// feed to the widget yourself.
library;

import 'package:intl/intl.dart';

import 'planner_entry.dart';
import 'planner_time.dart';

/// A fixed window of [dayCount] consecutive calendar days starting at [start],
/// and the `date ↔ column-index` mapping between those days and the planner's
/// columns. Column `0` is [start]; column `i` is the date `i` days later.
///
/// This is the bridge between real `DateTime`s and the widget's opaque day
/// indices. A consumer holds the current window, derives the widget inputs from
/// it ([labels], [todayColumn], [entriesFor]), and steps weeks with [next] /
/// [previous]. The widget never sees a `DateTime`.
///
/// Immutable and equatable, so it works as a state value you can diff.
class CalendarWindow {
  /// The date of column `0`, normalized to date-only (local midnight). The
  /// time-of-day of the value passed to the constructor is dropped, so every
  /// window aligns to whole calendar days.
  final DateTime start;

  /// The number of columns (consecutive days) in the window — match this to
  /// `PlannerConfig.labels.length`. A 7-day week is the default; pass `5` for a
  /// work week, `1` for a single day, etc.
  final int dayCount;

  /// Creates a window of [dayCount] days beginning on [start]'s calendar day.
  CalendarWindow({required DateTime start, this.dayCount = 7})
      : assert(dayCount > 0, 'dayCount must be positive'),
        start = DateTime(start.year, start.month, start.day);

  /// A week-aligned window: the [dayCount]-day window whose first column is the
  /// most recent [firstWeekday] on or before [anchor].
  ///
  /// [firstWeekday] uses the `DateTime.monday`..`DateTime.sunday` constants
  /// (`1`..`7`) and defaults to Monday, so `CalendarWindow.week(anchor: …)`
  /// snaps any date in a week to that week's Monday. Pass
  /// `firstWeekday: DateTime.sunday` for Sunday-first locales, or a smaller
  /// [dayCount] (e.g. `5`) for a Monday–Friday work week.
  factory CalendarWindow.week({
    required DateTime anchor,
    int firstWeekday = DateTime.monday,
    int dayCount = 7,
  }) {
    final date = DateTime(anchor.year, anchor.month, anchor.day);
    final back = (date.weekday - firstWeekday) % 7; // 0..6, never negative
    return CalendarWindow(start: _addDays(date, -back), dayCount: dayCount);
  }

  /// The date shown in column [index], normalized to date-only. [index] is not
  /// range-checked — values outside `0..dayCount-1` still return the date that
  /// many days from [start] (useful for peeking just past the edges).
  DateTime dateAt(int index) => _addDays(start, index);

  /// The column offset of [date] from column `0`, **unclamped**: `0` for
  /// [start]'s day, negative for days before the window, and `>= dayCount` for
  /// days after it. [indexOf] is this restricted to days inside the window.
  ///
  /// Only the calendar day matters; [date]'s time-of-day is ignored.
  int offsetOf(DateTime date) => _daysBetween(start, date);

  /// The column index of [date] within this window, or `null` if its calendar
  /// day falls outside `start .. start + dayCount - 1`.
  int? indexOf(DateTime date) {
    final i = offsetOf(date);
    return (i >= 0 && i < dayCount) ? i : null;
  }

  /// Whether [date]'s calendar day falls within the window.
  bool contains(DateTime date) => indexOf(date) != null;

  /// The date of every column, in order (length == [dayCount]).
  List<DateTime> get dates => [for (var i = 0; i < dayCount; i++) dateAt(i)];

  /// The next window of the same length — i.e. step forward one window (one
  /// week for the default `dayCount: 7`). Use for "next week" navigation.
  CalendarWindow get next =>
      CalendarWindow(start: _addDays(start, dayCount), dayCount: dayCount);

  /// The previous window of the same length — step back one window.
  CalendarWindow get previous =>
      CalendarWindow(start: _addDays(start, -dayCount), dayCount: dayCount);

  /// The column labels for `PlannerConfig.labels`, one per column.
  ///
  /// [format] turns each column's date into its header string; when omitted it
  /// defaults to a localized `EEE d` (e.g. `Mon 8`) via `intl`'s [DateFormat],
  /// honouring [Intl.defaultLocale]. Pass your own for a different format or
  /// explicit locale, e.g. `labels((d) => DateFormat.MMMEd('fr_FR').format(d))`.
  List<String> labels([String Function(DateTime date)? format]) {
    final fmt = format ?? _defaultLabel;
    return [for (final d in dates) fmt(d)];
  }

  /// The column index of today (`DateTime.now()`), or `null` if today is
  /// outside this window. Feed it straight to `PlannerConfig.highlightedColumn`
  /// for a "today" highlight (a `null` highlights nothing, which is exactly the
  /// right behaviour when today is in another week).
  int? get todayColumn => indexOf(DateTime.now());

  /// The `PlannerTime` placing an event that starts at [start] and lasts
  /// [duration] in this window, or `null` if [start]'s calendar day is outside
  /// the window. The column comes from [start]'s date; the row comes from its
  /// wall-clock [DateTime.hour] / [DateTime.minute]; [duration] is rounded to
  /// whole minutes (clamped to a `1` minimum).
  ///
  /// Pass [end] to make the event span columns (#47): its column range becomes
  /// `start .. end`, clamped to the window's last column if [end] runs past the
  /// edge. The span renders as a band at the [start] time repeated across those
  /// columns — the model is index-based, not a true running multi-day range
  /// (ADR 0001). An [end] that is not after [start]'s column is ignored, giving
  /// a single-column event.
  PlannerTime? timeFor(
    DateTime start, {
    Duration duration = const Duration(hours: 1),
    DateTime? end,
  }) {
    final day = indexOf(start);
    if (day == null) return null;

    int? endDay;
    if (end != null) {
      final lastOffset = offsetOf(end);
      if (lastOffset > day) {
        endDay = lastOffset >= dayCount ? dayCount - 1 : lastOffset;
      }
    }

    final minutes = duration.inMinutes;
    return PlannerTime(
      day: day,
      endDay: endDay,
      hour: start.hour,
      minutes: start.minute,
      duration: minutes < 1 ? 1 : minutes,
    );
  }

  /// Builds the `PlannerEntry` list for this window from your own dated
  /// [events], dropping any whose start date falls outside the window.
  ///
  /// [start] reads each event's start `DateTime`; [build] turns an event plus
  /// its computed [PlannerTime] into a `PlannerEntry` (you own the id, title,
  /// colour and styles). [duration] supplies each event's length (default one
  /// hour) and [end] an optional end date for a column-spanning event (#47) —
  /// both via callbacks so they read from your own model:
  ///
  /// ```dart
  /// final entries = window.entriesFor(
  ///   myMeetings,
  ///   start: (m) => m.startsAt,
  ///   duration: (m) => m.length,
  ///   build: (m, time) => PlannerEntry(
  ///     id: m.id, time: time, title: m.title, content: m.notes,
  ///     color: m.color,
  ///   ),
  /// );
  /// ```
  List<PlannerEntry> entriesFor<T>(
    Iterable<T> events, {
    required DateTime Function(T event) start,
    required PlannerEntry Function(T event, PlannerTime time) build,
    Duration Function(T event)? duration,
    DateTime Function(T event)? end,
  }) {
    final result = <PlannerEntry>[];
    for (final event in events) {
      final time = timeFor(
        start(event),
        duration: duration?.call(event) ?? const Duration(hours: 1),
        end: end?.call(event),
      );
      if (time != null) result.add(build(event, time));
    }
    return result;
  }

  static String _defaultLabel(DateTime date) =>
      DateFormat('EEE d').format(date);

  /// Adds [days] to [date] via the `DateTime` constructor (which normalizes
  /// month/year overflow) rather than `Duration` arithmetic, so it lands on the
  /// right calendar day even across a daylight-saving transition.
  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// Whole calendar days from [from] to [to]. Both are reduced to date-only and
  /// the hour difference is divided by 24 and rounded, so a 23- or 25-hour DST
  /// day still counts as one day.
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return (b.difference(a).inHours / 24).round();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarWindow &&
          other.start == start &&
          other.dayCount == dayCount;

  @override
  int get hashCode => Object.hash(start, dayCount);

  @override
  String toString() => 'CalendarWindow(start: $start, dayCount: $dayCount)';
}
