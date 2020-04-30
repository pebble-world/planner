class Config {
  List<PlanColumn> colums;

  int minHour = 8;
  int maxHour = 18;
}

class PlanColumn {
  int id;
  String name;
  bool active;

  PlanColumn(this.id, this.name, this.active);
}
