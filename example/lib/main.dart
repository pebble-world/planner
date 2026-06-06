import 'package:example/data.dart';
import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MyHomePage(title: 'Planner Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var dataEntries = DataEntry.createSampleData();

  @override
  Widget build(BuildContext context) {
    // create planner entries from the data set
    List<PlannerEntry> entries = [];
    for (final element in dataEntries) {
      entries.add(PlannerEntry(
          id: element.id.toString(),
          time: PlannerTime(
              day: element.day,
              hour: element.hour,
              minutes: element.minutes,
              duration: element.durationInMinutes),
          title: element.hour.toString() +
              ':' +
              element.minutes.toString() +
              ' ' +
              element.title,
          content: element.content,
          color: element.type == DataType.A ? Colors.green : Colors.blue));
    }

    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Planner(
          config: PlannerConfig(
              minHour: 0,
              maxHour: 23,
              labels: [
                "day 1",
                "day 2",
                "day 3",
                "day 4",
                "day 5",
                "day 6",
                "day 7",
                "day 8",
                "day 9",
                "day 10"
              ],
              // Emphasize a column ("today" style). The widget is date-agnostic,
              // so a real calendar would map DateTime.now() to this index itself.
              highlightedColumn: 0,
              //dateBackground: Colors.red,
              //hourBackground: Colors.deepOrange,
              onEntryMove: (entry) {
                for (int i = 0; i < entries.length; i++) {
                  if (dataEntries[i].id.toString() == entry.id) {
                    dataEntries[i].day = entry.time.day;
                    dataEntries[i].hour = entry.time.hour;
                    dataEntries[i].minutes = entry.time.minutes;
                    continue;
                  }
                }
              },
              onEntryEdit: (entry) {
                debugPrint('entry: ' + entry.title);
              },
              onEntryCreate: (time) {
                debugPrint(
                    'day: ${time.day} hour: ${time.hour} minutes: ${time.minutes}');
              },
              onEntryDelete: (entry) {
                debugPrint('deleting entry: ' + entry.title);
              },
              // The freed-up touch gesture (#66): the widget is presentation-
              // only, so the host decides the response. A real app would show a
              // selection UI / action sheet here.
              onEntryLongPress: (entry) {
                debugPrint('long-pressed entry: ' + entry.title);
              }),
          entries: entries,
        )
        // This trailing comma makes auto-formatting nicer for build methods.
        );
  }
}
