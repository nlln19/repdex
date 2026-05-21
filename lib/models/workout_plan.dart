import 'package:hive_ce/hive.dart';

part 'workout_plan.g.dart';

@HiveType(typeId: 2)
class WorkoutPlan extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> exerciseIds;

  @HiveField(3)
  final int restSeconds;

  @HiveField(4)
  final List<WorkoutPlanDay> days;

  WorkoutPlan({
    required this.id,
    required this.name,
    required List<String> exerciseIds,
    required this.restSeconds,
    List<WorkoutPlanDay>? days,
  })  : exerciseIds = List.unmodifiable(_uniqueIds(exerciseIds)),
        days = List.unmodifiable(_normalizeDays(days, exerciseIds));

  WorkoutPlanDay dayForWeekday(int weekday) {
    return days.firstWhere(
      (day) => day.weekday == weekday,
      orElse: () => WorkoutPlanDay.restDay(weekday: weekday),
    );
  }

  static List<String> _uniqueIds(Iterable<String> ids) {
    final result = <String>[];

    for (final id in ids) {
      final cleanedId = id.trim();

      if (cleanedId.isEmpty || result.contains(cleanedId)) {
        continue;
      }

      result.add(cleanedId);
    }

    return result;
  }

  static List<WorkoutPlanDay> _normalizeDays(
    List<WorkoutPlanDay>? days,
    List<String> fallbackExerciseIds,
  ) {
    final daysByWeekday = <int, WorkoutPlanDay>{};

    for (final day in days ?? const <WorkoutPlanDay>[]) {
      if (day.weekday < DateTime.monday || day.weekday > DateTime.sunday) {
        continue;
      }

      daysByWeekday[day.weekday] = day.normalized();
    }

    if (daysByWeekday.isEmpty && fallbackExerciseIds.isNotEmpty) {
      daysByWeekday[DateTime.monday] = WorkoutPlanDay.trainingDay(
        weekday: DateTime.monday,
        name: 'Training',
        exerciseIds: fallbackExerciseIds,
      );
    }

    return [
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        daysByWeekday[weekday] ?? WorkoutPlanDay.restDay(weekday: weekday),
    ];
  }
}

@HiveType(typeId: 4)
class WorkoutPlanDay {
  @HiveField(0)
  final int weekday;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> exerciseIds;

  @HiveField(3)
  final bool isRestDay;

  WorkoutPlanDay({
    required this.weekday,
    required this.name,
    required List<String> exerciseIds,
    required this.isRestDay,
  }) : exerciseIds = List.unmodifiable(
          isRestDay ? const <String>[] : WorkoutPlan._uniqueIds(exerciseIds),
        );

  factory WorkoutPlanDay.trainingDay({
    required int weekday,
    required String name,
    required List<String> exerciseIds,
  }) {
    return WorkoutPlanDay(
      weekday: weekday,
      name: name.trim().isEmpty ? weekdayName(weekday) : name.trim(),
      exerciseIds: exerciseIds,
      isRestDay: false,
    );
  }

  factory WorkoutPlanDay.restDay({required int weekday}) {
    return WorkoutPlanDay(
      weekday: weekday,
      name: 'Restday',
      exerciseIds: const [],
      isRestDay: true,
    );
  }

  WorkoutPlanDay normalized() {
    final validWeekday = weekday < DateTime.monday || weekday > DateTime.sunday
        ? DateTime.monday
        : weekday;

    if (isRestDay) {
      return WorkoutPlanDay.restDay(weekday: validWeekday);
    }

    return WorkoutPlanDay.trainingDay(
      weekday: validWeekday,
      name: name,
      exerciseIds: exerciseIds,
    );
  }

  static String weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Montag';
      case DateTime.tuesday:
        return 'Dienstag';
      case DateTime.wednesday:
        return 'Mittwoch';
      case DateTime.thursday:
        return 'Donnerstag';
      case DateTime.friday:
        return 'Freitag';
      case DateTime.saturday:
        return 'Samstag';
      case DateTime.sunday:
        return 'Sonntag';
      default:
        return 'Trainingstag';
    }
  }

  static String shortWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mo';
      case DateTime.tuesday:
        return 'Di';
      case DateTime.wednesday:
        return 'Mi';
      case DateTime.thursday:
        return 'Do';
      case DateTime.friday:
        return 'Fr';
      case DateTime.saturday:
        return 'Sa';
      case DateTime.sunday:
        return 'So';
      default:
        return '?';
    }
  }
}
