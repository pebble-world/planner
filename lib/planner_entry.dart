import 'package:flutter/material.dart';

import 'planner_time.dart';

/// A single event drawn on the planner: its [id], its [time] (day column /
/// start / duration), display [title]/[content], fill [color] and text styles.
///
/// Immutable (#27): every field is `final`, so a drag/resize or accessibility
/// nudge produces a *new* instance via [copyWith] (carrying a new [PlannerTime])
/// reported through the host callbacks, instead of mutating the entry in place.
/// Value [==] means two entries with the same fields compare equal, so hosts
/// can diff entry lists.
class PlannerEntry {
  final String id;
  final PlannerTime time;

  final Color color;

  final TextStyle titleStyle;
  final TextStyle textStyle;

  final String title;
  final String content;

  const PlannerEntry({
    required this.id,
    required this.time,
    required this.title,
    required this.content,
    required this.color,
    this.titleStyle = const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
    this.textStyle = const TextStyle(fontSize: 10, color: Colors.white),
  });

  /// Returns a copy with the given fields replaced; omitted fields are kept.
  PlannerEntry copyWith({
    String? id,
    PlannerTime? time,
    Color? color,
    TextStyle? titleStyle,
    TextStyle? textStyle,
    String? title,
    String? content,
  }) =>
      PlannerEntry(
        id: id ?? this.id,
        time: time ?? this.time,
        color: color ?? this.color,
        titleStyle: titleStyle ?? this.titleStyle,
        textStyle: textStyle ?? this.textStyle,
        title: title ?? this.title,
        content: content ?? this.content,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannerEntry &&
          other.id == id &&
          other.time == time &&
          other.color == color &&
          other.titleStyle == titleStyle &&
          other.textStyle == textStyle &&
          other.title == title &&
          other.content == content;

  @override
  int get hashCode =>
      Object.hash(id, time, color, titleStyle, textStyle, title, content);

  @override
  String toString() => 'PlannerEntry(id: $id, time: $time, title: $title)';
}
