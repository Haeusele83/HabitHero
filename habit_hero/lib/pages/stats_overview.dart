// lib/pages/stats_overview.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:habit_hero/data/db_helper.dart';
import 'package:habit_hero/models/habit.dart';
import 'package:habit_hero/pages/habit_detail.dart';

class StatsOverviewPage extends StatefulWidget {
  const StatsOverviewPage({Key? key}) : super(key: key);

  @override
  State<StatsOverviewPage> createState() => _StatsOverviewPageState();
}

class _StatsOverviewPageState extends State<StatsOverviewPage> with TickerProviderStateMixin {
  final DBHelper _db = DBHelper.instance;
  bool _loading = true;
  List<Habit> _habits = [];
  Map<int, List<int>> _last30 = {}; // habitId -> 30 days (oldest -> newest)
  Map<int, int> _streaks = {};
  int _averagePercent = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final habits = await _db.getHabits();
      final Map<int, List<int>> last30 = {};
      final Map<int, int> streaks = {};

      for (final h in habits) {
        if (h.id == null) continue;
        final l30 = await _db.getChecksForLastNDays(h.id!, 30);
        final l7 = await _db.getChecksForLastNDays(h.id!, 7);
        last30[h.id!] = _padTo(l30, 30);
        streaks[h.id!] = _calcStreak(l7);
      }

      final avg = _calcAveragePercent(last30);

