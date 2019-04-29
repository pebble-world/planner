class Config {
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
}