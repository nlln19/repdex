import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_plan.dart';

String _formatRestSecondsLabel(int restSeconds) {
  final safeSeconds = restSeconds < 1 ? 1 : restSeconds;

  if (safeSeconds % 60 == 0) {
    return '${safeSeconds ~/ 60} Min.';
  }

  final minutes = safeSeconds / 60;
  return '${minutes.toStringAsFixed(1).replaceAll('.', ',')} Min.';
}

String _formatRestMinutesInput(int restSeconds) {
  final safeSeconds = restSeconds < 1 ? 1 : restSeconds;
  final minutes = safeSeconds / 60;

  if (minutes.roundToDouble() == minutes) {
    return minutes.toInt().toString();
  }

  return minutes.toStringAsFixed(1);
}

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
                    child: plans.isEmpty
                        ? _EmptyPlansState(onCreate: () => _openEditor(context))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                            itemCount: plans.length + 1,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _PlansHero(onCreate: () => _openEditor(context));
                              }

                              final plan = plans[index - 1];
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
                                  await settingsBox.put(selectedWorkoutPlanKey, plan.id);
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
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, {WorkoutPlan? plan}) async {
    _PlanTemplate? initialTemplate;

    if (plan == null) {
      initialTemplate = await showModalBottomSheet<_PlanTemplate>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _TemplateSelectionSheet(),
      );

      if (initialTemplate == null || !context.mounted) {
        return;
      }
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlanEditorScreen(
          plan: plan,
          initialTemplate: initialTemplate,
        ),
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
      decoration: _panelDecoration(),
      child: Row(
        children: [
          _IconBadge(icon: Icons.calendar_month_rounded),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Builder',
                  style: TextStyle(
                    color: Color(0xFFEAF2F4),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Geführt erstellen: Basis, Woche, Übungen.',
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
    final trainingDays = plan.days
        .where((day) => !day.isRestDay && day.exerciseIds.isNotEmpty)
        .length;
    final muscleGroups = exercises
        .expand((exercise) => exercise.muscleGroups)
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty)
        .toSet();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF08111A),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00E5FF).withValues(alpha: 0.42)
              : const Color(0xFF00E5FF).withValues(alpha: 0.14),
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
              blurRadius: 28,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(
                icon: isActive ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFEAF2F4),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$trainingDays Trainingstage · ${exercises.length} Übungen · ${muscleGroups.length} Muskelgruppen · Pause ${_formatRestSecondsLabel(plan.restSeconds)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8A93A3),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF09131B),
                iconColor: const Color(0xFFEAF2F4),
                onSelected: (value) {
                  switch (value) {
                    case 'activate':
                      onActivate();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Text('Aktivieren'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                  const PopupMenuItem(value: 'delete', child: Text('Löschen')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in plan.days)
                _DayMiniChip(
                  label: WorkoutPlanDay.shortWeekdayName(day.weekday),
                  active: !day.isRestDay && day.exerciseIds.isNotEmpty,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SmallActionButton(
                  label: isActive ? 'Aktiv' : 'Aktivieren',
                  icon: isActive ? Icons.check_rounded : Icons.play_arrow_rounded,
                  filled: !isActive,
                  onTap: isActive ? () {} : onActivate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallActionButton(
                  label: 'Bearbeiten',
                  icon: Icons.edit_rounded,
                  filled: false,
                  onTap: onEdit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanEditorScreen extends StatefulWidget {
  const _PlanEditorScreen({this.plan, this.initialTemplate});

  final WorkoutPlan? plan;
  final _PlanTemplate? initialTemplate;

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

  late final Box<dynamic> _settingsBox;
  late final Box<WorkoutPlan> _workoutPlanBox;
  late final Box<Exercise> _exerciseBox;

  final TextEditingController _planNameController = TextEditingController();
  final TextEditingController _restMinutesController = TextEditingController();
  final TextEditingController _trainingSequenceController = TextEditingController();
  final List<_DayDraft> _dayDrafts = [];

  var _step = 0;
  var _selectedDayIndex = 0;
  var _makeActiveAfterSave = true;

  @override
  void initState() {
    super.initState();

    _settingsBox = Hive.box('settings');
    _workoutPlanBox = Hive.box<WorkoutPlan>('workout_plans');
    _exerciseBox = Hive.box<Exercise>('exercises');

    final plan = widget.plan;

    if (plan == null) {
      _restMinutesController.text = _formatRestMinutesInput(180);
      _makeActiveAfterSave = true;
      _applyTemplate(widget.initialTemplate ?? _PlanTemplate.pushPullLegs, notify: false);
      return;
    }

    _planNameController.text = plan.name;
    _restMinutesController.text = _formatRestMinutesInput(plan.restSeconds);
    _makeActiveAfterSave = _settingsBox.get(PlanBuilderScreen.selectedWorkoutPlanKey) == plan.id;
    _dayDrafts.addAll(plan.days.map((day) => _DayDraft.fromPlanDay(day, _exerciseBox)));
    _setTrainingNameSequence(_inferTrainingNameSequence(_dayDrafts));

    if (_dayDrafts.isEmpty) {
      _applyTemplate(_PlanTemplate.empty, notify: false);
    }

    _rebalanceTrainingDayNames();

    final firstTrainingDay = _dayDrafts.indexWhere((day) => !day.isRestDay);
    _selectedDayIndex = firstTrainingDay == -1 ? 0 : firstTrainingDay;
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _restMinutesController.dispose();
    _trainingSequenceController.dispose();

    for (final dayDraft in _dayDrafts) {
      dayDraft.dispose();
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
          widget.plan == null ? 'Plan erstellen' : 'Plan bearbeiten',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: _StepTabs(
                currentStep: _step,
                onSelected: (step) => setState(() => _step = step),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildStep(),
              ),
            ),
            _EditorBottomBar(
              step: _step,
              onBack: _step == 0 ? null : () => setState(() => _step--),
              onNext: _step == 2 ? _savePlan : () => setState(() => _step++),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildBasicsStep();
      case 1:
        return _buildWeekStep();
      default:
        return _buildExercisesStep();
    }
  }

  Widget _buildBasicsStep() {
    return ListView(
      key: const ValueKey('basics'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        _EditorPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Basis',
                subtitle: 'Name, Satzpause und Aktivierung.',
              ),
              const SizedBox(height: 16),
              _NeonTextField(
                controller: _planNameController,
                label: 'Plan Name',
                hintText: 'z. B. Push Pull Legs',
                icon: Icons.drive_file_rename_outline_rounded,
              ),
              const SizedBox(height: 14),
              _MetricTextField(
                controller: _restMinutesController,
                label: 'Satzpause in Minuten',
                hintText: '3',
                decimal: true,
              ),
              const SizedBox(height: 14),
              _NeonTextField(
                controller: _trainingSequenceController,
                label: 'Trainingstage-Reihenfolge',
                hintText: 'z. B. Push, Pull, Legs',
                icon: Icons.repeat_rounded,
                onChanged: (_) {
                  setState(() {
                    _rebalanceTrainingDayNames();
                  });
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Die aktiven Trainingstage folgen immer dieser Reihenfolge. Wenn du Restdays änderst, bleiben z. B. Push → Pull → Legs korrekt sortiert.',
                style: TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
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
      ],
    );
  }

  Widget _buildWeekStep() {
    return ListView(
      key: const ValueKey('week'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        const _SectionTitle(
          title: 'Woche',
          subtitle: 'Lege fest, welche Tage Trainingstage sind.',
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < _dayDrafts.length; index++) ...[
          _WeekDayCard(
            draft: _dayDrafts[index],
            selected: index == _selectedDayIndex,
            onSelect: () {
              setState(() {
                _selectedDayIndex = index;
                _step = 2;
              });
            },
            onToggleRestDay: (value) {
              setState(() {
                _dayDrafts[index].setRestDay(value);
                _rebalanceTrainingDayNames();
                _selectedDayIndex = _bestSelectedDayIndex(_selectedDayIndex);
              });
            },
            onNameChanged: (value) {
              setState(() {
                _updateTrainingSequenceFromDay(index, value);
              });
            },
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildExercisesStep() {
    final selectedDay = _dayDrafts[_selectedDayIndex];

    return ListView(
      key: const ValueKey('exercises'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        _DaySelector(
          days: _dayDrafts,
          selectedIndex: _selectedDayIndex,
          onSelected: (index) {
            setState(() {
              _selectedDayIndex = index;
            });
          },
        ),
        const SizedBox(height: 14),
        _EditorPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: selectedDay.isRestDay ? 'Restday' : selectedDay.name,
                subtitle: selectedDay.isRestDay
                    ? 'Restdays stellst du im Tab "Woche" ein.'
                    : '${selectedDay.exerciseDrafts.length} Übungen geplant.',
              ),
              if (!selectedDay.isRestDay) ...[
                const SizedBox(height: 14),
                for (var index = 0; index < selectedDay.exerciseDrafts.length; index++) ...[
                  _ExerciseDraftCard(
                    index: index,
                    draft: selectedDay.exerciseDrafts[index],
                    onChanged: () => setState(() {}),
                    onRemove: selectedDay.exerciseDrafts.length == 1
                        ? null
                        : () {
                            setState(() {
                              selectedDay.removeExercise(index);
                            });
                          },
                    onPickMuscles: () => _openMusclePicker(selectedDay.exerciseDrafts[index]),
                  ),
                  const SizedBox(height: 12),
                ],
                _AddExerciseButton(
                  onTap: () {
                    setState(() {
                      selectedDay.addExercise();
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndApplyTemplate(_PlanTemplate template) async {
    final hasContent = _dayDrafts.any((day) =>
        !day.isRestDay &&
        day.exerciseDrafts.any((exercise) => exercise.name.trim().isNotEmpty));

    if (hasContent) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF09131B),
            title: const Text('Template übernehmen?'),
            content: const Text(
              'Die aktuelle Wochenstruktur und Übungen werden durch das Template ersetzt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Übernehmen'),
              ),
            ],
          );
        },
      );

      if (shouldReplace != true) {
        return;
      }
    }

    _applyTemplate(template);
  }

  void _applyTemplate(_PlanTemplate template, {bool notify = true}) {
    for (final dayDraft in _dayDrafts) {
      dayDraft.dispose();
    }

    _dayDrafts.clear();
    _planNameController.text = _templatePlanName(template);
    _setTrainingNameSequence(_templateTrainingSequence(template));

    switch (template) {
      case _PlanTemplate.pushPullLegs:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Push',
            exercises: _pushExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.tuesday,
            'Pull',
            exercises: _pullExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.wednesday,
            'Legs',
            exercises: _legsExercises(),
          ),
          _DayDraft.createRestDay(DateTime.thursday, fallbackTrainingName: 'Push'),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Push',
            exercises: _pushExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.saturday,
            'Pull',
            exercises: _pullExercises(),
          ),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Legs'),
        ]);
        break;
      case _PlanTemplate.upperLower:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Upper',
            exercises: _upperExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.tuesday,
            'Lower',
            exercises: _lowerExercises(),
          ),
          _DayDraft.createRestDay(DateTime.wednesday, fallbackTrainingName: 'Upper'),
          _DayDraft.createTrainingDay(
            DateTime.thursday,
            'Upper',
            exercises: _upperExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Lower',
            exercises: _lowerExercises(),
          ),
          _DayDraft.createRestDay(DateTime.saturday, fallbackTrainingName: 'Upper'),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Lower'),
        ]);
        break;
      case _PlanTemplate.fullBody:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Full Body',
            exercises: _fullBodyExercises(),
          ),
          _DayDraft.createRestDay(DateTime.tuesday, fallbackTrainingName: 'Full Body'),
          _DayDraft.createTrainingDay(
            DateTime.wednesday,
            'Full Body',
            exercises: _fullBodyExercises(),
          ),
          _DayDraft.createRestDay(DateTime.thursday, fallbackTrainingName: 'Full Body'),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Full Body',
            exercises: _fullBodyExercises(),
          ),
          _DayDraft.createRestDay(DateTime.saturday, fallbackTrainingName: 'Full Body'),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Full Body'),
        ]);
        break;
      case _PlanTemplate.torsoLimbs:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Torso',
            exercises: _torsoExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.tuesday,
            'Limbs',
            exercises: _limbsExercises(),
          ),
          _DayDraft.createRestDay(DateTime.wednesday, fallbackTrainingName: 'Torso'),
          _DayDraft.createTrainingDay(
            DateTime.thursday,
            'Torso',
            exercises: _torsoExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Limbs',
            exercises: _limbsExercises(),
          ),
          _DayDraft.createRestDay(DateTime.saturday, fallbackTrainingName: 'Torso'),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Limbs'),
        ]);
        break;
      case _PlanTemplate.broSplit:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Chest',
            exercises: _chestExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.tuesday,
            'Back',
            exercises: _backExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.wednesday,
            'Legs',
            exercises: _legsExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.thursday,
            'Shoulders',
            exercises: _shouldersExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Arms',
            exercises: _armsExercises(),
          ),
          _DayDraft.createRestDay(DateTime.saturday, fallbackTrainingName: 'Chest'),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Back'),
        ]);
        break;
      case _PlanTemplate.arnoldSplit:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Chest & Back',
            exercises: _chestBackExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.tuesday,
            'Shoulders & Arms',
            exercises: _shouldersArmsExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.wednesday,
            'Legs',
            exercises: _legsExercises(),
          ),
          _DayDraft.createRestDay(DateTime.thursday, fallbackTrainingName: 'Chest & Back'),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Chest & Back',
            exercises: _chestBackExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.saturday,
            'Shoulders & Arms',
            exercises: _shouldersArmsExercises(),
          ),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Legs'),
        ]);
        break;
      case _PlanTemplate.phul:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Upper Power',
            exercises: _upperPowerExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.tuesday,
            'Lower Power',
            exercises: _lowerPowerExercises(),
          ),
          _DayDraft.createRestDay(DateTime.wednesday, fallbackTrainingName: 'Upper Hypertrophy'),
          _DayDraft.createTrainingDay(
            DateTime.thursday,
            'Upper Hypertrophy',
            exercises: _upperHypertrophyExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Lower Hypertrophy',
            exercises: _lowerHypertrophyExercises(),
          ),
          _DayDraft.createRestDay(DateTime.saturday, fallbackTrainingName: 'Upper Power'),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Lower Power'),
        ]);
        break;
      case _PlanTemplate.strength5x5:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Strength A',
            exercises: _strengthAExercises(),
          ),
          _DayDraft.createRestDay(DateTime.tuesday, fallbackTrainingName: 'Strength B'),
          _DayDraft.createTrainingDay(
            DateTime.wednesday,
            'Strength B',
            exercises: _strengthBExercises(),
          ),
          _DayDraft.createRestDay(DateTime.thursday, fallbackTrainingName: 'Strength A'),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Strength A',
            exercises: _strengthAExercises(),
          ),
          _DayDraft.createRestDay(DateTime.saturday, fallbackTrainingName: 'Strength B'),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Strength A'),
        ]);
        break;
      case _PlanTemplate.bodybuilding4Day:
        _dayDrafts.addAll([
          _DayDraft.createTrainingDay(
            DateTime.monday,
            'Chest & Triceps',
            exercises: _chestTricepsExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.tuesday,
            'Back & Biceps',
            exercises: _backBicepsExercises(),
          ),
          _DayDraft.createRestDay(DateTime.wednesday, fallbackTrainingName: 'Legs'),
          _DayDraft.createTrainingDay(
            DateTime.thursday,
            'Legs',
            exercises: _legsExercises(),
          ),
          _DayDraft.createTrainingDay(
            DateTime.friday,
            'Shoulders',
            exercises: _shouldersExercises(),
          ),
          _DayDraft.createRestDay(DateTime.saturday, fallbackTrainingName: 'Chest & Triceps'),
          _DayDraft.createRestDay(DateTime.sunday, fallbackTrainingName: 'Back & Biceps'),
        ]);
        break;
      case _PlanTemplate.empty:
        _dayDrafts.addAll([
          _DayDraft.createRestDay(DateTime.monday),
          _DayDraft.createRestDay(DateTime.tuesday),
          _DayDraft.createRestDay(DateTime.wednesday),
          _DayDraft.createRestDay(DateTime.thursday),
          _DayDraft.createRestDay(DateTime.friday),
          _DayDraft.createRestDay(DateTime.saturday),
          _DayDraft.createRestDay(DateTime.sunday),
        ]);
        break;
    }

    _rebalanceTrainingDayNames();

    final firstTrainingDay = _dayDrafts.indexWhere((day) => !day.isRestDay);
    _selectedDayIndex = firstTrainingDay == -1 ? 0 : firstTrainingDay;

    if (notify) {
      setState(() {});
    }
  }

  String _templatePlanName(_PlanTemplate template) {
    switch (template) {
      case _PlanTemplate.pushPullLegs:
        return 'Push Pull Legs';
      case _PlanTemplate.upperLower:
        return 'Upper Lower';
      case _PlanTemplate.fullBody:
        return 'Full Body';
      case _PlanTemplate.torsoLimbs:
        return 'Torso / Limbs';
      case _PlanTemplate.broSplit:
        return 'Bro Split';
      case _PlanTemplate.arnoldSplit:
        return 'Arnold Split';
      case _PlanTemplate.phul:
        return 'PHUL';
      case _PlanTemplate.strength5x5:
        return '5x5 Strength';
      case _PlanTemplate.bodybuilding4Day:
        return 'Bodybuilding 4 Tage';
      case _PlanTemplate.empty:
        return 'Neuer Plan';
    }
  }


  List<String> _templateTrainingSequence(_PlanTemplate template) {
    switch (template) {
      case _PlanTemplate.pushPullLegs:
        return const ['Push', 'Pull', 'Legs'];
      case _PlanTemplate.upperLower:
        return const ['Upper', 'Lower'];
      case _PlanTemplate.fullBody:
        return const ['Full Body'];
      case _PlanTemplate.torsoLimbs:
        return const ['Torso', 'Limbs'];
      case _PlanTemplate.broSplit:
        return const ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms'];
      case _PlanTemplate.arnoldSplit:
        return const ['Chest & Back', 'Shoulders & Arms', 'Legs'];
      case _PlanTemplate.phul:
        return const ['Upper Power', 'Lower Power', 'Upper Hypertrophy', 'Lower Hypertrophy'];
      case _PlanTemplate.strength5x5:
        return const ['Strength A', 'Strength B'];
      case _PlanTemplate.bodybuilding4Day:
        return const ['Chest & Triceps', 'Back & Biceps', 'Legs', 'Shoulders'];
      case _PlanTemplate.empty:
        return const ['Training'];
    }
  }

  void _setTrainingNameSequence(List<String> names) {
    final cleaned = _cleanTrainingNameSequence(names);
    _trainingSequenceController.text = _formatTrainingNameSequence(cleaned);
  }

  List<String> _trainingNameSequence() {
    return _cleanTrainingNameSequence(
      _trainingSequenceController.text
          .split(RegExp(r'[,;\n]'))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty),
    );
  }

  List<String> _cleanTrainingNameSequence(Iterable<String> names) {
    final cleaned = <String>[];

    for (final name in names) {
      final cleanName = _DayDraft._cleanTrainingName(name, DateTime.monday);

      if (cleanName.isEmpty || cleanName == 'Training') {
        continue;
      }

      cleaned.add(cleanName);
    }

    return cleaned.isEmpty ? const ['Training'] : cleaned;
  }

  String _formatTrainingNameSequence(List<String> names) {
    return names.join(', ');
  }

  List<String> _inferTrainingNameSequence(List<_DayDraft> dayDrafts) {
    final sequence = <String>[];

    for (final day in dayDrafts) {
      if (day.isRestDay) {
        continue;
      }

      final cleanName = _DayDraft._cleanTrainingName(day.name, day.weekday);
      if (!sequence.contains(cleanName)) {
        sequence.add(cleanName);
      }
    }

    return sequence.isEmpty ? const ['Training'] : sequence;
  }

  void _rebalanceTrainingDayNames() {
    final sequence = _trainingNameSequence();
    final exerciseBank = _exerciseSnapshotsByTrainingName();
    var trainingIndex = 0;

    for (final day in _dayDrafts) {
      if (day.isRestDay) {
        continue;
      }

      final oldName = _DayDraft._cleanTrainingName(day.name, day.weekday);
      final nextName = sequence[trainingIndex % sequence.length];
      day.setTrainingName(nextName);

      if (oldName != nextName) {
        final replacementExercises = exerciseBank[nextName];
        if (replacementExercises != null && replacementExercises.isNotEmpty) {
          day.replaceExercisesFromSnapshots(replacementExercises);
        }
      }

      day.ensureExerciseDraft();
      trainingIndex++;
    }
  }

  Map<String, List<_ExerciseDraftSnapshot>> _exerciseSnapshotsByTrainingName() {
    final bank = <String, List<_ExerciseDraftSnapshot>>{};

    for (final day in _dayDrafts) {
      final name = _DayDraft._cleanTrainingName(
        day.isRestDay ? day.lastTrainingName : day.name,
        day.weekday,
      );

      if (name == 'Training' || bank.containsKey(name)) {
        continue;
      }

      final source = day.restorableExerciseDrafts;
      final snapshots = source
          .where((draft) => draft.hasContent)
          .map(_ExerciseDraftSnapshot.fromDraft)
          .toList(growable: false);

      if (snapshots.isNotEmpty) {
        bank[name] = snapshots;
      }
    }

    return bank;
  }

  int _bestSelectedDayIndex(int preferredIndex) {
    if (_dayDrafts.isEmpty) {
      return 0;
    }

    if (preferredIndex >= 0 &&
        preferredIndex < _dayDrafts.length &&
        !_dayDrafts[preferredIndex].isRestDay) {
      return preferredIndex;
    }

    final firstTrainingDay = _dayDrafts.indexWhere((day) => !day.isRestDay);
    return firstTrainingDay == -1 ? 0 : firstTrainingDay;
  }

  void _updateTrainingSequenceFromDay(int dayIndex, String value) {
    if (dayIndex < 0 || dayIndex >= _dayDrafts.length) {
      return;
    }

    final day = _dayDrafts[dayIndex];
    if (day.isRestDay) {
      return;
    }

    final sequence = _trainingNameSequence();
    final trainingPosition = _trainingPositionOfDay(dayIndex);

    if (trainingPosition == -1) {
      return;
    }

    final sequenceIndex = trainingPosition % sequence.length;
    sequence[sequenceIndex] = _DayDraft._cleanTrainingName(value, day.weekday);
    _setTrainingNameSequence(sequence);
    _rebalanceTrainingDayNames();
  }

  int _trainingPositionOfDay(int dayIndex) {
    var trainingPosition = 0;

    for (var index = 0; index < _dayDrafts.length; index++) {
      final day = _dayDrafts[index];

      if (day.isRestDay) {
        continue;
      }

      if (index == dayIndex) {
        return trainingPosition;
      }

      trainingPosition++;
    }

    return -1;
  }

  List<_ExerciseDraft> _pushExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Schulterdrücken',
        muscleGroups: {'Schultern', 'Trizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Trizeps Pushdown',
        muscleGroups: {'Trizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _pullExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Klimmzüge',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 3,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 4,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bizeps Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _legsExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Kniebeugen',
        muscleGroups: {'Quads', 'Po'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Romanian Deadlift',
        muscleGroups: {'Hamstrings', 'Po'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Beinpresse',
        muscleGroups: {'Quads'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _upperExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 4,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Schulterdrücken',
        muscleGroups: {'Schultern', 'Trizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bizeps Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _lowerExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Kniebeugen',
        muscleGroups: {'Quads', 'Po'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Romanian Deadlift',
        muscleGroups: {'Hamstrings', 'Po'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Hip Thrust',
        muscleGroups: {'Po', 'Hamstrings'},
        sets: 3,
        reps: 10,
      ),
    ];
  }

  List<_ExerciseDraft> _fullBodyExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Kniebeugen',
        muscleGroups: {'Quads', 'Po'},
        sets: 3,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 3,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Plank',
        muscleGroups: {'Bauch/Core'},
        sets: 3,
        reps: 30,
      ),
    ];
  }

  List<_ExerciseDraft> _torsoExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 4,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Schulterdrücken',
        muscleGroups: {'Schultern', 'Trizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Lat Pulldown',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 3,
        reps: 10,
      ),
    ];
  }

  List<_ExerciseDraft> _limbsExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Kniebeugen',
        muscleGroups: {'Quads', 'Po'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Romanian Deadlift',
        muscleGroups: {'Hamstrings', 'Po'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bizeps Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Trizeps Pushdown',
        muscleGroups: {'Trizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _chestExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Schrägbankdrücken',
        muscleGroups: {'Brust', 'Schultern', 'Trizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Chest Fly',
        muscleGroups: {'Brust'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _backExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Klimmzüge',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 3,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 4,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Lat Pulldown',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 3,
        reps: 10,
      ),
    ];
  }

  List<_ExerciseDraft> _shouldersExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Schulterdrücken',
        muscleGroups: {'Schultern', 'Trizeps'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Seitheben',
        muscleGroups: {'Schultern'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Reverse Fly',
        muscleGroups: {'Schultern', 'Rücken'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _armsExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Bizeps Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Hammer Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Trizeps Pushdown',
        muscleGroups: {'Trizeps'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Overhead Trizeps Extension',
        muscleGroups: {'Trizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _chestBackExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Klimmzüge',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 3,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Schrägbankdrücken',
        muscleGroups: {'Brust', 'Schultern', 'Trizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 4,
        reps: 10,
      ),
    ];
  }

  List<_ExerciseDraft> _shouldersArmsExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Schulterdrücken',
        muscleGroups: {'Schultern', 'Trizeps'},
        sets: 4,
        reps: 8,
      ),
      _ExerciseDraft.createPreset(
        name: 'Seitheben',
        muscleGroups: {'Schultern'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bizeps Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Trizeps Pushdown',
        muscleGroups: {'Trizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }


  List<_ExerciseDraft> _upperPowerExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 5,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 5,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Schulterdrücken',
        muscleGroups: {'Schultern', 'Trizeps'},
        sets: 4,
        reps: 6,
      ),
    ];
  }

  List<_ExerciseDraft> _lowerPowerExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Kniebeugen',
        muscleGroups: {'Quads', 'Po'},
        sets: 5,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Kreuzheben',
        muscleGroups: {'Hamstrings', 'Po', 'Rücken'},
        sets: 3,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Beinpresse',
        muscleGroups: {'Quads'},
        sets: 4,
        reps: 8,
      ),
    ];
  }

  List<_ExerciseDraft> _upperHypertrophyExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Schrägbankdrücken',
        muscleGroups: {'Brust', 'Schultern', 'Trizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Lat Pulldown',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Seitheben',
        muscleGroups: {'Schultern'},
        sets: 3,
        reps: 12,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bizeps Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _lowerHypertrophyExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Romanian Deadlift',
        muscleGroups: {'Hamstrings', 'Po'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bulgarian Split Squats',
        muscleGroups: {'Quads', 'Po'},
        sets: 3,
        reps: 10,
      ),
      _ExerciseDraft.createPreset(
        name: 'Hip Thrust',
        muscleGroups: {'Po', 'Hamstrings'},
        sets: 3,
        reps: 10,
      ),
    ];
  }

  List<_ExerciseDraft> _strengthAExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Kniebeugen',
        muscleGroups: {'Quads', 'Po'},
        sets: 5,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Bankdrücken',
        muscleGroups: {'Brust', 'Trizeps'},
        sets: 5,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Rudern',
        muscleGroups: {'Rücken', 'Bizeps'},
        sets: 5,
        reps: 5,
      ),
    ];
  }

  List<_ExerciseDraft> _strengthBExercises() {
    return [
      _ExerciseDraft.createPreset(
        name: 'Kniebeugen',
        muscleGroups: {'Quads', 'Po'},
        sets: 5,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Schulterdrücken',
        muscleGroups: {'Schultern', 'Trizeps'},
        sets: 5,
        reps: 5,
      ),
      _ExerciseDraft.createPreset(
        name: 'Kreuzheben',
        muscleGroups: {'Hamstrings', 'Po', 'Rücken'},
        sets: 1,
        reps: 5,
      ),
    ];
  }

  List<_ExerciseDraft> _chestTricepsExercises() {
    return [
      ..._chestExercises(),
      _ExerciseDraft.createPreset(
        name: 'Trizeps Pushdown',
        muscleGroups: {'Trizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  List<_ExerciseDraft> _backBicepsExercises() {
    return [
      ..._backExercises(),
      _ExerciseDraft.createPreset(
        name: 'Bizeps Curls',
        muscleGroups: {'Bizeps'},
        sets: 3,
        reps: 12,
      ),
    ];
  }

  Future<void> _openMusclePicker(_ExerciseDraft draft) async {
    final selected = {...draft.muscleGroups};

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: const Color(0xFF09131B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Muskelgruppen',
                      style: TextStyle(
                        color: Color(0xFFEAF2F4),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final muscleGroup in _availableMuscleGroups)
                          FilterChip(
                            label: Text(muscleGroup),
                            selected: selected.contains(muscleGroup),
                            selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.22),
                            checkmarkColor: const Color(0xFF00E5FF),
                            onSelected: (value) {
                              setSheetState(() {
                                if (value) {
                                  selected.add(muscleGroup);
                                } else {
                                  selected.remove(muscleGroup);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(selected),
                        child: const Text('Übernehmen'),
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

    if (result == null) {
      return;
    }

    setState(() {
      draft.muscleGroups
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _savePlan() async {
    final planName = _planNameController.text.trim();

    if (planName.isEmpty) {
      _showError('Bitte gib dem Plan einen Namen.');
      return;
    }

    final restSeconds = _restSecondsFromInput();

    if (restSeconds == null) {
      _showError('Bitte gib eine gültige Satzpause in Minuten ein.');
      return;
    }

    final planId = widget.plan?.id ?? _createId('plan');
    final exerciseIds = <String>[];
    final days = <WorkoutPlanDay>[];

    for (final day in _dayDrafts) {
      if (day.isRestDay) {
        days.add(WorkoutPlanDay.restDay(weekday: day.weekday));
        continue;
      }

      final dayName = day.name.trim();

      if (dayName.isEmpty) {
        _showError('Bitte benenne ${WorkoutPlanDay.weekdayName(day.weekday)}.');
        return;
      }

      final validExerciseDrafts = day.exerciseDrafts
          .where((draft) => draft.name.trim().isNotEmpty)
          .toList();

      if (validExerciseDrafts.isEmpty) {
        _showError('Füge bei $dayName mindestens eine Übung hinzu oder setze den Tag auf Restday.');
        return;
      }

      final dayExerciseIds = <String>[];

      for (final draft in validExerciseDrafts) {
        final sets = draft.sets;
        final minReps = draft.minReps;
        final maxReps = draft.maxReps;
        final weight = draft.weight;

        if (sets == null || minReps == null || maxReps == null || weight == null) {
          _showError('Prüfe Sätze, Rep-Range und Gewicht bei "${draft.name.trim()}".');
          return;
        }

        if (minReps > maxReps) {
          _showError('Die minimale Wiederholungszahl darf bei "${draft.name.trim()}" nicht höher als die maximale sein.');
          return;
        }

        if (draft.muscleGroups.isEmpty) {
          _showError('Wähle mindestens eine Muskelgruppe bei "${draft.name.trim()}".');
          return;
        }

        final exercise = Exercise(
          id: draft.id,
          name: draft.name.trim(),
          muscleGroups: draft.muscleGroups.toList()..sort(),
          plannedSets: sets,
          plannedReps: maxReps,
          plannedWeight: weight,
          targetMinReps: minReps,
          targetMaxReps: maxReps,
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
          name: dayName,
          exerciseIds: dayExerciseIds,
        ),
      );
    }

    final hasTrainingDay = days.any((day) => !day.isRestDay && day.exerciseIds.isNotEmpty);

    if (!hasTrainingDay) {
      _showError('Der Plan braucht mindestens einen Trainingstag.');
      return;
    }

    await _deleteRemovedExercises(planId, exerciseIds.toSet());

    final plan = WorkoutPlan(
      id: planId,
      name: planName,
      exerciseIds: exerciseIds,
      restSeconds: restSeconds,
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

  Future<void> _deleteRemovedExercises(String planId, Set<String> keptExerciseIds) async {
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

  int? _restSecondsFromInput() {
    final text = _restMinutesController.text.trim().replaceAll(',', '.');
    final minutes = double.tryParse(text);

    if (minutes == null || minutes <= 0) {
      return null;
    }

    final seconds = (minutes * 60).round();
    return seconds < 1 ? null : seconds;
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

enum _PlanTemplate {
  pushPullLegs,
  upperLower,
  fullBody,
  torsoLimbs,
  broSplit,
  arnoldSplit,
  phul,
  strength5x5,
  bodybuilding4Day,
  empty,
}

class _DayDraft {
  _DayDraft({
    required this.weekday,
    required String name,
    required this.isRestDay,
    required List<_ExerciseDraft> exerciseDrafts,
    String? fallbackTrainingName,
  })  : nameController = TextEditingController(text: name),
        exerciseDrafts = [...exerciseDrafts],
        _lastTrainingName = _cleanTrainingName(fallbackTrainingName ?? name, weekday);

  factory _DayDraft.createTrainingDay(
    int weekday,
    String name, {
    List<_ExerciseDraft>? exercises,
  }) {
    final cleanName = _cleanTrainingName(name, weekday);

    return _DayDraft(
      weekday: weekday,
      name: cleanName,
      isRestDay: false,
      exerciseDrafts: exercises ?? [_ExerciseDraft.createEmpty()],
      fallbackTrainingName: cleanName,
    );
  }

  factory _DayDraft.createRestDay(
    int weekday, {
    String? fallbackTrainingName,
  }) {
    return _DayDraft(
      weekday: weekday,
      name: 'Restday',
      isRestDay: true,
      exerciseDrafts: const [],
      fallbackTrainingName: fallbackTrainingName,
    );
  }

  factory _DayDraft.fromPlanDay(WorkoutPlanDay day, Box<Exercise> exerciseBox) {
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
      fallbackTrainingName: day.name,
    );
  }

  final int weekday;
  final TextEditingController nameController;
  final List<_ExerciseDraft> exerciseDrafts;
  bool isRestDay;

  String _lastTrainingName;
  List<_ExerciseDraft>? _storedExerciseDrafts;

  String get name => nameController.text;

  String get lastTrainingName => _lastTrainingName;

  List<_ExerciseDraft> get restorableExerciseDrafts {
    if (isRestDay) {
      return _storedExerciseDrafts ?? const <_ExerciseDraft>[];
    }

    return exerciseDrafts;
  }

  void setTrainingName(String value) {
    final cleanName = _cleanTrainingName(value, weekday);
    nameController.text = cleanName;
    _lastTrainingName = cleanName;
  }

  void rememberTrainingName() {
    if (isRestDay) {
      return;
    }

    final cleanName = _cleanTrainingName(nameController.text, weekday);
    if (cleanName != 'Training') {
      _lastTrainingName = cleanName;
    }
  }

  void setRestDay(bool value) {
    if (isRestDay == value) {
      return;
    }

    if (value) {
      rememberTrainingName();
      _storedExerciseDrafts = [...exerciseDrafts];
      exerciseDrafts.clear();
      isRestDay = true;
      nameController.text = 'Restday';
      return;
    }

    isRestDay = false;
    nameController.text = _cleanTrainingName(_lastTrainingName, weekday);

    final stored = _storedExerciseDrafts;
    if (stored != null && stored.isNotEmpty) {
      exerciseDrafts.addAll(stored);
      _storedExerciseDrafts = null;
    }

    if (exerciseDrafts.isEmpty) {
      exerciseDrafts.add(_ExerciseDraft.createEmpty());
    }
  }

  void replaceExercisesFromSnapshots(List<_ExerciseDraftSnapshot> snapshots) {
    for (final draft in exerciseDrafts) {
      draft.dispose();
    }

    exerciseDrafts
      ..clear()
      ..addAll(snapshots.map((snapshot) => snapshot.toDraft()));

    _storedExerciseDrafts = null;
    ensureExerciseDraft();
  }

  void ensureExerciseDraft() {
    if (!isRestDay && exerciseDrafts.isEmpty) {
      exerciseDrafts.add(_ExerciseDraft.createEmpty());
    }
  }

  void addExercise() {
    exerciseDrafts.add(_ExerciseDraft.createEmpty());
  }

  void removeExercise(int index) {
    final removed = exerciseDrafts.removeAt(index);
    removed.dispose();
  }

  void dispose() {
    nameController.dispose();

    for (final draft in exerciseDrafts) {
      draft.dispose();
    }

    for (final draft in _storedExerciseDrafts ?? const <_ExerciseDraft>[]) {
      draft.dispose();
    }
  }

  static String _cleanTrainingName(String? value, int weekday) {
    final clean = value?.trim() ?? '';

    if (clean.isEmpty || clean.toLowerCase() == 'restday') {
      return 'Training';
    }

    final weekdayName = WorkoutPlanDay.weekdayName(weekday);
    if (clean == weekdayName) {
      return 'Training';
    }

    return clean;
  }
}

class _ExerciseDraft {
  _ExerciseDraft({
    required this.id,
    required String name,
    required Set<String> muscleGroups,
    required int plannedSets,
    required int targetMinReps,
    required int targetMaxReps,
    required double plannedWeight,
  })  : nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: plannedSets.toString()),
        minRepsController = TextEditingController(text: targetMinReps.toString()),
        maxRepsController = TextEditingController(text: targetMaxReps.toString()),
        weightController = TextEditingController(text: _formatWeightInput(plannedWeight)),
        muscleGroups = {...muscleGroups};

  factory _ExerciseDraft.createEmpty() {
    return _ExerciseDraft(
      id: 'exercise_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}',
      name: '',
      muscleGroups: {},
      plannedSets: 3,
      targetMinReps: 8,
      targetMaxReps: 12,
      plannedWeight: 0,
    );
  }

  factory _ExerciseDraft.createPreset({
    required String name,
    required Set<String> muscleGroups,
    required int sets,
    required int reps,
    int? minReps,
    int? maxReps,
    double weight = 0,
  }) {
    final targetMax = maxReps ?? reps;
    final targetMin = minReps ?? (targetMax <= 5 ? targetMax : targetMax - 2);

    return _ExerciseDraft(
      id: 'exercise_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}',
      name: name,
      muscleGroups: muscleGroups,
      plannedSets: sets,
      targetMinReps: targetMin < 1 ? 1 : targetMin,
      targetMaxReps: targetMax < 1 ? 1 : targetMax,
      plannedWeight: weight,
    );
  }

  factory _ExerciseDraft.fromExercise(Exercise exercise) {
    return _ExerciseDraft(
      id: exercise.id,
      name: exercise.name,
      muscleGroups: exercise.muscleGroups.toSet(),
      plannedSets: exercise.plannedSets,
      targetMinReps: exercise.targetMinReps,
      targetMaxReps: exercise.targetMaxReps,
      plannedWeight: exercise.plannedWeight,
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController minRepsController;
  final TextEditingController maxRepsController;
  final TextEditingController weightController;
  final Set<String> muscleGroups;

  String get name => nameController.text;

  bool get hasContent {
    return name.trim().isNotEmpty || muscleGroups.isNotEmpty;
  }

  int? get sets {
    final value = int.tryParse(setsController.text.trim());
    return value == null || value < 1 ? null : value;
  }

  int? get minReps {
    final value = int.tryParse(minRepsController.text.trim());
    return value == null || value < 1 ? null : value;
  }

  int? get maxReps {
    final value = int.tryParse(maxRepsController.text.trim());
    return value == null || value < 1 ? null : value;
  }

  String get repRangeSummary {
    final min = minReps;
    final max = maxReps;

    if (min == null || max == null) {
      return 'Rep-Range prüfen';
    }

    if (min == max) {
      return '$max Wdh.';
    }

    return '$min-$max Wdh.';
  }

  double? get weight {
    final text = weightController.text.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      return 0;
    }

    final value = double.tryParse(text);
    return value == null || value < 0 ? null : value;
  }

  String get muscleSummary {
    if (muscleGroups.isEmpty) {
      return 'Keine Muskelgruppe gewählt';
    }

    final sorted = muscleGroups.toList()..sort();
    return sorted.join(', ');
  }

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    minRepsController.dispose();
    maxRepsController.dispose();
    weightController.dispose();
  }

  static String _formatWeightInput(double weight) {
    if (weight == 0) {
      return '0';
    }

    final rounded = weight.roundToDouble();
    if (rounded == weight) {
      return rounded.toInt().toString();
    }

    return weight.toStringAsFixed(1);
  }
}

class _ExerciseDraftSnapshot {
  const _ExerciseDraftSnapshot({
    required this.name,
    required this.muscleGroups,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.weight,
  });

  factory _ExerciseDraftSnapshot.fromDraft(_ExerciseDraft draft) {
    return _ExerciseDraftSnapshot(
      name: draft.name.trim(),
      muscleGroups: {...draft.muscleGroups},
      sets: draft.sets ?? 3,
      minReps: draft.minReps ?? 8,
      maxReps: draft.maxReps ?? 12,
      weight: draft.weight ?? 0,
    );
  }

  final String name;
  final Set<String> muscleGroups;
  final int sets;
  final int minReps;
  final int maxReps;
  final double weight;

  _ExerciseDraft toDraft() {
    return _ExerciseDraft.createPreset(
      name: name,
      muscleGroups: {...muscleGroups},
      sets: sets,
      reps: maxReps,
      minReps: minReps,
      maxReps: maxReps,
      weight: weight,
    );
  }
}

class _StepTabs extends StatelessWidget {
  const _StepTabs({required this.currentStep, required this.onSelected});

  final int currentStep;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepTab(
            index: 0,
            label: 'Basis',
            selected: currentStep == 0,
            onTap: () => onSelected(0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StepTab(
            index: 1,
            label: 'Woche',
            selected: currentStep == 1,
            onTap: () => onSelected(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StepTab(
            index: 2,
            label: 'Übungen',
            selected: currentStep == 2,
            onTap: () => onSelected(2),
          ),
        ),
      ],
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
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
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.16)
                : const Color(0xFF08111A),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.42)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? const Color(0xFF00E5FF) : const Color(0xFF8A93A3),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFEAF2F4) : const Color(0xFF8A93A3),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.draft,
    required this.selected,
    required this.onSelect,
    required this.onToggleRestDay,
    required this.onNameChanged,
    required this.onChanged,
  });

  final _DayDraft draft;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<bool> onToggleRestDay;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF08111A),
        border: Border.all(
          color: selected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.38)
              : const Color(0xFF00E5FF).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.24)),
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
                TextField(
                  controller: draft.nameController,
                  enabled: !draft.isRestDay,
                  onChanged: onNameChanged,
                  style: const TextStyle(
                    color: Color(0xFFEAF2F4),
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Tagesname',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                Text(
                  draft.isRestDay
                      ? 'Restday'
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
          _RestDaySwitch(
            value: draft.isRestDay,
            onChanged: onToggleRestDay,
          ),
          IconButton(
            onPressed: draft.isRestDay ? null : onSelect,
            icon: const Icon(Icons.chevron_right_rounded),
            color: const Color(0xFFEAF2F4),
          ),
        ],
      ),
    );
  }
}

class _RestDaySwitch extends StatelessWidget {
  const _RestDaySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeColor = value ? const Color(0xFF00E5FF) : const Color(0xFF3DDC97);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF050A0F),
        border: Border.all(color: activeColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 18,
            color: value ? const Color(0xFF64748B) : const Color(0xFF3DDC97),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF00E5FF),
            inactiveThumbColor: const Color(0xFF3DDC97),
            activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.30),
            inactiveTrackColor: const Color(0xFF3DDC97).withValues(alpha: 0.24),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
          Icon(
            Icons.bed_rounded,
            size: 18,
            color: value ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_DayDraft> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < days.length; index++) ...[
          Expanded(
            child: _DaySelectorButton(
              day: days[index],
              selected: index == selectedIndex,
              onTap: () => onSelected(index),
            ),
          ),
          if (index != days.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _DaySelectorButton extends StatelessWidget {
  const _DaySelectorButton({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _DayDraft day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? const Color(0xFF00E5FF) : const Color(0xFF8A93A3);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.13)
                : const Color(0xFF08111A),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.38)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                day.isRestDay ? Icons.hotel_rounded : Icons.fitness_center_rounded,
                size: 15,
                color: accent,
              ),
              const SizedBox(height: 3),
              Text(
                WorkoutPlanDay.shortWeekdayName(day.weekday),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? const Color(0xFFEAF2F4) : const Color(0xFF8A93A3),
                  fontSize: 11,
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

class _ExerciseDraftCard extends StatelessWidget {
  const _ExerciseDraftCard({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
    required this.onPickMuscles,
  });

  final int index;
  final _ExerciseDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final VoidCallback onPickMuscles;

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
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
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
              Expanded(
                child: _NeonTextField(
                  controller: draft.nameController,
                  label: 'Übung',
                  hintText: 'z. B. Bankdrücken',
                  icon: Icons.fitness_center_rounded,
                  onChanged: (_) {
                    onChanged();
                  },
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF8A93A3),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTextField(
                  controller: draft.setsController,
                  label: 'Sätze',
                  hintText: '3',
                  onChanged: (_) {
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTextField(
                  controller: draft.minRepsController,
                  label: 'Min Wdh.',
                  hintText: '8',
                  onChanged: (_) {
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTextField(
                  controller: draft.maxRepsController,
                  label: 'Max Wdh.',
                  hintText: '12',
                  onChanged: (_) {
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTextField(
                  controller: draft.weightController,
                  label: 'Gewicht kg',
                  hintText: '0',
                  decimal: true,
                  onChanged: (_) {
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReadOnlyMetricBox(
                  label: 'Ziel',
                  value: draft.repRangeSummary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onPickMuscles,
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF08111A),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.layers_rounded,
                      color: Color(0xFF7DD3FC),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        draft.muscleSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFEAF2F4),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF8A93A3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _ReadOnlyMetricBox extends StatelessWidget {
  const _ReadOnlyMetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF08111A),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A93A3),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorBottomBar extends StatelessWidget {
  const _EditorBottomBar({
    required this.step,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF050A0F),
        border: Border(
          top: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SmallActionButton(
              label: 'Zurück',
              icon: Icons.arrow_back_rounded,
              filled: false,
              onTap: onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SmallActionButton(
              label: step == 2 ? 'Speichern' : 'Weiter',
              icon: step == 2 ? Icons.save_rounded : Icons.arrow_forward_rounded,
              filled: true,
              onTap: onNext,
            ),
          ),
        ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

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
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF8A93A3),
            fontSize: 13,
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
    required this.label,
    required this.hintText,
    required this.icon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        color: Color(0xFFEAF2F4),
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF7DD3FC)),
        labelStyle: const TextStyle(color: Color(0xFF8A93A3)),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFF050A0F),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF00E5FF)),
        ),
      ),
    );
  }
}

class _MetricTextField extends StatelessWidget {
  const _MetricTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.decimal = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool decimal;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: const TextStyle(
        color: Color(0xFFEAF2F4),
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: Color(0xFF8A93A3), fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFF050A0F),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF00E5FF)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF050A0F),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
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
                SizedBox(height: 3),
                Text(
                  'HomeScreen und Start-Button nutzen diesen Plan.',
                  style: TextStyle(
                    color: Color(0xFF8A93A3),
                    fontSize: 12,
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

const List<_TemplateMenuEntry> _planTemplateEntries = [
  _TemplateMenuEntry(
    template: _PlanTemplate.pushPullLegs,
    label: 'Push Pull Legs',
    description: '6 Tage möglich · Push, Pull, Legs',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.upperLower,
    label: 'Upper Lower',
    description: '4 Tage · Oberkörper und Unterkörper',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.fullBody,
    label: 'Full Body',
    description: '3 Tage · Ganzkörper',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.torsoLimbs,
    label: 'Torso / Limbs',
    description: '4 Tage · Torso und Arme/Beine',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.broSplit,
    label: 'Bro Split',
    description: '5 Tage · einzelne Muskelgruppen',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.arnoldSplit,
    label: 'Arnold Split',
    description: '6 Tage möglich · klassischer Split',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.phul,
    label: 'PHUL',
    description: 'Power + Hypertrophy',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.strength5x5,
    label: '5x5 Strength',
    description: 'Kraftfokus · A/B Tage',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.bodybuilding4Day,
    label: 'Bodybuilding 4 Tage',
    description: 'Brust, Rücken, Beine, Schultern',
  ),
  _TemplateMenuEntry(
    template: _PlanTemplate.empty,
    label: 'Leer starten',
    description: 'Alles selbst festlegen',
  ),
];

class _TemplateSelectionSheet extends StatelessWidget {
  const _TemplateSelectionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: const Color(0xFF09131B),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(icon: Icons.auto_awesome_rounded),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Template wählen',
                        style: TextStyle(
                          color: Color(0xFFEAF2F4),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Damit startest du direkt mit einer passenden Wochenstruktur.',
                        style: TextStyle(
                          color: Color(0xFF8A93A3),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF8A93A3),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.68,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _planTemplateEntries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final entry = _planTemplateEntries[index];
                  return _TemplateSelectionTile(entry: entry);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateSelectionTile extends StatelessWidget {
  const _TemplateSelectionTile({required this.entry});

  final _TemplateMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).pop(entry.template),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF050A0F),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.13),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.09),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Color(0xFF7DD3FC),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: const TextStyle(
                        color: Color(0xFFEAF2F4),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.description,
                      style: const TextStyle(
                        color: Color(0xFF8A93A3),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatePickerButton extends StatelessWidget {
  const _TemplatePickerButton({required this.onSelected});

  final ValueChanged<_PlanTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF00E5FF),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Template',
                style: TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Optional auswählen',
                style: TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<_PlanTemplate>(
          tooltip: 'Template auswählen',
          color: const Color(0xFF09131B),
          onSelected: onSelected,
          itemBuilder: (context) {
            return [
              for (final entry in _planTemplateEntries)
                PopupMenuItem<_PlanTemplate>(
                  value: entry.template,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: const TextStyle(
                          color: Color(0xFFEAF2F4),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.description,
                        style: const TextStyle(
                          color: Color(0xFF8A93A3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ];
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFF050A0F),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Auswählen',
                  style: TextStyle(
                    color: Color(0xFF7DD3FC),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF7DD3FC),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateMenuEntry {
  const _TemplateMenuEntry({
    required this.template,
    required this.label,
    required this.description,
  });

  final _PlanTemplate template;
  final String label;
  final String description;
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
      backgroundColor: const Color(0xFF050A0F),
      side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.18)),
      onPressed: onTap,
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Color(0xFF7DD3FC)),
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

class _GlowIconButton extends StatelessWidget {
  const _GlowIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: const Color(0xFF7DD3FC)),
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
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Neu'),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: filled
                ? const Color(0xFF00E5FF)
                : const Color(0xFF00E5FF).withValues(alpha: 0.08),
            border: Border.all(
              color: filled
                  ? Colors.transparent
                  : const Color(0xFF00E5FF).withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled ? Colors.black : const Color(0xFF7DD3FC),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.black : const Color(0xFFEAF2F4),
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: const Color(0xFF00E5FF)),
    );
  }
}

class _DayMiniChip extends StatelessWidget {
  const _DayMiniChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.16)
            : const Color(0xFF050A0F),
        border: Border.all(
          color: active
              ? const Color(0xFF00E5FF).withValues(alpha: 0.34)
              : const Color(0xFF00E5FF).withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF7DD3FC) : const Color(0xFF64748B),
          fontWeight: FontWeight.w900,
          fontSize: 12,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF7DD3FC),
              size: 54,
            ),
            const SizedBox(height: 16),
            const Text(
              'Noch kein Plan',
              style: TextStyle(
                color: Color(0xFFEAF2F4),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Erstelle deinen ersten Wochenplan mit wenigen Schritten.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A93A3),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(30),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D1B28), Color(0xFF071018), Color(0xFF050A0F)],
    ),
    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.18)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
        blurRadius: 28,
        spreadRadius: 1,
      ),
    ],
  );
}
