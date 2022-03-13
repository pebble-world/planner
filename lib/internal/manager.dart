import 'package:flutter/material.dart';
import 'package:planner/internal/event.dart';
import 'package:planner/planner.dart';

import '../planner_time.dart';
import 'controller.dart';

class Manager {
  final PlannerConfig config;
  final List<PlannerEntry> entries;
  late Controller controller;
  final List<Event> events = [];

  Manager({
    required this.config,
    required this.entries,
  }) {
    controller = Controller(config);
    for (PlannerEntry entry in entries) {
      events.add(Event(entry: entry, manager: this));
    }
  }

  Event? getEventAtPos(Offset pos) {
    Offset realPos = Offset(pos.dx - controller.offset.dx,
        (pos.dy - controller.offset.dy) / controller.zoom);

    for (Event event in events) {
      if (event.canvasRect.contains(realPos)) {
        return event;
      }
    }

    return null;
  }

  PlannerTime getTimeAtPos(Offset pos) {
    Offset realPos = Offset(pos.dx - controller.offset.dx,
        (pos.dy - controller.offset.dy) / controller.zoom);

    int day = (realPos.dx / config.blockWidth).floor();
    int hour = config.minHour + (realPos.dy / config.blockHeight).floor();
    int minutes = 0;
    if (controller.zoom > 2.25) {
      minutes = ((realPos.dy.toInt() % config.blockHeight) / 10).floor() * 15;
    } else if (controller.zoom > 1.25) {
      minutes = ((realPos.dy.toInt() % config.blockHeight) / 20).floor() * 30;
    }
    return PlannerTime(day: day, hour: hour, minutes: minutes);
  }
}
