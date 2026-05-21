import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';

final exerciseBoxProvider = Provider<Box<Exercise>>((ref) {
  return Hive.box<Exercise>('exercises');
});

final workoutPlanBoxProvider = Provider<Box<WorkoutPlan>>((ref) {
  return Hive.box<WorkoutPlan>('workout_plans');
});

final workoutSessionBoxProvider = Provider<Box<WorkoutSession>>((ref) {
  return Hive.box<WorkoutSession>('workout_sessions');
});