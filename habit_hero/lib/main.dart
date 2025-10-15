// lib/main.dart (komplett ersetzen)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'data/db_helper.dart';
import 'models/habit.dart';
import 'pages/stats_overview.dart';
import 'pages/habit_detail.dart';
import 'pages/onboarding.dart';
import 'pages/settings.dart';
import 'pages/month_calendar.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..loadFromPrefs()),
        ChangeNotifierProvider(create: (_) => AppSettingsNotifier()..loadFromPrefs()),
      ],
      child: HabitHeroApp(),
    ),
  );
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  Future<void> loadFromPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final isDark = sp.getBool('dark_mode') ?? false;
    _mode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _mode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('dark_mode', isDark);
  }
}

class AppSettingsNotifier extends ChangeNotifier {
  bool _compactMode = false;
  bool get compactMode => _compactMode;

  Future<void> loadFromPrefs() async {
    final sp = await SharedPreferences.getInstance();
    _compactMode = sp.getBool('compact_mode') ?? false;
    notifyListeners();
  }

  Future<void> setCompactMode(bool v) async {
    _compactMode = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('compact_mode', v);
  }
}

class HabitHeroApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return MaterialApp(
          title: 'HabitHero',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.mode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: EntryDecider(),
        );
      },
    );
  }

  ThemeData _lightTheme() {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      useMaterial3: true,
      primaryColor: Colors.teal,
      colorScheme: base.colorScheme.copyWith(primary: Colors.teal),
      scaffoldBackgroundColor: Colors.grey[100],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w700),
      ),
      cardColor: Colors.white,
    );
  }

  ThemeData _darkTheme() {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      useMaterial3: true,
      primaryColor: Colors.teal,
      colorScheme: base.colorScheme.copyWith(primary: Colors.teal),
      scaffoldBackgroundColor: Colors.black,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      cardColor: Colors.grey[850],
    );
  }
}

class EntryDecider extends StatefulWidget {
  @override
  _EntryDeciderState createState() => _EntryDeciderState();
}

