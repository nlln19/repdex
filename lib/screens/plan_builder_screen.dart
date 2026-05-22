import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_plan.dart';

class PlanBuilderScreen extends StatelessWidget {
  const PlanBuilderScreen({super.key});

  static const String selectedWorkoutPlanKey = 'selected_workout_plan_id';

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
                final plans = workoutPlanBox.values.toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
                final activePlanId = settingsBox.get(selectedWorkoutPlanKey);

                return Scaffold(
                  backgroundColor: const Color(0xFF050A0F),
                  appBar: AppBar(
                    backgroundColor: const Color(0xFF050A0F),
                    foregroundColor: const Color(0xFFEAF2F4),
                    elevation: 0,
                    centerTitle: true,
                    title: const Text(
                      'Workout Plans',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _GlowIconButton(
                          icon: Icons.add_rounded,
                          onTap: () => _openEditor(context),
                        ),
                      ),
                    ],
                  ),
                  body: SafeArea(
                    top: false,
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                          sliver: SliverToBoxAdapter(
                            child: _PlansHero(
                              onCreate: () => _openEditor(context),
                            ),
                          ),
                        ),
                        if (plans.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyPlansState(
                              onCreate: () => _openEditor(context),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                            sliver: SliverList.separated(
                              itemCount: plans.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final plan = plans[index];
                                final exercises = plan.exerciseIds
                                    .map(exerciseBox.get)
                                    .whereType<Exercise>()
                                    .toList();
                                final isActive = activePlanId == plan.id;

                                return _PlanCard(
                                  plan: plan,
                                  exercises: exercises,
                                  isActive: isActive,
                                  onActivate: () async {
                                    await settingsBox.put(
                                      selectedWorkoutPlanKey,
                                      plan.id,
                                    );
                                  },
                                  onEdit: () => _openEditor(context, plan: plan),
                                  onDelete: () => _deletePlan(
                                    context: context,
                                    settingsBox: settingsBox,
                                    workoutPlanBox: workoutPlanBox,
                                    exerciseBox: exerciseBox,
                                    plan: plan,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openEditor(BuildContext context, {WorkoutPlan? plan}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlanEditorScreen(plan: plan),
      ),
    );
  }

  Future<void> _deletePlan({
    required BuildContext context,
    required Box<dynamic> settingsBox,
    required Box<WorkoutPlan> workoutPlanBox,
    required Box<Exercise> exerciseBox,
    required WorkoutPlan plan,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF09131B),
          title: const Text('Plan löschen?'),
          content: Text(
            'Der Plan "${plan.name}" wird entfernt. Übungen, die nur in diesem Plan vorkommen, werden ebenfalls gelöscht.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final otherExerciseIds = workoutPlanBox.values
        .where((otherPlan) => otherPlan.id != plan.id)
        .expand((otherPlan) => otherPlan.exerciseIds)
        .toSet();

    for (final exerciseId in plan.exerciseIds) {
      if (!otherExerciseIds.contains(exerciseId)) {
        await exerciseBox.delete(exerciseId);
      }
    }

    await workoutPlanBox.delete(plan.id);

    if (settingsBox.get(selectedWorkoutPlanKey) == plan.id) {
      await settingsBox.delete(selectedWorkoutPlanKey);
    }
  }
}

class _PlansHero extends StatelessWidget {
  const _PlansHero({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B28), Color(0xFF071018), Color(0xFF050A0F)],
        ),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.09),
            blurRadius: 34,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wochenplan erstellen',
                  style: TextStyle(
                    color: Color(0xFFEAF2F4),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Lege fest, was an welchem Tag trainiert wird.',
                  style: TextStyle(
                    color: Color(0xFF8A93A3),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CompactCreateButton(onTap: onCreate),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.exercises,
    required this.isActive,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutPlan plan;
  final List<Exercise> exercises;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muscleGroups = exercises
        .expand((exercise) => exercise.muscleGroups)
        .toSet()
        .toList()
      ..sort();
    final trainingDays = plan.days
        .where((day) => !day.isRestDay && day.exerciseIds.isNotEmpty)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF08111A),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00E5FF).withValues(alpha: 0.52)
              : const Color(0xFF00E5FF).withValues(alpha: 0.14),
          width: isActive ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: isActive ? 0.18 : 0.06),
            blurRadius: isActive ? 34 : 20,
            spreadRadius: isActive ? 1 : 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFEAF2F4),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        if (isActive) const _ActiveBadge(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$trainingDays Trainingstage · ${exercises.length} Übungen · ${muscleGroups.length} Muskelgruppen',
                      style: const TextStyle(
                        color: Color(0xFF8A93A3),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SmallCircleButton(icon: Icons.edit_rounded, onTap: onEdit),
              const SizedBox(width: 8),
              _SmallCircleButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
            ],
          ),
          const SizedBox(height: 14),
          _WeekPreview(days: plan.days),
          if (muscleGroups.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in muscleGroups) _MuscleGroupPill(label: group),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _ActivatePlanButton(
            isActive: isActive,
            onTap: isActive ? null : onActivate,
          ),
        ],
      ),
    );
  }
}

