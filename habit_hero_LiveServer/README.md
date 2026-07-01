# HabitHero – optimierte Live-Server-Version

Diese Version ist als einfache, professionelle Web-App aufgebaut. Sie läuft direkt im Browser und benötigt keine Flutter-Konfiguration, keine Datenbank, keinen Emulator und kein Build-System.

## Start in VS Code

1. Ordner `HabitHero_LiveServer_v2` in VS Code öffnen.
2. Erweiterung **Live Server** installieren, falls noch nicht vorhanden.
3. Rechtsklick auf `index.html`.
4. **Open with Live Server** auswählen.
5. Optional: Auf **Demo** klicken, damit sofort realistische Testdaten angezeigt werden.

## Umgesetzte Funktionen

- Habit erfassen, bearbeiten und löschen
- Habit für den heutigen Tag abhaken
- Filter: alle, offen, erledigt
- Suche über Titel, Beschreibung und Kategorie
- Tagesfortschritt mit Fortschrittsring
- XP und Level-System
- Badges / Achievements
- Wochenstatistik mit fällig/erledigt-Vergleich
- 14-Tage-Heatmap
- Habit-Erfolg der letzten 30 Tage
- JSON-Export und JSON-Import
- Demo-Daten für Präsentation und Test
- Responsives Layout für Desktop, Tablet und Smartphone
- Speicherung im Browser über `localStorage`

## Dateien

```text
HabitHero_LiveServer_v2/
├── index.html
├── style.css
├── app.js
├── manifest.json
├── README.md
└── assets/
    ├── favicon.png
    ├── logo.png
    ├── logo-full.png
    └── logo-icon.png
```

## Hinweise zur Präsentation

Für die Live-Demo eignet sich folgender Ablauf:

1. App mit Live Server öffnen.
2. Demo-Daten laden.
3. Dashboard zeigen: Tagesfortschritt, offene Habits, Level-Fortschritt.
4. Einen Habit abhaken und Veränderung bei Prozent, XP und Statistik zeigen.
5. Einen neuen Habit erfassen.
6. Statistik öffnen und Wochenübersicht, Heatmap sowie Habit-Erfolg erklären.
7. Badges öffnen und Gamification zeigen.

Die App ist bewusst als MVP umgesetzt: Sie zeigt die Kernfunktionalitäten vollständig, bleibt aber technisch schlank und wartbar.
