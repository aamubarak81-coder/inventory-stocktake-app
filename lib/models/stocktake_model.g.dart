// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stocktake_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StocktakeModelAdapter extends TypeAdapter<StocktakeModel> {
  @override
  final int typeId = 1;

  @override
  StocktakeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StocktakeModel(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      orgId: fields[2] as String,
      productId: fields[3] as String,
      barcode: fields[4] as String,
      scannedQuantity: fields[5] as int,
      expectedQuantity: fields[6] as int?,
      isBlindCount: fields[7] as bool,
      latitude: fields[8] as double?,
      longitude: fields[9] as double?,
      scannedBy: fields[10] as String,
      scannedAt: fields[11] as DateTime,
      isSynced: fields[12] as bool,
      deviceId: fields[13] as String?,
      locationRef: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StocktakeModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.orgId)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.barcode)
      ..writeByte(5)
      ..write(obj.scannedQuantity)
      ..writeByte(6)
      ..write(obj.expectedQuantity)
      ..writeByte(7)
      ..write(obj.isBlindCount)
      ..writeByte(8)
      ..write(obj.latitude)
      ..writeByte(9)
      ..write(obj.longitude)
      ..writeByte(10)
      ..write(obj.scannedBy)
      ..writeByte(11)
      ..write(obj.scannedAt)
      ..writeByte(12)
      ..write(obj.isSynced)
      ..writeByte(13)
      ..write(obj.deviceId)
      ..writeByte(14)
      ..write(obj.locationRef);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StocktakeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
