class Habit {
  final int? id;
  final String name;

  Habit({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> m) {
    return Habit(
      id: m['id'] as int?,
      name: m['name'] as String,
    );
  }
}
