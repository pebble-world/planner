import 'package:flutter/material.dart';
import 'package:planner/manager.dart';

class DateContainer extends StatelessWidget {
  final ManagerProvider manager;

  DateContainer({@required this.manager});
  static TextStyle listTitleDefaultTextStyle = TextStyle(color: Color(0xff297fca), fontWeight: FontWeight.w600, fontSize: 20.0);

  @override
  Widget build(BuildContext context) {
    return new Row(
        children: manager.config.colums.values
            .map((item) => Expanded(
                    child: Center(
                        child: Text(
                  item,
                  style: listTitleDefaultTextStyle,
                ))))
            .toList());
  }
}
