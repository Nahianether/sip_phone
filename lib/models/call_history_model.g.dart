// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_history_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallHistoryModelAdapter extends TypeAdapter<CallHistoryModel> {
  @override
  final int typeId = 0;

  @override
  CallHistoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CallHistoryModel(
      id: fields[0] as String,
      phoneNumber: fields[1] as String,
      contactName: fields[2] as String?,
      type: fields[3] as CallType,
      timestamp: fields[4] as DateTime,
      duration: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CallHistoryModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.phoneNumber)
      ..writeByte(2)
      ..write(obj.contactName)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.duration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallHistoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CallTypeAdapter extends TypeAdapter<CallType> {
  @override
  final int typeId = 1;

  @override
  CallType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CallType.incoming;
      case 1:
        return CallType.outgoing;
      case 2:
        return CallType.missed;
      default:
        return CallType.incoming;
    }
  }

  @override
  void write(BinaryWriter writer, CallType obj) {
    switch (obj) {
      case CallType.incoming:
        writer.writeByte(0);
        break;
      case CallType.outgoing:
        writer.writeByte(1);
        break;
      case CallType.missed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
