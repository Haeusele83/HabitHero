import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/db_helper.dart';
import 'models/habit.dart';
import 'pages/stats_overview.dart';
import 'pages/habit_detail.dart';
import 'pages/onboarding.dart';
import 'pages/settings.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier()..loadFromPrefs(),
      child: HabitHeroApp(),
    ),
  );
}

/// ThemeNotifier verwaltet ThemeMode und persistiert die Auswahl.
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

/// entscheidet, ob Onboarding oder Home gezeigt wird
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

/// Hauptseite — verbessert: Logo, Slidable swipe actions, nicer animations
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 140,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Row(
            children: [
              Hero(
                tag: 'logo-hero',
                child: Image.asset('assets/logo.png', width: 48, height: 48, fit: BoxFit.contain),
              ),
              SizedBox(width: 8),
              Flexible(child: Text('HabitHero', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        actions: [
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
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            // Card mit Today + Add
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text('Meine Habits – ${_formatToday()}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: _showAddDialog, icon: Icon(Icons.add)),
                  ],
                ),
              ),
            ),

            SizedBox(height: 10),

            // Habit-Liste
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : (_habits.isEmpty
                      ? Center(child: Text('Noch keine Habits. Tippe + um einen zu erstellen.'))
                      : ListView.separated(
                          itemCount: _habits.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final h = _habits[i];
                            final isOn = h.id != null && _checked.contains(h.id);
                            final chart = (h.id != null && _chartData.containsKey(h.id)) ? _chartData[h.id!]! : List.filled(7, 0);

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
                                    },
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Löschen',
                                  ),
                                ],
                              ),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                                ),
                                child: ListTile(
                                  onTap: () {
                                    if (h.id != null) {
                                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailPage(habit: h))).then((_) => _loadAll());
                                    }
                                  },
                                  leading: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: Duration(milliseconds: 300),
                                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                      child: Icon(
                                        isOn ? Icons.check_circle : Icons.radio_button_unchecked,
                                        key: ValueKey(isOn),
                                        color: isOn ? Colors.green : Colors.grey,
                                        size: 28,
                                      ),
                                    ),
                                    onPressed: h.id != null ? () => _toggleCheck(h.id!) : null,
                                  ),
                                  title: Text(h.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('Letzte 7 Tage', style: TextStyle(color: Colors.grey[700]))),
                                        SizedBox(width: 8),
                                        SizedBox(width: 140, height: 36, child: HabitMiniChart(data: chart)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
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

/// Very small, polished mini-chart used in the list (keeps previous simple implementation)
class HabitMiniChart extends StatelessWidget {
  final List<int> data;
  final double width;
  final double height;

  HabitMiniChart({required this.data, this.width = 140, this.height = 36});

  @override
  Widget build(BuildContext context) {
    final filled = Theme.of(context).primaryColor;
    final empty = Colors.grey.shade300;

    final d = List<int>.from(data);
    if (d.length < 7) {
      d.insertAll(0, List<int>.filled(7 - d.length, 0));
    } else if (d.length > 7) {
      final last7 = d.sublist(d.length - 7);
      d.clear();
      d.addAll(last7);
    }

    final gap = 6.0;
    final barW = (width - gap * 6) / 7;

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final v = d[i];
          final barH = v == 1 ? height * 0.88 : height * 0.28;
          return AnimatedContainer(
            duration: Duration(milliseconds: 400 + i * 20),
            width: barW,
            height: barH,
            decoration: BoxDecoration(color: v == 1 ? filled : empty, borderRadius: BorderRadius.circular(4)),
          );
        }),
      ),
    );
  }
}