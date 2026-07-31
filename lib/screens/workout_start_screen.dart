import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../models/workout_set.dart';
import '../services/rest_sound_player.dart';

class WorkoutStartScreen extends StatefulWidget {
  const WorkoutStartScreen({
    super.key,
    required this.plan,
    required this.day,
    required this.exercises,
  });

  final WorkoutPlan plan;
  final WorkoutPlanDay day;
  final List<Exercise> exercises;

  static const String activeWorkoutDateKey = 'active_workout_date';
  static const String activeWorkoutPlanIdKey = 'active_workout_plan_id';
  static const String activeWorkoutExerciseIndexKey = 'active_workout_exercise_index';
  static const String activeWorkoutCurrentSetKey = 'active_workout_current_set';
  static const String activeWorkoutPhaseKey = 'active_workout_phase';
  static const String activeWorkoutRestEndMillisKey = 'active_workout_rest_end_millis';
  static const String activeWorkoutLoggedRepsKey = 'active_workout_logged_reps';
  static const String activeWorkoutLoggedWeightsKey = 'active_workout_logged_weights';
  static const String activeWorkoutNextWeightsKey = 'active_workout_next_weights';
  static const String completedWorkoutDateKey = 'completed_workout_date';
  static const String completedWorkoutMuscleGroupsKey = 'completed_workout_muscle_groups';
  static const String completedWorkoutDayNameKey = 'completed_workout_day_name';

  static String dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static bool hasCompletedWorkoutToday(Box<dynamic> settingsBox) {
    return settingsBox.get(completedWorkoutDateKey) == dateKey(DateTime.now());
  }

  static bool hasActiveWorkoutToday(Box<dynamic> settingsBox) {
    return settingsBox.get(activeWorkoutDateKey) == dateKey(DateTime.now());
  }

  static Future<void> clearActiveWorkout(Box<dynamic> settingsBox) async {
    await settingsBox.delete(activeWorkoutDateKey);
    await settingsBox.delete(activeWorkoutPlanIdKey);
    await settingsBox.delete(activeWorkoutExerciseIndexKey);
    await settingsBox.delete(activeWorkoutCurrentSetKey);
    await settingsBox.delete(activeWorkoutPhaseKey);
    await settingsBox.delete(activeWorkoutRestEndMillisKey);
    await settingsBox.delete(activeWorkoutLoggedRepsKey);
    await settingsBox.delete(activeWorkoutLoggedWeightsKey);
    await settingsBox.delete(activeWorkoutNextWeightsKey);
  }

  @override
  State<WorkoutStartScreen> createState() => _WorkoutStartScreenState();
}

class _WorkoutStartScreenState extends State<WorkoutStartScreen> {
  static const String _phaseSet = 'set';
  static const String _phaseRest = 'rest';

  late final Box<dynamic> _settingsBox;
  late final String _todayKey;

  Timer? _restTimer;
  int _exerciseIndex = 0;
  int _currentSet = 1;
  int _remainingRestSeconds = 0;
  int? _restEndMillis;
  bool _isResting = false;
  bool _isFinished = false;
  final Map<String, int> _loggedReps = {};
  final Map<String, double> _loggedWeights = {};
  final Map<String, double> _nextWeights = {};

  Exercise get _currentExercise => widget.exercises[_safeExerciseIndex];

  int get _safeExerciseIndex {
    if (widget.exercises.isEmpty) {
      return 0;
    }

    if (_exerciseIndex < 0) {
      return 0;
    }

    if (_exerciseIndex >= widget.exercises.length) {
      return widget.exercises.length - 1;
    }

    return _exerciseIndex;
  }

  int get _safeRestSeconds => widget.plan.restSeconds < 1 ? 1 : widget.plan.restSeconds;

  int get _currentExerciseSetCount => _setCountFor(_currentExercise);

  bool get _isLastExercise => _safeExerciseIndex == widget.exercises.length - 1;

