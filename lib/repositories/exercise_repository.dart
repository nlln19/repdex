import 'package:hive_ce/hive.dart';

import '../models/exercise.dart';

class ExerciseRepository {
  ExerciseRepository(this._box);

  final Box<Exercise> _box;

  List<Exercise> getAllExercises() {
    return _box.values.toList();
  }

  Future<void> addExercise(Exercise exercise) async {
    await _box.put(exercise.id, exercise);
  }

  Future<void> deleteExercise(String id) async {
    await _box.delete(id);
  }

  Exercise? getExerciseById(String id) {
    return _box.get(id);
  }
}