/// The position of an event on the planner grid: a [day] column index (into
/// `PlannerConfig.labels` — there are no calendar dates here), a start [hour]
/// and [minutes], and a [duration] in minutes.
///
/// An event may also **span columns** (#47): when [endDay] is set to a column
/// index after [day], the event renders across the whole `day..endDay` range
/// (a multi-day / multi-column event). This stays index-based — no `DateTime`
/// enters the model (ADR 0001). [endDay] of `null` (or any value `<= day`) is a
/// single-column event, the default.
///
/// Immutable (#27): every field is `final`, so a drag/resize or accessibility
/// nudge produces a *new* instance via [copyWith] rather than mutating in place,
/// which keeps diffing predictable and lets value [==] decide when anything
/// actually changed.
class PlannerTime {
  final int day;

  /// Last column the event covers, inclusive. `null` (or `<= day`) means the
  /// event occupies the single column [day]. When greater than [day] the event
  /// spans the columns `day..endDay` — see [lastDay] / [columnSpan] for the
  /// normalized values the geometry uses.
  final int? endDay;

  final int hour;
  final int minutes;
  final int duration;

  PlannerTime(
      {this.day = 0,
      this.endDay,
      this.hour = 0,
      this.minutes = 0,
      this.duration = 60});

  /// The last column the event covers, inclusive and never before [day]: the
  /// raw [endDay] when it lies after [day], otherwise [day] itself. Geometry and
  /// hit-testing iterate `day..lastDay`.
  int get lastDay => (endDay != null && endDay! > day) ? endDay! : day;

  /// How many columns the event covers (`1` for a single-column event).
  int get columnSpan => lastDay - day + 1;

  /// Whether the event covers more than one column (a spanning event).
  bool get spansColumns => columnSpan > 1;

  /// Returns a copy with the given fields replaced; omitted fields are kept.
  PlannerTime copyWith(
          {int? day, int? endDay, int? hour, int? minutes, int? duration}) =>
      PlannerTime(
        day: day ?? this.day,
        endDay: endDay ?? this.endDay,
        hour: hour ?? this.hour,
        minutes: minutes ?? this.minutes,
        duration: duration ?? this.duration,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannerTime &&
          other.day == day &&
          other.endDay == endDay &&
          other.hour == hour &&
          other.minutes == minutes &&
          other.duration == duration;

  @override
  int get hashCode => Object.hash(day, endDay, hour, minutes, duration);

  @override
  String toString() =>
      'PlannerTime(day: $day, endDay: $endDay, hour: $hour, minutes: $minutes, duration: $duration)';
}
