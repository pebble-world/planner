import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'internal/all_day_band.dart';
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

  // Identifies the events-canvas RenderCustomPaint so a scroll/zoom can rebuild
  // its accessibility semantics (#56). RenderCustomPaint wires the painter's
  // `repaint` listenable to markNeedsPaint only — never markNeedsSemanticsUpdate
  // — so a pan/zoom (which just ticks triggerUpdate) repaints the events but
  // leaves their semantics nodes frozen at the rects they had when last built.
  // We listen to that same notifier and poke this canvas to rebuild its
  // semantics, so each event node's rect tracks the view (keeping touch-
  // exploration hit-areas and the AT focus highlight correct as the user pans).
  final GlobalKey _eventsCanvasKey = GlobalKey();

  // The all-day band's RenderCustomPaint, poked on a day-axis pan to rebuild its
  // chip semantics the same way as the event canvas (#72/#56): the band's chip
  // rects track the horizontal scroll, and the `repaint` listenable only
  // triggers markNeedsPaint, never markNeedsSemanticsUpdate. Null until (and
  // unless) the band is mounted, so the poke is a no-op when there's no band.
  final GlobalKey _allDayCanvasKey = GlobalKey();

  // The local position of the most recent double-tap-down on the all-day band,
  // captured so [_onAllDayDoubleTap] (which carries no position itself) knows
  // which chip / empty column the double-tap landed on.
  Offset _allDayDoubleTapPos = Offset.zero;

  /// Whether [kind] is a precise pointer (a mouse) that gets the Outlook-style
  /// immediate drag-move/resize. Touch keeps one-finger drag as pan; its
  /// move/resize affordance is the long-press callback (the companion #66).
  bool _isPrecise(PointerDeviceKind kind) => kind == PointerDeviceKind.mouse;

  @override
  void initState() {
    super.initState();
    _data = Manager(config: widget.config, entries: widget.entries);
    // Rebuild the canvas semantics whenever the view changes (#56). The
    // controller is preserved across rebuilds (Manager.update keeps it), so this
    // listener stays valid for the life of the State.
    _data.controller.triggerUpdate.addListener(_rebuildCanvasSemantics);
  }

  /// Rebuilds the events-canvas and all-day-band accessibility semantics so each
  /// node's rect tracks the current scroll/zoom (#56/#72). Fired on every
  /// controller update: RenderCustomPaint only repaints (not re-semantics) on
  /// the `repaint` listenable, so without this poke a scrolled event/chip keeps
  /// its stale node rect. A no-op for a canvas that isn't mounted
  /// (`currentContext` is null — e.g. the band when it's disabled or empty).
  void _rebuildCanvasSemantics() {
    _eventsCanvasKey.currentContext
        ?.findRenderObject()
        ?.markNeedsSemanticsUpdate();
    _allDayCanvasKey.currentContext
        ?.findRenderObject()
        ?.markNeedsSemanticsUpdate();
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
    _data.controller.triggerUpdate.removeListener(_rebuildCanvasSemantics);
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _data.controller.setSize(constraints.biggest);
      // The context menu overlay is lifted to a planner-wide Stack so it can
      // sit over either the time grid or the all-day band (#72): the band is a
      // thin strip above the grid in the Column, so a menu opened from it must
      // be free to overflow downward over the grid — impossible while the menu
      // lived inside the grid's own Stack (the grid paints over earlier Column
      // children). menuPos is therefore planner-local; both surfaces convert
      // their local hit position into this space.
      return Stack(
        children: [
          Column(
            children: [
              paintDates(),
              // The all-day band (#48) sits between the date row and the time
              // grid. It self-sizes to its lanes and is omitted entirely (no
              // widget, no reserved space) when the band is disabled
              // (showAllDayBand) or there are no all-day events.
              if (_data.allDayBandHeight > 0) paintAllDayBand(),
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
                              var event =
                                  _data.getEventAtPos(position.relative!);
                              if (event != null &&
                                  _data.config.onEntryEdit != null) {
                                _data.config.onEntryEdit!(event.entry);
                              } else if (event == null &&
                                  _data.config.onEntryCreate != null) {
                                var time =
                                    _data.getTimeAtPos(position.relative!);
                                _data.config.onEntryCreate!(time);
                              }
                            },
                            child: paintEvents(),
                          ),
                          paintZoomButtons(context),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          ...paintMenu(),
        ],
      );
    });
  }

  /// The events canvas's top-left in planner-local coordinates: right of the
  /// hour gutter and below the date row plus any all-day band. Used to map an
  /// events-canvas-local hit position into the planner-local space the lifted
  /// context menu is positioned in (#72).
  Offset get _eventsCanvasOrigin => Offset(
        _data.config.hourColumnWidth,
        _data.config.dateRowHeight + _data.allDayBandHeight,
      );

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

  /// The all-day band (#48): a fixed strip of chips above the time grid for
  /// events flagged [PlannerTime.allDay]. Like the date row directly above it,
  /// it pans the day axis on a horizontal drag (so it isn't a dead zone) and
  /// tracks the horizontal scroll, but it does not zoom or scroll with the time
  /// axis. Only mounted when the band is enabled and there is at least one
  /// all-day event.
  ///
  /// Its chips are interactive at parity with timed events (#72): double-tap a
  /// chip to edit (or empty space to create), right-click for the edit/delete
  /// (or create) context menu, and long-press a chip for [onEntryLongPress].
  /// These coexist with the day-axis horizontal drag in one GestureDetector —
  /// a moving press pans, a still tap/press resolves to the tap gestures.
  Widget paintAllDayBand() {
    return GestureDetector(
      onHorizontalDragStart: (detail) =>
          _data.controller.startHorizontalDrag(detail.globalPosition.dx),
      onHorizontalDragUpdate: (detail) =>
          _data.controller.updateHorizontalDrag(detail.globalPosition.dx),
      // Double-tap carries no position, so capture it on the down event.
      onDoubleTapDown: (detail) => _allDayDoubleTapPos = detail.localPosition,
      onDoubleTap: _onAllDayDoubleTap,
      onSecondaryTapDown: (detail) => _showAllDayMenu(detail.localPosition),
      onLongPressStart: (detail) => _onAllDayLongPress(detail.localPosition),
      child: ClipRect(
        child: Container(
          height: _data.allDayBandHeight,
          color: _data.config.allDayBandBackground,
          child: CustomPaint(
            key: _allDayCanvasKey,
            painter: AllDayBand(
              manager: _data,
              repaint: _data.controller.triggerUpdate,
            ),
            child: Container(),
          ),
        ),
      ),
    );
  }

  /// Double-tap on the all-day band (#72): edit the chip under the press, or —
  /// mirroring the grid's double-tap — create an all-day event on empty band
  /// space (the position was captured by `onDoubleTapDown`).
  void _onAllDayDoubleTap() {
    final chip = _data.getAllDayEventAtPos(_allDayDoubleTapPos);
    if (chip != null) {
      _data.config.onEntryEdit?.call(chip.entry);
    } else if (_data.config.onEntryCreate != null) {
      _data
          .config.onEntryCreate!(_data.getAllDayTimeAtPos(_allDayDoubleTapPos));
    }
  }

  /// Right-click on the all-day band (#72): open the edit/delete menu for the
  /// chip under [bandLocalPos], or the create menu on empty band space. The
  /// band sits at planner-local `(0, dateRowHeight)`, so the band-local press
  /// maps to planner-local by shifting down past the date row for the lifted
  /// menu overlay.
  void _showAllDayMenu(Offset bandLocalPos) {
    final plannerPos = bandLocalPos + Offset(0, _data.config.dateRowHeight);
    final chip = _data.getAllDayEventAtPos(bandLocalPos);
    if (chip != null) {
      _data.controller.showEventMenu(plannerPos, chip.entry, hideMenu);
    } else {
      _data.controller.showPlannerMenu(
          plannerPos, _data.getAllDayTimeAtPos(bandLocalPos), hideMenu);
    }
    setState(() {});
  }

  /// Long-press on an all-day chip fires [PlannerConfig.onEntryLongPress] (#72),
  /// the touch path to act on a chip — at parity with a long-press on a timed
  /// event ([_onLongPress]). A press on empty band space, or with no callback
  /// wired, is a no-op.
  void _onAllDayLongPress(Offset bandLocalPos) {
    final onLongPress = _data.config.onEntryLongPress;
    if (onLongPress == null) return;
    final chip = _data.getAllDayEventAtPos(bandLocalPos);
    if (chip == null) return;
    onLongPress(chip.entry);
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

    // Empty-area (and touch) drag pans both axes within the existing clamps,
    // reusing the controller's per-axis drag handlers (the day axis is also
    // panned by the date row, the time axis by the hour gutter).
    _mode = _GestureMode.pan;
    _data.controller.startHorizontalDrag(details.focalPoint.dx);
    _data.controller.startVerticalDrag(details.focalPoint.dy);
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
      _data.controller.updateVerticalDrag(details.focalPoint.dy);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_mode == _GestureMode.moveResize) {
      _data.endDrag();
    }
    _mode = _GestureMode.idle;
  }

  /// Fires [PlannerConfig.onEntryLongPress] when a long-press lands on an event
  /// (#66) — the freed-up touch gesture for acting on one (touch has no
  /// right-click, and a one-finger drag now pans); a desktop long-press fires it
  /// too. The widget takes no action itself: the host decides the response. A
  /// long-press on empty space, or one with no callback wired, is a no-op.
  void _onLongPress(LongPressStartDetails details) {
    final onLongPress = _data.config.onEntryLongPress;
    if (onLongPress == null) return;
    final event = _data.getEventAtPos(details.localPosition);
    if (event == null) return;
    onLongPress(event.entry);
  }

  /// Routes a mouse-wheel notch by keyboard modifier (#65): plain wheel scrolls
  /// the time axis (unchanged), Shift+wheel scrolls the day axis, Ctrl+wheel
  /// zooms (clamped to `minZoom`/`maxZoom` by the controller). The vertical
  /// `dy > 0` sign drives all three so they agree on notch direction; a notch
  /// with no vertical delta (e.g. a pure horizontal trackpad scroll) is ignored.
  void _handleWheel(PointerScrollEvent event) {
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed) {
      _data.controller.startZoom();
      _data.controller.updateZoom(dy < 0 ? 1.1 : 0.9);
    } else if (keys.isShiftPressed) {
      _data.controller.horizontalScroll(dy > 0);
    } else {
      _data.controller.verticalScroll(dy > 0);
    }
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
          // Long-press -> onEntryLongPress (#66). Shares this arena with the
          // scale and tap recognizers: a still press past the long-press timeout
          // wins here, while a press that moves past the pan slop lets the scale
          // recognizer take the gesture, so long-press never steals a pan or a
          // desktop drag (this is the same arena the old layout ran a long-press
          // in). Always registered; with no callback wired it's an inert no-op.
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(),
            (LongPressGestureRecognizer instance) {
              instance.onLongPressStart = _onLongPress;
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
              onPointerScroll: _handleWheel,
              child: Container(
                  color: _data.config.plannerBackground,
                  child: CustomPaint(
                    key: _eventsCanvasKey,
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
          onPointerScroll: _handleWheel,
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
    // Hit-testing uses the events-canvas-local position; the menu is positioned
    // in planner-local space (the lifted overlay), so shift by the canvas origin.
    final local = details.localPosition;
    final plannerPos = local + _eventsCanvasOrigin;
    var event = _data.getEventAtPos(local);
    if (event != null) {
      _data.controller.showEventMenu(plannerPos, event.entry, hideMenu);
    } else {
      var time = _data.getTimeAtPos(local);
      _data.controller.showPlannerMenu(plannerPos, time, hideMenu);
    }

    setState(() {});
  }
}
