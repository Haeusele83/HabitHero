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
  List<int> _last30 = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _db.getChecksForLastNDays(widget.habit.id!, 30);
      setState(() => _last30 = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  String _dayLabel(int indexFromOldest) {
    final start = DateTime.now().subtract(Duration(days: 29));
    final d = start.add(Duration(days: indexFromOldest));
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _weekdayShort(int indexFromOldest) {
    final start = DateTime.now().subtract(Duration(days: 29));
    final d = start.add(Duration(days: indexFromOldest));
    const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return names[(d.weekday - 1) % 7];
  }

  Future<void> _toggleAt(int indexFromOldest) async {
    final start = DateTime.now().subtract(Duration(days: 29));
    final day = start.add(Duration(days: indexFromOldest));
    final dayStr = day.toIso8601String().split('T')[0];
    await _db.toggleCheckoff(widget.habit.id!, dayStr);
    await _load();
  }

  Future<void> _deleteHabit() async {
    if (widget.habit.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Habit löschen'),
        content: Text('Möchtest du "${widget.habit.name}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Löschen')),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteHabit(widget.habit.id!);
      Navigator.of(context).pop(true); // signal back that deletion happened
    }
  }

  Future<void> _renameHabit() async {
    final ctrl = TextEditingController(text: widget.habit.name);
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Habit umbenennen'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: Text('Speichern')),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      final updated = Habit(id: widget.habit.id, name: res);
      await _db.updateHabit(updated);
      // replace local habit name (widget.habit is final) — navigate back with reload or update by reloading parent
      Navigator.of(context).pop(); // go back so parent reloads list (main.dart .then(_loadAll))
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit.name),
        actions: [
          IconButton(icon: Icon(Icons.edit), tooltip: 'Umbenennen', onPressed: _renameHabit),
          IconButton(icon: Icon(Icons.delete), tooltip: 'Löschen', onPressed: _deleteHabit),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('30-Tage-Übersicht', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('Tippe ein Feld, um den Tag als erledigt / nicht erledigt zu markieren.', style: TextStyle(color: Colors.grey[700])),
                  SizedBox(height: 12),
                  // grid 6 columns x5 rows = 30
                  Expanded(
                    child: GridView.builder(
                      itemCount: 30,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (ctx, i) {
                        final done = (i < _last30.length) ? _last30[i] == 1 : false;
                        final dayLabel = _dayLabel(i);
                        final weekday = _weekdayShort(i);
                        final isToday = i == 29; // index 29 = today (oldest->newest)
                        return GestureDetector(
                          onTap: () => _toggleAt(i),
                          child: Container(
                            decoration: BoxDecoration(
                              color: done ? Theme.of(context).primaryColor : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                              border: isToday ? Border.all(color: Colors.black45, width: 2) : null,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(weekday, style: TextStyle(fontWeight: FontWeight.w700, color: done ? Colors.white : Colors.black87)),
                                  SizedBox(height: 6),
                                  Text(dayLabel.substring(0,5), style: TextStyle(fontSize: 12, color: done ? Colors.white : Colors.black54)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: Icon(Icons.refresh),
                        label: Text('Neu laden'),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back),
                        label: Text('Zurück'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
