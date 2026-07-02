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
      productId: fields[2] as String,
      barcode: fields[3] as String,
      countedQuantity: fields[4] as int,
      timestamp: fields[5] as DateTime,
      isSynced: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StocktakeModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.productId)
      ..writeByte(3)
      ..write(obj.barcode)
      ..writeByte(4)
      ..write(obj.countedQuantity)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.isSynced);
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
