// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LlmModelAdapter extends TypeAdapter<LlmModel> {
  @override
  final int typeId = 0;

  @override
  LlmModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LlmModel(
      name: fields[0] as String,
      copiedPath: fields[1] as String,
      lastUsed: fields[2] as String,
      isActive: fields[3] as bool,
      createdAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LlmModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.copiedPath)
      ..writeByte(2)
      ..write(obj.lastUsed)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LlmModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