class _WeekPreview extends StatelessWidget {
  const _WeekPreview({required this.days});

  final List<WorkoutPlanDay> days;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final day in days)
          _WeekdayPill(
            label: WorkoutPlanDay.shortWeekdayName(day.weekday),
            value: day.isRestDay ? 'Rest' : day.name,
            active: !day.isRestDay && day.exerciseIds.isNotEmpty,
          ),
      ],
    );
  }
}

class _WeekdayPill extends StatelessWidget {
  const _WeekdayPill({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.10)
            : const Color(0xFF0B1620),
        border: Border.all(
          color: active
              ? const Color(0xFF00E5FF).withValues(alpha: 0.28)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: active ? const Color(0xFFEAF2F4) : const Color(0xFF8A93A3),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanEditorScreen extends StatefulWidget {
  const _PlanEditorScreen({this.plan});

  final WorkoutPlan? plan;

  @override
  State<_PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<_PlanEditorScreen> {
  static const List<String> _availableMuscleGroups = [
    'Brust',
    'Rücken',
    'Schultern',
    'Bizeps',
    'Trizeps',
    'Bauch/Core',
    'Quads',
    'Hamstrings',
    'Po',
    'Nacken',
  ];

  final TextEditingController _planNameController = TextEditingController();
  final List<_DayDraft> _dayDrafts = [];

  late final Box<dynamic> _settingsBox;
  late final Box<WorkoutPlan> _workoutPlanBox;
  late final Box<Exercise> _exerciseBox;
  late bool _makeActiveAfterSave;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();

    _settingsBox = Hive.box('settings');
    _workoutPlanBox = Hive.box<WorkoutPlan>('workout_plans');
    _exerciseBox = Hive.box<Exercise>('exercises');

    final activePlanId = _settingsBox.get(PlanBuilderScreen.selectedWorkoutPlanKey);
    _makeActiveAfterSave = widget.plan?.id == activePlanId || activePlanId == null;

    final plan = widget.plan;

    if (plan == null) {
      _planNameController.text = 'Push Pull Legs';
      _dayDrafts.addAll([
        _DayDraft.createTrainingDay(DateTime.monday, 'Push'),
        _DayDraft.createTrainingDay(DateTime.tuesday, 'Pull'),
        _DayDraft.createTrainingDay(DateTime.wednesday, 'Legs'),
        _DayDraft.createRestDay(DateTime.thursday),
        _DayDraft.createTrainingDay(DateTime.friday, 'Push'),
        _DayDraft.createTrainingDay(DateTime.saturday, 'Pull'),
        _DayDraft.createRestDay(DateTime.sunday),
      ]);
      return;
    }

    _planNameController.text = plan.name;

    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final day = plan.dayForWeekday(weekday);
      _dayDrafts.add(_DayDraft.fromPlanDay(day, _exerciseBox));
    }
  }

  @override
  void dispose() {
    _planNameController.dispose();

    for (final draft in _dayDrafts) {
      draft.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050A0F),
        foregroundColor: const Color(0xFFEAF2F4),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isEditing ? 'Plan bearbeiten' : 'Plan erstellen',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: [
            _EditorPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _EditorSectionTitle(
                    title: 'Plan Name',
                    subtitle: 'Beispiel: Push Pull Legs, Upper Lower oder Full Body.',
                  ),
                  const SizedBox(height: 12),
                  _NeonTextField(
                    controller: _planNameController,
                    hintText: 'z. B. Push Pull Legs',
                    icon: Icons.drive_file_rename_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _ActiveSwitchTile(
                    value: _makeActiveAfterSave,
                    onChanged: (value) {
                      setState(() {
                        _makeActiveAfterSave = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _EditorSectionTitle(
              title: 'Wochenablauf',
              subtitle: 'Lege für jeden Tag fest, ob trainiert wird oder Restday ist.',
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _dayDrafts.length; index++) ...[
              _DayDraftCard(
                draft: _dayDrafts[index],
                availableMuscleGroups: _availableMuscleGroups,
                onChanged: () => setState(() {}),
                onAddExercise: () => _addExerciseToDay(index),
                onRemoveExercise: (exerciseIndex) =>
                    _removeExerciseFromDay(index, exerciseIndex),
                onToggleRestDay: (isRestDay) =>
                    _setRestDay(index: index, isRestDay: isRestDay),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            _SavePlanButton(
              isEditing: _isEditing,
              onTap: _savePlan,
            ),
          ],
        ),
      ),
    );
  }

  void _addExerciseToDay(int dayIndex) {
    setState(() {
      final day = _dayDrafts[dayIndex];
      day.isRestDay = false;
      day.exerciseDrafts.add(_ExerciseDraft.createEmpty());
    });
  }

  void _removeExerciseFromDay(int dayIndex, int exerciseIndex) {
    setState(() {
      final day = _dayDrafts[dayIndex];
      final removedDraft = day.exerciseDrafts.removeAt(exerciseIndex);
      removedDraft.dispose();

      if (day.exerciseDrafts.isEmpty) {
        day.exerciseDrafts.add(_ExerciseDraft.createEmpty());
      }
    });
  }

  void _setRestDay({required int index, required bool isRestDay}) {
    setState(() {
      final day = _dayDrafts[index];
      day.isRestDay = isRestDay;

      if (isRestDay) {
        for (final exercise in day.exerciseDrafts) {
          exercise.dispose();
        }
        day.exerciseDrafts.clear();
        day.nameController.text = 'Restday';
      } else {
        day.nameController.text = WorkoutPlanDay.weekdayName(day.weekday);
        if (day.exerciseDrafts.isEmpty) {
          day.exerciseDrafts.add(_ExerciseDraft.createEmpty());
        }
      }
    });
  }

  Future<void> _savePlan() async {
    final planName = _planNameController.text.trim();

    if (planName.isEmpty) {
      _showError('Bitte gib dem Plan einen Namen.');
      return;
    }

    final hasAtLeastOneTrainingDay = _dayDrafts.any(
      (day) => !day.isRestDay && day.exerciseDrafts.isNotEmpty,
    );

    if (!hasAtLeastOneTrainingDay) {
      _showError('Bitte erstelle mindestens einen Trainingstag.');
      return;
    }

    for (final day in _dayDrafts) {
      if (day.isRestDay) {
        continue;
      }

      if (day.name.trim().isEmpty) {
        _showError('${WorkoutPlanDay.weekdayName(day.weekday)} braucht einen Namen.');
        return;
      }

      if (day.exerciseDrafts.isEmpty) {
        _showError('${day.name} braucht mindestens eine Übung.');
        return;
      }

      for (final exercise in day.exerciseDrafts) {
        if (exercise.name.trim().isEmpty) {
          _showError('Jede Übung braucht einen Namen.');
          return;
        }

        if (exercise.muscleGroups.isEmpty) {
          _showError('Jede Übung braucht mindestens eine Muskelgruppe.');
          return;
        }

        if (exercise.plannedSets == null) {
          _showError('Sätze müssen eine ganze Zahl grösser als 0 sein.');
          return;
        }

        if (exercise.plannedReps == null) {
          _showError('Wiederholungen müssen eine ganze Zahl grösser als 0 sein.');
          return;
        }

        if (exercise.plannedWeight == null) {
          _showError('Gewicht muss eine Zahl ab 0 sein.');
          return;
        }
      }
    }

    final planId = widget.plan?.id ?? _createId('plan');
    final exerciseIds = <String>[];
    final days = <WorkoutPlanDay>[];

    for (final day in _dayDrafts) {
      if (day.isRestDay) {
        days.add(WorkoutPlanDay.restDay(weekday: day.weekday));
        continue;
      }

      final dayExerciseIds = <String>[];

      for (final draft in day.exerciseDrafts) {
        final exercise = Exercise(
          id: draft.id,
          name: draft.name.trim(),
          muscleGroups: draft.muscleGroups.toList()..sort(),
          plannedSets: draft.plannedSets!,
          plannedReps: draft.plannedReps!,
          plannedWeight: draft.plannedWeight!,
        );

        await _exerciseBox.put(exercise.id, exercise);
        dayExerciseIds.add(exercise.id);

        if (!exerciseIds.contains(exercise.id)) {
          exerciseIds.add(exercise.id);
        }
      }

      days.add(
        WorkoutPlanDay.trainingDay(
          weekday: day.weekday,
          name: day.name.trim(),
          exerciseIds: dayExerciseIds,
        ),
      );
    }

    await _deleteRemovedExercises(planId, exerciseIds.toSet());

    final plan = WorkoutPlan(
      id: planId,
      name: planName,
      exerciseIds: exerciseIds,
      restSeconds: widget.plan?.restSeconds ?? 90,
      days: days,
    );

    await _workoutPlanBox.put(plan.id, plan);

    if (_makeActiveAfterSave) {
      await _settingsBox.put(PlanBuilderScreen.selectedWorkoutPlanKey, plan.id);
    } else if (_settingsBox.get(PlanBuilderScreen.selectedWorkoutPlanKey) == plan.id) {
      await _settingsBox.delete(PlanBuilderScreen.selectedWorkoutPlanKey);
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _deleteRemovedExercises(
    String planId,
    Set<String> keptExerciseIds,
  ) async {
    final oldPlan = widget.plan;

    if (oldPlan == null) {
      return;
    }

    final exerciseIdsUsedByOtherPlans = _workoutPlanBox.values
        .where((plan) => plan.id != planId)
        .expand((plan) => plan.exerciseIds)
        .toSet();

    for (final oldExerciseId in oldPlan.exerciseIds) {
      final isStillInThisPlan = keptExerciseIds.contains(oldExerciseId);
      final isUsedElsewhere = exerciseIdsUsedByOtherPlans.contains(oldExerciseId);

      if (!isStillInThisPlan && !isUsedElsewhere) {
        await _exerciseBox.delete(oldExerciseId);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF7F1D1D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _createId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }
}

class _DayDraft {
  _DayDraft({
    required this.weekday,
    required String name,
    required this.isRestDay,
    required List<_ExerciseDraft> exerciseDrafts,
  })  : nameController = TextEditingController(text: name),
        exerciseDrafts = [...exerciseDrafts];

  factory _DayDraft.createTrainingDay(int weekday, String name) {
    return _DayDraft(
      weekday: weekday,
      name: name,
      isRestDay: false,
      exerciseDrafts: [_ExerciseDraft.createEmpty()],
    );
  }

  factory _DayDraft.createRestDay(int weekday) {
    return _DayDraft(
      weekday: weekday,
      name: 'Restday',
      isRestDay: true,
      exerciseDrafts: const [],
    );
  }

  factory _DayDraft.fromPlanDay(
    WorkoutPlanDay day,
    Box<Exercise> exerciseBox,
  ) {
    if (day.isRestDay) {
      return _DayDraft.createRestDay(day.weekday);
    }

    final exerciseDrafts = day.exerciseIds
        .map(exerciseBox.get)
        .whereType<Exercise>()
        .map(_ExerciseDraft.fromExercise)
        .toList();

    if (exerciseDrafts.isEmpty) {
      exerciseDrafts.add(_ExerciseDraft.createEmpty());
    }

    return _DayDraft(
      weekday: day.weekday,
      name: day.name,
      isRestDay: false,
      exerciseDrafts: exerciseDrafts,
    );
  }

  final int weekday;
  final TextEditingController nameController;
  final List<_ExerciseDraft> exerciseDrafts;
  bool isRestDay;

  String get name => nameController.text;

  void dispose() {
    nameController.dispose();

    for (final draft in exerciseDrafts) {
      draft.dispose();
    }
  }
}

class _ExerciseDraft {
  _ExerciseDraft({
    required this.id,
    required String name,
    required Set<String> muscleGroups,
    required int plannedSets,
    required int plannedReps,
    required double plannedWeight,
  })  : nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: plannedSets.toString()),
        repsController = TextEditingController(text: plannedReps.toString()),
        weightController = TextEditingController(
          text: plannedWeight == 0
              ? ''
              : plannedWeight.roundToDouble() == plannedWeight
                  ? plannedWeight.toInt().toString()
                  : plannedWeight.toStringAsFixed(1),
        ),
        muscleGroups = {...muscleGroups};

  factory _ExerciseDraft.createEmpty() {
    return _ExerciseDraft(
      id: 'exercise_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}',
      name: '',
      muscleGroups: {},
      plannedSets: 3,
      plannedReps: 10,
      plannedWeight: 0,
    );
  }

  factory _ExerciseDraft.fromExercise(Exercise exercise) {
    final normalizedExercise = Exercise(
      id: exercise.id,
      name: exercise.name,
      muscleGroups: exercise.muscleGroups,
      plannedSets: exercise.plannedSets,
      plannedReps: exercise.plannedReps,
      plannedWeight: exercise.plannedWeight,
    );

    return _ExerciseDraft(
      id: normalizedExercise.id,
      name: normalizedExercise.name,
      muscleGroups: normalizedExercise.muscleGroups.toSet(),
      plannedSets: normalizedExercise.plannedSets,
      plannedReps: normalizedExercise.plannedReps,
      plannedWeight: normalizedExercise.plannedWeight,
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final Set<String> muscleGroups;

  String get name => nameController.text;

  int? get plannedSets {
    final value = int.tryParse(setsController.text.trim());
    return value == null || value < 1 ? null : value;
  }

  int? get plannedReps {
    final value = int.tryParse(repsController.text.trim());
    return value == null || value < 1 ? null : value;
  }

  double? get plannedWeight {
    final text = weightController.text.trim().replaceAll(',', '.');

    if (text.isEmpty) {
      return 0;
    }

    final value = double.tryParse(text);
    return value == null || value < 0 ? null : value;
  }

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
  }
}

class _DayDraftCard extends StatelessWidget {
  const _DayDraftCard({
    required this.draft,
    required this.availableMuscleGroups,
    required this.onChanged,
    required this.onAddExercise,
    required this.onRemoveExercise,
    required this.onToggleRestDay,
  });

  final _DayDraft draft;
  final List<String> availableMuscleGroups;
  final VoidCallback onChanged;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;
  final ValueChanged<bool> onToggleRestDay;

  @override
  Widget build(BuildContext context) {
    return _EditorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.26),
                  ),
                ),
                child: Text(
                  WorkoutPlanDay.shortWeekdayName(draft.weekday),
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      WorkoutPlanDay.weekdayName(draft.weekday),
                      style: const TextStyle(
                        color: Color(0xFFEAF2F4),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.isRestDay
                          ? 'Kein Training an diesem Tag'
                          : '${draft.exerciseDrafts.length} Übungen',
                      style: const TextStyle(
                        color: Color(0xFF8A93A3),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: draft.isRestDay,
                activeThumbColor: const Color(0xFF00E5FF),
                onChanged: onToggleRestDay,
              ),
              const Text(
                'Rest',
                style: TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (!draft.isRestDay) ...[
            const SizedBox(height: 14),
            _NeonTextField(
              controller: draft.nameController,
              hintText: 'z. B. Push, Pull, Legs',
              icon: Icons.label_rounded,
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < draft.exerciseDrafts.length; index++) ...[
              _ExerciseDraftCard(
                index: index,
                draft: draft.exerciseDrafts[index],
                availableMuscleGroups: availableMuscleGroups,
                onChanged: onChanged,
                onRemove: draft.exerciseDrafts.length == 1
                    ? null
                    : () => onRemoveExercise(index),
              ),
              const SizedBox(height: 10),
            ],
            _AddExerciseButton(onTap: onAddExercise),
          ],
        ],
      ),
    );
  }
}

class _ExerciseDraftCard extends StatelessWidget {
  const _ExerciseDraftCard({
    required this.index,
    required this.draft,
    required this.availableMuscleGroups,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _ExerciseDraft draft;
  final List<String> availableMuscleGroups;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF050A0F),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Übung',
                  style: TextStyle(
                    color: Color(0xFFEAF2F4),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onRemove != null)
                _SmallCircleButton(
                  icon: Icons.close_rounded,
                  onTap: onRemove!,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _NeonTextField(
            controller: draft.nameController,
            hintText: 'z. B. Bankdrücken',
            icon: Icons.fitness_center_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactMetricField(
                  controller: draft.setsController,
                  label: 'Sätze',
                  hintText: '3',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricField(
                  controller: draft.repsController,
                  label: 'Wdh.',
                  hintText: '10',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetricField(
                  controller: draft.weightController,
                  label: 'Gewicht',
                  hintText: 'kg',
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Getroffene Muskelgruppen',
            style: TextStyle(
              color: Color(0xFF8A93A3),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in availableMuscleGroups)
                _SelectableMuscleChip(
                  label: group,
                  selected: draft.muscleGroups.contains(group),
                  onTap: () {
                    if (draft.muscleGroups.contains(group)) {
                      draft.muscleGroups.remove(group);
                    } else {
                      draft.muscleGroups.add(group);
                    }

                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetricField extends StatelessWidget {
  const _CompactMetricField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      cursorColor: const Color(0xFF00E5FF),
      style: const TextStyle(
        color: Color(0xFFEAF2F4),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(
          color: Color(0xFF7DD3FC),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: const TextStyle(color: Color(0xFF586174)),
        filled: true,
        fillColor: const Color(0xFF071018),
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.1),
        ),
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: const Color(0xFF08111A),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
            blurRadius: 22,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EditorSectionTitle extends StatelessWidget {
  const _EditorSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEAF2F4),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
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

class _NeonTextField extends StatelessWidget {
  const _NeonTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: const Color(0xFF00E5FF),
      style: const TextStyle(
        color: Color(0xFFEAF2F4),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF586174)),
        prefixIcon: Icon(icon, color: const Color(0xFF7DD3FC)),
        filled: true,
        fillColor: const Color(0xFF050A0F),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
      ),
    );
  }
}

class _ActiveSwitchTile extends StatelessWidget {
  const _ActiveSwitchTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF050A0F),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF7DD3FC)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Als aktiven Plan verwenden',
                  style: TextStyle(
                    color: Color(0xFFEAF2F4),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Der HomeScreen zeigt dann die Einheit vom heutigen Wochentag.',
                  style: TextStyle(
                    color: Color(0xFF8A93A3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF00E5FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SelectableMuscleChip extends StatelessWidget {
  const _SelectableMuscleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                : const Color(0xFF0B1620),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.74)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.16),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFEAFBFF) : const Color(0xFF8A93A3),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MuscleGroupPill extends StatelessWidget {
  const _MuscleGroupPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF00E5FF).withValues(alpha: 0.09),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7DD3FC),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActivatePlanButton extends StatelessWidget {
  const _ActivatePlanButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF3DDC97)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF08111C)],
                  ),
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : const Color(0xFF00E5FF).withValues(alpha: 0.28),
            ),
          ),
          child: Center(
            child: Text(
              isActive ? 'Aktiver Plan' : 'Diesen Plan aktivieren',
              style: TextStyle(
                color: isActive ? Colors.black : const Color(0xFFEAF2F4),
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavePlanButton extends StatelessWidget {
  const _SavePlanButton({required this.isEditing, required this.onTap});

  final bool isEditing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00E5FF), Color(0xFF3DDC97)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              isEditing ? 'Plan speichern' : 'Plan erstellen',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Color(0xFF00E5FF), size: 21),
              SizedBox(width: 8),
              Text(
                'Übung hinzufügen',
                style: TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactCreateButton extends StatelessWidget {
  const _CompactCreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF3DDC97)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.24),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
        ),
      ),
    );
  }
}

class _GlowIconButton extends StatelessWidget {
  const _GlowIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: const Color(0xFF0B1620),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.24)),
          ),
          child: Icon(icon, color: const Color(0xFF7DD3FC)),
        ),
      ),
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  const _SmallCircleButton({required this.icon, required this.onTap});

  final IconData icon;
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B1620),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: const Color(0xFF8A93A3), size: 20),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFF00E5FF), Color(0xFF3DDC97)],
        ),
      ),
      child: const Text(
        'AKTIV',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyPlansState extends StatelessWidget {
  const _EmptyPlansState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF00E5FF),
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Noch keine Pläne',
            style: TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Erstelle deinen ersten Wochenplan mit Trainingstagen, Restdays und Übungen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8A93A3),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          _SavePlanButton(isEditing: false, onTap: onCreate),
        ],
      ),
    );
  }
}
