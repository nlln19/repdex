// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final typeId = 3;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSession(
      id: fields[0] as String,
      workoutPlanId: fields[1] as String,
      date: fields[2] as DateTime,
      exerciseSets: (fields[3] as Map).map(
        (dynamic k, dynamic v) =>
            MapEntry(k as String, (v as List).cast<WorkoutSet>()),
      ),
      workoutPlanName: fields[4] as String? ?? '',
      dayName: fields[5] as String? ?? '',
      exerciseNames: (fields[6] as Map?)?.map(
            (dynamic k, dynamic v) => MapEntry(k as String, v as String),
          ) ??
          const {},
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.workoutPlanId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.exerciseSets)
      ..writeByte(4)
      ..write(obj.workoutPlanName)
      ..writeByte(5)
      ..write(obj.dayName)
      ..writeByte(6)
      ..write(obj.exerciseNames);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
