// lib/main.dart (komplett ersetzen)
// Änderungen: kleinere linke Prozent-Anzeige, großer horizontaler Fortschrittsbalken oben,
// größere Erledigt- & Löschen-Controls, Layout-Feinabstimmungen gegen Overflow.

import 'dart:math' as math;
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
      colorScheme: base.colorScheme.copyWith(primary: Colors.teal, secondary: Colors.tealAccent),
      scaffoldBackgroundColor: Colors.grey[50],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
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
      colorScheme: base.colorScheme.copyWith(primary: Colors.teal, secondary: Colors.tealAccent),
      scaffoldBackgroundColor: Colors.grey[900],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 1,
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

/// --- HomePage ---
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

  late final AnimationController _listAnimController;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(vsync: this, duration: Duration(milliseconds: 450));
    _loadAll();
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
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

      if (_habits.isNotEmpty) _listAnimController.forward(from: 0.0);
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

  Future<void> _confirmAndDelete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Habit löschen'),
        content: Text('Wirklich "$name" löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text('Löschen')),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteHabit(id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Habit gelöscht'), duration: Duration(seconds: 2)));
    }
  }

  Future<void> _showAddDialog() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Neuer Habit'),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: 'z. B. 30 Min. Bewegung')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text('Speichern')),
        ],
      ),
    );

    if (res != null && res.trim().isNotEmpty) {
      await _addHabit(res);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Habit erstellt'), duration: Duration(milliseconds: 900)));
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

  double _overallCompletionPercent() {
    if (_chartData.isEmpty) return 0.0;
    double sum = 0.0;
    int count = 0;
    _chartData.forEach((_, list) {
      if (list.isNotEmpty) {
        sum += list.reduce((a, b) => a + b) / list.length;
        count++;
      }
    });
    if (count == 0) return 0.0;
    return (sum / count) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appSettings = Provider.of<AppSettingsNotifier>(context);
    final compact = appSettings.compactMode;

    final cardPadding = compact ? 10.0 : 16.0;
    final tileFontSize = compact ? 14.0 : 16.0;
    final double cardMinHeight = compact ? 100.0 : 126.0; // etwas höher wegen top-bar
    final overallPercent = _overallCompletionPercent().round();

    // available width clamps
    final screenW = MediaQuery.of(context).size.width;
    final headerRightWidth = (screenW * 0.28).clamp(70.0, 120.0);

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        leadingWidth: 160,
        leading: Padding(
          padding: EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Hero(
                tag: 'logo-hero',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/logo.png', width: compact ? 40 : 48, height: compact ? 40 : 48, fit: BoxFit.contain),
                ),
              ),
              SizedBox(width: 8),
              Flexible(child: Text('HabitHero', style: TextStyle(fontWeight: FontWeight.w700))),
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
            icon: Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage())).then((_) => _loadAll()),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Column(
          children: [
            // Header card (gleich wie vorher)
            AnimatedContainer(
              duration: Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
              ),
              padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: compact ? 12 : 16),
              child: Row(
                children: [
                  // left: flexible text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deine Gewohnheiten', style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text('${_habits.length} Habits • Letzte Aktualisierung: ${_formatToday()}', style: TextStyle(fontSize: compact ? 12 : 13, color: Colors.grey[600])),
                        SizedBox(height: compact ? 8 : 12),
                        Row(
                          children: [
                            _smallInfoChip(Icons.local_fire_department, 'Streaks', '0', compact),
                            SizedBox(width: 8),
                            _smallInfoChip(Icons.check_circle_outline, 'Erledigt heute', '0', compact),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // right: percent (clamped width to avoid overflow)
                  SizedBox(
                    width: headerRightWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: overallPercent / 100.0),
                          duration: Duration(milliseconds: 800),
                          builder: (context, val, _) {
                            final p = (val * 100).round();
                            return Column(
                              children: [
                                SizedBox(
                                  width: compact ? 56 : 72,
                                  height: compact ? 56 : 72,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: val,
                                        strokeWidth: compact ? 6 : 8,
                                        backgroundColor: theme.colorScheme.onSurface.withOpacity(0.06),
                                        valueColor: AlwaysStoppedAnimation(p >= 70 ? Colors.green : (p >= 40 ? Colors.orange : Colors.red)),
                                      ),
                                      Text('$p%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 12 : 14)),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text('Ø-Erf.', style: TextStyle(fontSize: compact ? 12 : 13, color: Colors.grey[600])),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: compact ? 10 : 14),

            // Action row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add, size: compact ? 18 : 20),
                    label: Text('Neuen Habit'),
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12)),
                    onPressed: _showAddDialog,
                  ),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.info_outline, size: 18),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Tipps')),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingPage())),
                  ),
                ),
              ],
            ),

            SizedBox(height: compact ? 10 : 12),

            // Content
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _habits.isEmpty
                      ? _buildEmptyState(context)
                      : FadeTransition(
                          opacity: CurvedAnimation(parent: _listAnimController, curve: Curves.easeIn),
                          child: ListView.separated(
                            itemCount: _habits.length,
                            separatorBuilder: (_, __) => SizedBox(height: compact ? 10 : 12),
                            itemBuilder: (ctx, i) {
                              final h = _habits[i];
                              final isOn = h.id != null && _checked.contains(h.id);
                              final last7 = (h.id != null && _chartData.containsKey(h.id)) ? _chartData[h.id!]! : List.filled(7, 0);

                              final int percent30 = _calcPercentFromList(last7);
                              final int streak = _calcStreakFor7(last7);

                              return _buildHabitCard(h, percent30, streak, last7, tileFontSize, cardMinHeight, compact, ctx, i);
                            },
                          ),
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

  Widget _smallInfoChip(IconData icon, String label, String value, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 6),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: Theme.of(context).primaryColor),
          SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: compact ? 11 : 12, color: Colors.grey[700])),
            Text(value, style: TextStyle(fontSize: compact ? 12 : 13, fontWeight: FontWeight.w700)),
          ])
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final compact = Provider.of<AppSettingsNotifier>(context).compactMode;
    final maxWidth = math.min(MediaQuery.of(context).size.width * 0.95, 460.0);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: maxWidth,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 6))],
              ),
              child: Column(
                children: [
                  Icon(Icons.emoji_objects_outlined, size: 64, color: Colors.teal),
                  SizedBox(height: 12),
                  Text('Fange klein an', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('Erstelle deinen ersten Habit und verfolge ihn täglich. Ich helfe dir dabei, dran zu bleiben.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                  SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(onPressed: _showAddDialog, icon: Icon(Icons.add), label: Text('Erstellen')),
                      SizedBox(width: 12),
                      OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingPage())), icon: Icon(Icons.play_circle_outline), label: Text('Kurze Einführung')),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            Text('Tipp: Beginne mit einer kleinen, konkreten Gewohnheit — z. B. 10 Minuten Bewegung.', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(Habit h, int percent30, int streak, List<int> last7, double tileFontSize, double cardMinHeight, bool compact, BuildContext ctx, int index) {
    final theme = Theme.of(context);
    final screenW = MediaQuery.of(context).size.width;
    final availableCardWidth = screenW - (compact ? 32 : 48);
    final rightMax = (availableCardWidth * (compact ? 0.26 : 0.28)).clamp(84.0, 160.0);

    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onLongPress: () {
          if (h.id != null) _confirmAndDelete(h.id!, h.name);
        },
        child: Slidable(
          key: ValueKey(h.id ?? '${h.name}-$index'),
          endActionPane: ActionPane(
            motion: DrawerMotion(),
            extentRatio: 0.34,
            children: [
              SlidableAction(
                onPressed: (ctx) {
                  if (h.id != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailPage(habit: h))).then((_) => _loadAll());
                },
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: 'Details',
              ),
              SlidableAction(
                onPressed: (ctx) async {
                  if (h.id != null) {
                    await _confirmAndDelete(h.id!, h.name);
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
            duration: Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(minHeight: cardMinHeight),
            margin: EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top progress bar (neu): zeigt Prozent als horizontalen Balken
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 10 : 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: compact ? 8 : 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (percent30.clamp(0, 100)) / 100.0,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(percent30 >= 70 ? Colors.green : (percent30 >= 40 ? Colors.orange : Colors.red)),
                              minHeight: compact ? 8 : 10,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      // smaller circular percent to the right of the bar
                      SizedBox(
                        width: compact ? 44 : 52,
                        child: Column(
                          children: [
                            CircularProgressPercent(percent: percent30, size: compact ? 36 : 44),
                            SizedBox(height: 4),
                            Text('${percent30}%', style: TextStyle(fontSize: compact ? 10 : 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // main content row
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 6 : 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // left: minimal small circle (we keep small visual - optional)
                      SizedBox(width: compact ? 6 : 8),

                      // middle: expandable column with title, streak, timeline
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  h.name,
                                  style: TextStyle(fontSize: tileFontSize, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                            SizedBox(height: compact ? 6 : 8),
                            Row(
                              children: [
                                Icon(Icons.local_fire_department, size: compact ? 14 : 16, color: streak > 0 ? Colors.orange : Colors.grey),
                                SizedBox(width: 6),
                                Text('Streak: $streak', style: TextStyle(fontSize: compact ? 12 : 13, color: Colors.grey[600])),
                              ],
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: math.max(140, MediaQuery.of(context).size.width * 0.5)),
                              child: HabitDotTimeline(data: last7, compact: compact),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 12),

                      // right controls: Erledigt (grösser) + Löschen (grösser)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: rightMax),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // bigger Erledigt button: we increase pref width and height
                            HabitDoneButton(
                              habitId: h.id,
                              isDone: h.id != null && _checked.contains(h.id),
                              compact: compact,
                              bigger: true, // new parameter handled below
                              onToggled: () async {
                                if (h.id == null) return;
                                await _toggleCheck(h.id!);
                              },
                            ),
                            SizedBox(height: 8),
                            // larger delete icon, with more spacing to avoid overlaps
                            SizedBox(
                              height: compact ? 40 : 44,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(minWidth: compact ? 40 : 44, minHeight: compact ? 40 : 44),
                                icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: compact ? 22 : 26),
                                tooltip: 'Löschen',
                                onPressed: () {
                                  if (h.id != null) _confirmAndDelete(h.id!, h.name);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Circular percent widget (kleiner)
class CircularProgressPercent extends StatelessWidget {
  final int percent;
  final double size;
  const CircularProgressPercent({Key? key, required this.percent, this.size = 44}) : super(key: key);

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

/// HabitDotTimeline (wie zuvor)
class HabitDotTimeline extends StatelessWidget {
  final List<int> data; // oldest -> newest
  final bool compact;

  const HabitDotTimeline({Key? key, required this.data, this.compact = false}) : super(key: key);

  String _weekdayShortForDate(DateTime day) {
    const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return names[(day.weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    final d = List<int>.from(data);
    if (d.length < 7) d.insertAll(0, List<int>.filled(7 - d.length, 0));

    final dotSize = compact ? 14.0 : 18.0;
    final weekdaySize = compact ? 10.0 : 12.0;
    final dateSize = compact ? 11.0 : 12.0;
    final gap = compact ? 8.0 : 10.0;

    final start = DateTime.now().subtract(Duration(days: 6));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return LayoutBuilder(builder: (context, constraints) {
      final avail = constraints.maxWidth;
      final minTotalDotsWidth = 7 * dotSize + 6 * gap;
      double computedGap = gap;
      if (avail > minTotalDotsWidth) {
        computedGap = ((avail - 7 * dotSize) / 6).clamp(gap, gap * 2.5);
      } else {
        computedGap = ((avail - 7 * dotSize) / 6).clamp(4.0, gap);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: weekdaySize + 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (i) {
                final day = days[i];
                final label = _weekdayShortForDate(day);
                final isToday = _isSameDate(day, DateTime.now());
                return Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : computedGap),
                  child: SizedBox(
                    width: dotSize + 6,
                    child: Center(
                      child: Text(label,
                          style: TextStyle(
                            fontSize: weekdaySize,
                            color: isToday ? Theme.of(context).primaryColor : Colors.grey[700],
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          )),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            height: dotSize + 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (i) {
                final done = d[i] == 1;
                final day = days[i];
                final isToday = _isSameDate(day, DateTime.now());
                final color = done ? Theme.of(context).primaryColor : Colors.grey.shade300;
                return Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : computedGap),
                  child: GestureDetector(
                    onTap: () {
                      final dateStr = '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
                      final status = done ? 'Erledigt' : 'Nicht erledigt';
                      final snack = SnackBar(content: Text('$dateStr — $status'), duration: Duration(milliseconds: 900));
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(snack);
                    },
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isToday ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.9), width: 2.0) : null,
                        boxShadow: done ? [BoxShadow(color: color.withOpacity(0.22), blurRadius: 6, offset: Offset(0, 2))] : [],
                      ),
                      child: Center(child: done ? Icon(Icons.check, size: dotSize * 0.6, color: Colors.white) : SizedBox.shrink()),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            height: dateSize + 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (i) {
                final day = days[i];
                final isToday = _isSameDate(day, DateTime.now());
                return Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : computedGap),
                  child: SizedBox(
                    width: dotSize + 6,
                    child: Center(
                      child: Text('${day.day}',
                          style: TextStyle(fontSize: dateSize, color: isToday ? Theme.of(context).primaryColor : Colors.grey[700], fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    });
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Done button (mit optional größerem Layout)
class HabitDoneButton extends StatefulWidget {
  final int? habitId;
  final bool isDone;
  final bool compact;
  final bool bigger;
  final Future<void> Function() onToggled;

  const HabitDoneButton({Key? key, required this.habitId, required this.isDone, required this.onToggled, this.compact = false, this.bigger = false}) : super(key: key);

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
    final bigger = widget.bigger;
    final minW = compact ? (bigger ? 64.0 : 44.0) : (bigger ? 84.0 : 52.0);
    final prefW = compact ? (bigger ? 140.0 : 110.0) : (bigger ? 160.0 : 140.0);
    final height = compact ? (bigger ? 44.0 : 36.0) : (bigger ? 48.0 : 42.0);

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
              border: Border.all(color: _done ? Colors.green : Colors.grey.shade400, width: 1.4),
              boxShadow: _done ? [BoxShadow(color: Colors.green.withOpacity(0.18), blurRadius: 8, offset: Offset(0, 4))] : [],
            ),
            padding: EdgeInsets.symmetric(horizontal: 12),
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
