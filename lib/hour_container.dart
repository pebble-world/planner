import 'package:flutter/material.dart';
import 'package:planner/manager.dart';

class HourContainer extends StatelessWidget {
  final ManagerProvider manager;
  var _hours = List<Widget>();

  HourContainer({@required this.manager}) {}
  static TextStyle listTitleDefaultTextStyle = TextStyle(color: Color(0xff297fca), fontWeight: FontWeight.w600, fontSize: 20.0);

  @override
  Widget build(BuildContext context) {
    for (int i = manager.minHour; i < manager.maxHour; i++) {
      _hours.add(Flexible(
          child: Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide( //                   <--- left side
                      color: Color(0xff297fca),
                      width: 0.5,
                    ), //
                  top: BorderSide( //                   <--- left side
                    color: Color(0xff297fca),
                    width: 0.5,
                  ), //  //    <--- BoxDecoration here
                ),
              ),
              child: Center(

              child: Text(
                i.toString(),
                style: listTitleDefaultTextStyle,
                textAlign: TextAlign.center,
      )))));
    }

    return new Column(
      children: _hours,
    );
  }
}
