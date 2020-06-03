import 'planner_entry.dart';

class PlannerConfig {
  double days = 5;
  List<String> labels = [];

  void setLabels(int value) {
    labels.clear();
    for(int i = 0; i < value; i++) {
      labels.add('day ${i+1}');
    }
    days = value.toDouble();
  }

  int minHour = 0;
  int maxHour = 24;

  int blockWidth = 200;
  int blockHeight = 40;

  Function(int day, int hour, int minute) onPlannerDoubleTap;
  Function(PlannerEntry) onEntryDoubleTap;
  Function(PlannerEntry) onEntryChanged;
}