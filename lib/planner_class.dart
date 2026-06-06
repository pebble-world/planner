import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'internal/context_menu.dart';
import 'internal/controller.dart';
import 'internal/events_painter.dart';
import 'internal/hour_column.dart';
import 'internal/scroll_detector.dart';
import 'internal/positioned_tap_detector_2.dart';
import 'internal/date_row.dart';
import 'internal/manager.dart';
import 'planner_entry.dart';
import 'planner_config.dart';

/// What a single in-progress events-canvas gesture is doing. Decided when the
/// unified [ScaleGestureRecognizer] starts and refined to [zoom] as soon as a
/// second pointer joins, so pan and zoom no longer fight in the gesture arena
/// (the old layout combined a horizontal-drag recognizer with scale).
enum _GestureMode { idle, pan, zoom }

class Planner extends StatefulWidget {
  final List<PlannerEntry> entries;
  final PlannerConfig config;

  const Planner({
    super.key,
    required this.config,
    required this.entries,
  });

  @override
  State<Planner> createState() => _PlannerState();
}

class _PlannerState extends State<Planner> {
  // Owned by the State so it survives parent rebuilds: building it in the widget
  // constructor recreated the Manager (every Event, every TextPainter, the whole
  // Grid) on every parent build and forced the Controller's scroll/zoom to be
  // static to survive that churn.
  late Manager _data;

  // Drives the position-aware double-tap detector from the single events
  // GestureDetector below. Nesting a second tap detector (the old layout) let
  // the inner detector win the gesture arena, so the double-tap stream was
  // never fed and onEntryEdit/onEntryCreate never fired (#40). Feeding the
  // detector through its controller keeps one detector in the arena.
  final PositionedTapController _tapController = PositionedTapController();

  // What the current events-canvas drag is doing. Set when the unified scale
  // recognizer starts (single pointer => pan) and switched to zoom the moment a
  // second pointer joins, so a one-finger pan and a pinch-zoom can't both apply
  // to the same gesture (the old detector ran horizontal-drag and scale at once).
  _GestureMode _mode = _GestureMode.idle;

  @override
  void initState() {
    super.initState();
    _data = Manager(config: widget.config, entries: widget.entries);
  }

