// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final typeId = 0;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final plannedReps = (fields[4] as num?)?.toInt() ?? 10;
    return Exercise(
      id: fields[0] as String,
      name: fields[1] as String,
      muscleGroups: (fields[2] as List?)?.cast<String>(),
      plannedSets: (fields[3] as num?)?.toInt() ?? 3,
      plannedReps: plannedReps,
      plannedWeight: (fields[5] as num?)?.toDouble() ?? 0,
      targetMinReps: (fields[6] as num?)?.toInt() ?? plannedReps,
      targetMaxReps: (fields[7] as num?)?.toInt() ?? plannedReps,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.muscleGroups)
      ..writeByte(3)
      ..write(obj.plannedSets)
      ..writeByte(4)
      ..write(obj.plannedReps)
      ..writeByte(5)
      ..write(obj.plannedWeight)
      ..writeByte(6)
      ..write(obj.targetMinReps)
      ..writeByte(7)
      ..write(obj.targetMaxReps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
