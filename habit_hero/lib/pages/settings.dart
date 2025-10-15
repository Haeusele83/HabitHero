import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // für ThemeNotifier und AppSettingsNotifier

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _compactLocal = false;

  @override
  void initState() {
    super.initState();
    final appSettings = Provider.of<AppSettingsNotifier>(context, listen: false);
    _compactLocal = appSettings.compactMode;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final appSettings = Provider.of<AppSettingsNotifier>(context);
    final isDark = themeNotifier.mode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Einstellungen')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: SwitchListTile(
                title: Text('Dunkles Theme'),
                subtitle: Text('Aktiviere Dark Mode (wird gespeichert)'),
                value: isDark,
                onChanged: (v) async {
                  await themeNotifier.setDarkMode(v);
                },
              ),
            ),
            SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: Text('Kompakte Ansicht'),
                subtitle: Text('Weniger Abstände & kleinere UI-Elemente'),
                value: appSettings.compactMode,
                onChanged: (v) async {
                  await appSettings.setCompactMode(v);
                  setState(() {
                    _compactLocal = v;
                  });
                },
              ),
            ),
            SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text('App-Info'),
                subtitle: Text('HabitHero — Prototype\nVersion 1.0.0'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}