  bool get _isLastSetOfExercise => _currentSet >= _currentExerciseSetCount;

  bool get _isLastSetOfWorkout => _isLastExercise && _isLastSetOfExercise;

  int? get _lastLoggedReps => _loggedReps[_setKey(_currentExercise, _currentSet)];

  int get _totalSets {
    return widget.exercises.fold<int>(
      0,
      (total, exercise) => total + _setCountFor(exercise),
    );
  }

  int get _completedSets {
    if (_isFinished) {
      return _totalSets;
    }

    var completed = 0;

    for (var index = 0; index < _safeExerciseIndex; index++) {
      completed += _setCountFor(widget.exercises[index]);
    }

    completed += _isResting ? _currentSet : _currentSet - 1;
    return completed.clamp(0, _totalSets).toInt();
  }

  double get _progress {
    if (_totalSets == 0) {
      return 0;
    }

    return _completedSets / _totalSets;
  }

  List<_ProgressionSuggestion> get _progressionSuggestions {
    final suggestions = <_ProgressionSuggestion>[];

    for (final exercise in widget.exercises) {
      final reps = _loggedRepsFor(exercise);
      if (exercise.shouldIncreaseWeight(reps)) {
        suggestions.add(
          _ProgressionSuggestion(
            exercise: exercise,
            nextWeight: _nextWeights[exercise.id],
          ),
        );
      }
    }

    return suggestions;
  }

