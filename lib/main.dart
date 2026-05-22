import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';
import 'models/exercise.dart';
import 'models/workout_plan.dart';
import 'models/workout_set.dart';
import 'models/workout_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutSetAdapter());
  Hive.registerAdapter(WorkoutPlanAdapter());
  Hive.registerAdapter(WorkoutSessionAdapter());
  Hive.registerAdapter(WorkoutPlanDayAdapter());

  await Hive.openBox<Exercise>('exercises');
  await Hive.openBox<WorkoutPlan>('workout_plans');
  await Hive.openBox<WorkoutSession>('workout_sessions');
  await Hive.openBox('settings');

  runApp(const ProviderScope(child: GymTrackerApp()));
}
