import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'internal/context_menu.dart';
import 'internal/controller.dart';
import 'internal/event.dart';
import 'internal/events_painter.dart';
import 'internal/hour_column.dart';
import 'internal/scroll_detector.dart';
import 'internal/positioned_tap_detector_2.dart';
import 'internal/date_row.dart';
import 'internal/manager.dart';
import 'planner_entry.dart';
import 'planner_config.dart';

/// What a single in-progress events-canvas gesture is doing. Decided when the
/// unified [ScaleGestureRecognizer] starts — by hit-testing the press point on a
/// precise pointer ([moveResize] on an event, [pan] on empty space) and always
/// [pan] on touch — then refined to [zoom] as soon as a second pointer joins, so
/// pan, zoom and move/resize no longer fight in the gesture arena (the old
/// layout combined a horizontal-drag recognizer with scale and a long-press).
enum _GestureMode { idle, pan, zoom, moveResize }

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
  // recognizer starts and switched to zoom the moment a second pointer joins, so
  // pan, zoom and move/resize can't all apply to the same gesture (the old
  // detector ran horizontal-drag, scale and long-press at once).
  _GestureMode _mode = _GestureMode.idle;

  // The kind and local position of the most recent pointer-down, captured by the
  // thin Listener below. The kind decides drag intent (precise pointer =>
  // press-and-drag an event to move/resize; touch => one-finger drag pans), and
  // the down position anchors a move/resize so the event follows the pointer
  // with no dead zone (the scale recognizer only fires onStart after the pan
  // slop, so anchoring on the recognizer's start would drop that slop distance).
  PointerDeviceKind _lastPointerKind = PointerDeviceKind.touch;
  Offset _pointerDownPos = Offset.zero;

  // The desktop hover cursor over the events canvas: move over an event body,
  // resizeUpDown over its top/bottom edge, basic otherwise. Held in a notifier
  // so only the MouseRegion rebuilds on a hover change, not the whole Planner.
  final ValueNotifier<MouseCursor> _cursor =
      ValueNotifier<MouseCursor>(SystemMouseCursors.basic);

  /// Whether [kind] is a precise pointer (a mouse) that gets the Outlook-style
  /// immediate drag-move/resize. Touch keeps one-finger drag as pan; its
  /// move/resize affordance is the long-press callback (the companion #66).
  bool _isPrecise(PointerDeviceKind kind) => kind == PointerDeviceKind.mouse;

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
  void dispose() {
    _cursor.dispose();
    super.dispose();
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
  // One ScaleGestureRecognizer drives pan, zoom and (desktop) move/resize: a
  // multi-finger pinch zooms; a one-finger drag pans, except on a precise
  // pointer pressed on an event, where it moves the body or resizes the edge —
  // the Outlook-style immediate drag, no long-press. This replaces the old
  // horizontal-drag + scale + long-press combo that fought in the gesture arena.

  void _onScaleStart(ScaleStartDetails details) {
    // Decide intent from the press point captured at pointer-down. A precise
    // pointer on an event grabs it (move on the body, resize on an edge); on
    // empty space, or on touch, the gesture pans. startZoom captures the
    // pre-gesture zoom so a pinch that begins mid-gesture stays continuous; the
    // single->second-pointer switch to zoom happens in _onScaleUpdate.
    _data.controller.startZoom();

    if (_isPrecise(_lastPointerKind)) {
      _data.startDrag(_pointerDownPos);
      if (_data.draggedEvent != null) {
        _mode = _GestureMode.moveResize;
        return;
      }
    }

    _mode = _GestureMode.pan;
    _data.controller.startHorizontalDrag(details.focalPoint.dx);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // A move/resize is single-pointer on a mouse, so it never coexists with a
    // pinch; keep following the pointer.
    if (_mode == _GestureMode.moveResize) {
      _data.updateDrag(details.localFocalPoint);
    } else if (details.pointerCount >= 2) {
      _mode = _GestureMode.zoom;
      _data.controller.updateZoom(details.verticalScale);
    } else if (_mode == _GestureMode.pan) {
      _data.controller.updateHorizontalDrag(details.focalPoint.dx);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_mode == _GestureMode.moveResize) {
      _data.endDrag();
    }
    _mode = _GestureMode.idle;
  }

  /// Maps a hover [position] (events-canvas-local) to the cursor that signals
  /// what a press there would do: move over an event body, resizeUpDown over its
  /// top/bottom edge, basic over empty space — the desktop discoverability cue.
  void _updateHoverCursor(Offset position) {
    final cursor = switch (_data.dragTypeAt(position)) {
      DragType.body => SystemMouseCursors.move,
      DragType.topHandle ||
      DragType.bottomHandle =>
        SystemMouseCursors.resizeUpDown,
      DragType.none => SystemMouseCursors.basic,
    };
    _cursor.value = cursor;
  }

  Widget paintEvents() {
    // The outer Listener records the kind and position of each pointer-down (a
    // thin pass-through, it claims nothing) so the scale recognizer can tell a
    // mouse from a finger and anchor a move/resize at the true press point.
    return Listener(
      onPointerDown: (event) {
        _lastPointerKind = event.kind;
        _pointerDownPos = event.localPosition;
      },
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          // Pan (one finger) + zoom (pinch) + desktop move/resize, all in one
          // recognizer so they share an arena instead of fighting in it.
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
        // Hover cursor (desktop discoverability): the MouseRegion rebuilds on a
        // cursor change via the notifier; the canvas below is passed as `child`
        // so it isn't rebuilt with it.
        child: ValueListenableBuilder<MouseCursor>(
          valueListenable: _cursor,
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
            ),
          ),
          builder: (context, cursor, child) {
            return MouseRegion(
              cursor: cursor,
              onHover: (event) => _updateHoverCursor(event.localPosition),
              onExit: (_) => _cursor.value = SystemMouseCursors.basic,
              child: child,
            );
          },
        ),
      ),
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
