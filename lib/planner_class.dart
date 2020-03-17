import 'package:flutter/material.dart';
import 'package:planner/date_painter.dart';
import 'package:planner/hour_painter.dart';
import 'package:planner/events_painter.dart';
import 'package:planner/manager.dart';
import 'package:planner/planner_date_pos.dart';
import 'package:planner/planner_entry.dart';
import 'package:after_layout/after_layout.dart';
import 'package:positioned_tap_detector/positioned_tap_detector.dart';

class Planner extends StatefulWidget {
  final List<String> labels;
  final int minHour;
  final int maxHour;
  final List<PlannerEntry> entries;
  final blockWidth;
  final blockHeight;

  final Function(int day, int hour, int minute) onPlannerDoubleTap;
  final Function(PlannerEntry) onEntryDoubleTap;
  final Function(PlannerEntry) onEntryChanged;

  Planner(
      {Key key,
      @required this.labels,
      @required this.minHour,
      @required this.maxHour,
      @required this.entries,
      this.blockHeight = 40,
      this.blockWidth = 200,
      this.onEntryChanged,
      this.onEntryDoubleTap,
      this.onPlannerDoubleTap})
      : super(key: key);

  @override
  _PlannerState createState() => _PlannerState();
}

class _PlannerState extends State<Planner> with AfterLayoutMixin<Planner> {
  double _vDragStart;
  double _vDrag = 0.0;
  double _hDragStart;
  double _hDrag = 0.0;
  double _previousZoom;
  Manager manager;
  GlobalKey _keyEventPainter = GlobalKey();

  Offset lastTapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    manager = Manager(
      blockWidth: widget.blockWidth,
      blockHeight: widget.blockHeight,
      labels: widget.labels,
      minHour: widget.minHour,
      maxHour: widget.maxHour,
      entries: widget.entries,
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    final RenderBox eventBox =
        _keyEventPainter.currentContext.findRenderObject();
    manager.eventsPainterOffset = eventBox.localToGlobal(Offset.zero);
    debugPrint('offset: ${manager.eventsPainterOffset}');
  }

  @override
  Widget build(BuildContext context) {
    manager.update(
      blockWidth: 200,
      blockHeight: 40,
      labels: widget.labels,
      minHour: widget.minHour,
      maxHour: widget.maxHour,
      entries: widget.entries,
    );

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragStart: (detail) {
            _hDragStart = detail.globalPosition.dx;
            _hDrag = manager.hScroll;
          },
          onHorizontalDragUpdate: (detail) {
            setState(() {
              _hDrag += detail.globalPosition.dx - _hDragStart;
              _hDragStart = detail.globalPosition.dx;
              manager.hScroll = _hDrag;
            });
          },
          child: ClipRect(
            child: Container(
              constraints: BoxConstraints(
                  minWidth: double.infinity, maxWidth: double.infinity),
              color: Colors.black,
              height: 50.0,
              child: CustomPaint(
                painter: DatePainter(
                  manager: manager,
                ),
                child: Container(),
              ),
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onVerticalDragStart: (detail) {
                  _vDragStart = detail.globalPosition.dy;
                  _vDrag = manager.vScroll;
                },
                onVerticalDragUpdate: (detail) {
                  setState(() {
                    _vDrag += detail.globalPosition.dy - _vDragStart;
                    _vDragStart = detail.globalPosition.dy;
                    manager.vScroll = _vDrag;
                  });
                },
                child: ClipRect(
                  child: Container(
                      width: 50.0,
                      //constraints: BoxConstraints.expand(),
                      color: Colors.black,
                      child: CustomPaint(
                        painter: HourPainter(
                          manager: manager,
                        ),
                        child: Container(),
                      )),
                ),
              ),
              Expanded(
                child: PositionedTapDetector(
                  onDoubleTap: (position) {
                    var entry = manager.getPlannerEntry(position.global);
                    if (entry == null) {
                      PlannerDatePos pos =
                          manager.getPlannerDatePos(position.global);
                      if (widget.onPlannerDoubleTap != null)
                        widget.onPlannerDoubleTap(
                            pos.day, pos.hour, pos.minutes);
                    } else {
                      if (widget.onEntryDoubleTap != null)
                        widget.onEntryDoubleTap(entry);
                    }
                  },
                  child: GestureDetector(
                    onScaleStart: (detail) => _previousZoom = manager.zoom,
                    onScaleUpdate: (detail) {
                      setState(() {
                        //_zoom = _previousZoom * detail.scale;
                        manager.zoom = _previousZoom * detail.scale;
                      });
                    },
                    onLongPressStart: (details) {
                      setState(() {
                        manager.touchPos = details.globalPosition;
                      });
                    },
                    onLongPressMoveUpdate: (details) {
                      setState(() {
                        manager.touchPos = details.globalPosition;
                      });
                    },
                    onLongPressEnd: (details) {
                      setState(() {
                        manager.touchPos = null;
                      });
                    },
                    child: ClipRect(
                      child: Container(
                        key: _keyEventPainter,
                        color: Colors.grey[900],
                        child: CustomPaint(
                          painter: EventsPainter(
                              manager: manager,
                              onEntryChanged: widget.onEntryChanged),
                          child: Container(),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}
