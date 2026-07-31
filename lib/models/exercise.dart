import 'package:hive_ce/hive.dart';

part 'exercise.g.dart';

@HiveType(typeId: 0)
class Exercise extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> muscleGroups;

  @HiveField(3)
  final int plannedSets;

  @HiveField(4)
  final int plannedReps;

  @HiveField(5)
  final double plannedWeight;

  @HiveField(6)
  final int targetMinReps;

  @HiveField(7)
  final int targetMaxReps;

  Exercise({
    required this.id,
    required this.name,
    List<String>? muscleGroups,
    String? muscleGroup,
    int plannedSets = 3,
    int plannedReps = 10,
    double plannedWeight = 0,
    int? targetMinReps,
    int? targetMaxReps,
  })  : muscleGroups = _normalizeMuscleGroups(
          muscleGroups ?? (muscleGroup == null ? const [] : [muscleGroup]),
        ),
        plannedSets = plannedSets < 1 ? 1 : plannedSets,
        plannedReps = plannedReps < 1 ? 1 : plannedReps,
        plannedWeight = plannedWeight < 0 ? 0 : plannedWeight,
        targetMinReps = _normalizeMinReps(
          targetMinReps,
          targetMaxReps,
          plannedReps,
        ),
        targetMaxReps = _normalizeMaxReps(
          targetMinReps,
          targetMaxReps,
          plannedReps,
        );



  Exercise copyWith({
    String? id,
    String? name,
    List<String>? muscleGroups,
    int? plannedSets,
    int? plannedReps,
    double? plannedWeight,
    int? targetMinReps,
    int? targetMaxReps,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      plannedSets: plannedSets ?? this.plannedSets,
      plannedReps: plannedReps ?? this.plannedReps,
      plannedWeight: plannedWeight ?? this.plannedWeight,
      targetMinReps: targetMinReps ?? this.targetMinReps,
      targetMaxReps: targetMaxReps ?? this.targetMaxReps,
    );
  }

  String get muscleGroup => muscleGroups.isEmpty ? '' : muscleGroups.first;

  String get plannedWeightLabel {
    if (plannedWeight == 0) {
      return 'Bodyweight';
    }

    final roundedWeight = plannedWeight.roundToDouble();

    if (roundedWeight == plannedWeight) {
      return '${roundedWeight.toInt()} kg';
    }

    return '${plannedWeight.toStringAsFixed(1)} kg';
  }

  String get repRangeLabel {
    if (targetMinReps == targetMaxReps) {
      return '$targetMaxReps';
    }

    return '$targetMinReps-$targetMaxReps';
  }

  String get plannedVolumeLabel => '$plannedSets x $repRangeLabel · $plannedWeightLabel';

  bool shouldIncreaseWeight(List<int> completedReps) {
    return shouldIncreaseWeightEarly(completedReps) ||
        shouldIncreaseWeightAfterAllSets(completedReps);
  }

  bool shouldIncreaseWeightEarly(List<int> completedReps) {
    if (completedReps.length < 2) {
      return false;
    }

    final firstSetReachedTop = completedReps[0] >= targetMaxReps;
    final secondSetNearlyReachedTop = completedReps[1] >= targetMaxReps - 1;

    return firstSetReachedTop && secondSetNearlyReachedTop;
  }

  bool shouldIncreaseWeightAfterAllSets(List<int> completedReps) {
    if (completedReps.length < plannedSets) {
      return false;
    }

    return completedReps.take(plannedSets).every((reps) => reps >= targetMaxReps);
  }

  static int _normalizeMinReps(
    int? targetMinReps,
    int? targetMaxReps,
    int plannedReps,
  ) {
    final fallback = plannedReps < 1 ? 1 : plannedReps;
    final minReps = targetMinReps == null || targetMinReps < 1 ? fallback : targetMinReps;
    final maxReps = targetMaxReps == null || targetMaxReps < 1 ? fallback : targetMaxReps;
    return minReps > maxReps ? maxReps : minReps;
  }

  static int _normalizeMaxReps(
    int? targetMinReps,
    int? targetMaxReps,
    int plannedReps,
  ) {
    final fallback = plannedReps < 1 ? 1 : plannedReps;
    final minReps = targetMinReps == null || targetMinReps < 1 ? fallback : targetMinReps;
    final maxReps = targetMaxReps == null || targetMaxReps < 1 ? fallback : targetMaxReps;
    return maxReps < minReps ? minReps : maxReps;
  }

  static List<String> _normalizeMuscleGroups(List<String> groups) {
    final cleanedGroups = <String>[];

    for (final group in groups) {
      for (final normalizedGroup in _normalizeMuscleGroup(group)) {
        if (normalizedGroup.isEmpty || cleanedGroups.contains(normalizedGroup)) {
          continue;
        }

        cleanedGroups.add(normalizedGroup);
      }
    }

    return List.unmodifiable(cleanedGroups);
  }

  static List<String> _normalizeMuscleGroup(String group) {
    final cleanedGroup = group.trim();
    final normalizedGroup = cleanedGroup
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');

    switch (normalizedGroup) {
      case 'arms':
      case 'arm':
      case 'arme':
        return const ['Bizeps', 'Trizeps'];
      case 'forearms':
      case 'forearm':
      case 'unterarme':
      case 'unterarm':
        return const [];
      case 'legs':
      case 'leg':
      case 'beine':
      case 'bein':
        return const ['Quads', 'Hamstrings'];
      default:
        return [cleanedGroup];
    }
  }
}
