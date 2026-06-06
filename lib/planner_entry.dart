import 'package:flutter/material.dart';

import 'planner_time.dart';

class PlannerEntry {
  String id;
  PlannerTime time;

  final Color color;

  final TextStyle titleStyle;
  final TextStyle textStyle;

  final String title;
  final String content;

  PlannerEntry({
    required this.id,
    required this.time,
    required this.title,
    required this.content,
    required this.color,
    this.titleStyle = const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
    this.textStyle = const TextStyle(fontSize: 10, color: Colors.white),
  });
}