class _EntryDeciderState extends State<EntryDecider> {
  bool _loading = true;
  bool _seenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final sp = await SharedPreferences.getInstance();
    final seen = sp.getBool('seen_onboarding') ?? false;
    setState(() {
      _seenOnboarding = seen;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return _seenOnboarding ? HomePage() : OnboardingPage();
  }
}

/// HomePage
class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DBHelper _db = DBHelper.instance;
  List<Habit> _habits = [];
  Set<int> _checked = {};
  Map<int, List<int>> _chartData = {};
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ladefehler: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addHabit(String name) async {
    if (name.trim().isEmpty) return;
    final newHabit = Habit(name: name.trim(), createdAt: DateTime.now().toIso8601String());
    await _db.insertHabit(newHabit);
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
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: 'z. B. 30 Min. Bewegung')),
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
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  int _calcPercentFromList(List<int> data) {
    if (data.isEmpty) return 0;
    final sum = data.fold<int>(0, (p, e) => p + e);
    return ((sum / data.length) * 100).round();
  }

  int _calcStreakFor7(List<int> data) {
    if (data.isEmpty) return 0;
    int streak = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 1) streak++;
      else break;
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appSettings = Provider.of<AppSettingsNotifier>(context);
    final compact = appSettings.compactMode;

    final cardPadding = compact ? 8.0 : 12.0;
    final tileFontSize = compact ? 14.0 : 16.0;

    final double cardMinHeight = compact ? 88.0 : 110.0;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 140,
        leading: Padding(
          padding: EdgeInsets.only(left: cardPadding),
          child: Row(
            children: [
              Hero(
                tag: 'logo-hero',
                child: Image.asset('assets/logo.png', width: compact ? 40 : 48, height: compact ? 40 : 48, fit: BoxFit.contain),
              ),
              SizedBox(width: compact ? 6 : 8),
              Flexible(child: Text('HabitHero', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month_outlined),
            tooltip: 'Monats-Kalender',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MonthCalendarPage())).then((_) => _loadAll()),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart_outlined),
            tooltip: 'Statistik',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StatsOverviewPage())).then((_) => _loadAll()),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage())).then((_) => _loadAll()),
          ),
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadAll, tooltip: 'Neu laden'),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(compact ? 8 : 12),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Row(
                  children: [
                    Expanded(child: Text('Meine Habits – ${_formatToday()}')),
                    IconButton(onPressed: _showAddDialog, icon: Icon(Icons.add), visualDensity: compact ? VisualDensity.compact : VisualDensity.standard),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 10),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _habits.isEmpty
                      ? Center(child: Text('Noch keine Habits. Tippe + um einen zu erstellen.'))
                      : ListView.separated(
                          itemCount: _habits.length,
                          separatorBuilder: (_, __) => SizedBox(height: compact ? 6 : 8),
                          itemBuilder: (ctx, i) {
                            final h = _habits[i];
                            final isOn = h.id != null && _checked.contains(h.id);
                            final last7 = (h.id != null && _chartData.containsKey(h.id)) ? _chartData[h.id!]! : List.filled(7, 0);

                            final int percent30 = _calcPercentFromList(last7);
                            final int streak = _calcStreakFor7(last7);

                            return LayoutBuilder(builder: (context, constraints) {
                              final availableCardWidth = constraints.maxWidth;
                              final rightMax = (availableCardWidth * (compact ? 0.22 : 0.24)).clamp(70.0, 140.0);

                              return Slidable(
                                key: ValueKey(h.id ?? '${h.name}-$i'),
                                endActionPane: ActionPane(
                                  motion: DrawerMotion(),
                                  extentRatio: 0.32,
                                  children: [
                                    SlidableAction(
                                      onPressed: (ctx) {
                                        if (h.id != null) {
                                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailPage(habit: h))).then((_) => _loadAll());
                                        }
                                      },
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      icon: Icons.edit,
                                      label: 'Details',
                                    ),
                                    SlidableAction(
                                      onPressed: (ctx) async {
                                        if (h.id != null) {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (dCtx) => AlertDialog(
                                              title: Text('Habit löschen'),
                                              content: Text('Wirklich "${h.name}" löschen?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: Text('Abbrechen')),
                                                ElevatedButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text('Löschen')),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _deleteHabit(h.id!);
                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Habit gelöscht'),
                                                action: SnackBarAction(
                                                  label: 'Rückgängig',
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bitte neu anlegen — Wiederherstellung nicht verfügbar.')));
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete,
                                      label: 'Löschen',
                                    ),
                                  ],
                                ),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  constraints: BoxConstraints(minHeight: cardMinHeight),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 8 : 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // left: circular percent
                                        SizedBox(
                                          width: compact ? 56 : 68,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              CircularProgressPercent(percent: percent30, size: compact ? 44 : 56),
                                              SizedBox(height: 6),
                                              FittedBox(child: Text('${percent30}%', style: TextStyle(fontSize: compact ? 11 : 12))),
                                            ],
                                          ),
                                        ),

                                        SizedBox(width: compact ? 10 : 14),

                                        // middle: flexible column (title + streak + timeline)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      h.name,
                                                      style: TextStyle(fontSize: tileFontSize, fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: compact ? 6 : 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.local_fire_department, size: compact ? 14 : 16, color: streak > 0 ? Colors.orange : Colors.grey),
                                                  SizedBox(width: 6),
                                                  Text('Streak: $streak', style: TextStyle(fontSize: compact ? 12 : 13, color: Colors.grey[700])),
                                                ],
                                              ),
                                              SizedBox(height: compact ? 8 : 10),
                                              HabitDotTimeline(data: last7, compact: compact),
                                            ],
                                          ),
                                        ),

                                        SizedBox(width: 12),

                                        // right: constrained button area
                                        ConstrainedBox(
                                          constraints: BoxConstraints(maxWidth: rightMax),
                                          child: HabitDoneButton(
                                            habitId: h.id,
                                            isDone: isOn,
                                            compact: compact,
                                            onToggled: () async {
                                              if (h.id == null) return;
                                              await _toggleCheck(h.id!);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            });
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: Icon(Icons.add),
        tooltip: 'Neuen Habit',
      ),
    );
  }
}

