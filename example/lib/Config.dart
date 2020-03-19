class Config {
  List<String> labels = [];

  void setLabels(int value) {
    labels.clear();
    for(int i = 0; i < value; i++) {
      labels.add('day ${i+1}');
    }
  }

  int minHour = 8;
  int maxHour = 18;
}