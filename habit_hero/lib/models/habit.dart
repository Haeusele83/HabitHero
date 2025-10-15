// lib/models/habit.dart

class Habit {
  int? id;
  String name;
  String? createdAt; // ISO-String
  bool reminderEnabled;
  String? reminderTime; // 'HH:mm' Format, optional

  Habit({
    this.id,
    required this.name,
    this.createdAt,
    this.reminderEnabled = false,
    this.reminderTime,
  });

  factory Habit.fromMap(Map<String, dynamic> m) {
    return Habit(
      id: m['id'] is int ? m['id'] as int : (m['id'] != null ? int.tryParse(m['id'].toString()) : null),
      name: m['name'] as String? ?? '',
      createdAt: (m['created_at'] as String?) ?? (m['createdAt'] as String?),
      reminderEnabled: _parseBool(m['reminder_enabled']),
      reminderTime: (m['reminder_time'] as String?) ?? (m['reminderTime'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'reminder_time': reminderTime,
    };
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
}
