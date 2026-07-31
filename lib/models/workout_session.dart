import 'package:hive_ce/hive.dart';

import 'workout_set.dart';

part 'workout_session.g.dart';

@HiveType(typeId: 3)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String workoutPlanId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final Map<String, List<WorkoutSet>> exerciseSets;

  @HiveField(4)
  final String workoutPlanName;

  @HiveField(5)
  final String dayName;

  @HiveField(6)
  final Map<String, String> exerciseNames;

  WorkoutSession({
    required this.id,
    required this.workoutPlanId,
    required this.date,
    required this.exerciseSets,
    this.workoutPlanName = '',
    this.dayName = '',
    Map<String, String>? exerciseNames,
  }) : exerciseNames = Map.unmodifiable(exerciseNames ?? const {});

  int get totalSets {
    return exerciseSets.values.fold<int>(
      0,
      (total, sets) => total + sets.length,
    );
  }

  int get totalReps {
    return exerciseSets.values.fold<int>(
      0,
      (total, sets) => total + sets.fold<int>(0, (sum, set) => sum + set.reps),
    );
  }

  double get totalVolume {
    return exerciseSets.values.fold<double>(
      0,
      (total, sets) =>
          total + sets.fold<double>(0, (sum, set) => sum + (set.weight * set.reps)),
    );
  }

  String exerciseNameFor(String exerciseId) {
    final storedName = exerciseNames[exerciseId]?.trim();

    if (storedName != null && storedName.isNotEmpty) {
      return storedName;
    }

    return exerciseId;
  }
}
