// lib/pages/onboarding.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_hero/main.dart'; // HomePage wird in main.dart definiert

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _loading = false;

  Future<void> _setSeenAndOpenHome() async {
    setState(() => _loading = true);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage()));
  }

  void _next() {
    if (_page < 2) {
      _pageController.animateToPage(_page + 1, duration: Duration(milliseconds: 360), curve: Curves.easeInOut);
    } else {
      _setSeenAndOpenHome();
    }
  }

  void _skip() {
    _setSeenAndOpenHome();
  }

  Widget _buildPage({
    required String title,
    required String subtitle,
    required IconData icon,
    required String imageAsset,
    required Color accent,
  }) {
    // Grösseres, fokussiertes Layout: Logo prominent, Text darunter
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // sehr grosses Logo vorne
          Hero(
            tag: 'logo-hero',
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: Center(
                child: Image.asset(
                  imageAsset,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black87.withOpacity(0.76)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // heller, dezenter Hintergrund — kein kräftiges Grün
  BoxDecoration _backgroundDecoration(BuildContext context) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF5F8FF), // sehr helles Blau
          Color(0xFFF7F4FC), // leichter Lavendel-Ton
        ],
        stops: [0.0, 1.0],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;
    return Scaffold(
      body: Container(
        decoration: _backgroundDecoration(context),
        child: SafeArea(
          child: Stack(
            children: [
              // Haupt-Inhalt (PageView + Controls)
              Column(
                children: [
                  // Top Row: Skip (sichtbar, dezent)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Row(
                      children: [
                        Spacer(),
                        GestureDetector(
                          onTap: _skip,
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Text('Überspringen', style: TextStyle(color: Colors.black54, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (p) => setState(() => _page = p),
                      children: [
                        _buildPage(
                          title: 'Willkommen bei HabitHero',
                          subtitle: 'Gewohnheiten einfach tracken. Kleine Schritte, grosse Wirkung.',
                          icon: Icons.emoji_events_outlined,
                          imageAsset: 'assets/logo.png',
                          accent: Colors.teal.shade700,
                        ),
                        _buildPage(
                          title: 'Kleine Gewohnheiten, grosse Wirkung',
                          subtitle: 'Täglich ein bisschen – und schon verändern sich Routinen nachhaltig.',
                          icon: Icons.timeline,
                          imageAsset: 'assets/logo.png',
                          accent: Colors.indigo.shade700,
                        ),
                        _buildPage(
                          title: 'Los geht’s!',
                          subtitle: 'Lege deinen ersten Habit an und bleibe dran. Ich helfe dir dabei.',
                          icon: Icons.thumb_up_alt_outlined,
                          imageAsset: 'assets/logo.png',
                          accent: Colors.deepPurple.shade700,
                        ),
                      ],
                    ),
                  ),

                  // Paginierung + Buttons
                  Padding(
                    padding: EdgeInsets.only(left: 20, right: 20, bottom: math.max(10, safe.bottom + 8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final active = i == _page;
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 260),
                              margin: EdgeInsets.symmetric(horizontal: 6),
                              width: active ? 30 : 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: active ? Colors.black87 : Colors.black26,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _skip,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  side: BorderSide(color: Colors.black26),
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Überspringen', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _next,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _loading
                                    ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(_page == 2 ? 'Starten' : 'Weiter', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Optional: leichtes, grosses Logo im Hintergrund (sehr dezent)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 0.03,
                      child: Image.asset('assets/logo.png', width: 380, height: 380, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
