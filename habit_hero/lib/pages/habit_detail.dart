// lib/pages/habit_detail.dart
import 'package:flutter/material.dart';
import '../data/db_helper.dart';
import '../models/habit.dart';

class HabitDetailPage extends StatefulWidget {
  final Habit habit;
  HabitDetailPage({required this.habit});
  @override
  _HabitDetailPageState createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  final DBHelper _db = DBHelper.instance;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.habit.name;
  }

  Future<void> _save() async {
    final updated = Habit(
      id: widget.habit.id,
      name: _ctrl.text.trim(),
      createdAt: widget.habit.createdAt,
      // keep reminder fields unchanged in the DB model (we don't touch them here)
      reminderEnabled: widget.habit.reminderEnabled,
      reminderTime: widget.habit.reminderTime,
    );
    await _db.updateHabit(updated);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Habit bearbeiten')),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            TextField(controller: _ctrl, decoration: InputDecoration(labelText: 'Name')),
            SizedBox(height: 18),
            Spacer(),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Abbrechen'))),
                SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _save, child: Text('Speichern'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