  @override
  void initState() {
    super.initState();

    _settingsBox = Hive.box('settings');
    _todayKey = WorkoutStartScreen.dateKey(DateTime.now());

    if (widget.exercises.isEmpty) {
      _isFinished = true;
      return;
    }

    final restored = _restoreWorkoutState();

    if (!restored) {
      _persistSetState();
    }

    if (_isResting) {
      _syncRestFromClock(useSetState: false);
      _startRestTimer();
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
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
          _isFinished ? 'Fertig' : widget.day.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isFinished ? _buildFinishedView() : _buildWorkoutView(),
      ),
    );
  }

  Widget _buildWorkoutView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        children: [
          _ProgressBar(progress: _progress),
          const SizedBox(height: 26),
          Expanded(
            child: Center(
              child: _isResting ? _buildRestContent() : _buildExerciseContent(),
            ),
          ),
          const SizedBox(height: 20),
          _BottomActionButton(
            label: _isResting ? 'Pause überspringen' : _setButtonLabel,
            icon: _isResting ? Icons.skip_next_rounded : Icons.check_rounded,
            onTap: _isResting ? _skipRest : _completeSet,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseContent() {
    final exercise = _currentExercise;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_safeExerciseIndex + 1}/${widget.exercises.length}',
          style: const TextStyle(
            color: Color(0xFF7DD3FC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          exercise.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFEAF2F4),
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _MinimalMetric(
                label: 'Satz',
                value: '$_currentSet/$_currentExerciseSetCount',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MinimalMetric(
                label: 'Ziel Wdh.',
                value: exercise.repRangeLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MinimalMetric(
                label: 'Gewicht',
                value: exercise.plannedWeightLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Nach dem Satz frag ich dich nach den geschafften Wiederholungen.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8A93A3),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildRestContent() {
    final lastLoggedReps = _lastLoggedReps;
    final showProgressionHint = _isLastSetOfExercise && _shouldIncreaseWeight(_currentExercise);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Pause',
          style: TextStyle(
            color: Color(0xFF7DD3FC),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _formatSeconds(_remainingRestSeconds),
          style: const TextStyle(
            color: Color(0xFFEAF2F4),
            fontSize: 72,
            fontWeight: FontWeight.w900,
            letterSpacing: -3,
          ),
        ),
        if (lastLoggedReps != null) ...[
          const SizedBox(height: 10),
          _RepsBadge(label: 'Letzter Satz: $lastLoggedReps Wdh.'),
        ],
        if (showProgressionHint) ...[
          const SizedBox(height: 12),
          _ProgressionHint(text: _increaseMessage(_currentExercise)),
        ],
        const SizedBox(height: 16),
        Text(
          'Danach: ${_nextStepLabel()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8A93A3),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedView() {
    final suggestions = _progressionSuggestions;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3DDC97).withValues(alpha: 0.16),
                  border: Border.all(
                    color: const Color(0xFF3DDC97).withValues(alpha: 0.42),
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF3DDC97),
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Workout abgeschlossen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_totalSets Sätze erledigt',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 22),
                _ProgressionSummary(suggestions: suggestions),
              ],
              const SizedBox(height: 28),
              _BottomActionButton(
                label: 'Zurück',
                icon: Icons.home_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _setButtonLabel {
    if (_isLastSetOfWorkout) {
      return 'Workout beenden';
    }

    return 'Satz erledigt';
  }

  bool _restoreWorkoutState() {
    final activeDate = _settingsBox.get(WorkoutStartScreen.activeWorkoutDateKey);
    final activePlanId = _settingsBox.get(WorkoutStartScreen.activeWorkoutPlanIdKey);

    if (activeDate != _todayKey || activePlanId != widget.plan.id) {
      return false;
    }

    final restoredExerciseIndex = _readInt(
      WorkoutStartScreen.activeWorkoutExerciseIndexKey,
      fallback: 0,
    );
    final restoredCurrentSet = _readInt(
      WorkoutStartScreen.activeWorkoutCurrentSetKey,
      fallback: 1,
    );
    final restoredPhase = _settingsBox.get(WorkoutStartScreen.activeWorkoutPhaseKey);
    final restoredRestEndMillis = _readInt(
      WorkoutStartScreen.activeWorkoutRestEndMillisKey,
      fallback: 0,
    );

    _exerciseIndex = restoredExerciseIndex.clamp(0, widget.exercises.length - 1).toInt();
    _currentSet = restoredCurrentSet.clamp(1, _setCountFor(_currentExercise)).toInt();
    _isResting = restoredPhase == _phaseRest;
    _restEndMillis = restoredRestEndMillis <= 0 ? null : restoredRestEndMillis;
    _restoreLoggedReps();
    _restoreLoggedWeights();
    _restoreNextWeights();

    return true;
  }

  int _readInt(String key, {required int fallback}) {
    final value = _settingsBox.get(key);

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return fallback;
  }

  Future<void> _persistSetState() async {
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutDateKey, _todayKey);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutPlanIdKey, widget.plan.id);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutExerciseIndexKey, _safeExerciseIndex);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutCurrentSetKey, _currentSet);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutPhaseKey, _phaseSet);
    await _settingsBox.delete(WorkoutStartScreen.activeWorkoutRestEndMillisKey);
    await _persistLoggedReps();
    await _persistLoggedWeights();
    await _persistNextWeights();
  }

  Future<void> _persistRestState() async {
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutDateKey, _todayKey);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutPlanIdKey, widget.plan.id);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutExerciseIndexKey, _safeExerciseIndex);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutCurrentSetKey, _currentSet);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutPhaseKey, _phaseRest);
    await _settingsBox.put(
      WorkoutStartScreen.activeWorkoutRestEndMillisKey,
      _restEndMillis ?? DateTime.now().millisecondsSinceEpoch,
    );
    await _persistLoggedReps();
    await _persistLoggedWeights();
    await _persistNextWeights();
  }

  Future<void> _persistLoggedReps() async {
    final entries = _loggedReps.entries.map((entry) => '${entry.key}|${entry.value}').toList();
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutLoggedRepsKey, entries);
  }

  Future<void> _persistLoggedWeights() async {
    final entries = _loggedWeights.entries
        .map((entry) => '${entry.key}|${entry.value}')
        .toList();
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutLoggedWeightsKey, entries);
  }

  Future<void> _persistNextWeights() async {
    final entries = _nextWeights.entries
        .map((entry) => '${entry.key}|${entry.value}')
        .toList();
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutNextWeightsKey, entries);
  }

  void _restoreLoggedReps() {
    final rawEntries = _settingsBox.get(WorkoutStartScreen.activeWorkoutLoggedRepsKey);
    _loggedReps.clear();

    if (rawEntries is! List) {
      return;
    }

    for (final rawEntry in rawEntries) {
      final entry = rawEntry.toString();
      final splitIndex = entry.lastIndexOf('|');

      if (splitIndex <= 0 || splitIndex >= entry.length - 1) {
        continue;
      }

      final key = entry.substring(0, splitIndex);
      final reps = int.tryParse(entry.substring(splitIndex + 1));

      if (reps != null && reps >= 0) {
        _loggedReps[key] = reps;
      }
    }
  }

  void _restoreLoggedWeights() {
    _restoreDoubleMap(
      key: WorkoutStartScreen.activeWorkoutLoggedWeightsKey,
      target: _loggedWeights,
    );
  }

  void _restoreNextWeights() {
    _restoreDoubleMap(
      key: WorkoutStartScreen.activeWorkoutNextWeightsKey,
      target: _nextWeights,
    );
  }

  void _restoreDoubleMap({required String key, required Map<String, double> target}) {
    final rawEntries = _settingsBox.get(key);
    target.clear();

    if (rawEntries is! List) {
      return;
    }

    for (final rawEntry in rawEntries) {
      final entry = rawEntry.toString();
      final splitIndex = entry.lastIndexOf('|');

      if (splitIndex <= 0 || splitIndex >= entry.length - 1) {
        continue;
      }

      final mapKey = entry.substring(0, splitIndex);
      final value = double.tryParse(entry.substring(splitIndex + 1));

      if (value != null && value >= 0) {
        target[mapKey] = value;
      }
    }
  }

  Future<void> _completeSet() async {
    if (_isResting || _isFinished) {
      return;
    }

    final completedReps = await _askCompletedReps();

    if (!mounted || completedReps == null) {
      return;
    }

    final completedExercise = _currentExercise;
    final completedSet = _currentSet;

    setState(() {
      final setKey = _setKey(completedExercise, completedSet);
      _loggedReps[setKey] = completedReps;
      _loggedWeights[setKey] = completedExercise.plannedWeight;
    });

    await _persistLoggedReps();
    await _persistLoggedWeights();

    if (_shouldAskNextWeightNow(completedExercise, completedSet)) {
      await _askAndSaveNextWeight(completedExercise);
    }

    if (_isLastSetOfWorkout) {
      await _finishWorkout();
      return;
    }

    _startRest();
  }

  Future<int?> _askCompletedReps() async {
    final controller = TextEditingController(text: _currentExercise.targetMaxReps.toString());

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF09131B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wie viele Wiederholungen geschafft?',
                style: TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_currentExercise.name} · Satz $_currentSet · Ziel ${_currentExercise.repRangeLabel}',
                style: const TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  labelText: 'Wiederholungen',
                  labelStyle: const TextStyle(color: Color(0xFF8A93A3)),
                  filled: true,
                  fillColor: const Color(0xFF050A0F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1F3345)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1F3345)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.4),
                  ),
                ),
                onSubmitted: (_) => _submitCompletedReps(context, controller),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => _submitCompletedReps(context, controller),
                  child: const Text('Pause starten'),
                ),
              ),
            ],
          ),
        );
      },
    );

    // Do not dispose this local controller here. On Flutter Web, the bottom
    // sheet can still rebuild for a frame while closing, and disposing the
    // controller immediately can trigger: "TextEditingController was used after
    // being disposed." The controller is short-lived and will be collected
    // after the sheet is closed.
    return result;
  }

  void _submitCompletedReps(BuildContext context, TextEditingController controller) {
    final reps = int.tryParse(controller.text.trim());

    if (reps == null || reps < 0) {
      return;
    }

    Navigator.of(context).pop(reps);
  }

  Future<void> _askAndSaveNextWeight(Exercise exercise) async {
    final nextWeight = await _askNextWeight(exercise);

    if (!mounted || nextWeight == null) {
      return;
    }

    final exerciseBox = Hive.box<Exercise>('exercises');
    final updatedExercise = exercise.copyWith(plannedWeight: nextWeight);

    await exerciseBox.put(exercise.id, updatedExercise);

    setState(() {
      _nextWeights[exercise.id] = nextWeight;
    });

    await _persistNextWeights();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Gespeichert: ${exercise.name} nächstes Mal mit ${_formatWeight(nextWeight)}.',
        ),
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<double?> _askNextWeight(Exercise exercise) async {
    final suggestedWeight = exercise.plannedWeight > 0 ? exercise.plannedWeight + 2.5 : 0.0;
    final controller = TextEditingController(text: _formatWeightInput(suggestedWeight));

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF09131B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gewicht fürs nächste Mal',
                style: TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${exercise.name}: Alle Sätze im oberen Zielbereich geschafft.',
                style: const TextStyle(
                  color: Color(0xFF8A93A3),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  labelText: 'Nächstes Gewicht in kg',
                  helperText: '0 = Bodyweight',
                  helperStyle: const TextStyle(color: Color(0xFF64748B)),
                  labelStyle: const TextStyle(color: Color(0xFF8A93A3)),
                  filled: true,
                  fillColor: const Color(0xFF050A0F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1F3345)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF1F3345)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.4),
                  ),
                ),
                onSubmitted: (_) => _submitNextWeight(context, controller),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8A93A3),
                          side: const BorderSide(color: Color(0xFF1F3345)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Überspringen'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: () => _submitNextWeight(context, controller),
                        child: const Text('Speichern'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  void _submitNextWeight(BuildContext context, TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    final weight = double.tryParse(text);

    if (weight == null || weight < 0) {
      return;
    }

    Navigator.of(context).pop(weight);
  }

  void _startRest() {
    _restTimer?.cancel();

    final restEndMillis = DateTime.now().millisecondsSinceEpoch + (_safeRestSeconds * 1000);

    setState(() {
      _isResting = true;
      _restEndMillis = restEndMillis;
      _remainingRestSeconds = _safeRestSeconds;
    });

    _persistRestState();
    _startRestTimer();
  }

  void _startRestTimer() {
    _restTimer?.cancel();

    if (!_isResting) {
      return;
    }

    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncRestFromClock();
    });
  }

  void _syncRestFromClock({bool useSetState = true}) {
    final restEndMillis = _restEndMillis;

    if (!_isResting || restEndMillis == null) {
      return;
    }

    final millisLeft = restEndMillis - DateTime.now().millisecondsSinceEpoch;
    final secondsLeft = millisLeft <= 0 ? 0 : ((millisLeft + 999) ~/ 1000);

    if (secondsLeft <= 0) {
      RestSoundPlayer.playIfEnabled(_settingsBox);
      _advanceAfterRest(useSetState: useSetState);
      return;
    }

    if (useSetState && mounted) {
      setState(() {
        _remainingRestSeconds = secondsLeft;
      });
    } else {
      _remainingRestSeconds = secondsLeft;
    }
  }

  void _skipRest() {
    _restTimer?.cancel();
    _advanceAfterRest();
  }

  void _advanceAfterRest({bool useSetState = true}) {
    var shouldFinishWorkout = false;

    void advance() {
      _isResting = false;
      _remainingRestSeconds = 0;
      _restEndMillis = null;

      if (_currentSet < _currentExerciseSetCount) {
        _currentSet++;
      } else if (_safeExerciseIndex < widget.exercises.length - 1) {
        _exerciseIndex = _safeExerciseIndex + 1;
        _currentSet = 1;
      } else {
        shouldFinishWorkout = true;
      }
    }

    if (useSetState && mounted) {
      setState(advance);
    } else {
      advance();
    }

    if (shouldFinishWorkout) {
      _finishWorkout();
      return;
    }

    _persistSetState();
  }

  Future<void> _finishWorkout() async {
    _restTimer?.cancel();

    if (mounted) {
      setState(() {
        _isResting = false;
        _isFinished = true;
        _remainingRestSeconds = 0;
        _restEndMillis = null;
      });
    } else {
      _isResting = false;
      _isFinished = true;
      _remainingRestSeconds = 0;
      _restEndMillis = null;
    }

    await _saveWorkoutSession();
    await _settingsBox.put(WorkoutStartScreen.completedWorkoutDateKey, _todayKey);
    await _settingsBox.put(
      WorkoutStartScreen.completedWorkoutDayNameKey,
      _completedDayDisplayName(),
    );
    await _settingsBox.put(
      WorkoutStartScreen.completedWorkoutMuscleGroupsKey,
      _completedMuscleGroups().toList()..sort(),
    );
    await WorkoutStartScreen.clearActiveWorkout(_settingsBox);
  }

  Future<void> _saveWorkoutSession() async {
    final sessionBox = Hive.box<WorkoutSession>('workout_sessions');
    final exerciseSets = <String, List<WorkoutSet>>{};
    final exerciseNames = <String, String>{};

    for (final exercise in widget.exercises) {
      final sets = <WorkoutSet>[];

      for (var setNumber = 1; setNumber <= _setCountFor(exercise); setNumber++) {
        final reps = _loggedReps[_setKey(exercise, setNumber)];

        if (reps == null) {
          continue;
        }

        sets.add(
          WorkoutSet(
            weight: _loggedWeights[_setKey(exercise, setNumber)] ?? exercise.plannedWeight,
            reps: reps,
          ),
        );
      }

      if (sets.isEmpty) {
        continue;
      }

      exerciseSets[exercise.id] = sets;
      exerciseNames[exercise.id] = exercise.name;
    }

    if (exerciseSets.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final session = WorkoutSession(
      id: '${_todayKey}_${widget.plan.id}_${now.millisecondsSinceEpoch}',
      workoutPlanId: widget.plan.id,
      workoutPlanName: widget.plan.name,
      dayName: _completedDayDisplayName(),
      date: now,
      exerciseSets: exerciseSets,
      exerciseNames: exerciseNames,
    );

    await sessionBox.put(session.id, session);
  }

  String _completedDayDisplayName() {
    final cleanName = widget.day.name.trim();

    if (cleanName.isNotEmpty && cleanName.toLowerCase() != 'restday') {
      return cleanName;
    }

    return WorkoutPlanDay.weekdayName(widget.day.weekday);
  }

  String _nextStepLabel() {
    if (_currentSet < _currentExerciseSetCount) {
      return '${_currentExercise.name}, Satz ${_currentSet + 1}';
    }

    if (_safeExerciseIndex < widget.exercises.length - 1) {
      return widget.exercises[_safeExerciseIndex + 1].name;
    }

    return 'Workout abschliessen';
  }

  Set<String> _completedMuscleGroups() {
    final muscleGroups = <String>{};

    for (final exercise in widget.exercises) {
      for (final muscleGroup in exercise.muscleGroups) {
        final cleanedMuscleGroup = muscleGroup.trim();

        if (cleanedMuscleGroup.isNotEmpty) {
          muscleGroups.add(cleanedMuscleGroup);
        }
      }
    }

    return muscleGroups;
  }

  int _setCountFor(Exercise exercise) {
    return exercise.plannedSets < 1 ? 1 : exercise.plannedSets;
  }

  String _setKey(Exercise exercise, int setNumber) {
    return '${exercise.id}::$setNumber';
  }

  List<int> _loggedRepsFor(Exercise exercise) {
    final reps = <int>[];

    for (var setNumber = 1; setNumber <= _setCountFor(exercise); setNumber++) {
      final value = _loggedReps[_setKey(exercise, setNumber)];
      if (value != null) {
        reps.add(value);
      }
    }

    return reps;
  }

  bool _shouldIncreaseWeight(Exercise exercise) {
    return exercise.shouldIncreaseWeight(_loggedRepsFor(exercise));
  }

  bool _shouldAskNextWeightNow(Exercise exercise, int completedSet) {
    if (_nextWeights.containsKey(exercise.id)) {
      return false;
    }

    final completedReps = _loggedRepsFor(exercise);

    if (completedSet == 2 && exercise.shouldIncreaseWeightEarly(completedReps)) {
      return true;
    }

    if (completedSet >= _setCountFor(exercise) &&
        exercise.shouldIncreaseWeightAfterAllSets(completedReps)) {
      return true;
    }

    return false;
  }

  String _increaseMessage(Exercise exercise) {
    final nextWeight = _nextWeights[exercise.id];

    if (nextWeight != null) {
      return 'Gespeichert fürs nächste Mal: ${_formatWeight(nextWeight)}.';
    }

    if (exercise.plannedWeight <= 0) {
      return 'Oberen Zielbereich früh erreicht. Nächstes Mal schwerere Variante wählen.';
    }

    return 'Oberen Zielbereich früh erreicht. Nächstes Mal Gewicht erhöhen.';
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1).toDouble(),
        minHeight: 8,
        backgroundColor: const Color(0xFF111827),
        valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
      ),
    );
  }
}

