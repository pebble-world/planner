import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../planner_config.dart';

class Controller {
  final triggerUpdate = ValueNotifier<int>(0);

  double _x = 0;
  double get x => _x;
  set x(double value) {
    _x = value;
    triggerUpdate.value++;
  }

  double _y = 0;
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
    print('touchpos update');
  }

  Offset get offset => Offset(x, y);

  double _previousZoom = 1;
  double _zoom = 1;
  double get zoom => _zoom;

  double _hDragStart = 0;
  double _hDrag = 0;

  double _vDragStart = 0;
  double _vDrag = 0;

  late double _minXOffset, _maxXOffset;
  late double _minYOffset, _maxYOffset;

  double _canvasWidth = 0;
  double _canvasHeight = 0;

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
                _canvasHeight) -
            20);
    if (_maxYOffset > 0) {
      _maxYOffset = 0;
    }
    print(
        'maxyoffset: $_maxYOffset | zoom: $zoom  | canvasheight: $_canvasHeight');
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
    print('vdrag : $_vDrag');

    if (_vDrag > _minYOffset) {
      _vDrag = _minYOffset;
    } else if (_vDrag < (_maxYOffset)) {
      _vDrag = _maxYOffset;
    }
    y = _vDrag;
  }

  void startZoom() {
    _previousZoom = _zoom;
  }

  void updateZoom(double scale) {
    _zoom = _previousZoom * scale;
    _calculateOffsets();
    triggerUpdate.value++;
  }
}
