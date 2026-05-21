import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class GymTrackerApp extends StatelessWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080A0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDC97),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF080A0D),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF11151C),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF2A303A)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}