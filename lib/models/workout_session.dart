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

  WorkoutSession({
    required this.id,
    required this.workoutPlanId,
    required this.date,
    required this.exerciseSets,
  });
}