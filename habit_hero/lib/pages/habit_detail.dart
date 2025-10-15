// lib/pages/habit_detail.dart
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../data/db_helper.dart';
import 'package:intl/intl.dart';

class HabitDetailPage extends StatefulWidget {
  final Habit habit;
  HabitDetailPage({required this.habit});

  @override
  _HabitDetailPageState createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  final DBHelper _db = DBHelper.instance;

  // scheduling state
  int _daysMask = 0; // bitmask Mo..So
  int? _repeatsPerWeek;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _loading = true);
    final sched = await _db.getSchedule(widget.habit.id!);
    if (sched != null) {
      _daysMask = (sched['days_mask'] as int?) ?? 0;
      _repeatsPerWeek = sched['repeats_per_week'] as int?;
      final ts = sched['time_start'] as String?;
      final te = sched['time_end'] as String?;
      _timeStart = ts != null ? _timeFromString(ts) : null;
      _timeEnd = te != null ? _timeFromString(te) : null;
    } else {
      _daysMask = 0;
      _repeatsPerWeek = null;
      _timeStart = null;
      _timeEnd = null;
    }
    setState(() => _loading = false);
  }

  TimeOfDay _timeFromString(String s) {
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _timeToString(TimeOfDay? t) {
    if (t == null) return '';
    return t.hour.toString().padLeft(2, '0') + ':' + t.minute.toString().padLeft(2, '0');
  }

  void _toggleWeekday(int bit) {
    setState(() {
      _daysMask ^= bit;
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? (_timeStart ?? TimeOfDay(hour: 8, minute: 0)) : (_timeEnd ?? TimeOfDay(hour: 20, minute: 0));
    final res = await showTimePicker(context: context, initialTime: initial);
    if (res != null) {
      setState(() {
        if (isStart) _timeStart = res;
        else _timeEnd = res;
      });
    }
  }

  Future<void> _save() async {
    await _db.setSchedule(widget.habit.id!, daysMask: _daysMask, repeatsPerWeek: _repeatsPerWeek, timeStart: _timeToString(_timeStart), timeEnd: _timeToString(_timeEnd));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zeitplan gespeichert')));
    Navigator.of(context).pop();
  }

  Widget _weekdayButton(String label, int bit, bool active) {
    return GestureDetector(
      onTap: () => _toggleWeekday(bit),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.teal : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = [
      {'label': 'Mo', 'bit': 1},
      {'label': 'Di', 'bit': 2},
      {'label': 'Mi', 'bit': 4},
      {'label': 'Do', 'bit': 8},
      {'label': 'Fr', 'bit': 16},
      {'label': 'Sa', 'bit': 32},
      {'label': 'So', 'bit': 64},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Habit: ${widget.habit.name}'),
        actions: [
          TextButton(onPressed: _save, child: Text('Speichern', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wiederholung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: weekdays
                        .map((w) => _weekdayButton(w['label'] as String, w['bit'] as int, (_daysMask & (w['bit'] as int)) != 0))
                        .toList(),
                  ),
                  SizedBox(height: 18),
                  Text('Anzahl pro Woche (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 120,
                        child: TextFormField(
                          initialValue: _repeatsPerWeek?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: 'z. B. 3'),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            setState(() => _repeatsPerWeek = n);
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('oder wähle Tage oben (Mo–So)'),
                    ],
                  ),
                  SizedBox(height: 18),
                  Text('Zeitfenster (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickTime(true),
                        icon: Icon(Icons.access_time),
                        label: Text(_timeStart != null ? _timeToString(_timeStart) : 'Start'),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _pickTime(false),
                        icon: Icon(Icons.access_time),
                        label: Text(_timeEnd != null ? _timeToString(_timeEnd) : 'Ende'),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Hinweis', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text(
                    'Wähle Wochentage, an denen der Habit aktiv sein soll. Optional kannst du angeben, '
                    'wie oft pro Woche (z. B. 3×) oder ein Zeitfenster, in dem die Erledigung sinnvoll ist. '
                    'Die App nutzt diese Informationen für Erinnerungen/Statistiken (wenn implementiert).',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      ElevatedButton(onPressed: _save, child: Text('Speichern')),
                      SizedBox(width: 12),
                      OutlinedButton(
                          onPressed: () {
                            // clear schedule
                            setState(() {
                              _daysMask = 0;
                              _repeatsPerWeek = null;
                              _timeStart = null;
                              _timeEnd = null;
                            });
                          },
                          child: Text('Zurücksetzen')),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
