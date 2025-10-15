// lib/models/habit.dart
class Habit {
  int? id;
  String name;
  String? createdAt; // ISO string

  Habit({
    this.id,
    required this.name,
    this.createdAt,
  });

  factory Habit.fromMap(Map<String, dynamic> m) {
    return Habit(
      id: m['id'] is int ? m['id'] as int : (m['id'] != null ? int.tryParse(m['id'].toString()) : null),
      name: m['name'] as String? ?? '',
      createdAt: (m['created_at'] as String?) ?? (m['createdAt'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }
}
