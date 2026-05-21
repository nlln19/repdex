// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutPlanAdapter extends TypeAdapter<WorkoutPlan> {
  @override
  final typeId = 2;

  @override
  WorkoutPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      exerciseIds: (fields[2] as List).cast<String>(),
      restSeconds: (fields[3] as num).toInt(),
      days: (fields[4] as List?)?.cast<WorkoutPlanDay>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPlan obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.exerciseIds)
      ..writeByte(3)
      ..write(obj.restSeconds)
      ..writeByte(4)
      ..write(obj.days);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutPlanDayAdapter extends TypeAdapter<WorkoutPlanDay> {
  @override
  final typeId = 4;

  @override
  WorkoutPlanDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutPlanDay(
      weekday: (fields[0] as num).toInt(),
      name: fields[1] as String,
      exerciseIds: (fields[2] as List).cast<String>(),
      isRestDay: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPlanDay obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.weekday)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.exerciseIds)
      ..writeByte(3)
      ..write(obj.isRestDay);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutPlanDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