      if (mounted) {
        setState(() {
          _habits = habits;
          _last30 = last30;
          _streaks = streaks;
          _averagePercent = avg;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ladefehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<int> _padTo(List<int> src, int n) {
    final s = List<int>.from(src);
    if (s.length < n) {
      final fill = List<int>.filled(n - s.length, 0);
      return [...fill, ...s];
    } else if (s.length > n) {
      return s.sublist(s.length - n);
    }
    return s;
  }

  int _calcStreak(List<int>? last7) {
    if (last7 == null || last7.isEmpty) return 0;
    int streak = 0;
    for (int i = last7.length - 1; i >= 0; i--) {
      if (last7[i] == 1) streak++;
      else break;
    }
    return streak;
  }

  int _calcPercentFromList(List<int> list) {
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(0, (p, e) => p + e);
    return ((sum / list.length) * 100).round();
  }

  int _calcAveragePercent(Map<int, List<int>> map) {
    if (map.isEmpty) return 0;
    double total = 0;
    int count = 0;
    map.forEach((k, v) {
      if (v.isNotEmpty) {
        total += v.fold<int>(0, (p, e) => p + e) / v.length;
        count++;
      }
    });
    if (count == 0) return 0;
    return (total / count * 100).round();
  }

  Color _heatColorForValue(double v) {
    // v between 0 and 1
    if (v <= 0) return Colors.grey.shade200;
    if (v < 0.4) return Colors.teal.shade100;
    if (v < 0.7) return Colors.teal.shade300;
    return Colors.teal.shade700;
  }

  String _formatDateFromIndex(int indexFromOldest) {
    // indexFromOldest: 0..29 -> oldest .. newest (today)
    final day = DateTime.now().subtract(Duration(days: (29 - indexFromOldest)));
    return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Statistik Übersicht'),
        elevation: 1,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: EdgeInsets.all(14),
                children: [
                  _buildHeaderCard(),
                  SizedBox(height: 14),
                  ..._habits.map((h) => _buildHabitCard(h)).toList(),
                  SizedBox(height: 18),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final totalHabits = _habits.length;
    final msg = _averagePercent >= 75
        ? 'Top! Behalte die Leistung bei.'
        : (_averagePercent >= 40 ? 'Gute Entwicklung — dranbleiben!' : 'Kleinschrittig starten und verbessern.');
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // grosse Prozentzahl
            Container(
              width: 84,
              height: 84,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: _averagePercent / 100.0),
                  duration: Duration(milliseconds: 900),
                  builder: (context, v, _) {
                    final p = (v * 100).round();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: v,
                                strokeWidth: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(p >= 70 ? Colors.green : (p >= 40 ? Colors.orange : Colors.red)),
                              ),
                              Text('$p%', style: TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        SizedBox(height: 6),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: 12),
            // Text & Legend
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Durchschnitt (30 Tage)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('$totalHabits Habits • Letzte 30 Tage', style: TextStyle(color: Colors.grey[700])),
                  SizedBox(height: 8),
                  Text(msg, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                ],
              ),
            ),
            // simple legend
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _legendRow(Colors.teal.shade700, 'Erledigt'),
                SizedBox(height: 6),
                _legendRow(Colors.grey.shade300, 'Nicht erledigt'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildHabitCard(Habit h) {
    final id = h.id;
    final data30 = (id != null && _last30.containsKey(id)) ? _last30[id]! : List<int>.filled(30, 0);
    final percent = _calcPercentFromList(data30);
    final streak = id != null && _streaks.containsKey(id) ? _streaks[id!] ?? 0 : 0;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          children: [
            // Row: name + percent + small sparkline
            Row(
              children: [
                // percent circle
                SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      SmallCircularPercent(percent: percent),
                      SizedBox(height: 6),
                      Text('$percent%', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                // title + streak
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.name, style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 16, color: streak > 0 ? Colors.orange : Colors.grey),
                          SizedBox(width: 6),
                          Text('Streak: $streak', style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                // Details button
                IconButton(
                  icon: Icon(Icons.open_in_new_outlined),
                  tooltip: 'Details',
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailPage(habit: h))).then((_) => _loadStats());
                  },
                ),
              ],
            ),

            SizedBox(height: 12),

            // Heatmap grid (5 columns x 6 rows = 30 days)
            _HeatmapGrid(
              values: data30,
              onCellTap: (index, done) {
                final date = _formatDateFromIndex(index);
                final text = done ? '$date — Erledigt' : '$date — Nicht erledigt';
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: Duration(milliseconds: 1000)));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular percent used in header/card
class SmallCircularPercent extends StatelessWidget {
  final int percent;
  const SmallCircularPercent({Key? key, required this.percent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final val = (percent.clamp(0, 100)) / 100.0;
    final color = percent >= 70 ? Colors.green : (percent >= 40 ? Colors.orange : Colors.red);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: val,
            strokeWidth: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text('$percent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Heatmap grid widget: 5 columns x 6 rows (30 cells)
class _HeatmapGrid extends StatelessWidget {
  final List<int> values; // oldest -> newest, length 30 (padded)
  final void Function(int indexFromOldest, bool done) onCellTap;

  const _HeatmapGrid({Key? key, required this.values, required this.onCellTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final padded = _pad(values, 30);
    // We render as 6 rows x 5 cols (left-to-right, top-to-bottom)
    // Index mapping: i in 0..29 -> padded[i]
    final theme = Theme.of(context);
    final cellSize = min(36.0, (MediaQuery.of(context).size.width - 64) / 5);

    return Column(
      children: List.generate(6, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (col) {
              final idx = row * 5 + col; // 0..29
              final v = padded[idx];
              final done = v >= 1;
              final color = done ? theme.primaryColor : Colors.grey.shade300;
              final bg = done ? _heatColorForValue(theme, 1.0) : Colors.grey.shade200;
              return GestureDetector(
                onTap: () => onCellTap(idx, done),
                child: Column(
                  children: [
                    Container(
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        color: done ? color : bg,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: done ? [BoxShadow(color: color.withOpacity(0.18), blurRadius: 6, offset: Offset(0, 3))] : [],
                        border: Border.all(color: done ? color.withOpacity(0.9) : Colors.grey.shade200, width: 1),
                      ),
                      child: done
                          ? Center(child: Icon(Icons.check, color: Colors.white, size: cellSize * 0.45))
                          : SizedBox.shrink(),
                    ),
                    SizedBox(height: 6),
                    // day number
                    Container(
                      width: cellSize,
                      child: Center(
                        child: Text(
                          _dayNumberForIndex(idx),
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  List<int> _pad(List<int> src, int n) {
    final s = List<int>.from(src);
    if (s.length < n) {
      final fill = List<int>.filled(n - s.length, 0);
      return [...fill, ...s];
    } else if (s.length > n) {
      return s.sublist(s.length - n);
    }
    return s;
  }

  String _dayNumberForIndex(int indexFromOldest) {
    final day = DateTime.now().subtract(Duration(days: (29 - indexFromOldest)));
    return day.day.toString();
  }

  Color _heatColorForValue(ThemeData theme, double v) {
    if (v <= 0) return Colors.grey.shade200;
    if (v < 0.4) return theme.primaryColor.withOpacity(0.22);
    if (v < 0.7) return theme.primaryColor.withOpacity(0.42);
    return theme.primaryColor.withOpacity(0.9);
  }
}
