import 'package:flutter/material.dart';
import 'package:planner/manager.dart';
import 'package:planner/planner.dart';
import 'package:provider/provider.dart';

import 'Config.dart';

void main() {
  //debugPaintSizeEnabled=true;
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planner Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Planner Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Config config;
  List<PlannerEntry> entries;

  @override
  Widget build(BuildContext context) {

    config = Config();
    //Days
    config.setLabels(5);

    entries = List<PlannerEntry>();
    entries.add(PlannerEntry(day: 0, hour: 12, title: 'entry 1', content: 'some content to show in this entry', color: Colors.blue));
    entries.add(PlannerEntry(
        day: 1,
        hour: 11,
        duration: 180,
        title: 'entry 2 is a bit longer and does not fit inside its box',
        content: 'This is the content of entry 2. It takes up a bit more space.',
        color: Colors.green));

    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ManagerProvider(
            labels: config.labels,
            minHour: config.minHour,
            maxHour: config.maxHour,
            entries: entries,
          )),
        ],
        child: Scaffold(
      body: Planner(
          onEntryDoubleTap: onEntryDoubleTap,
          onPlannerDoubleTap: onPlannerDoubleTap,
          onEntryChanged: onEntryChanged,
        )));
  }

  void onEntryChanged(PlannerEntry entry) {
    print('entry changed');
    // the argument is the changed entry
    // This method should be used if you need extra checks on the
    // new position and save them to a database
  }

  void onEntryDoubleTap(PlannerEntry entry) {
    // this should probably provide a way to change the
    // event's content
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(title: Text(entry.title), content: Text(entry.content), actions: [
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ]);
        });
  }

  // minutes will be rounded according to planner grid. Can be 0, 15, 30 or 45
  void onPlannerDoubleTap(int day, int hour, int minute, ManagerProvider manager) {
    print('day: $day hour: $hour minute: $minute');
    PlannerEntry entry = PlannerEntry(
      title: 'new planner entry',
      content: 'some content explaining what this is about',
      day: day,
      hour: hour,
      minutes: minute,
      duration: 30, // minutes
      color: Colors.red,
    );
    entry.createPainters(config.minHour);
    manager.entries.add(entry);
    manager.redraw();
  }
}
