import 'package:flutter/material.dart';
import 'data/db_helper.dart';
import 'models/habit.dart';
import 'pages/stats_overview.dart';
import 'pages/habit_detail.dart';

void main() => runApp(HabitHeroApp());

class HabitHeroApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabitHero',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DBHelper _db = DBHelper.instance;
  List<Habit> _habits = [];
  Set<int> _checked = {};
  Map<int, List<int>> _chartData = {}; // habitId -> last 7 days 0/1 oldest->newest
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final habits = await _db.getHabits();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final checkedToday = await _db.getCheckedForDay(todayStr);

      final Map<int, List<int>> charts = {};
      for (final h in habits) {
        if (h.id == null) continue;
        final last7 = await _db.getChecksForLastNDays(h.id!, 7);
        charts[h.id!] = last7;
      }

      setState(() {
        _habits = habits;
        _checked = checkedToday.toSet();
        _chartData = charts;
      });
    } catch (e) {
      print('Fehler beim Laden: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addHabit(String name) async {
    if (name.trim().isEmpty) return;
    await _db.insertHabit(Habit(name: name.trim()));
    await _loadAll();
  }

  Future<void> _toggleCheck(int habitId) async {
    final day = DateTime.now().toIso8601String().split('T')[0];
    await _db.toggleCheckoff(habitId, day);
    await _loadAll();
  }

  Future<void> _deleteHabit(int id) async {
    await _db.deleteHabit(id);
    await _loadAll();
  }

  Future<void> _showAddDialog() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Neuen Habit'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'z. B. 30 Min. Bewegung'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text('Speichern')),
        ],
      ),
    );

    if (res != null && res.trim().isNotEmpty) {
      await _addHabit(res);
    }
  }

  String _formatToday() {
    final d = DateTime.now();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd.$mm.$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HabitHero'),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart),
            tooltip: 'Statistik',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => StatsOverviewPage()));
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text('Meine Habits – ${_formatToday()}'),
                trailing: IconButton(icon: Icon(Icons.add), onPressed: _showAddDialog),
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : (_habits.isEmpty
                      ? Center(child: Text('Noch keine Habits.'))
                      : ListView.builder(
                          itemCount: _habits.length,
                          itemBuilder: (ctx, i) {
                            final h = _habits[i];
                            final isOn = h.id != null && _checked.contains(h.id);
                            final chart = (h.id != null && _chartData.containsKey(h.id)) ? _chartData[h.id!]! : List.filled(7, 0);

                            return Dismissible(
                              key: ValueKey(h.id ?? '${h.name}-$i'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) async {
                                if (h.id != null) await _deleteHabit(h.id!);
                              },
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: 16),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    onTap: () {
                                      // -> Habit detail page
                                      if (h.id != null) {
                                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailPage(habit: h))).then((_) => _loadAll());
                                      }
                                    },
                                    leading: IconButton(
                                      icon: Icon(Icons.check_circle, color: isOn ? Colors.green : Colors.grey),
                                      onPressed: h.id != null ? () => _toggleCheck(h.id!) : null,
                                    ),
                                    title: Text(h.name),
                                    subtitle: Row(
                                      children: [
                                        Expanded(child: Text('Letzte 7 Tage')),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 120,
                                          height: 36,
                                          child: HabitMiniChart(data: chart),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(height: 1),
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sehr einfache Mini-Chart (ohne externe Lib) — robust und sichtbar.
/// data: List<int> mit 0/1 (ältester links)
class HabitMiniChart extends StatelessWidget {
  final List<int> data; // 0/1 oldest->newest (len 7 recommended)
  final double width;
  final double height;

  HabitMiniChart({required this.data, this.width = 120, this.height = 36});

  @override
  Widget build(BuildContext context) {
    final filledColor = Theme.of(context).primaryColor;
    final emptyColor = Colors.grey.shade300;

    // Sicherstellen: immer 7 Elemente (älteste links)
    final d = List<int>.from(data);
    if (d.length < 7) {
      final pad = List<int>.filled(7 - d.length, 0);
      d.insertAll(0, pad);
    } else if (d.length > 7) {
      final last7 = d.sublist(d.length - 7);
      d.clear();
      d.addAll(last7);
    }

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final v = d[i];
          final barHeight = v == 1 ? height * 0.85 : height * 0.28;
          return Container(
            width: (width - 6 * 6) / 7,
            height: barHeight,
            decoration: BoxDecoration(
              color: v == 1 ? filledColor : emptyColor,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}
