enum DataType {
  A,
  B,
}

class DataEntry {
  int id;
  int day;
  int hour;
  int minutes;
  int durationInMinutes;

  String title;
  String content;

  DataType type;

  DataEntry(
      {required this.id,
      required this.day,
      required this.hour,
      required this.minutes,
      required this.durationInMinutes,
      required this.title,
      required this.content,
      required this.type});

  static List<DataEntry> CreateSampleData() {
    List<DataEntry> entries = [
      DataEntry(
          id: 0,
          day: 0,
          hour: 8,
          minutes: 0,
          durationInMinutes: 60,
          title: "Entry 1",
          content: "some content to show in this entry",
          type: DataType.A),
      DataEntry(
          id: 1,
          day: 0,
          hour: 13,
          minutes: 30,
          durationInMinutes: 90,
          title: "Entry 2 is a bit longer and does not fit inside its box",
          content:
              "This is the content of entry 2. It takes up a bit more space.",
          type: DataType.B),
    ];
    return entries;
  }
}
