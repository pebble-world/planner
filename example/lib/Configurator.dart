import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

//import 'package:flutter_range_slider/flutter_range_slider.dart';

class Configurator extends StatefulWidget {
  final PlannerConfig config;

  Configurator({this.config});

  @override
  _ConfiguratorState createState() => _ConfiguratorState();
}

class _ConfiguratorState extends State<Configurator> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 50,
              child: Text('Days'),
            ),
            Slider(
              min: 2,
              max: 10,
              label: '${widget.config.days.round()}',
              divisions: 8,
              value: widget.config.days.toDouble(),
              onChanged: (newValue) {
                setState(() {
                  widget.config.days = newValue;
                });
              },
              onChangeEnd: (newValue) {
                setState(() {
                  widget.config.setLabels(newValue.toInt());
                });
              },
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Container(
              width: 50,
              child: Text('Max Hour'),
            ),
            Slider(
              min: 12,
              max: 24,
              divisions: 12,
              //lowerValue: widget.config.minHour.toDouble(),
              value: widget.config.maxHour.toDouble(),
              
              onChanged: (double value) {
                //widget.config.minHour = lower.toInt();
                widget.config.maxHour = value.toInt();
              },
              //showValueIndicator: true,
              //valueIndicatorMaxDecimals: 0,
            )
          ],
        ),
      ],
    );
  }
}
