import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // für ThemeNotifier

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _compactMode = false;

  @override
  void initState() {
    super.initState();
    // zukünftige Persistenz möglich (noch nicht persistent)
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
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
              child: ListTile(
                title: Text('Design-Modus'),
                subtitle: Text('Kompakte Listenansicht (experimentell)'),
                trailing: Switch(
                  value: _compactMode,
                  onChanged: (v) => setState(() => _compactMode = v),
                ),
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
