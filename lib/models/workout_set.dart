import 'package:hive_ce/hive.dart';

part 'workout_set.g.dart';

@HiveType(typeId: 1)
class WorkoutSet extends HiveObject {
  @HiveField(0)
  final double weight;

  @HiveField(1)
  final int reps;

  WorkoutSet({
    required this.weight,
    required this.reps,
  });
}