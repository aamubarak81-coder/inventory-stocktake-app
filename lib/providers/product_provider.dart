class ProductModel {
  final String id;
  final String orgId;
  final String? barcode;
  final String name;
  final int systemQuantity;
  final double price;
  final String? warehouseId;
  final String? locationRef;
  final bool isFrozen;
  final DateTime updatedAt;
  final String? code;
  final String? unit;
  final bool isSynced;

  ProductModel({
    required this.id,
    required this.orgId,
    this.barcode,
    required this.name,
    required this.systemQuantity,
    required this.price,
    this.warehouseId,
    this.locationRef,
    this.isFrozen = false,
    required this.updatedAt,
    this.code,
    this.unit,
    this.isSynced = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      barcode: json['barcode']?.toString(),
      name: json['name']?.toString() ?? '',
      systemQuantity: json['system_quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      warehouseId: json['warehouse_id']?.toString(),
      locationRef: json['location_ref']?.toString(),
      isFrozen: json['is_frozen'] ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      code: json['code']?.toString(),
      unit: json['unit']?.toString(),
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'barcode': barcode,
      'name': name,
      'system_quantity': systemQuantity,
      'price': price,
      'warehouse_id': warehouseId,
      'location_ref': locationRef,
      'is_frozen': isFrozen,
      'updated_at': updatedAt.toIso8601String(),
      'code': code,
      'unit': unit,
    };
  }

  Map<String, dynamic> toHive() {
    return {
      ...toJson(),
      'isSynced': isSynced,
    };
  }

  factory ProductModel.fromHive(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      orgId: map['org_id']?.toString() ?? '',
      barcode: map['barcode']?.toString(),
      name: map['name']?.toString() ?? '',
      systemQuantity: map['system_quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      warehouseId: map['warehouse_id']?.toString(),
      locationRef: map['location_ref']?.toString(),
      isFrozen: map['is_frozen'] ?? false,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
      code: map['code']?.toString(),
      unit: map['unit']?.toString(),
      isSynced: map['isSynced'] ?? false,
    );
  }

  bool get isAvailableForStocktake => !isFrozen;
  String get displayUnit => unit ?? 'piece';
}