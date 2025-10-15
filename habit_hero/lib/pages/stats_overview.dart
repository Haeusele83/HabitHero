import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../data/db_helper.dart';
import '../models/habit.dart';
import '../main.dart';

class StatsOverviewPage extends StatefulWidget {
  @override
  _StatsOverviewPageState createState() => _StatsOverviewPageState();
}

class _StatsOverviewPageState extends State<StatsOverviewPage> {
  final DBHelper _db = DBHelper.instance;
  List<Habit> _habits = [];
  Map<int, List<int>> _last7 = {};
  Map<int, List<int>> _last30 = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final habits = await _db.getHabits();
      final Map<int, List<int>> l7 = {};
      final Map<int, List<int>> l30 = {};
      for (final h in habits) {
        if (h.id == null) continue;
        final last7 = await _db.getChecksForLastNDays(h.id!, 7);
        final last30 = await _db.getChecksForLastNDays(h.id!, 30);
        l7[h.id!] = last7;
        l30[h.id!] = last30;
      }
      setState(() {
        _habits = habits;
        _last7 = l7;
        _last30 = l30;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  int _calcStreak(List<int> dataOldestToNewest) {
    if (dataOldestToNewest.isEmpty) return 0;
    int streak = 0;
    for (int i = dataOldestToNewest.length - 1; i >= 0; i--) {
      if (dataOldestToNewest[i] == 1) streak++;
      else break;
    }
    return streak;
  }

  int _calcPercent(List<int> data) {
    if (data.isEmpty) return 0;
    final sum = data.fold<int>(0, (p, e) => p + e);
    return ((sum / data.length) * 100).round();
  }

  String _dateFullForIndex(int indexFromOldest, int totalDays) {
    final start = DateTime.now().subtract(Duration(days: totalDays - 1));
    final day = start.add(Duration(days: indexFromOldest));
    return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  }

  String _weekdayShortForIndex(int indexFromOldest, int totalDays) {
    final start = DateTime.now().subtract(Duration(days: totalDays - 1));
    final day = start.add(Duration(days: indexFromOldest));
    const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return names[(day.weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = Provider.of<AppSettingsNotifier>(context);
    final compact = appSettings.compactMode;
    final theme = Theme.of(context);

    final chartHeight = compact ? 100.0 : 140.0;
    final bottomReserved = compact ? 40.0 : 48.0;
    final headerFontSize = compact ? 14.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistik Übersicht'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadStats, tooltip: 'Aktualisieren'),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(compact ? 8 : 12),
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // small dashboard
                  Card(
                    margin: EdgeInsets.only(bottom: compact ? 8 : 12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 10 : 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Durchschnitt (30 Tage)', style: TextStyle(color: Colors.grey[700], fontSize: headerFontSize)),
                                SizedBox(height: 6),
                                Text('${_overallAveragePercent()}%', style: TextStyle(fontSize: compact ? 22 : 28, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _legendSwatch(theme.primaryColor, compact),
                              SizedBox(height: 6),
                              _legendSwatch(Colors.grey.shade300, compact),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: _habits.isEmpty
                        ? Center(child: Text('Noch keine Habits.'))
                        : RefreshIndicator(
                            onRefresh: _loadStats,
                            child: ListView.builder(
                              padding: EdgeInsets.only(bottom: 24),
                              itemCount: _habits.length,
                              itemBuilder: (ctx, i) {
                                final h = _habits[i];
                                final d7 = (_last7[h.id!] ?? List.filled(7, 0));
                                final d30 = (_last30[h.id!] ?? List.filled(30, 0));
                                final percent30 = _calcPercent(d30);
                                final streak = _calcStreak(d7);

                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
                                  child: Padding(
                                    padding: EdgeInsets.all(compact ? 10 : 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(h.name, style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w600))),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('$percent30%', style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.bold)),
                                                SizedBox(height: 4),
                                                Text('Streak: $streak', style: TextStyle(color: Colors.grey[700], fontSize: compact ? 12 : 13)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: compact ? 8 : 12),
                                        SizedBox(
                                          height: chartHeight,
                                          child: BarChart(
                                            BarChartData(
                                              maxY: 1.0,
                                              minY: 0.0,
                                              barGroups: _barGroupsFromDataWithColor(d7, theme.primaryColor),
                                              alignment: BarChartAlignment.spaceAround,
                                              gridData: FlGridData(show: false),
                                              borderData: FlBorderData(show: false),
                                              titlesData: FlTitlesData(
                                                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: bottomReserved,
                                                    getTitlesWidget: (double value, TitleMeta meta) {
                                                      final i = value.toInt();
                                                      if (i < 0 || i > 6) return const SizedBox.shrink();
                                                      final week = _weekdayShortForIndex(i, 7);
                                                      final date = _dateFullForIndex(i, 7);
                                                      return SizedBox(
                                                        height: bottomReserved,
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(week, style: TextStyle(fontSize: compact ? 10 : 12)),
                                                            SizedBox(height: 4),
                                                            Text(date.substring(0, 5), style: TextStyle(fontSize: compact ? 9 : 11, color: Colors.grey[700])),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              barTouchData: BarTouchData(
                                                enabled: true,
                                                touchTooltipData: BarTouchTooltipData(
                                                  tooltipMargin: 6,
                                                  getTooltipItem: (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                                                    final idxBar = group.x.toInt();
                                                    final dateFull = _dateFullForIndex(idxBar, 7);
                                                    final done = rod.toY >= 0.5;
                                                    final status = done ? 'Erledigt' : 'Nicht erledigt';
                                                    final text = '$dateFull\n$status';
                                                    return BarTooltipItem(text, TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: compact ? 11 : 13));
                                                  },
                                                ),
                                              ),
                                            ),
                                            swapAnimationDuration: Duration(milliseconds: 500),
                                            swapAnimationCurve: Curves.easeOutCubic,
                                          ),
                                        ),
                                        SizedBox(height: compact ? 8 : 10),
                                        Row(
                                          children: [
                                            Text('Letzte 7 Tage: ${d7.reduce((a, b) => a + b)}/7', style: TextStyle(color: Colors.grey[800], fontSize: compact ? 12 : 13)),
                                            SizedBox(width: 12),
                                            Text('Letzte 30 Tage: ${d30.reduce((a, b) => a + b)}/30', style: TextStyle(color: Colors.grey[800], fontSize: compact ? 12 : 13)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _legendSwatch(Color color, bool compact) {
    return Row(
      children: [
        Container(width: compact ? 12 : 14, height: compact ? 12 : 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        SizedBox(width: compact ? 8 : 10),
      ],
    );
  }

  List<BarChartGroupData> _barGroupsFromDataWithColor(List<int> data, Color primary) {
    final List<int> d = List<int>.from(data);
    if (d.length < 7) {
      final pad = List<int>.filled(7 - d.length, 0);
      d.insertAll(0, pad);
    } else if (d.length > 7) {
      d.removeRange(0, d.length - 7);
    }

    return List.generate(7, (i) {
      final val = d[i].toDouble();
      final isDone = val >= 1.0;
      final color = isDone ? primary : Colors.grey.shade300;
      final height = isDone ? 1.0 : 0.18;
      final rod = BarChartRodData(toY: height, width: 18, borderRadius: BorderRadius.circular(6), color: color);
      return BarChartGroupData(x: i, barRods: [rod]);
    });
  }

  int _overallAveragePercent() {
    if (_habits.isEmpty) return 0;
    final totals = _habits.map((h) {
      final d30 = _last30[h.id!] ?? List.filled(30, 0);
      final sum = d30.fold<int>(0, (p, e) => p + e);
      return ((sum / d30.length) * 100).round();
    }).toList();
    if (totals.isEmpty) return 0;
    final avg = totals.reduce((a, b) => a + b) / totals.length;
    return avg.round();
  }
}
