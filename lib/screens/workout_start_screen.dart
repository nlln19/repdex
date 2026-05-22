import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_plan.dart';

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
  static const String activeWorkoutExerciseIndexKey =
      'active_workout_exercise_index';
  static const String activeWorkoutCurrentSetKey = 'active_workout_current_set';
  static const String activeWorkoutPhaseKey = 'active_workout_phase';
  static const String activeWorkoutRestEndMillisKey =
      'active_workout_rest_end_millis';
  static const String completedWorkoutDateKey = 'completed_workout_date';

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
                label: 'Wdh.',
                value: '${exercise.plannedReps}',
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
      ],
    );
  }

  Widget _buildRestContent() {
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
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
            const SizedBox(height: 28),
            _BottomActionButton(
              label: 'Zurück',
              icon: Icons.home_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
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
    final activePlanId = _settingsBox.get(
      WorkoutStartScreen.activeWorkoutPlanIdKey,
    );

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
    _currentSet = restoredCurrentSet
        .clamp(1, _setCountFor(_currentExercise))
        .toInt();
    _isResting = restoredPhase == _phaseRest;
    _restEndMillis = restoredRestEndMillis <= 0 ? null : restoredRestEndMillis;

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
    await _settingsBox.put(
      WorkoutStartScreen.activeWorkoutExerciseIndexKey,
      _safeExerciseIndex,
    );
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutCurrentSetKey, _currentSet);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutPhaseKey, _phaseSet);
    await _settingsBox.delete(WorkoutStartScreen.activeWorkoutRestEndMillisKey);
  }

  Future<void> _persistRestState() async {
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutDateKey, _todayKey);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutPlanIdKey, widget.plan.id);
    await _settingsBox.put(
      WorkoutStartScreen.activeWorkoutExerciseIndexKey,
      _safeExerciseIndex,
    );
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutCurrentSetKey, _currentSet);
    await _settingsBox.put(WorkoutStartScreen.activeWorkoutPhaseKey, _phaseRest);
    await _settingsBox.put(
      WorkoutStartScreen.activeWorkoutRestEndMillisKey,
      _restEndMillis ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _completeSet() {
    if (_isResting || _isFinished) {
      return;
    }

    if (_isLastSetOfWorkout) {
      _finishWorkout();
      return;
    }

    _startRest();
  }

  void _startRest() {
    _restTimer?.cancel();

    final restEndMillis =
        DateTime.now().millisecondsSinceEpoch + (_safeRestSeconds * 1000);

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

    await _settingsBox.put(WorkoutStartScreen.completedWorkoutDateKey, _todayKey);
    await WorkoutStartScreen.clearActiveWorkout(_settingsBox);
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

  int _setCountFor(Exercise exercise) {
    return exercise.plannedSets < 1 ? 1 : exercise.plannedSets;
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

String _formatSeconds(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final restSeconds = safeSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${restSeconds.toString().padLeft(2, '0')}';
}
