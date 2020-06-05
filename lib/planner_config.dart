import 'package:flutter/material.dart';

import 'planner_entry.dart';

class PlannerConfig {
  List<String> labels = [];

  int minHour = 0;
  int maxHour = 24;

  int blockWidth = 200;
  int blockHeight = 40;

  TextStyle hourLabelStyle = TextStyle(color: Colors.white);
  TextStyle dateLabelStyle = TextStyle(color: Colors.white);


  Color hourBackground = Colors.black;
  Color dateBackground = Colors.black;
  Color plannerBackground = Colors.grey[900];
  Color horizontalLineColor = Colors.grey[800];
  Color verticalLineColor = Colors.grey[600];

  Function(int day, int hour, int minute) onPlannerDoubleTap;
  Function(PlannerEntry) onEntryDoubleTap;
  Function(PlannerEntry) onEntryChanged;
}