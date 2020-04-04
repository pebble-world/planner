import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:planner/config.dart';
import 'package:planner/planner_date_pos.dart';
import 'package:planner/planner_entry.dart';

class ManagerProvider with ChangeNotifier {
  ManagerProvider({@required List<PlannerEntry> entries, @required this.config}) {
    _canvasWidth = blockWidth * config.colums.length;
    _canvasHeight = blockHeight * (config.maxHour - config.minHour);
    updateEntries(entries);
  }

  Config config;
  List<PlannerEntry> _entries;
  List<PlannerEntry> get entries => _entries;

  void updateEntries(List<PlannerEntry> entries){
    this._entries = entries;
    entries.forEach((entry) {
      entry.createPainters(config);
    });
    notifyListeners();
  }
  void addEntry(PlannerEntry entry){
    entry.createPainters(config);
    _entries.add(entry);
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
    _entries.forEach((entry) {
      if (entry.canvasRect.contains(canvasPos)) {
        result = entry;
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
    print("zoom $_zoom");
    return result;
  }

  void setSize(double width, double height) {
    this._screenWidth = width;
    this._screenHeight = height;
    _scale = this._screenWidth / _canvasWidth;
    _zoom = _screenHeight / _canvasHeight / _scale;
    debugPrint('scale to: ${_scale.toString()}');
    debugPrint('_zoom to: ${_zoom.toString()}');
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
