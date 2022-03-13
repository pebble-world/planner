import 'package:flutter/material.dart';
import 'package:planner/planner_time.dart';

import 'planner_entry.dart';

class PlannerConfig {
  List<String> labels;

  int minHour;
  int maxHour;

  int blockWidth;
  int blockHeight;

  TextStyle hourLabelStyle;
  TextStyle dateLabelStyle;

  Color hourBackground;
  Color dateBackground;
  Color plannerBackground = const Color.fromARGB(255, 50, 50, 50);
  Color horizontalLineColor = const Color.fromARGB(255, 100, 100, 100);
  Color verticalLineColor = const Color.fromARGB(255, 150, 150, 150);

  Function(PlannerTime time)? onPlannerDoubleTap;
  Function(PlannerEntry)? onEntryDoubleTap;
  Function(PlannerEntry)? onEntryChanged;

  PlannerConfig({
    required this.labels,
    this.minHour = 0,
    this.maxHour = 24,
    this.blockWidth = 200,
    this.blockHeight = 40,
    this.hourLabelStyle = const TextStyle(color: Colors.black),
    this.dateLabelStyle = const TextStyle(color: Colors.black),
    this.hourBackground = Colors.white,
    this.dateBackground = Colors.white,
    this.plannerBackground = const Color.fromARGB(255, 50, 50, 50),
    this.horizontalLineColor = const Color.fromARGB(255, 100, 100, 100),
    this.verticalLineColor = const Color.fromARGB(255, 150, 150, 150),
    this.onEntryChanged,
    this.onEntryDoubleTap,
    this.onPlannerDoubleTap,
  });
}
