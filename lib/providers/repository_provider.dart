import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/exercise_repository.dart';
import 'hive_providers.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final box = ref.watch(exerciseBoxProvider);
  return ExerciseRepository(box);
});