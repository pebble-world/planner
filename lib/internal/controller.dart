import 'package:flutter/material.dart';

import '../planner.dart';
import 'event.dart';

enum MenuType {
  planner,
  entry,
  none,
}

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

  // Vertical chrome reserved above the time grid besides the date row — the
  // all-day band's height (#48), or 0 when no band is shown. Subtracted from the
  // grid viewport when computing the time-axis scroll clamp so the grid can't
  // over-scroll by the band's height.
  double _reservedHeight = 0;

  MenuType menuType = MenuType.none;
  Offset? menuPos;
  Event? menuEvent;
  PlannerTime? menuTime;
  Function? _onCloseMenu;

  PlannerConfig config;

  Controller(this.config) {
    _calculateOffsets();
  }

  /// Adopts a new [config] (e.g. when the host `Planner` is rebuilt with
  /// different settings) and recomputes the scroll bounds, while leaving the
  /// current scroll/zoom position untouched.
  void updateConfig(PlannerConfig config) {
    this.config = config;
    _calculateOffsets();
  }

  void setSize(Size? size) {
    if (size != null) {
      _canvasWidth = size.width > 0 ? size.width : _canvasWidth;
      _canvasHeight = size.height > 0 ? size.height : _canvasHeight;

      _calculateOffsets();
    }
  }

  /// Records the height of the chrome reserved above the time grid besides the
  /// date row — the all-day band (#48). Recomputes the scroll clamp so the grid
  /// viewport excludes the band. A no-op when the height is unchanged.
  void setReservedHeight(double height) {
    if (height == _reservedHeight) return;
    _reservedHeight = height;
    _calculateOffsets();
  }

  void _calculateOffsets() {
    _minXOffset = 0;
    _maxXOffset =
        0 - ((config.blockWidth * config.labels.length) - _canvasWidth) - 50;
    _minYOffset = 0;
    _maxYOffset = 0 -
        (((config.blockHeight * zoom) * (config.maxHour - config.minHour + 1) -
            (_canvasHeight - config.dateRowHeight - _reservedHeight)));
    if (_maxXOffset > 0) {
      _maxXOffset = 0;
    }
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
    // Scale the step by the current zoom so one wheel notch always moves the
    // same amount of *time*: each hour-row is `blockHeight * zoom` px tall, so a
    // fixed pixel step (the old hardcoded 20) moved progressively less time the
    // further you zoomed in. `step / (blockHeight * zoom)` hours is now constant.
    final step = config.scrollStep * zoom;
    y += up ? -step : step;
    if (y > _minYOffset) {
      y = _minYOffset;
    } else if (y < (_maxYOffset)) {
      y = _maxYOffset;
    }
  }

  /// Scrolls the day-axis by one wheel notch — the Shift+wheel horizontal scroll
  /// (#65). [forward] (a wheel-down notch) reveals later columns by decreasing
  /// [x]; the reverse reveals earlier ones. The step is the flat
  /// [PlannerConfig.scrollStep]: unlike the time axis, columns are a fixed
  /// [PlannerConfig.blockWidth] wide and don't scale with zoom, so a notch always
  /// moves the same distance. Clamped to the same `[_maxXOffset, _minXOffset]`
  /// bounds as a horizontal drag, so it can't reveal past the grid edges.
  void horizontalScroll(bool forward) {
    final step = config.scrollStep;
    x += forward ? -step : step;
    if (x > _minXOffset) {
      x = _minXOffset;
    } else if (x < _maxXOffset) {
      x = _maxXOffset;
    }
  }

  void startZoom() {
    _previousZoom = _zoom;
  }

  void updateZoom(double scale) {
    _zoom = (_previousZoom * scale)
        .clamp(config.minZoom, config.maxZoom)
        .toDouble();
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
