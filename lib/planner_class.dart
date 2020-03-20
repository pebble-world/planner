import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:planner/events_painter.dart';
import 'package:planner/hour_container.dart';
import 'package:planner/manager.dart';
import 'package:planner/planner_date_pos.dart';
import 'package:planner/planner_entry.dart';
import 'package:positioned_tap_detector/positioned_tap_detector.dart';
import 'package:provider/provider.dart';

import 'date_container.dart';

class Planner extends StatefulWidget {
  final blockWidth = 200;
  final blockHeight = 40;

  final Function(int day, int hour, int minute) onPlannerDoubleTap;
  final Function(PlannerEntry) onEntryDoubleTap;
  final Function(PlannerEntry) onEntryChanged;

  Planner({Key key, this.onEntryChanged, this.onEntryDoubleTap, this.onPlannerDoubleTap}) : super(key: key);

  @override
  _PlannerState createState() => _PlannerState();
}

class _PlannerState extends State<Planner> with AfterLayoutMixin<Planner> {
  double _vDragStart;
  double _vDrag = 0.0;
  double _hDragStart;
  double _hDrag = 0.0;
  ManagerProvider manager;
  GlobalKey _keyEventPainter = GlobalKey();
  Offset lastTapPos = Offset.zero;

  @override
  void afterFirstLayout(BuildContext context) {
    //Calculate Calendar Position
    final RenderBox eventBox = _keyEventPainter.currentContext.findRenderObject();
    Provider.of<ManagerProvider>(context, listen: false).eventsPainterOffset = eventBox.localToGlobal(Offset.zero);
    //print('offset: ${manager.eventsPainterOffset}');

  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ManagerProvider>(context);
    return Column(
      children: [
        // Header
        Row(
            children: [
              Container(
                width: 50.0,
                height: 50.0,
                color: Colors.black,
                child: Icon(Icons.calendar_today, color: Colors.white,),
              ),
              // Day
              Expanded(
                child: GestureDetector(
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
                      //constraints: BoxConstraints(minWidth: double.infinity, maxWidth: double.infinity),
                      color: Colors.black,
                      height: 50.0,
                      child: DateContainer(
                          manager: manager,
                        ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        Expanded(
          child: Row(
            children: [
              // Hour Sidebar
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
                      child: HourContainer(
                          manager: manager,
                        ),
                      ),
                ),
              ),
              // Calendar
              Expanded(
                child: PositionedTapDetector(
                  onDoubleTap: (position) {
                    var entry = manager.getPlannerEntry(position.global);
                    if (entry == null) {
                      PlannerDatePos pos = manager.getPlannerDatePos(position.global);
                      if (widget.onPlannerDoubleTap != null) widget.onPlannerDoubleTap(pos.day, pos.hour, pos.minutes);
                    } else {
                      if (widget.onEntryDoubleTap != null) widget.onEntryDoubleTap(entry);
                    }
                    manager.entries.forEach((entry) => print(entry.toString()));
                  },
                  child: GestureDetector(
                    onScaleStart: (detail) => manager.previousZoom = manager.zoom,
                    onScaleUpdate: (detail) {
                      setState(() {
                        manager.zoom = manager.previousZoom * detail.scale;
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
                    child: Container(
                      key: _keyEventPainter,
                      //decoration: BoxDecoration(                        border: Border.all(color: Colors.red),                      ), //       <--- BoxDecoration here
                      color: Colors.grey[900],
                      child: CustomPaint(
                        painter: EventsPainter(manager: manager, onEntryChanged: widget.onEntryChanged),
                        child: Container(),
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