  @override
  void didUpdateWidget(covariant Planner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.config, widget.config) ||
        !identical(oldWidget.entries, widget.entries)) {
      _data.update(config: widget.config, entries: widget.entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _data.controller.setSize(constraints.biggest);
      return Column(
        children: [
          paintDates(),
          Expanded(
            child: Row(
              children: [
                paintHours(),
                Expanded(
                  child: Stack(
                    children: [
                      PositionedTapDetector2(
                        controller: _tapController,
                        onDoubleTap: (position) {
                          if (position.relative == null) {
                            return;
                          }
                          var event = _data.getEventAtPos(position.relative!);
                          if (event != null &&
                              _data.config.onEntryEdit != null) {
                            _data.config.onEntryEdit!(event.entry);
                          } else if (event == null &&
                              _data.config.onEntryCreate != null) {
                            var time = _data.getTimeAtPos(position.relative!);
                            _data.config.onEntryCreate!(time);
                          }
                        },
                        child: paintEvents(),
                      ),
                      paintZoomButtons(context),
                      ...paintMenu(),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      );
    });
  }

  List<Widget> paintMenu() {
    List<Widget> result = [];
    if (_data.controller.menuType != MenuType.none) {
      result.add(
        Positioned.fill(child: Container(color: Colors.transparent)),
      );

      result.add(
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => _data.controller.hideMenu(),
          onTap: () => _data.controller.hideMenu(),
          onSecondaryTapDown: (_) => _data.controller.hideMenu(),
          child: Container(),
        ),
      );

      result.add(
        Transform.translate(
          offset: _data.controller.menuPos!,
          child: ContextMenu(manager: _data),
        ),
      );
    }
    return result;
  }

  GestureDetector paintDates() {
    return GestureDetector(
      onHorizontalDragStart: (detail) =>
          _data.controller.startHorizontalDrag(detail.globalPosition.dx),
      onHorizontalDragUpdate: (detail) =>
          _data.controller.updateHorizontalDrag(detail.globalPosition.dx),
      child: ClipRect(
        child: Container(
          height: _data.config.dateRowHeight,
          color: _data.config.dateBackground,
          child: CustomPaint(
            painter: DateRow(
              manager: _data,
              repaint: _data.controller.triggerUpdate,
            ),
            child: Container(),
          ),
        ),
      ),
    );
  }

  Widget paintZoomButtons(BuildContext context) {
    // Hosts that drive zoom themselves (pinch, own chrome) can hide the built-in
    // controls via config; an empty box keeps the Stack child list stable.
    if (!_data.config.showZoomControls) {
      return const SizedBox.shrink();
    }

    // Fall back to the previous hardcoded theme colour when no override is set.
    final Color fillColor =
        _data.config.zoomButtonColor ?? Theme.of(context).colorScheme.secondary;
    final Color iconColor = _data.config.zoomButtonIconColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: IconButton(
            onPressed: () {
              _data.controller.startZoom();
              _data.controller.updateZoom(0.9);
            },
            iconSize: 22.0,
            padding: const EdgeInsets.all(4.0),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              backgroundColor: fillColor,
              elevation: 2.0,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              Icons.zoom_out,
              color: iconColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: IconButton(
            onPressed: () {
              _data.controller.startZoom();
              _data.controller.updateZoom(1.1);
            },
            iconSize: 22.0,
            padding: const EdgeInsets.all(4.0),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              backgroundColor: fillColor,
              elevation: 2.0,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              Icons.zoom_in,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }

  // --- Events-canvas gesture handlers ---------------------------------------
  // One ScaleGestureRecognizer drives both pan and zoom (a one-finger drag pans;
  // a multi-finger pinch zooms), replacing the old horizontal-drag + scale combo
  // that fought in the gesture arena. Move/resize stays on the long-press
  // recognizer for now (unchanged behaviour); the desktop immediate-drag path
  // arrives in a later commit.

  void _onScaleStart(ScaleStartDetails details) {
    // Single pointer => pan; switched to zoom in _onScaleUpdate once a second
    // pointer joins. Pan is horizontal-only here, matching the previous
    // horizontal-drag recognizer; startZoom captures the pre-gesture zoom so a
    // pinch that begins mid-gesture stays continuous.
    _mode = _GestureMode.pan;
    _data.controller.startHorizontalDrag(details.focalPoint.dx);
    _data.controller.startZoom();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      _mode = _GestureMode.zoom;
      _data.controller.updateZoom(details.verticalScale);
    } else if (_mode == _GestureMode.pan) {
      _data.controller.updateHorizontalDrag(details.focalPoint.dx);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _mode = _GestureMode.idle;
  }

  Widget paintEvents() {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        // Pan (one finger) + zoom (pinch) in a single recognizer.
        ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
          () => ScaleGestureRecognizer(),
          (ScaleGestureRecognizer instance) {
            instance
              ..onStart = _onScaleStart
              ..onUpdate = _onScaleUpdate
              ..onEnd = _onScaleEnd;
          },
        ),
        // Long-press move/resize: press an event and drag to move, or drag its
        // top/bottom handle to resize. Drag intent (body vs edge) is decided in
        // Event.startDrag via Manager.startDrag.
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(),
          (LongPressGestureRecognizer instance) {
            instance
              ..onLongPressStart = (d) {
                _data.startDrag(d.localPosition);
              }
              ..onLongPressMoveUpdate = (d) {
                _data.updateDrag(d.localPosition);
              }
              ..onLongPressEnd = (d) {
                _data.endDrag();
              };
          },
        ),
        // Tap / double-tap / right-click. Taps are fed to the double-tap
        // detector via its controller (see _tapController): onTapDown records
        // the pending tap, onTap confirms it. hideMenu stays on the immediate
        // tap so dismissing the menu isn't held back by the double-tap window.
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (TapGestureRecognizer instance) {
            instance
              ..onTapDown = (d) {
                _tapController.onTapDown(d);
              }
              ..onTap = () {
                _data.controller.hideMenu();
                _tapController.onTap();
              }
              ..onSecondaryTapDown = (d) {
                showMenu(d);
              };
          },
        ),
      },
      child: ClipRect(
          child: ScrollDetector(
        onPointerScroll: (event) {
          if (event.scrollDelta.dy > 0) {
            _data.controller.verticalScroll(true);
          } else {
            _data.controller.verticalScroll(false);
          }
        },
        child: Container(
            color: _data.config.plannerBackground,
            child: CustomPaint(
              painter: EventsPainter(
                manager: _data,
                repaint: _data.controller.triggerUpdate,
              ),
              child: Container(),
            )),
      )),
    );
  }

  GestureDetector paintHours() {
    return GestureDetector(
      onVerticalDragStart: ((details) =>
          _data.controller.startVerticalDrag(details.globalPosition.dy)),
      onVerticalDragUpdate: ((details) =>
          _data.controller.updateVerticalDrag(details.globalPosition.dy)),
      child: ClipRect(
        child: ScrollDetector(
          onPointerScroll: (event) {
            if (event.scrollDelta.dy > 0) {
              _data.controller.verticalScroll(true);
            } else {
              _data.controller.verticalScroll(false);
            }
          },
          child: Container(
            width: _data.config.hourColumnWidth,
            color: _data.config.hourBackground,
            child: CustomPaint(
              painter: HourColumn(
                manager: _data,
                repaint: _data.controller.triggerUpdate,
              ),
              child: Container(),
            ),
          ),
        ),
      ),
    );
  }

  void hideMenu() {
    setState(() {});
  }

  void showMenu(TapDownDetails details) {
    var event = _data.getEventAtPos(details.localPosition);
    if (event != null) {
      _data.controller.showEventMenu(details.localPosition, event, hideMenu);
    } else {
      var time = _data.getTimeAtPos(details.localPosition);
      _data.controller.showPlannerMenu(details.localPosition, time, hideMenu);
    }

    setState(() {});
  }
}
