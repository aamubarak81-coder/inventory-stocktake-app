import 'package:hive/hive.dart';

part 'product_model.g.dart';

@HiveType(typeId: 0)
class ProductModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String orgId;

  @HiveField(2)
  String warehouseId;

  @HiveField(3)
  String code;

  @HiveField(4)
  String name;

  @HiveField(5)
  String unit;

  @HiveField(6)
  String barcode;

  @HiveField(7)
  int systemQuantity;

  @HiveField(8)
  double price;

  @HiveField(9)
  bool isFrozen;

  @HiveField(10)
  bool isSynced;

  @HiveField(11)
  DateTime lastUpdated;

  @HiveField(12)
  String locationRef;

  ProductModel({
    required this.id,
    required this.orgId,
    this.warehouseId = '',
    required this.code,
    required this.name,
    this.unit = '',
    this.barcode = '',
    required this.systemQuantity,
    required this.price,
    this.isFrozen = false,
    this.isSynced = false,
    required this.lastUpdated,
    this.locationRef = '',
  });

  // اسم بديل للتوافق مع الكود القديم (نفس systemQuantity)
  int get quantity => systemQuantity;

  // تحويل من بيانات Supabase (JSON) إلى موديل محلي
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      orgId: map['org_id'] ?? '',
      warehouseId: map['warehouse_id'] ?? '',
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      unit: map['unit'] ?? '',
      barcode: map['barcode'] ?? '',
      systemQuantity: map['system_quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      isFrozen: map['is_frozen'] ?? false,
      isSynced: true, // إذا جاي من Supabase فهو متزامن أصلاً
      lastUpdated: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
      locationRef: map['location_ref'] ?? '',
    );
  }

  // تحويل الموديل المحلي إلى بيانات جاهزة للإرسال لـ Supabase
  // ملاحظة: ما منبعت id لو كان فاضي، عشان قاعدة البيانات تولده تلقائياً
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'org_id': orgId,
      'warehouse_id': warehouseId.isEmpty ? null : warehouseId,
      'code': code.isEmpty ? null : code,
      'name': name,
      'unit': unit.isEmpty ? null : unit,
      'barcode': barcode.isEmpty ? null : barcode,
      'system_quantity': systemQuantity,
      'price': price,
      'is_frozen': isFrozen,
      'updated_at': lastUpdated.toIso8601String(),
      'location_ref': locationRef.isEmpty ? null : locationRef,
    };
  }
}
