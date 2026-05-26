import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../widgets/body_strength_map.dart';
import 'plan_builder_screen.dart';
import 'settings_screen.dart';
import 'workout_start_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String _selectedWorkoutPlanKey = 'selected_workout_plan_id';
  static const String _skippedWorkoutDateKey = 'skipped_workout_date';
  static const String _skippedWorkoutPlanIdKey = 'skipped_workout_plan_id';

  static const Color _cyanAccent = Color(0xFF00E5FF);
  static const Color _redAccent = Color(0xFFFF3B3B);
  static const Color _redAccentDark = Color(0xFF7F1D1D);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, settingsBox, _) {
        return ValueListenableBuilder<Box<WorkoutPlan>>(
          valueListenable: Hive.box<WorkoutPlan>('workout_plans').listenable(),
          builder: (context, workoutPlanBox, _) {
            return ValueListenableBuilder<Box<Exercise>>(
              valueListenable: Hive.box<Exercise>('exercises').listenable(),
              builder: (context, exerciseBox, _) {
                final todayWorkout = _buildTodayWorkoutData(
                  settingsBox: settingsBox,
                  workoutPlanBox: workoutPlanBox,
                  exerciseBox: exerciseBox,
                );

                return _buildScaffold(
                  context: context,
                  todayWorkout: todayWorkout,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold({
    required BuildContext context,
    required _TodayWorkoutData todayWorkout,
  }) {
    return Scaffold(
      backgroundColor: todayWorkout.isDepleted
          ? const Color(0xFF120506)
          : const Color(0xFF050A0F),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _buildHeader(
                  context: context,
                  isDepleted: todayWorkout.isDepleted,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(child: _buildBodyCard(todayWorkout)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              sliver: SliverToBoxAdapter(
                child: _buildActions(
                  context: context,
                  todayWorkout: todayWorkout,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _TodayWorkoutData _buildTodayWorkoutData({
    required Box<dynamic> settingsBox,
    required Box<WorkoutPlan> workoutPlanBox,
    required Box<Exercise> exerciseBox,
  }) {
    final now = DateTime.now();
    final todayKey = WorkoutStartScreen.dateKey(now);
    final completedWorkoutToday = WorkoutStartScreen.hasCompletedWorkoutToday(
      settingsBox,
    );
    final completedMuscleGroups = _completedMuscleGroupsFromSettings(settingsBox);
    final selectedPlanId = settingsBox.get(_selectedWorkoutPlanKey);
    final selectedPlan = selectedPlanId is String ? workoutPlanBox.get(selectedPlanId) : null;

    if (completedWorkoutToday) {
      final completedDayName = _completedDayNameFromSettings(settingsBox);
      final tomorrow = selectedPlan == null ? null : _tomorrowDay(selectedPlan, now.weekday);

      return _TodayWorkoutData(
        planName: 'Workout abgeschlossen',
        dayName: 'Heute trainiert',
        scheduleSummary: _completedScheduleSummary(completedDayName, tomorrow),
        muscleGroups: completedMuscleGroups,
        exerciseCount: 0,
        isRestDay: false,
        highlightFullBody: completedMuscleGroups.isEmpty,
        isDepleted: true,
        isSkipped: false,
      );
    }

    final skippedToday = settingsBox.get(_skippedWorkoutDateKey) == todayKey;

    if (skippedToday) {
      final tomorrow = selectedPlan == null ? null : _tomorrowDay(selectedPlan, now.weekday);

      return _TodayWorkoutData(
        planName: 'Training verschoben',
        dayName: 'Heute übersprungen',
        scheduleSummary: tomorrow == null
            ? 'Heute übersprungen · Morgen geht es weiter.'
            : 'Heute übersprungen · Morgen: ${_dayDisplayName(tomorrow)}',
        muscleGroups: const {},
        exerciseCount: 0,
        isRestDay: true,
        highlightFullBody: false,
        isDepleted: false,
        isSkipped: true,
      );
    }

    if (selectedPlanId == null || selectedPlanId is! String) {
      return const _TodayWorkoutData(
        planName: 'Kein Plan ausgewählt',
        dayName: 'Kein aktiver Wochenplan',
        scheduleSummary: null,
        muscleGroups: {},
        exerciseCount: 0,
        isRestDay: false,
        highlightFullBody: true,
        isDepleted: false,
        isSkipped: false,
      );
    }

    if (selectedPlan == null) {
      return const _TodayWorkoutData(
        planName: 'Ausgewählter Plan nicht gefunden',
        dayName: 'Plan fehlt',
        scheduleSummary: null,
        muscleGroups: {},
        exerciseCount: 0,
        isRestDay: false,
        highlightFullBody: true,
        isDepleted: false,
        isSkipped: false,
      );
    }

    final today = selectedPlan.dayForWeekday(now.weekday);
    final tomorrow = _tomorrowDay(selectedPlan, now.weekday);

    if (today.isRestDay || today.exerciseIds.isEmpty) {
      return _TodayWorkoutData(
        planName: selectedPlan.name,
        dayName: 'Heute: Restday',
        scheduleSummary: 'Heute: Restday · Morgen: ${_dayDisplayName(tomorrow)}',
        muscleGroups: const {},
        exerciseCount: 0,
        isRestDay: true,
        highlightFullBody: false,
        isDepleted: false,
        isSkipped: false,
      );
    }

    final exercisesById = {
      for (final exercise in exerciseBox.values) exercise.id: exercise,
    };

    final muscleGroups = <String>{};
    var exerciseCount = 0;

    for (final exerciseId in today.exerciseIds) {
      final exercise = exercisesById[exerciseId];

      if (exercise == null) {
        continue;
      }

      exerciseCount++;

      for (final muscleGroup in exercise.muscleGroups) {
        final cleanedMuscleGroup = muscleGroup.trim();

        if (cleanedMuscleGroup.isNotEmpty) {
          muscleGroups.add(cleanedMuscleGroup);
        }
      }
    }

    return _TodayWorkoutData(
      planName: selectedPlan.name,
      dayName: 'Heute: ${today.name}',
      scheduleSummary: 'Heute: ${_dayDisplayName(today)} · Morgen: ${_dayDisplayName(tomorrow)}',
      muscleGroups: muscleGroups,
      exerciseCount: exerciseCount,
      isRestDay: false,
      highlightFullBody: false,
      isDepleted: false,
      isSkipped: false,
    );
  }

  WorkoutPlanDay _tomorrowDay(WorkoutPlan plan, int todayWeekday) {
    final tomorrowWeekday = todayWeekday == DateTime.sunday
        ? DateTime.monday
        : todayWeekday + 1;
    return plan.dayForWeekday(tomorrowWeekday);
  }

  String _dayDisplayName(WorkoutPlanDay day) {
    if (day.isRestDay || day.exerciseIds.isEmpty) {
      return 'Restday';
    }

    final cleanName = day.name.trim();
    return cleanName.isEmpty ? WorkoutPlanDay.weekdayName(day.weekday) : cleanName;
  }

  String _completedScheduleSummary(String todayName, WorkoutPlanDay? tomorrow) {
    final cleanTodayName = todayName.trim().isEmpty ? 'Training' : todayName.trim();

    if (tomorrow == null) {
      return 'Heute trainiert: $cleanTodayName · Bis morgen';
    }

    return 'Heute trainiert: $cleanTodayName · Morgen: ${_dayDisplayName(tomorrow)}';
  }

  String _completedDayNameFromSettings(Box<dynamic> settingsBox) {
    final value = settingsBox.get(WorkoutStartScreen.completedWorkoutDayNameKey);

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return 'Training';
  }

  Set<String> _completedMuscleGroupsFromSettings(Box<dynamic> settingsBox) {
    final value = settingsBox.get(
      WorkoutStartScreen.completedWorkoutMuscleGroupsKey,
    );

    if (value is! Iterable) {
      return const {};
    }

    return value
        .whereType<String>()
        .map((muscleGroup) => muscleGroup.trim())
        .where((muscleGroup) => muscleGroup.isNotEmpty)
        .toSet();
  }

  Widget _buildHeader({
    required BuildContext context,
    required bool isDepleted,
  }) {
    final accentColor = isDepleted ? _redAccent : _cyanAccent;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gym Tracker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                  color: isDepleted ? const Color(0xFFFFE4E6) : const Color(0xFFEAF2F4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isDepleted ? 'Recovery mode. Bis morgen.' : 'Track performance. Build strength.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDepleted ? const Color(0xFFFCA5A5) : const Color(0xFF8A93A3),
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _HeaderIconButton(
              icon: Icons.tune_rounded,
              accentColor: accentColor,
              isDepleted: isDepleted,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _AchievementsButton(
              accentColor: accentColor,
              isDepleted: isDepleted,
              onTap: () {
                _openPlaceholder(context, 'Achievements');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyCard(_TodayWorkoutData todayWorkout) {
    final accentColor = todayWorkout.isDepleted ? _redAccent : _cyanAccent;
    final cardColor = todayWorkout.isDepleted
        ? const Color(0xFF1A0708)
        : const Color(0xFF09131B);
    final subtitle = todayWorkout.highlightFullBody
        ? 'Erstelle oder aktiviere einen Plan, um nur die heutigen Muskeln zu markieren.'
        : todayWorkout.scheduleSummary ??
            (todayWorkout.isSkipped
                ? 'Der heutige Trainingstag wurde auf morgen verschoben.'
                : todayWorkout.isDepleted
                    ? 'Deine trainierten Muskelgruppen sind heute erschöpft.'
                    : todayWorkout.isRestDay
                        ? 'Heute ist kein Training geplant.'
                        : '${todayWorkout.exerciseCount} Übungen · ${todayWorkout.muscleGroups.length} Muskelgruppen');

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: todayWorkout.isDepleted ? 0.18 : 0.08),
            blurRadius: 42,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TodayWorkoutHeader(
              title: todayWorkout.dayName,
              subtitle: subtitle,
              accentColor: accentColor,
              isDepleted: todayWorkout.isDepleted,
            ),
            const SizedBox(height: 14),
            BodyStrengthMap(
              trainedMuscleGroups: todayWorkout.muscleGroups,
              highlightFullBody: todayWorkout.highlightFullBody,
              isDepleted: todayWorkout.isDepleted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions({
    required BuildContext context,
    required _TodayWorkoutData todayWorkout,
  }) {
    final startUnavailable = todayWorkout.isDepleted || todayWorkout.isSkipped;
    final startLabel = todayWorkout.isDepleted
        ? 'Bis morgen'
        : todayWorkout.isSkipped
            ? 'Verschoben'
            : 'Start';
    final startSubtitle = todayWorkout.isDepleted
        ? 'Heute erledigt'
        : todayWorkout.isSkipped
            ? 'Training pausiert'
            : null;

    return Column(
      children: [
        _StartWorkoutButton(
          label: startLabel,
          subtitle: startSubtitle,
          icon: todayWorkout.isDepleted
              ? Icons.nightlight_round_rounded
              : todayWorkout.isSkipped
                  ? Icons.skip_next_rounded
                  : Icons.bolt_rounded,
          isUnavailable: startUnavailable,
          isDepleted: todayWorkout.isDepleted,
          onTap: startUnavailable
              ? null
              : () {
                  _startWorkout(context);
                },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NeonActionButton(
                label: 'Plan',
                subtitle: 'Bearbeiten',
                icon: Icons.add_rounded,
                compact: true,
                isDepleted: todayWorkout.isDepleted,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanBuilderScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NeonActionButton(
                label: 'Skip',
                subtitle: 'Heute',
                icon: Icons.skip_next_rounded,
                compact: true,
                isDepleted: todayWorkout.isDepleted,
                enabled: !todayWorkout.isDepleted && !todayWorkout.isSkipped,
                onTap: () {
                  _skipTodayWorkout(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final settingsBox = Hive.box('settings');
    final workoutPlanBox = Hive.box<WorkoutPlan>('workout_plans');
    final exerciseBox = Hive.box<Exercise>('exercises');
    final todayKey = WorkoutStartScreen.dateKey(DateTime.now());

    if (WorkoutStartScreen.hasCompletedWorkoutToday(settingsBox)) {
      _showStartError(
        context,
        'Du hast heute bereits ein Workout absolviert.',
      );
      return;
    }

    if (settingsBox.get(_skippedWorkoutDateKey) == todayKey) {
      _showStartError(
        context,
        'Du hast das heutige Workout bereits auf morgen verschoben.',
      );
      return;
    }

    final activeWorkoutDate = settingsBox.get(
      WorkoutStartScreen.activeWorkoutDateKey,
    );

    if (activeWorkoutDate == todayKey) {
      final activePlanId = settingsBox.get(
        WorkoutStartScreen.activeWorkoutPlanIdKey,
      );

      if (activePlanId is String) {
        final activePlan = workoutPlanBox.get(activePlanId);

        if (activePlan != null) {
          final activeDay = activePlan.dayForWeekday(DateTime.now().weekday);
          final activeExercises = activeDay.exerciseIds
              .map(exerciseBox.get)
              .whereType<Exercise>()
              .toList(growable: false);

          if (activeExercises.isNotEmpty) {
            _openWorkoutScreen(
              context: context,
              plan: activePlan,
              day: activeDay,
              exercises: activeExercises,
            );
            return;
          }
        }
      }

      await WorkoutStartScreen.clearActiveWorkout(settingsBox);

      if (!context.mounted) {
        return;
      }
    } else if (activeWorkoutDate is String && activeWorkoutDate.isNotEmpty) {
      await WorkoutStartScreen.clearActiveWorkout(settingsBox);

      if (!context.mounted) {
        return;
      }
    }

    final selectedPlanId = settingsBox.get(_selectedWorkoutPlanKey);

    if (selectedPlanId == null || selectedPlanId is! String) {
      _showStartError(
        context,
        'Bitte wähle zuerst einen aktiven Workout-Plan aus.',
      );
      return;
    }

    final selectedPlan = workoutPlanBox.get(selectedPlanId);

    if (selectedPlan == null) {
      _showStartError(
        context,
        'Der aktive Plan wurde nicht gefunden. Bitte wähle einen anderen Plan aus.',
      );
      return;
    }

    final today = selectedPlan.dayForWeekday(DateTime.now().weekday);

    if (today.isRestDay || today.exerciseIds.isEmpty) {
      _showStartError(
        context,
        'Heute ist in deinem aktiven Plan kein Training eingetragen.',
      );
      return;
    }

    final exercises = today.exerciseIds
        .map(exerciseBox.get)
        .whereType<Exercise>()
        .toList(growable: false);

    if (exercises.isEmpty) {
      _showStartError(
        context,
        'Für den heutigen Trainingstag wurden keine Übungen gefunden.',
      );
      return;
    }

    _openWorkoutScreen(
      context: context,
      plan: selectedPlan,
      day: today,
      exercises: exercises,
    );
  }

  Future<void> _skipTodayWorkout(BuildContext context) async {
    final settingsBox = Hive.box('settings');
    final workoutPlanBox = Hive.box<WorkoutPlan>('workout_plans');
    final todayKey = WorkoutStartScreen.dateKey(DateTime.now());

    if (WorkoutStartScreen.hasCompletedWorkoutToday(settingsBox)) {
      _showStartError(
        context,
        'Du hast heute bereits ein Workout absolviert.',
      );
      return;
    }

    if (WorkoutStartScreen.hasActiveWorkoutToday(settingsBox)) {
      _showStartError(
        context,
        'Du hast heute bereits ein Workout gestartet. Beende zuerst das laufende Workout.',
      );
      return;
    }

    if (settingsBox.get(_skippedWorkoutDateKey) == todayKey) {
      _showStartError(
        context,
        'Du hast das heutige Workout bereits verschoben.',
      );
      return;
    }

    final selectedPlanId = settingsBox.get(_selectedWorkoutPlanKey);

    if (selectedPlanId == null || selectedPlanId is! String) {
      _showStartError(
        context,
        'Bitte wähle zuerst einen aktiven Workout-Plan aus.',
      );
      return;
    }

    final selectedPlan = workoutPlanBox.get(selectedPlanId);

    if (selectedPlan == null) {
      _showStartError(
        context,
        'Der aktive Plan wurde nicht gefunden.',
      );
      return;
    }

    final today = selectedPlan.dayForWeekday(DateTime.now().weekday);

    if (today.isRestDay || today.exerciseIds.isEmpty) {
      _showStartError(
        context,
        'Heute ist Restday. Es gibt kein Training zum Verschieben.',
      );
      return;
    }

    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF09131B),
          title: const Text('Workout verschieben?'),
          content: Text(
            '"${today.name}" wird auf morgen verschoben. Alle anderen Trainingstage rutschen ebenfalls um einen Tag weiter.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Verschieben'),
            ),
          ],
        );
      },
    );

    if (shouldSkip != true) {
      return;
    }

    final shiftedPlan = _shiftPlanForwardOneDay(selectedPlan);
    await workoutPlanBox.put(shiftedPlan.id, shiftedPlan);
    await settingsBox.put(_skippedWorkoutDateKey, todayKey);
    await settingsBox.put(_skippedWorkoutPlanIdKey, shiftedPlan.id);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout wurde auf morgen verschoben.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  WorkoutPlan _shiftPlanForwardOneDay(WorkoutPlan plan) {
    final shiftedDays = plan.days.map((day) {
      final newWeekday = day.weekday == DateTime.sunday
          ? DateTime.monday
          : day.weekday + 1;

      if (day.isRestDay) {
        return WorkoutPlanDay.restDay(weekday: newWeekday);
      }

      return WorkoutPlanDay.trainingDay(
        weekday: newWeekday,
        name: day.name,
        exerciseIds: day.exerciseIds,
      );
    }).toList();

    return WorkoutPlan(
      id: plan.id,
      name: plan.name,
      exerciseIds: plan.exerciseIds,
      restSeconds: plan.restSeconds,
      days: shiftedDays,
    );
  }

  void _openWorkoutScreen({
    required BuildContext context,
    required WorkoutPlan plan,
    required WorkoutPlanDay day,
    required List<Exercise> exercises,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutStartScreen(
          plan: plan,
          day: day,
          exercises: exercises,
        ),
      ),
    );
  }

  void _showStartError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _redAccentDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _PlaceholderScreen(title: title)));
  }
}

class _TodayWorkoutData {
  const _TodayWorkoutData({
    required this.planName,
    required this.dayName,
    required this.scheduleSummary,
    required this.muscleGroups,
    required this.exerciseCount,
    required this.isRestDay,
    required this.highlightFullBody,
    required this.isDepleted,
    required this.isSkipped,
  });

  final String planName;
  final String dayName;
  final String? scheduleSummary;
  final Set<String> muscleGroups;
  final int exerciseCount;
  final bool isRestDay;
  final bool highlightFullBody;
  final bool isDepleted;
  final bool isSkipped;
}

class _TodayWorkoutHeader extends StatelessWidget {
  const _TodayWorkoutHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isDepleted,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isDepleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDepleted ? const Color(0xFF120506) : const Color(0xFF050A0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accentColor.withValues(alpha: 0.10),
              border: Border.all(color: accentColor.withValues(alpha: 0.24)),
            ),
            child: Icon(
              isDepleted ? Icons.local_fire_department_rounded : Icons.calendar_today_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDepleted ? const Color(0xFFFFE4E6) : const Color(0xFFEAF2F4),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDepleted ? const Color(0xFFFCA5A5) : const Color(0xFF8A93A3),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.accentColor,
    required this.isDepleted,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isDepleted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDepleted
                  ? const [Color(0xFF2A090A), Color(0xFF120506)]
                  : const [Color(0xFF122031), Color(0xFF071018)],
            ),
            border: Border.all(color: accentColor.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isDepleted ? const Color(0xFFFCA5A5) : const Color(0xFF7DD3FC),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _AchievementsButton extends StatelessWidget {
  const _AchievementsButton({
    required this.onTap,
    required this.accentColor,
    required this.isDepleted,
  });

  final VoidCallback onTap;
  final Color accentColor;
  final bool isDepleted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDepleted
                  ? const [Color(0xFF2A090A), Color(0xFF120506)]
                  : const [Color(0xFF122031), Color(0xFF071018)],
            ),
            border: Border.all(color: accentColor.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.emoji_events_rounded,
            color: isDepleted ? const Color(0xFFFCA5A5) : const Color(0xFF7DD3FC),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _StartWorkoutButton extends StatelessWidget {
  const _StartWorkoutButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isUnavailable,
    required this.isDepleted,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isUnavailable;
  final bool isDepleted;

  @override
  Widget build(BuildContext context) {
    final accentColor = isDepleted ? const Color(0xFFFF3B3B) : const Color(0xFF00E5FF);
    final gradientColors = isDepleted
        ? const [Color(0xFF2A090A), Color(0xFF1A0708), Color(0xFF120506)]
        : isUnavailable
            ? const [Color(0xFF111827), Color(0xFF0B1220), Color(0xFF020617)]
            : const [Color(0xFF0F172A), Color(0xFF08111C), Color(0xFF020617)];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: isUnavailable ? null : onTap,
        child: Ink(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(
              color: accentColor.withValues(alpha: isUnavailable ? 0.26 : 0.46),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isUnavailable ? 0.10 : 0.22),
                blurRadius: 34,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.1,
                      colors: [
                        accentColor.withValues(alpha: isUnavailable ? 0.10 : 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isUnavailable ? 0.08 : 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: isUnavailable ? 0.20 : 0.32),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: accentColor.withValues(alpha: isUnavailable ? 0.70 : 1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isDepleted
                                ? const Color(0xFFFFE4E6)
                                : isUnavailable
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFFEAF2F4),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: isDepleted
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF8A93A3),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonActionButton extends StatelessWidget {
  const _NeonActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.isDepleted = false,
    this.enabled = true,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final bool isDepleted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accentColor = isDepleted ? const Color(0xFFFF3B3B) : const Color(0xFF00E5FF);
    final backgroundGradient = isDepleted
        ? const LinearGradient(colors: [Color(0xFF260809), Color(0xFF150506)])
        : const LinearGradient(colors: [Color(0xFF0C1822), Color(0xFF071018)]);

    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: Ink(
            height: compact ? 70 : 74,
            decoration: BoxDecoration(
              gradient: backgroundGradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accentColor.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: isDepleted ? 0.14 : 0.08),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withValues(alpha: 0.24)),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 20 : 23,
                    color: isDepleted ? const Color(0xFFFCA5A5) : const Color(0xFF7DD3FC),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDepleted ? const Color(0xFFFFE4E6) : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 14 : 16,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDepleted ? const Color(0xFFFCA5A5) : const Color(0xFF8A93A3),
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        title: Text(title, textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: const Color(0xFF050A0F),
      ),
      body: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFFEAF2F4),
          ),
        ),
      ),
    );
  }
}
