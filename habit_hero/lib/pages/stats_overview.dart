import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/db_helper.dart';
import '../models/habit.dart';

/// Statistik-Übersicht — adaptive Chart-Höhe, kleinere Labels, Overflow-Fixes für hohe Auflösungen.
class StatsOverviewPage extends StatefulWidget {
  @override
  _StatsOverviewPageState createState() => _StatsOverviewPageState();
}

class _StatsOverviewPageState extends State<StatsOverviewPage> {
  final DBHelper _db = DBHelper.instance;
  List<Habit> _habits = [];
  Map<int, List<int>> _last7 = {}; // habitId -> 0/1 oldest->newest
  Map<int, List<int>> _last30 = {};
  bool _loading = true;

  // Baseline max values — werden adaptiv reduziert auf kleinen Bildschirmen
  static const double _maxChartHeight = 120;
  static const double _minChartHeight = 80;
  static const double _baseBottomReserved = 44;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
      }
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

  int _overallAveragePercent() {
    if (_habits.isEmpty) return 0;
    final totals = _habits.map((h) {
      final d30 = _last30[h.id!] ?? List.filled(30, 0);
      return _calcPercent(d30);
    }).toList();
    if (totals.isEmpty) return 0;
    final avg = totals.reduce((a, b) => a + b) / totals.length;
    return avg.round();
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

  /// Berechnet eine adaptive Chart-Höhe basierend auf verfügbarer Bildschirmhöhe
  double _computeChartHeight(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final available = mq.size.height - mq.padding.top - kToolbarHeight; // grobe verfügbare Höhe
    // Ziel: Chart nicht größer als 20% der verfügbaren Höhe, begrenzt durch min/max
    final candidate = available * 0.18;
    return candidate.clamp(_minChartHeight, _maxChartHeight);
  }

  /// Adaptive reserved size (für bottom titles) — reduziert leicht bei wenig Platz
  double _computeReservedSize(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final available = mq.size.height - mq.padding.top - kToolbarHeight;
    final candidate = _baseBottomReserved;
    // wenn sehr wenig Platz, mache reserved kleiner
    if (available < 600) return candidate * 0.9;
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    final overall = _overallAveragePercent();
    final theme = Theme.of(context);
    final chartHeight = _computeChartHeight(context);
    final reservedSize = _computeReservedSize(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistik Übersicht'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: _loading
              ? Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dashboard + legend (kompakter)
                    Card(
                      margin: EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Durchschnitt (30 Tage)', style: TextStyle(color: Colors.grey[700])),
                                  SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('$overall%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${_habits.length} Habits', style: TextStyle(color: Colors.grey[600])),
                                          SizedBox(height: 4),
                                          Text('Tippe Balken = Datum & Status', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    _legendSwatch(theme.primaryColor),
                                    SizedBox(width: 8),
                                    Text('Erledigt', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    _legendSwatch(Colors.grey.shade300),
                                    SizedBox(width: 8),
                                    Text('Nicht erledigt', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Habits list
                    Expanded(
                      child: _habits.isEmpty
                          ? Center(child: Text('Noch keine Habits.'))
                          : RefreshIndicator(
                              onRefresh: _loadStats,
                              child: ListView.builder(
                                padding: EdgeInsets.only(bottom: 28),
                                itemCount: _habits.length,
                                itemBuilder: (ctx, idx) {
                                  final h = _habits[idx];
                                  final d7 = (_last7[h.id!] ?? List.filled(7, 0));
                                  final d30 = (_last30[h.id!] ?? List.filled(30, 0));
                                  final percent30 = _calcPercent(d30);
                                  final streak = _calcStreak(d7);

                                  return Card(
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // header
                                          Row(
                                            children: [
                                              Expanded(child: Text(h.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text('$percent30%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                                  SizedBox(height: 4),
                                                  Text('Streak: $streak', style: TextStyle(color: Colors.grey[700])),
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),

                                          // Chart (adaptive height)
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
                                                      reservedSize: reservedSize,
                                                      getTitlesWidget: (double value, TitleMeta meta) {
                                                        final i = value.toInt();
                                                        if (i < 0 || i > 6) return const SizedBox.shrink();
                                                        final week = _weekdayShortForIndex(i, 7);
                                                        final date = _dateFullForIndex(i, 7);
                                                        // compact fixed-height widget to avoid overflow
                                                        return SizedBox(
                                                          height: reservedSize,
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(week, style: TextStyle(fontSize: 11)),
                                                              SizedBox(height: 4),
                                                              Text(date.substring(0, 5), style: TextStyle(fontSize: 10, color: Colors.grey[700])),
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
                                                      return BarTooltipItem(text, TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13));
                                                    },
                                                  ),
                                                ),
                                              ),
                                              swapAnimationDuration: Duration(milliseconds: 450),
                                              swapAnimationCurve: Curves.easeOutCubic,
                                            ),
                                          ),

                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text('Letzte 7 Tage: ${d7.reduce((a, b) => a + b)}/7', style: TextStyle(color: Colors.grey[800])),
                                              SizedBox(width: 16),
                                              Text('Letzte 30 Tage: ${d30.reduce((a, b) => a + b)}/30', style: TextStyle(color: Colors.grey[800])),
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
      ),
    );
  }

  Widget _legendSwatch(Color color) => Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)));

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
      final rod = BarChartRodData(
        toY: height,
        width: 20,
        borderRadius: BorderRadius.circular(6),
        color: color,
      );
      return BarChartGroupData(x: i, barRods: [rod]);
    });
  }
}