/// Circular percent widget
class CircularProgressPercent extends StatelessWidget {
  final int percent;
  final double size;
  const CircularProgressPercent({Key? key, required this.percent, this.size = 56}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double value = (percent.clamp(0, 100)) / 100.0;
    final color = percent >= 70 ? Colors.green : (percent >= 40 ? Colors.orange : Colors.red);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: size * 0.12,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$percent',
            style: TextStyle(fontSize: size * 0.28, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Dot timeline (7 days)
class HabitDotTimeline extends StatelessWidget {
  final List<int> data; // oldest -> newest
  final bool compact;

  const HabitDotTimeline({Key? key, required this.data, this.compact = false}) : super(key: key);

  String _dateForIndex(int idx) {
    final start = DateTime.now().subtract(Duration(days: 6));
    final day = start.add(Duration(days: idx));
    return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  }

  String _weekdayShort(int idx) {
    final start = DateTime.now().subtract(Duration(days: 6));
    final day = start.add(Duration(days: idx));
    const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return names[(day.weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    final d = List<int>.from(data);
    if (d.length < 7) d.insertAll(0, List<int>.filled(7 - d.length, 0));
    final dotSize = compact ? 14.0 : 18.0;
    final labelSize = compact ? 10.0 : 12.0;
    final gap = compact ? 6.0 : 8.0;

    return LayoutBuilder(builder: (context, constraints) {
      final avail = constraints.maxWidth;
      final maxDotsWidth = 7 * dotSize;
      final remaining = (avail - maxDotsWidth).clamp(0.0, avail);
      final computedGap = (remaining / 6).clamp(4.0, gap);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: labelSize + 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (i) {
                return Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : computedGap),
                  child: SizedBox(width: dotSize, child: Center(child: Text(_weekdayShort(i), style: TextStyle(fontSize: labelSize, color: Colors.grey[700])))),
                );
              }),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            height: dotSize + 4,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned.fill(
                  top: (dotSize / 2) + 2,
                  bottom: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0),
                    child: Container(height: 2, color: Theme.of(context).dividerColor.withOpacity(0.12)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (i) {
                    final done = d[i] == 1;
                    final color = done ? Theme.of(context).primaryColor : Colors.grey.shade300;
                    final isToday = i == 6;
                    return Padding(
                      padding: EdgeInsets.only(right: i == 6 ? 0 : computedGap),
                      child: GestureDetector(
                        onTap: () {
                          final date = _dateForIndex(i);
                          final status = done ? 'Erledigt' : 'Nicht erledigt';
                          final snack = SnackBar(content: Text('$date — $status'), duration: Duration(milliseconds: 900));
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(snack);
                        },
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isToday ? Border.all(color: Colors.black26, width: 1.2) : null,
                            boxShadow: done ? [BoxShadow(color: color.withOpacity(0.22), blurRadius: 6, offset: Offset(0, 2))] : [],
                          ),
                          child: Center(child: done ? Icon(Icons.check, size: dotSize * 0.6, color: Colors.white) : SizedBox.shrink()),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Done button
class HabitDoneButton extends StatefulWidget {
  final int? habitId;
  final bool isDone;
  final bool compact;
  final Future<void> Function() onToggled;

  const HabitDoneButton({Key? key, required this.habitId, required this.isDone, required this.onToggled, this.compact = false}) : super(key: key);

  @override
  _HabitDoneButtonState createState() => _HabitDoneButtonState();
}

class _HabitDoneButtonState extends State<HabitDoneButton> with SingleTickerProviderStateMixin {
  late bool _done;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _done = widget.isDone;
    _anim = AnimationController(vsync: this, duration: Duration(milliseconds: 260), value: _done ? 1.0 : 0.0);
  }

  @override
  void didUpdateWidget(covariant HabitDoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDone != widget.isDone) {
      setState(() => _done = widget.isDone);
      _done ? _anim.forward() : _anim.reverse();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    setState(() => _done = !_done);
    _done ? _anim.forward() : _anim.reverse();

    await widget.onToggled();

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_done ? 'Als erledigt markiert' : 'Als nicht erledigt markiert'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            HapticFeedback.lightImpact();
            setState(() => _done = !_done);
            _done ? _anim.forward() : _anim.reverse();
            await widget.onToggled();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final minW = compact ? 44.0 : 52.0;
    final prefW = compact ? 110.0 : 140.0;
    final height = compact ? 36.0 : 42.0;

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : prefW;
      final showText = maxW >= (compact ? 88.0 : 110.0);

      return Semantics(
        button: true,
        label: _done ? 'Habit erledigt. Tippe um rückgängig zu machen.' : 'Markieren als erledigt',
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 260),
            constraints: BoxConstraints(minWidth: minW, maxWidth: maxW),
            height: height,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _done ? Colors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: _done ? Colors.green : Colors.grey.shade400, width: 1.2),
              boxShadow: _done ? [BoxShadow(color: Colors.green.withOpacity(0.18), blurRadius: 8, offset: Offset(0, 4))] : [],
            ),
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: showText ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: _done
                      ? Icon(Icons.check, key: ValueKey('check'), color: Colors.white, size: compact ? 18 : 20)
                      : Icon(Icons.radio_button_unchecked, key: ValueKey('dot'), color: Colors.grey.shade600, size: compact ? 18 : 20),
                ),
                if (showText) ...[
                  SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Erledigt', style: TextStyle(color: _done ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}
