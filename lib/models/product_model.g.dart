// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      orgId: fields[1] as String,
      warehouseId: fields[2] as String,
      code: fields[3] as String,
      name: fields[4] as String,
      unit: fields[5] as String,
      barcode: fields[6] as String,
      systemQuantity: fields[7] as int,
      price: fields[8] as double,
      isFrozen: fields[9] as bool,
      isSynced: fields[10] as bool,
      lastUpdated: fields[11] as DateTime,
<<<<<<< HEAD
      locationRef: fields[12] as String,
      isDeleted: fields[13] as bool,
=======
      locationRef: fields[12] as String? ?? '',
      isDeleted: fields[13] as bool? ?? false,
>>>>>>> e52ea47620e032128fb2be8123ab7f10f3c7a4bf
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orgId)
      ..writeByte(2)
      ..write(obj.warehouseId)
      ..writeByte(3)
      ..write(obj.code)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.barcode)
      ..writeByte(7)
      ..write(obj.systemQuantity)
      ..writeByte(8)
      ..write(obj.price)
      ..writeByte(9)
      ..write(obj.isFrozen)
      ..writeByte(10)
      ..write(obj.isSynced)
      ..writeByte(11)
      ..write(obj.lastUpdated)
      ..writeByte(12)
      ..write(obj.locationRef)
      ..writeByte(13)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
