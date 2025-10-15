// lib/pages/month_calendar.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db_helper.dart';
import '../models/habit.dart';

class MonthCalendarPage extends StatefulWidget {
  @override
  _MonthCalendarPageState createState() => _MonthCalendarPageState();
}

class _MonthCalendarPageState extends State<MonthCalendarPage> {
  final DBHelper _db = DBHelper.instance;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Habit> _habits = [];
  Habit? _selectedHabit;
  Map<String, int> _countsCache = {}; // key: 'yyyy-mm-dd|habitId' -> count (0..n)
  bool _loading = true;
  bool _compact = false;

  // UI mode: 0 = month grid, 1 = 30-day heatmap
  int _viewMode = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadHabits();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final compact = sp.getBool('compact_mode') ?? false;
    setState(() => _compact = compact);
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);
    final habits = await _db.getHabits();
    setState(() {
      _habits = habits;
      if (_habits.isNotEmpty && _selectedHabit == null) _selectedHabit = _habits.first;
    });
    await _buildCountsCacheForMonth();
    setState(() => _loading = false);
  }

  /// Build a month cache of counts per day for the selected habit.
  /// Tries to use an optional DB method 'getCheckCountForDay(habitId, dateStr)' via dynamic call.
  /// Falls back to binary lookup using getCheckedForDay(dateStr).
  Future<void> _buildCountsCacheForMonth() async {
    if (_selectedHabit == null) {
      setState(() => _countsCache = {});
      return;
    }

    final Map<String, int> newCache = {};
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final last = DateTime(year, month + 1, 0);
    final days = last.day;

    for (int i = 1; i <= days; i++) {
      final d = DateTime(year, month, i);
      final keyDate = d.toIso8601String().split('T')[0];
      final key = '$keyDate|${_selectedHabit!.id}';
      int count = 0;

      // Try dynamic DB method returning a count for that habit & date
      try {
        // If DBHelper defines getCheckCountForDay(habitId, dateStr) -> int
        final dyn = _db as dynamic;
        final maybe = await dyn.getCheckCountForDay(_selectedHabit!.id, keyDate);
        if (maybe is int) {
          count = maybe;
        } else if (maybe is List) {
          // sometimes it might return a list of entries
          count = maybe.length;
        }
      } catch (_) {
        // fallback: check if getCheckedForDay(dateStr) exists (it did earlier)
        try {
          final checkedList = await _db.getCheckedForDay(keyDate); // expected List<int> habitIds
          if (checkedList is List) {
            // If DB stores one entry per habit per date, presence -> 1
            count = checkedList.contains(_selectedHabit!.id) ? 1 : 0;
          } else {
            count = 0;
          }
        } catch (_) {
          count = 0;
        }
      }

      newCache[key] = count;
    }

    if (mounted) setState(() => _countsCache = newCache);
  }

  Future<void> _toggleDay(DateTime d) async {
    if (_selectedHabit?.id == null) return;
    final dayStr = d.toIso8601String().split('T')[0];
    final key = '$dayStr|${_selectedHabit!.id}';

    // If DB supports counts >1, toggling semantics can be ambiguous.
    // We assume toggleCheckoff toggles a single "done" entry for that day (0<->1).
    // So we attempt to call toggleCheckoff and then rebuild counts cache (safe fallback).
    try {
      final dyn = _db as dynamic;
      if (dyn.toggleCheckoff != null) {
        await dyn.toggleCheckoff(_selectedHabit!.id, dayStr);
      } else {
        // fallback: try named method (but dynamic call already attempted)
        await _db.toggleCheckoff(_selectedHabit!.id!, dayStr);
      }
    } catch (_) {
      // try static fallback
      try {
        await _db.toggleCheckoff(_selectedHabit!.id!, dayStr);
      } catch (e) {
        // ignore
      }
    }

    // Rebuild counts for the month to reflect potential changes
    await _buildCountsCacheForMonth();

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text('Status geändert'),
      action: SnackBarAction(
        label: 'Rückgängig',
        onPressed: () async {
          // revert
          try {
            final dyn = _db as dynamic;
            if (dyn.toggleCheckoff != null) await dyn.toggleCheckoff(_selectedHabit!.id, dayStr);
            else await _db.toggleCheckoff(_selectedHabit!.id!, dayStr);
          } catch (_) {}
          await _buildCountsCacheForMonth();
        },
      ),
    ));
  }

  Future<void> _prevMonth() async {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1));
    await _buildCountsCacheForMonth();
  }

  Future<void> _nextMonth() async {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1));
    await _buildCountsCacheForMonth();
  }

  List<String> _weekdayNames() => ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  // Color interpolation helper: maps 0..maxCount -> color
  Color _colorForCount(BuildContext ctx, int count, int maxCount) {
    final theme = Theme.of(ctx);
    final base = Colors.grey.shade200;
    final target = theme.primaryColor;
    double factor;
    if (maxCount <= 1) {
      factor = (count == 0) ? 0.0 : 1.0;
    } else {
      factor = (count / maxCount).clamp(0.0, 1.0);
    }
    return Color.lerp(base, target, factor) ?? base;
  }

  // Try to fetch detailed entries for a date (timestamps or notes) for tooltip.
  // Use dynamic call to support different DB implementations. Return list of maps or null.
  Future<List<Map<String, dynamic>>?> _getDetailsForDate(int habitId, String dateStr) async {
    try {
      final dyn = _db as dynamic;
      // common possible method names: getCheckDetailsForDay, getCheckEntriesForDay, getChecksForDate
      if (dyn.getCheckDetailsForDay != null) {
        final r = await dyn.getCheckDetailsForDay(habitId, dateStr);
        return _coerceToMapList(r);
      }
    } catch (_) {}
    try {
      final dyn = _db as dynamic;
      if (dyn.getCheckEntriesForDay != null) {
        final r = await dyn.getCheckEntriesForDay(habitId, dateStr);
        return _coerceToMapList(r);
      }
    } catch (_) {}
    try {
      final dyn = _db as dynamic;
      if (dyn.getChecksForDate != null) {
        final r = await dyn.getChecksForDate(habitId, dateStr);
        return _coerceToMapList(r);
      }
    } catch (_) {}
    // If nothing, return null
    return null;
  }

  // helper to coerce various returned structures into List<Map<String,dynamic>>
  List<Map<String, dynamic>>? _coerceToMapList(dynamic r) {
    if (r == null) return null;
    if (r is List<Map<String, dynamic>>) return r;
    if (r is List) {
      // try to map items to maps if possible
      return r.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        return {'value': e};
      }).toList();
    }
    return null;
  }

  // Show dialog with precise tooltip/date details for that day
  Future<void> _showDayDetailsDialog(DateTime date) async {
    if (_selectedHabit == null) return;
    final dateStr = date.toIso8601String().split('T')[0];
    final key = '$dateStr|${_selectedHabit!.id}';
    final count = _countsCache[key] ?? 0;
    final details = await _getDetailsForDate(_selectedHabit!.id!, dateStr);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('${_selectedHabit!.name} — ${date.day}.${date.month}.${date.year}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anzahl Einträge: $count'),
              SizedBox(height: 8),
              if (details != null && details.isNotEmpty) ...[
                Text('Details:', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                ...details.map((m) {
                  // try to render common fields timestamp / time / note
                  final ts = m['timestamp'] ?? m['time'] ?? m['created_at'] ?? m['date_time'] ?? m['value'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(ts != null ? ts.toString() : m.toString(), style: TextStyle(fontSize: 13)),
                  );
                }).toList(),
              ] else
                Text('Keine detaillierten Zeitstempel vorhanden.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Schliessen')),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _toggleDay(date); // quick toggle from dialog
              },
              child: Text('Toggle'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _compact;
    final labelSize = compact ? 12.0 : 14.0;
    final padding = compact ? 8.0 : 12.0;

    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Mon
    final lastDay = DateTime(year, month + 1, 0).day;
    final totalCells = ((firstWeekday - 1) + lastDay);
    final rows = (totalCells / 7).ceil();

    // compute maxCount across cached month (for color scaling)
    int maxCount = 0;
    if (_countsCache.isNotEmpty) {
      maxCount = _countsCache.values.fold<int>(0, (p, e) => e > p ? e : p);
      maxCount = maxCount < 1 ? 1 : maxCount; // avoid zero division; keep at least 1
    }

    return Scaffold(
      appBar: AppBar(title: Text('Monats-Kalender')),
      body: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top: month nav + view toggle
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding / 1.2, vertical: padding / 1.0),
                child: Row(
                  children: [
                    IconButton(icon: Icon(Icons.chevron_left), onPressed: _prevMonth),
                    Expanded(
                      child: Center(
                        child: Text('${_visibleMonth.month.toString().padLeft(2, '0')}/${_visibleMonth.year}',
                            style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    ToggleButtons(
                      isSelected: [_viewMode == 0, _viewMode == 1],
                      onPressed: (idx) {
                        setState(() => _viewMode = idx);
                      },
                      constraints: BoxConstraints(minWidth: 42, minHeight: 36),
                      children: [Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Monat')), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('30 Tage'))],
                    ),
                    IconButton(icon: Icon(Icons.chevron_right), onPressed: _nextMonth),
                  ],
                ),
              ),
            ),

            SizedBox(height: 8),

            // habit selector + mini-month card
            Row(
              children: [
                Text('Habit:', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(width: 8),
                Expanded(
                  child: _habits.isEmpty
                      ? Text('Keine Habits', style: TextStyle(color: Colors.grey[700]))
                      : DropdownButton<Habit>(
                          isExpanded: true,
                          value: _selectedHabit,
                          items: _habits.map((h) => DropdownMenuItem(value: h, child: Text(h.name))).toList(),
                          onChanged: (v) async {
                            setState(() {
                              _selectedHabit = v;
                              _loading = true;
                            });
                            await _buildCountsCacheForMonth();
                            setState(() => _loading = false);
                          },
                        ),
                ),
                SizedBox(width: 12),
                if (_selectedHabit != null)
                  FutureBuilder<int>(
                    future: _calcMonthPercent(_selectedHabit!.id!, year, month),
                    builder: (ctx, snap) {
                      final percent = snap.hasData ? snap.data as int : 0;
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$percent%', style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w800)),
                            SizedBox(height: 6),
                            SizedBox(width: 120, child: LinearProgressIndicator(value: percent / 100.0, minHeight: compact ? 6 : 8)),
                            SizedBox(height: 4),
                            FutureBuilder<String>(future: _monthSummaryText(_selectedHabit!.id!, year, month), builder: (c, s2) {
                              final txt = s2.hasData ? s2.data as String : '';
                              return Text(txt, style: TextStyle(fontSize: compact ? 11 : 12, color: Colors.grey[700]));
                            }),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),

            SizedBox(height: 10),

            // legend + helper
            Row(children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(4))),
              SizedBox(width: 8),
              Text('Erledigt', style: TextStyle(fontSize: labelSize)),
              SizedBox(width: 16),
              Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
              SizedBox(width: 8),
              Text('Nicht erledigt', style: TextStyle(fontSize: labelSize)),
              Spacer(),
              if (maxCount > 1) _buildColorScale(context, maxCount),
            ]),
            SizedBox(height: 6),
            Text('Tippe ein Datum, um Status zu toggeln. Tippe lange für Details.', style: TextStyle(fontSize: labelSize - 1, color: Colors.grey[600])),

            SizedBox(height: 12),

            // weekday header
            Card(elevation: 0, color: Colors.transparent, child: Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Row(children: _weekdayNames().map((n) => Expanded(child: Center(child: Text(n, style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w700, color: Colors.grey[700]))))).toList()))),

            SizedBox(height: 8),

            // main area
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _selectedHabit == null
                      ? Center(child: Text('Bitte erst einen Habit auswählen.'))
                      : _viewMode == 0
                          ? _buildMonthGrid(context, year, month, firstWeekday, lastDay, rows, maxCount)
                          : _build30DayHeatmap(context, _selectedHabit!.id!, maxCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorScale(BuildContext ctx, int maxCount) {
    // Show 4 buckets for the legend
    final buckets = 4;
    return Row(
      children: List.generate(buckets, (i) {
        final factor = (i + 1) / buckets;
        final displayCount = ((factor * maxCount).ceil()).clamp(1, maxCount);
        final color = _colorForCount(ctx, displayCount, maxCount);
        return Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Row(children: [Container(width: 18, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), SizedBox(width: 6), Text('$displayCount')]),
        );
      }),
    );
  }

  Widget _buildMonthGrid(BuildContext context, int year, int month, int firstWeekday, int lastDay, int rows, int maxCount) {
    final compact = _compact;
    return LayoutBuilder(builder: (context, constraints) {
      final horizontalPadding = 6.0;
      final totalSpacing = horizontalPadding * 6;
      final cellWidth = ((constraints.maxWidth - totalSpacing) / 7).clamp(36.0, 64.0);
      final cellSize = cellWidth;

      return GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.0, mainAxisSpacing: 6, crossAxisSpacing: 6),
        itemCount: rows * 7,
        itemBuilder: (ctx, index) {
          final dayIndex = index - (firstWeekday - 1) + 1;
          if (dayIndex < 1 || dayIndex > lastDay) return SizedBox.shrink();

          final date = DateTime(year, month, dayIndex);
          final dateStr = date.toIso8601String().split('T')[0];
          final key = '$dateStr|${_selectedHabit!.id}';
          final count = _countsCache[key] ?? 0;
          final color = _colorForCount(context, count, maxCount);

          return Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await _toggleDay(date);
              },
              onLongPress: () async {
                await _showDayDetailsDialog(date);
              },
              child: Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: count > 0 ? color : Colors.transparent, width: 1.2),
                  boxShadow: count > 0 ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 6, offset: Offset(0, 2))] : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayIndex.toString(), style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w700, color: count > 0 ? Colors.white : Colors.black87)),
                    SizedBox(height: 6),
                    if (count > 1)
                      Text('x$count', style: TextStyle(fontSize: compact ? 11 : 12, color: Colors.white70))
                    else if (count == 1)
                      Icon(Icons.check_circle, size: compact ? 14 : 16, color: Colors.white70)
                    else
                      SizedBox(height: compact ? 14 : 16),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _build30DayHeatmap(BuildContext context, int habitId, int maxCount) {
    final compact = _compact;
    return FutureBuilder<List<int>>(
      future: _db.getChecksForLastNDays(habitId, 30),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        final data = snap.hasData ? snap.data! : List<int>.filled(30, 0);
        final d = List<int>.from(data);
        if (d.length < 30) d.insertAll(0, List<int>.filled(30 - d.length, 0));

        // If the returned values are only 0/1, maxCount might be 1; compute max based on values
        int computedMax = 1;
        for (var v in d) {
          if (v is int && v > computedMax) computedMax = v;
        }
        if (maxCount < computedMax) maxCount = computedMax;

        final startDate = DateTime.now().subtract(Duration(days: d.length - 1));
        final totalDone = d.fold<int>(0, (p, e) => p + (e is int ? e : 0));
        final percent = d.isEmpty ? 0 : ((totalDone / d.length) * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Text('Letzte 30 Tage', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: 12),
                  Text('$percent% erledigt', style: TextStyle(color: Colors.grey[700])),
                  Spacer(),
                  if (maxCount > 1) _buildColorScale(context, maxCount),
                  SizedBox(width: 8),
                ],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(d.length, (i) {
                      final date = startDate.add(Duration(days: i));
                      final v = d[i] is int ? d[i] as int : (d[i] == true ? 1 : 0);
                      final doneCount = v;
                      final color = _colorForCount(context, doneCount, maxCount);
                      final dayLabel = '${date.day}';
                      final weekdayShort = _weekdayShort(date.weekday);
                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(weekdayShort, style: TextStyle(fontSize: compact ? 11 : 12, color: Colors.grey[600])),
                            SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _toggleHeatmapDay(habitId, date),
                              onLongPress: () => _showDayDetailsDialog(date),
                              child: Container(
                                width: compact ? 34 : 44,
                                height: compact ? 34 : 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: doneCount > 0 ? color : Colors.transparent, width: 1.2),
                                  boxShadow: doneCount > 0 ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 6, offset: Offset(0, 2))] : [],
                                ),
                                child: Center(
                                  child: doneCount > 1 ? Text('x$doneCount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)) : (doneCount == 1 ? Icon(Icons.check, color: Colors.white) : Text(dayLabel, style: TextStyle(color: Colors.black87))),
                                ),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text('${date.day}.${date.month}', style: TextStyle(fontSize: compact ? 10 : 11, color: Colors.grey[600])),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Text('Erledigte Einträge: $totalDone / ${d.length}', style: TextStyle(color: Colors.grey[700])),
                  Spacer(),
                  ElevatedButton.icon(onPressed: () => setState(() => _viewMode = 0), icon: Icon(Icons.grid_view), label: Text('Zur Monatsansicht'), style: ElevatedButton.styleFrom(minimumSize: Size(120, 36))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleHeatmapDay(int habitId, DateTime date) async {
    final dayStr = date.toIso8601String().split('T')[0];
    try {
      final dyn = _db as dynamic;
      if (dyn.toggleCheckoff != null)
        await dyn.toggleCheckoff(habitId, dayStr);
      else
        await _db.toggleCheckoff(habitId, dayStr);
    } catch (_) {
      try {
        await _db.toggleCheckoff(habitId, dayStr);
      } catch (_) {}
    }
    await _buildCountsCacheForMonth();
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text('Status geändert'), action: SnackBarAction(label: 'Rückgängig', onPressed: () async {
      try {
        final dyn = _db as dynamic;
        if (dyn.toggleCheckoff != null) await dyn.toggleCheckoff(habitId, dayStr);
        else await _db.toggleCheckoff(habitId, dayStr);
      } catch (_) {}
      await _buildCountsCacheForMonth();
      setState(() {});
    })));
  }

  String _weekdayShort(int weekday) {
    const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return names[(weekday - 1) % 7];
  }

  Future<int> _calcMonthPercent(int habitId, int year, int month) async {
    final last = DateTime(year, month + 1, 0);
    final days = last.day;
    int count = 0;
    for (int i = 1; i <= days; i++) {
      final date = DateTime(year, month, i).toIso8601String().split('T')[0];
      try {
        // try count method first
        final dyn = _db as dynamic;
        if (dyn.getCheckCountForDay != null) {
          final maybe = await dyn.getCheckCountForDay(habitId, date);
          if (maybe is int) {
            if (maybe > 0) count += maybe;
            continue;
          }
        }
      } catch (_) {}
      try {
        final checkedList = await _db.getCheckedForDay(date);
        if (checkedList is List && checkedList.contains(habitId)) count++;
      } catch (_) {}
    }
    if (days == 0) return 0;
    return ((count / days) * 100).round();
  }

  Future<String> _monthSummaryText(int habitId, int year, int month) async {
    final last = DateTime(year, month + 1, 0);
    final days = last.day;
    int count = 0;
    for (int i = 1; i <= days; i++) {
      final date = DateTime(year, month, i).toIso8601String().split('T')[0];
      try {
        final dyn = _db as dynamic;
        if (dyn.getCheckCountForDay != null) {
          final maybe = await dyn.getCheckCountForDay(habitId, date);
          if (maybe is int) {
            if (maybe > 0) count++;
            continue;
          }
        }
      } catch (_) {}
      try {
        final checkedList = await _db.getCheckedForDay(date);
        if (checkedList is List && checkedList.contains(habitId)) count++;
      } catch (_) {}
    }
    return '$count / $days Tagen';
  }
}

