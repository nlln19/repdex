import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../widgets/body_strength_map.dart';
import 'plan_builder_screen.dart';
import 'workout_start_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String _selectedWorkoutPlanKey = 'selected_workout_plan_id';

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
      backgroundColor: const Color(0xFF050A0F),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              sliver: SliverToBoxAdapter(child: _buildHeader(context)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(child: _buildBodyCard(todayWorkout)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              sliver: SliverToBoxAdapter(child: _buildActions(context)),
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
    final selectedPlanId = settingsBox.get(_selectedWorkoutPlanKey);

    if (selectedPlanId == null || selectedPlanId is! String) {
      return const _TodayWorkoutData(
        planName: 'Kein Plan ausgewählt',
        dayName: 'Kein aktiver Wochenplan',
        muscleGroups: {},
        exerciseCount: 0,
        isRestDay: false,
        highlightFullBody: true,
      );
    }

    final selectedPlan = workoutPlanBox.get(selectedPlanId);

    if (selectedPlan == null) {
      return const _TodayWorkoutData(
        planName: 'Ausgewählter Plan nicht gefunden',
        dayName: 'Plan fehlt',
        muscleGroups: {},
        exerciseCount: 0,
        isRestDay: false,
        highlightFullBody: true,
      );
    }

    final today = selectedPlan.dayForWeekday(DateTime.now().weekday);

    if (today.isRestDay || today.exerciseIds.isEmpty) {
      return _TodayWorkoutData(
        planName: selectedPlan.name,
        dayName: 'Heute: Restday',
        muscleGroups: const {},
        exerciseCount: 0,
        isRestDay: true,
        highlightFullBody: false,
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
      muscleGroups: muscleGroups,
      exerciseCount: exerciseCount,
      isRestDay: false,
      highlightFullBody: false,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gym Tracker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                  color: Color(0xFFEAF2F4),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Track performance. Build strength.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _AchievementsButton(
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
    final subtitle = todayWorkout.highlightFullBody
        ? 'Erstelle oder aktiviere einen Plan, um nur die heutigen Muskeln zu markieren.'
        : todayWorkout.isRestDay
            ? 'Heute ist kein Training geplant.'
            : '${todayWorkout.exerciseCount} Übungen · ${todayWorkout.muscleGroups.length} Muskelgruppen';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF09131B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
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
            ),
            const SizedBox(height: 14),
            BodyStrengthMap(
              trainedMuscleGroups: todayWorkout.muscleGroups,
              highlightFullBody: todayWorkout.highlightFullBody,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        _StartWorkoutButton(
          onTap: () {
            _startWorkout(context);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NeonActionButton(
                label: 'Plan',
                subtitle: 'Erstellen',
                icon: Icons.add_rounded,
                compact: true,
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
                label: 'Verlauf',
                subtitle: 'Historie',
                icon: Icons.history_rounded,
                compact: true,
                onTap: () {
                  _openPlaceholder(context, 'Verlauf');
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
        backgroundColor: const Color(0xFF7F1D1D),
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
    required this.muscleGroups,
    required this.exerciseCount,
    required this.isRestDay,
    required this.highlightFullBody,
  });

  final String planName;
  final String dayName;
  final Set<String> muscleGroups;
  final int exerciseCount;
  final bool isRestDay;
  final bool highlightFullBody;
}

class _TodayWorkoutHeader extends StatelessWidget {
  const _TodayWorkoutHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF050A0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF00E5FF),
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
                  style: const TextStyle(
                    color: Color(0xFFEAF2F4),
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
                  style: const TextStyle(
                    color: Color(0xFF8A93A3),
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

class _AchievementsButton extends StatelessWidget {
  const _AchievementsButton({required this.onTap});

  final VoidCallback onTap;

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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF122031), Color(0xFF071018)],
            ),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFF7DD3FC),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _StartWorkoutButton extends StatelessWidget {
  const _StartWorkoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF08111C), Color(0xFF020617)],
            ),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.46),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
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
                        const Color(0xFF00E5FF).withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -18,
                top: -20,
                child: Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
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
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF00E5FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Start',
                      style: TextStyle(
                        color: Color(0xFFEAF2F4),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
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
  }
}

class _NeonActionButton extends StatelessWidget {
  const _NeonActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.compact = false,
  }) : filled = false;

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gradient = filled
        ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF3DDC97)])
        : const LinearGradient(colors: [Color(0xFF0C1822), Color(0xFF071018)]);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          height: compact ? 70 : 74,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: filled
                  ? Colors.transparent
                  : const Color(0xFF00E5FF).withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF00E5FF,
                ).withValues(alpha: filled ? 0.24 : 0.08),
                blurRadius: filled ? 28 : 16,
                spreadRadius: filled ? 2 : 0,
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
                  color: filled
                      ? Colors.black.withValues(alpha: 0.12)
                      : const Color(0xFF00E5FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: filled
                        ? Colors.black.withValues(alpha: 0.12)
                        : const Color(0xFF00E5FF).withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  icon,
                  size: compact ? 20 : 23,
                  color: filled ? Colors.black : const Color(0xFF7DD3FC),
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
                        color: filled ? Colors.black : Colors.white,
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
                        color: filled
                            ? Colors.black.withValues(alpha: 0.62)
                            : const Color(0xFF8A93A3),
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
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.58),
                blurRadius: 11,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8A93A3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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