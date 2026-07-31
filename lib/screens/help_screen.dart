import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050A0F),
        foregroundColor: const Color(0xFFEAF2F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Help',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: const [
            _IntroCard(),
            SizedBox(height: 14),
            _HelpSection(
              icon: Icons.home_rounded,
              title: 'HomeScreen',
              items: [
                'Die BodyMap zeigt, welche Muskeln heute dran sind.',
                'Blau bedeutet: Training ist geplant.',
                'Rot bedeutet: Heute bereits trainiert.',
                'Mit Skip verschiebst du den heutigen Trainingstag auf morgen.',
              ],
            ),
            SizedBox(height: 14),
            _HelpSection(
              icon: Icons.add_rounded,
              title: 'Plan erstellen',
              items: [
                'Wähle zuerst ein Template oder starte leer.',
                'In Basis legst du Name, Satzpause und Reihenfolge fest.',
                'In Woche bestimmst du Trainingstage und Restdays.',
                'In Übungen fügst du Übungen, Sätze, Rep-Range und Gewicht ein.',
              ],
            ),
            SizedBox(height: 14),
            _HelpSection(
              icon: Icons.bolt_rounded,
              title: 'Workout starten',
              items: [
                'Ein Workout startet immer mit der ersten Übung des heutigen Tages.',
                'Nach jedem Satz gibst du ein, wie viele Wiederholungen du geschafft hast.',
                'Danach startet automatisch deine Satzpause.',
                'Nach Ablauf der Pause hörst du einen Ton, falls Sound aktiviert ist.',
              ],
            ),
            SizedBox(height: 14),
            _HelpSection(
              icon: Icons.trending_up_rounded,
              title: 'Progression',
              items: [
                'Die Rep-Range zeigt dein Ziel, zum Beispiel 8-12 Wiederholungen.',
                'Wenn du alle Sätze am oberen Limit schaffst, empfiehlt RepDex mehr Gewicht.',
                'Bei Bodyweight-Übungen empfiehlt RepDex eine schwerere Variante.',
              ],
            ),
            SizedBox(height: 14),
            _HelpSection(
              icon: Icons.menu_book_rounded,
              title: 'History',
              items: [
                'In Settings > History findest du deine abgeschlossenen Workouts.',
                'Gespeichert werden Datum, Trainingstag, Übungen, Gewicht und Wiederholungen.',
                'So kannst du später sehen, wie du dich entwickelt hast.',
              ],
            ),
            SizedBox(height: 14),
            _HelpSection(
              icon: Icons.settings_rounded,
              title: 'Settings',
              items: [
                'Hier findest du History, Help und den Satzpausen-Ton.',
                'Du kannst den Ton aktivieren, deaktivieren oder eine eigene Sound-Datei verwenden.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B28), Color(0xFF071018), Color(0xFF050A0F)],
        ),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            blurRadius: 28,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RepDex kurz erklärt',
            style: TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Erstelle einen Plan, starte dein Workout, tracke deine Sätze und nutze die History für deinen Fortschritt.',
            style: TextStyle(
              color: Color(0xFF8A93A3),
              height: 1.35,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF09131B),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.13),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.09),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF7DD3FC),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFEAF2F4),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items) _HelpBullet(text: item),
        ],
      ),
    );
  }
}

class _HelpBullet extends StatelessWidget {
  const _HelpBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF8A93A3),
                height: 1.35,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
