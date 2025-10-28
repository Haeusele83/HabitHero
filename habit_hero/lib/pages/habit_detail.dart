// lib/pages/habit_detail.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_hero/models/habit.dart';

class HabitDetailPage extends StatefulWidget {
  final Habit habit;
  const HabitDetailPage({Key? key, required this.habit}) : super(key: key);

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  late TextEditingController _nameCtrl;
  // Repeat days Mo..So (index 0 = Mo)
  List<bool> _repeatDays = List<bool>.filled(7, false);
  // optional: n times per week
  TextEditingController _countPerWeekCtrl = TextEditingController();
  // optional: time window
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _loading = true;

  String get _prefsKey => 'habit_sched_${widget.habit.id ?? widget.habit.name}';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.habit.name);
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    setState(() => _loading = true);
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_prefsKey);
    if (raw != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(raw);
        if (map.containsKey('repeatDays')) {
          final List<dynamic> arr = map['repeatDays'];
          _repeatDays = List<bool>.generate(7, (i) => i < arr.length ? (arr[i] == 1 || arr[i] == true) : false);
        }
        if (map.containsKey('countPerWeek')) {
          _countPerWeekCtrl.text = (map['countPerWeek']?.toString() ?? '');
        }
        if (map.containsKey('startTime')) {
          final s = map['startTime'] as String?;
          if (s != null && s.isNotEmpty) {
            final parts = s.split(':');
            if (parts.length == 2) _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        }
        if (map.containsKey('endTime')) {
          final s = map['endTime'] as String?;
          if (s != null && s.isNotEmpty) {
            final parts = s.split(':');
            if (parts.length == 2) _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        }
      } catch (e) {
        // ignore parse errors
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _saveToPrefs() async {
    setState(() => _loading = true);
    final sp = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'repeatDays': _repeatDays.map((b) => b ? 1 : 0).toList(),
      'countPerWeek': _countPerWeekCtrl.text.trim(),
      'startTime': _startTime != null ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}' : '',
      'endTime': _endTime != null ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}' : '',
    };
    await sp.setString(_prefsKey, jsonEncode(map));

    // Optional: versuche die Habit-Datenbank zu updaten, falls du das später möchtest.
    // Ich rufe das absichtlich über `dynamic` auf, damit der Code kompiliert,
    // auch wenn Deine DB-Klasse derzeit kein updateHabit hat.
    try {
      // (DBHelper.instance as dynamic).updateHabit(updatedHabit);
      // falls du DB-Update brauchst: entferne Kommentar und passe updatedHabit an deine Modell-Klasse an.
    } catch (_) {
      // ignore — fallback: wir speichern nur in prefs
    }

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Einstellungen gespeichert')));
  }

  Future<void> _resetSettings() async {
    setState(() {
      _repeatDays = List<bool>.filled(7, false);
      _countPerWeekCtrl.text = '';
      _startTime = null;
      _endTime = null;
    });
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_prefsKey);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Einstellungen zurückgesetzt')));
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay(hour: 8, minute: 0));
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay(hour: 20, minute: 0));
    if (picked != null) setState(() => _endTime = picked);
  }

  Widget _dayToggle(int index, String label) {
    final active = _repeatDays[index];
    return GestureDetector(
      onTap: () => setState(() => _repeatDays[index] = !_repeatDays[index]),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _timeToString(TimeOfDay? t) {
    if (t == null) return '—';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countPerWeekCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Habit Einstellungen'),
        actions: [
          TextButton(
            onPressed: _loading ? null : () async {
              await _saveToPrefs();
              // gib geänderten Habit zurück (optional)
              Navigator.of(context).pop(true);
            },
            child: _loading ? SizedBox.shrink() : Text('Speichern', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name (readonly/editable)
                  Text('Habit', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  TextField(controller: _nameCtrl, decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'Name des Habits')),
                  SizedBox(height: 18),

                  // Wiederholung
                  Text('Wiederholung', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: List.generate(7, (i) => _dayToggle(i, names[i]))),
                  SizedBox(height: 14),

                  // Anzahl pro Woche
                  Text('Anzahl pro Woche (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _countPerWeekCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'z. B. 3', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 12),

                  // Zeitfenster
                  Text('Zeitfenster (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickStartTime,
                        icon: Icon(Icons.access_time, size: 18),
                        label: Text('Start: ${_timeToString(_startTime)}'),
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _pickEndTime,
                        icon: Icon(Icons.access_time, size: 18),
                        label: Text('Ende: ${_timeToString(_endTime)}'),
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),

                  Text('Hinweis', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text(
                    'Wähle Wochentage, an denen der Habit aktiv sein soll. Optional kannst du angeben, wie oft pro Woche (z. B. 3×) oder ein Zeitfenster. Diese Einstellungen werden lokal gespeichert und können später für Erinnerungen/Statistiken verwendet werden.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 20),

                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _loading ? null : () async {
                          await _saveToPrefs();
                          Navigator.of(context).pop(true);
                        },
                        child: _loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Speichern'),
                      ),
                      SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _loading ? null : _resetSettings,
                        child: Text('Zurücksetzen'),
                      )
                    ],
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
