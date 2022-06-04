import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../planner_config.dart';
import '../planner_time.dart';
import 'event.dart';

enum MenuType {
  planner,
  entry,
  none,
}

class Controller {
  final triggerUpdate = ValueNotifier<int>(0);

  static double _x = 0;
  double get x => _x;
  set x(double value) {
    _x = value;
    triggerUpdate.value++;
  }

  static double _y = 0;
  double get y => _y;
  set y(double value) {
    _y = value;
    triggerUpdate.value++;
  }

  Offset? _touchPos;
  Offset? get touchPos => _touchPos;
  set touchPos(Offset? value) {
    _touchPos = value;
    triggerUpdate.value++;
  }

  Offset get offset => Offset(x, y);

  static double _previousZoom = 1;
  static double _zoom = 1;
  double get zoom => _zoom;

  static double _hDragStart = 0;
  static double _hDrag = 0;

  double _vDragStart = 0;
  double _vDrag = 0;

  late double _minXOffset, _maxXOffset;
  late double _minYOffset, _maxYOffset;

  double _canvasWidth = 0;
  double _canvasHeight = 0;

  MenuType menuType = MenuType.none;
  Offset? menuPos;
  Event? menuEvent;
  PlannerTime? menuTime;
  Function? _onCloseMenu;

  final PlannerConfig config;

  Controller(this.config) {
    _calculateOffsets();
  }

  void setSize(Size? size) {
    if (size != null) {
      _canvasWidth = size.width > 0 ? size.width : _canvasWidth;
      _canvasHeight = size.height > 0 ? size.height : _canvasHeight;

      _calculateOffsets();
    }
  }

  void _calculateOffsets() {
    _minXOffset = 0;
    _maxXOffset =
        0 - ((config.blockWidth * config.labels.length) - _canvasWidth) - 50;
    _minYOffset = 0;
    _maxYOffset = 0 -
        (((config.blockHeight * zoom) * (config.maxHour - config.minHour + 1) -
            (_canvasHeight - config.dateRowHeight)));
    if (_maxYOffset > 0) {
      _maxYOffset = 0;
    }
  }

  void startHorizontalDrag(double xValue) {
    _hDragStart = xValue;
    _hDrag = x;
  }

  void updateHorizontalDrag(double xValue) {
    _hDrag += xValue - _hDragStart;
    _hDragStart = xValue;
    if (_hDrag > _minXOffset) {
      _hDrag = _minXOffset;
    } else if (_hDrag < _maxXOffset) {
      _hDrag = _maxXOffset;
    }
    x = _hDrag;
  }

  void startVerticalDrag(double yValue) {
    _vDragStart = yValue;
    _vDrag = y;
  }

  void updateVerticalDrag(double yValue) {
    _vDrag += yValue - _vDragStart;
    _vDragStart = yValue;

    if (_vDrag > _minYOffset) {
      _vDrag = _minYOffset;
    } else if (_vDrag < (_maxYOffset)) {
      _vDrag = _maxYOffset;
    }
    y = _vDrag;
  }

  void verticalScroll(bool up) {
    y += up ? -20 : 20;
    if (y > _minYOffset) {
      y = _minYOffset;
    } else if (y < (_maxYOffset)) {
      y = _maxYOffset;
    }
  }

  void startZoom() {
    _previousZoom = _zoom;
  }

  void updateZoom(double scale) {
    _zoom = _previousZoom * scale;
    _calculateOffsets();
    triggerUpdate.value++;
  }

  void showEventMenu(Offset pos, Event? event, Function onClose) {
    menuPos = pos;
    menuType = MenuType.entry;
    menuEvent = event;
    menuTime = null;
    _onCloseMenu = onClose;
  }

  void showPlannerMenu(Offset pos, PlannerTime time, Function onClose) {
    menuPos = pos;
    menuType = MenuType.planner;
    menuEvent = null;
    menuTime = time;
  }

  void hideMenu() {
    menuType = MenuType.none;
    menuEvent = null;
    menuTime = null;
    if (_onCloseMenu != null) {
      _onCloseMenu!();
    }
  }
}
