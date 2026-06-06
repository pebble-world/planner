/// The position of an event on the planner grid: a [day] column index (into
/// `PlannerConfig.labels` — there are no calendar dates here), a start [hour]
/// and [minutes], and a [duration] in minutes.
///
/// Immutable (#27): every field is `final`, so a drag/resize or accessibility
/// nudge produces a *new* instance via [copyWith] rather than mutating in place,
/// which keeps diffing predictable and lets value [==] decide when anything
/// actually changed.
class PlannerTime {
  final int day;
  final int hour;
  final int minutes;
  final int duration;

  PlannerTime(
      {this.day = 0, this.hour = 0, this.minutes = 0, this.duration = 60});

  /// Returns a copy with the given fields replaced; omitted fields are kept.
  PlannerTime copyWith({int? day, int? hour, int? minutes, int? duration}) =>
      PlannerTime(
        day: day ?? this.day,
        hour: hour ?? this.hour,
        minutes: minutes ?? this.minutes,
        duration: duration ?? this.duration,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannerTime &&
          other.day == day &&
          other.hour == hour &&
          other.minutes == minutes &&
          other.duration == duration;

  @override
  int get hashCode => Object.hash(day, hour, minutes, duration);

  @override
  String toString() =>
      'PlannerTime(day: $day, hour: $hour, minutes: $minutes, duration: $duration)';
}
