import 'package:flutter/material.dart';
import 'package:planner/internal/events_painter.dart';
import 'package:planner/internal/hour_column.dart';
import 'package:planner/internal/scroll_detector.dart';
import 'package:planner/internal/widget_size.dart';
import 'package:positioned_tap_detector_2/positioned_tap_detector_2.dart';
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
                              widget.data.config.onEntryDoubleTap != null) {
                            widget.data.config.onEntryDoubleTap!(event.entry);
                          } else if (event == null &&
                              widget.data.config.onPlannerDoubleTap != null) {
                            var time =
                                widget.data.getTimeAtPos(position.relative!);
                            widget.data.config.onPlannerDoubleTap!(time);
                          }
                        },
                        child: paintEvents(),
                      ),
                      paintZoomButtons(context)
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

  GestureDetector paintDates() {
    return GestureDetector(
      onHorizontalDragStart: (detail) =>
          widget.data.controller.startHorizontalDrag(detail.globalPosition.dx),
      onHorizontalDragUpdate: (detail) =>
          widget.data.controller.updateHorizontalDrag(detail.globalPosition.dx),
      child: ClipRect(
        child: ScrollDetector(
          onPointerScroll: (event) {
            print(event);
          },
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
}
