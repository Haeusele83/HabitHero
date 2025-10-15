import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schöneres Onboarding: sichtbarer "Überspringen"-Button oben rechts,
/// grösseres Logo, Hintergrund-Gradient, PageIndicator und klare Buttons.
/// Wenn Onboarding abgeschlossen wird, wird 'seen_onboarding' auf true gesetzt
/// und die App poppt zur ersten Route zurück (EntryDecider in main.dart liest die Pref).
class OnboardingPage extends StatefulWidget {
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  Future<void> _completeOnboarding() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('seen_onboarding', true);
    // Pop back to the first route — EntryDecider ist die erste Route und zeigt danach das Home.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _skip() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('seen_onboarding', true);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildPage({required String title, required String subtitle, required String asset}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(tag: 'logo-hero', child: Image.asset(asset, width: 160, height: 160, fit: BoxFit.contain)),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 6),
          width: active ? 26 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Gradient background for nicer look
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [
                        _buildPage(
                          title: 'Willkommen bei HabitHero',
                          subtitle: 'Gewohnheiten einfach tracken. Kleine Schritte, grosse Wirkung.',
                          asset: 'assets/logo.png',
                        ),
                        _buildPage(
                          title: 'Täglich abhaken',
                          subtitle: 'Tippe auf das Häkchen, um einen Habit für heute zu markieren.',
                          asset: 'assets/logo.png',
                        ),
                        _buildPage(
                          title: 'Statistiken & Motivation',
                          subtitle: 'Sieh deine Fortschritte: Streaks, 7-/30-Tage-Ansicht und Heatmaps.',
                          asset: 'assets/logo.png',
                        ),
                      ],
                    ),
                  ),
                  // Dots + Buttons (kompakt & gut sichtbar)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                    child: Column(
                      children: [
                        _buildDots(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _skip,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.white70),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text('Überspringen', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_page < 2) {
                                    _controller.nextPage(duration: Duration(milliseconds: 350), curve: Curves.easeInOut);
                                  } else {
                                    _completeOnboarding();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  backgroundColor: Colors.white,
                                  foregroundColor: theme.primaryColor,
                                ),
                                child: Text(_page < 2 ? 'Weiter' : 'Los geht\'s', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Top-right "Skip" as small text (also visible) — redundant but helps visibility
              Positioned(
                top: 12,
                right: 12,
                child: TextButton(
                  onPressed: _skip,
                  child: Text('Überspringen', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
