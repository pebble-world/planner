import 'package:flutter/material.dart';

import 'planner_time.dart';

/// A single event drawn on the planner: its [id], its [time] (day column /
/// start / duration), display [title]/[content], fill [color] and text styles,
/// plus an optional typed [data] payload (#77) for carrying app domain metadata.
///
/// Generic over the [data] payload type [T] (#77): an untyped `PlannerEntry(...)`
/// infers `T == dynamic` and behaves exactly as before, while
/// `PlannerEntry<ActivityMeta>(...)` makes [data] a typed `ActivityMeta?`. The
/// type threads through `PlannerConfig<T>`, `Planner<T>` and the entry callbacks,
/// so a host reads `entry.data` already typed — no side-map keyed by [id] and no
/// cast. It is the foundation for the custom event/chip builders (#75/#78): the
/// package itself never reads [data], it only carries it through.
///
/// Immutable (#27): every field is `final`, so a drag/resize or accessibility
/// nudge produces a *new* instance via [copyWith] (carrying a new [PlannerTime])
/// reported through the host callbacks, instead of mutating the entry in place.
/// Value [==] means two entries with the same fields compare equal, so hosts
/// can diff entry lists.
class PlannerEntry<T> {
  final String id;
  final PlannerTime time;

  final Color color;

  final TextStyle titleStyle;
  final TextStyle textStyle;

  final String title;
  final String content;

  /// Optional app domain metadata carried alongside the event (#77), typed [T].
  /// The package never reads it — it threads it through so custom event/chip
  /// builders and the host callbacks get the typed value back. `null` when no
  /// payload is supplied (and always `null` for an untyped `T == dynamic` entry
  /// that omits it).
  final T? data;

  const PlannerEntry({
    required this.id,
    required this.time,
    required this.title,
    required this.content,
    required this.color,
    this.data,
    this.titleStyle = const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
    this.textStyle = const TextStyle(fontSize: 10, color: Colors.white),
  });

  /// Returns a copy with the given fields replaced; omitted fields are kept.
  ///
  /// [data] follows the same `data ?? this.data` rule as every other field, so
  /// in this first cut (#77) it can be set or changed but **not reset to
  /// `null`**; a sentinel can be added later if clearing the payload is needed.
  PlannerEntry<T> copyWith({
    String? id,
    PlannerTime? time,
    Color? color,
    TextStyle? titleStyle,
    TextStyle? textStyle,
    String? title,
    String? content,
    T? data,
  }) =>
      PlannerEntry<T>(
        id: id ?? this.id,
        time: time ?? this.time,
        color: color ?? this.color,
        titleStyle: titleStyle ?? this.titleStyle,
        textStyle: textStyle ?? this.textStyle,
        title: title ?? this.title,
        content: content ?? this.content,
        data: data ?? this.data,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannerEntry<T> &&
          other.id == id &&
          other.time == time &&
          other.color == color &&
          other.titleStyle == titleStyle &&
          other.textStyle == textStyle &&
          other.title == title &&
          other.content == content &&
          other.data == data;

  @override
  int get hashCode =>
      Object.hash(id, time, color, titleStyle, textStyle, title, content, data);

  @override
  String toString() => 'PlannerEntry(id: $id, time: $time, title: $title)';
}
