import 'package:flutter/material.dart';
import 'package:planner/planner_time.dart';

import 'planner_entry.dart';

class PlannerConfig {
  List<String> labels;

  int minHour;
  int maxHour;

  /// Formats the integer hour shown in the left-hand hour column. Receives the
  /// hour-of-day (`minHour`..`maxHour`) and returns the label text. When `null`
  /// the hour is rendered as the bare integer (e.g. `9`, `17`).
  ///
  /// Use it for zero-padding, AM/PM, or `intl` formatting, e.g.
  /// `hourLabelFormatter: (h) => h.toString().padLeft(2, '0')` → `09`, `17`.
  String Function(int hour)? hourLabelFormatter;

  int blockWidth;
  int blockHeight;

  /// Granularity, in minutes, that event times snap to — for **both** creating
  /// an event by tapping an empty cell and dragging/resizing an existing one,
  /// so the two behave identically (the old code used different ad-hoc,
  /// zoom-dependent thresholds for each).
  ///
  /// Use a value that divides 60 evenly (e.g. `5`, `10`, `15`, `30`, `60`) so
  /// snaps land on clean sub-hour boundaries. A value `<= 1` disables snapping
  /// (minute precision). Snapping truncates rather than rounds, so a within-hour
  /// offset never spills into the next hour.
  int snapMinutes;

  /// Optional zoom-aware override of [snapMinutes]. When non-null it is called
  /// with the current zoom factor and its result is used as the snap interval
  /// for that frame, letting events snap more finely as the user zooms in, e.g.
  /// `snapMinutesForZoom: (z) => z >= 3 ? 5 : z >= 2 ? 15 : 30`. When null (the
  /// default) the flat [snapMinutes] applies at every zoom level.
  int Function(double zoom)? snapMinutesForZoom;

  /// Lower/upper bounds applied to the pinch/zoom factor in
  /// [Controller.updateZoom]. Without these the zoom could shrink toward 0
  /// (blocks collapse, hit-testing explodes) or grow without limit.
  double minZoom;
  double maxZoom;

  double dateRowHeight;
  double hourColumnWidth;

  TextStyle hourLabelStyle;
  TextStyle dateLabelStyle;
  TextStyle contextMenuTextStyle;
  TextStyle contextMenuDeleteTextStyle;

  Color hourBackground;
  Color dateBackground;
  Color plannerBackground = const Color.fromARGB(255, 50, 50, 50);
  Color horizontalLineColor = const Color.fromARGB(255, 100, 100, 100);
  Color verticalLineColor = const Color.fromARGB(255, 150, 150, 150);
  Color contextMenuBackground;

  Function(PlannerTime time)? onEntryCreate;
  Function(PlannerEntry)? onEntryEdit;
  Function(PlannerEntry)? onEntryDelete;
  Function(PlannerEntry)? onEntryMove;

  PlannerConfig({
    required this.labels,
    this.minHour = 0,
    this.maxHour = 23,
    this.hourLabelFormatter,
    this.blockWidth = 200,
    this.blockHeight = 40,
    this.snapMinutes = 15,
    this.snapMinutesForZoom,
    this.minZoom = 0.5,
    this.maxZoom = 4.0,
    this.hourLabelStyle = const TextStyle(color: Colors.black),
    this.dateLabelStyle = const TextStyle(color: Colors.black),
    this.contextMenuTextStyle = const TextStyle(color: Colors.blue),
    this.contextMenuDeleteTextStyle = const TextStyle(color: Colors.red),
    this.hourBackground = Colors.white,
    this.dateBackground = Colors.white,
    this.contextMenuBackground = Colors.white,
    this.plannerBackground = const Color.fromARGB(255, 50, 50, 50),
    this.horizontalLineColor = const Color.fromARGB(255, 100, 100, 100),
    this.verticalLineColor = const Color.fromARGB(255, 150, 150, 150),
    this.onEntryCreate,
    this.onEntryDelete,
    this.onEntryEdit,
    this.onEntryMove,
    this.dateRowHeight = 50,
    this.hourColumnWidth = 50,
  });
}
