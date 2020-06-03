import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:planner/config.dart';
import 'package:planner/planner_date_pos.dart';
import 'package:planner/planner_entry.dart';

class ManagerProvider with ChangeNotifier {
  ManagerProvider({@required List<PlannerEntry> entries, @required config}) {
    updateConfig(config);
    updateEntries(entries);
  }

  Config _config;
  Config get config => _config;
  void updateConfig(Config config) {
    this._config = config;
    _canvasWidth = blockWidth * config.colums.length;
    _canvasHeight = blockHeight * (config.maxHour - config.minHour);
  }

  Map<UniqueKey, PlannerEntry> _entries;
  List<PlannerEntry> get entries => _entries.entries.map((e) => e.value).toList();

  void updateEntries(List<PlannerEntry> entries) {
    this._entries = Map.fromIterable(entries, key: (e) => e.key, value: (e) => e);
    _entries.values.forEach((entry) {
      entry.createPainters(config);
    });
    notifyListeners();
  }

  void addEntry(PlannerEntry entry) {
    _entries.update(
      entry.key,
      // You can ignore the incoming parameter if you want to always update the value even if it is already in the map
      (existingValue) => entry,
      ifAbsent: () => entry,
    );
    entry.createPainters(config);
    notifyListeners();
  }

  int blockWidth = 200;
  int blockHeight = 40;
  int _canvasWidth;
  int _canvasHeight;

  double _screenWidth;
  double _screenHeight;
  double _scale = 1;
  double _zoom = 1;

  Offset eventsPainterOffset = Offset.zero;

  Offset _touchPos;
  Offset get touchPos => _touchPos;
  set touchPos(Offset pos) {
    _touchPos = pos;
    if (_touchPos != null) {
      _touchPos -= eventsPainterOffset;
      _touchPos = getCanvasPosition(_touchPos);
    }
  }

  // method is used on double tap. Returns zero when not tapped on entry
  PlannerEntry getPlannerEntry(Offset position) {
    Offset canvasPos = getCanvasPosition(position - eventsPainterOffset);
    PlannerEntry result;
    _entries.entries.forEach((entry) {
      if (entry.value.canvasRect.contains(canvasPos)) {
        result = entry.value;
      }
    });
    return result;
  }

  PlannerDatePos getPlannerDatePos(Offset position) {
    Offset canvasPos = getCanvasPosition(position - eventsPainterOffset);
    PlannerDatePos result = new PlannerDatePos();
    result.column = (canvasPos.dx / blockWidth).floor();
    result.hour = config.minHour + (canvasPos.dy / blockHeight).floor();
    result.minutes = ((canvasPos.dy.toInt() % blockHeight) / 10).floor() * 15;
    return result;
  }

  void setSize(double width, double height) {
    this._screenWidth = width;
    this._screenHeight = height;
    _scale = this._screenWidth / _canvasWidth;
    _zoom = _screenHeight / _canvasHeight / _scale;
  }

  Offset getScreenPosition(Offset canvasPos) {
    return Offset(canvasPos.dx * _scale, canvasPos.dy * _scale * _zoom);
  }

  Offset getCanvasPosition(Offset screenPos) {
    return Offset((screenPos.dx) / _scale, (screenPos.dy) / _scale / _zoom);
  }

  num getScale() {
    return _scale;
  }

  void redraw() {
    notifyListeners();
  }
}