class _MinimalMetric extends StatelessWidget {
  const _MinimalMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF08111A),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8A93A3),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepsBadge extends StatelessWidget {
  const _RepsBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7DD3FC),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressionHint extends StatelessWidget {
  const _ProgressionHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF3DDC97).withValues(alpha: 0.10),
        border: Border.all(color: const Color(0xFF3DDC97).withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: Color(0xFF3DDC97), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFEAF2F4),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressionSummary extends StatelessWidget {
  const _ProgressionSummary({required this.suggestions});

  final List<_ProgressionSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF08111A),
        border: Border.all(color: const Color(0xFF3DDC97).withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Color(0xFF3DDC97), size: 20),
              SizedBox(width: 8),
              Text(
                'Progression fürs nächste Mal',
                style: TextStyle(
                  color: Color(0xFFEAF2F4),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final suggestion in suggestions) ...[
            Text(
              '• ${suggestion.exercise.name}: ${suggestion.message}',
              style: const TextStyle(
                color: Color(0xFFB8C2CC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _ProgressionSuggestion {
  const _ProgressionSuggestion({required this.exercise, this.nextWeight});

  final Exercise exercise;
  final double? nextWeight;

  String get message {
    final savedNextWeight = nextWeight;

    if (savedNextWeight != null) {
      return 'nächstes Mal ${_formatWeight(savedNextWeight)}';
    }

    if (exercise.plannedWeight <= 0) {
      return 'schwerere Variante wählen';
    }

    return 'Gewicht leicht erhöhen';
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00E5FF), Color(0xFF3DDC97)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.24),
                blurRadius: 26,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 22),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
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

String _formatWeight(double weight) {
  if (weight <= 0) {
    return 'Bodyweight';
  }

  final roundedWeight = weight.roundToDouble();

  if (roundedWeight == weight) {
    return '${roundedWeight.toInt()} kg';
  }

  return '${weight.toStringAsFixed(1).replaceAll('.', ',')} kg';
}

String _formatWeightInput(double weight) {
  final roundedWeight = weight.roundToDouble();

  if (roundedWeight == weight) {
    return roundedWeight.toInt().toString();
  }

  return weight.toStringAsFixed(1);
}

String _formatSeconds(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final restSeconds = safeSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${restSeconds.toString().padLeft(2, '0')}';
}
