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

  Exercise({
    required this.id,
    required this.name,
    List<String>? muscleGroups,
    String? muscleGroup,
    int plannedSets = 3,
    int plannedReps = 10,
    double plannedWeight = 0,
  })  : muscleGroups = _normalizeMuscleGroups(
          muscleGroups ?? (muscleGroup == null ? const [] : [muscleGroup]),
        ),
        plannedSets = plannedSets < 1 ? 1 : plannedSets,
        plannedReps = plannedReps < 1 ? 1 : plannedReps,
        plannedWeight = plannedWeight < 0 ? 0 : plannedWeight;

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

  String get plannedVolumeLabel => '$plannedSets x $plannedReps · $plannedWeightLabel';

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
