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

  Exercise({
    required this.id,
    required this.name,
    List<String>? muscleGroups,
    String? muscleGroup,
  }) : muscleGroups = _normalizeMuscleGroups(
          muscleGroups ?? (muscleGroup == null ? const [] : [muscleGroup]),
        );

  String get muscleGroup => muscleGroups.isEmpty ? '' : muscleGroups.first;

  static List<String> _normalizeMuscleGroups(List<String> groups) {
    final cleanedGroups = <String>[];

    for (final group in groups) {
      final cleanedGroup = group.trim();

      if (cleanedGroup.isEmpty || cleanedGroups.contains(cleanedGroup)) {
        continue;
      }

      cleanedGroups.add(cleanedGroup);
    }

    return List.unmodifiable(cleanedGroups);
  }
}
