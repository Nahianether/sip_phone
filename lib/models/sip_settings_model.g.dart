// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sip_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SipSettingsModelAdapter extends TypeAdapter<SipSettingsModel> {
  @override
  final int typeId = 2;

  @override
  SipSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SipSettingsModel(
      username: fields[0] as String?,
      password: fields[1] as String?,
      server: fields[2] as String?,
      wsUrl: fields[3] as String?,
      displayName: fields[4] as String?,
      autoConnect: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SipSettingsModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.password)
      ..writeByte(2)
      ..write(obj.server)
      ..writeByte(3)
      ..write(obj.wsUrl)
      ..writeByte(4)
      ..write(obj.displayName)
      ..writeByte(5)
      ..write(obj.autoConnect);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SipSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
