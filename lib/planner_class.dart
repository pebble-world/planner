import 'package:flutter/material.dart';
import 'package:planner/internal/contex_menu.dart';
import 'package:planner/internal/controller.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/internal/hour_column.dart';
import 'package:planner/internal/scroll_detector.dart';
import 'internal/positioned_tap_detector_2.dart';
import 'internal/date_row.dart';
import 'internal/manager.dart';
import 'planner_entry.dart';
import 'planner_config.dart';

class Planner extends StatefulWidget {
  final List<PlannerEntry> entries;
  final PlannerConfig config;
  final Manager data;

  Planner({
    Key? key,
    required this.config,
    required this.entries,
  })  : data = Manager(config: config, entries: entries),
        super(key: key);

  @override
  _PlannerState createState() => _PlannerState();
}

class _PlannerState extends State<Planner> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      widget.data.controller.setSize(constraints.biggest);
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
                        onDoubleTap: (position) {
                          if (position.relative == null) {
                            return;
                          }
                          var event =
                              widget.data.getEventAtPos(position.relative!);
                          if (event != null &&
                              widget.data.config.onEntryEdit != null) {
                            widget.data.config.onEntryEdit!(event.entry);
                          } else if (event == null &&
                              widget.data.config.onEntryCreate != null) {
                            var time =
                                widget.data.getTimeAtPos(position.relative!);
                            widget.data.config.onEntryCreate!(time);
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
    if (widget.data.controller.menuType != MenuType.none) {
      result.add(
        Positioned.fill(child: Container(color: Colors.transparent)),
      );

      result.add(
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => widget.data.controller.hideMenu(),
          onTap: () => widget.data.controller.hideMenu(),
          onSecondaryTapDown: (_) => widget.data.controller.hideMenu(),
          child: Container(),
        ),
      );

      result.add(
        Transform.translate(
          offset: widget.data.controller.menuPos!,
          child: ContextMenu(manager: widget.data),
        ),
      );
    }
    return result;
  }

  GestureDetector paintDates() {
    return GestureDetector(
      onHorizontalDragStart: (detail) =>
          widget.data.controller.startHorizontalDrag(detail.globalPosition.dx),
      onHorizontalDragUpdate: (detail) =>
          widget.data.controller.updateHorizontalDrag(detail.globalPosition.dx),
      child: ClipRect(
        child: Container(
          height: widget.data.config.dateRowHeight,
          color: widget.data.config.dateBackground,
          child: CustomPaint(
            painter: DateRow(
              manager: widget.data,
              repaint: widget.data.controller.triggerUpdate,
            ),
            child: Container(),
          ),
        ),
      ),
    );
  }

  Row paintZoomButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: RawMaterialButton(
            onPressed: () {
              widget.data.controller.startZoom();
              widget.data.controller.updateZoom(0.9);
            },
            elevation: 2.0,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            fillColor: Theme.of(context).colorScheme.secondary,
            child: const Icon(
              Icons.zoom_out,
              size: 22.0,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(4.0),
            shape: const CircleBorder(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: RawMaterialButton(
            onPressed: () {
              widget.data.controller.startZoom();
              widget.data.controller.updateZoom(1.1);
            },
            elevation: 2.0,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            fillColor: Theme.of(context).colorScheme.secondary,
            child: const Icon(
              Icons.zoom_in,
              size: 22.0,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(4.0),
            shape: const CircleBorder(),
          ),
        ),
      ],
    );
  }

  GestureDetector paintEvents() {
    return GestureDetector(
      onHorizontalDragStart: (detail) =>
          widget.data.controller.startHorizontalDrag(detail.globalPosition.dx),
      onHorizontalDragUpdate: (detail) =>
          widget.data.controller.updateHorizontalDrag(detail.globalPosition.dx),
      onScaleStart: ((details) => widget.data.controller.startZoom()),
      onScaleUpdate: (details) =>
          widget.data.controller.updateZoom(details.verticalScale),
      onLongPressStart: (details) {
        widget.data.controller.touchPos = details.localPosition;
      },
      onLongPressMoveUpdate: (details) {
        widget.data.controller.touchPos = details.localPosition;
      },
      onLongPressEnd: (details) {
        widget.data.controller.touchPos = null;
      },
      onTap: () {
        widget.data.controller.hideMenu();
      },
      onSecondaryTapDown: (details) {
        showMenu(details);
      },
      child: ClipRect(
          child: ScrollDetector(
        onPointerScroll: (event) {
          if (event.scrollDelta.dy > 0) {
            widget.data.controller.verticalScroll(true);
          } else {
            widget.data.controller.verticalScroll(false);
          }
        },
        child: Container(
            color: widget.data.config.plannerBackground,
            child: CustomPaint(
              painter: EventsPainter(
                manager: widget.data,
                repaint: widget.data.controller.triggerUpdate,
              ),
              child: Container(),
            )),
      )),
    );
  }

  GestureDetector paintHours() {
    return GestureDetector(
      onVerticalDragStart: ((details) =>
          widget.data.controller.startVerticalDrag(details.globalPosition.dy)),
      onVerticalDragUpdate: ((details) =>
          widget.data.controller.updateVerticalDrag(details.globalPosition.dy)),
      child: ClipRect(
        child: ScrollDetector(
          onPointerScroll: (event) {
            if (event.scrollDelta.dy > 0) {
              widget.data.controller.verticalScroll(true);
            } else {
              widget.data.controller.verticalScroll(false);
            }
          },
          child: Container(
            width: widget.data.config.hourColumnWidth,
            color: widget.data.config.hourBackground,
            child: CustomPaint(
              painter: HourColumn(
                manager: widget.data,
                repaint: widget.data.controller.triggerUpdate,
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
    var event = widget.data.getEventAtPos(details.localPosition);
    if (event != null) {
      widget.data.controller
          .showEventMenu(details.localPosition, event, hideMenu);
    } else {
      var time = widget.data.getTimeAtPos(details.localPosition);
      widget.data.controller
          .showPlannerMenu(details.localPosition, time, hideMenu);
    }

    setState(() {});
  }
}
