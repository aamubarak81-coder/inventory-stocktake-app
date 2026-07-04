import 'package:hive/hive.dart';

part 'stocktake_model.g.dart';

@HiveType(typeId: 1)
class StocktakeModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String sessionId; // مفهوم محلي فقط، ما بينرفع لـ Supabase

  @HiveField(2)
  String orgId;

  @HiveField(3)
  String productId;

  @HiveField(4)
  String barcode; // للعرض المحلي فقط، ما بينرفع لـ Supabase

  @HiveField(5)
  int scannedQuantity;

  @HiveField(6)
  int? expectedQuantity;

  @HiveField(7)
  bool isBlindCount;

  @HiveField(8)
  double? latitude;

  @HiveField(9)
  double? longitude;

  @HiveField(10)
  String scannedBy;

  @HiveField(11)
  DateTime scannedAt;

  @HiveField(12)
  bool isSynced;

  @HiveField(13)
  String? deviceId;

  @HiveField(14)
  String? locationRef;

  StocktakeModel({
    required this.id,
    required this.sessionId,
    required this.orgId,
    required this.productId,
    this.barcode = '',
    required this.scannedQuantity,
    this.expectedQuantity,
    this.isBlindCount = true,
    this.latitude,
    this.longitude,
    required this.scannedBy,
    required this.scannedAt,
    this.isSynced = false,
    this.deviceId,
    this.locationRef,
  });

  factory StocktakeModel.fromMap(Map<String, dynamic> map) {
    return StocktakeModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String? ?? '',
      orgId: map['org_id'] as String,
      productId: map['product_id'] as String,
      barcode: map['barcode'] as String? ?? '',
      scannedQuantity: map['scanned_quantity'] as int,
      expectedQuantity: map['expected_quantity'] as int?,
      isBlindCount: map['is_blind_count'] as bool? ?? true,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      scannedBy: map['scanned_by'] as String,
      scannedAt: DateTime.parse(map['scanned_at'] as String),
      isSynced: true, // إذا جاي من Supabase فهو متزامن أصلاً
      deviceId: map['device_id'] as String?,
      locationRef: map['location_ref'] as String?,
    );
  }

  // ملاحظة: ما منبعت sessionId ولا barcode لأنهم مو أعمدة موجودة بجدول stocktakes
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'org_id': orgId,
      'product_id': productId,
      'scanned_quantity': scannedQuantity,
      'expected_quantity': expectedQuantity,
      'is_blind_count': isBlindCount,
      'latitude': latitude,
      'longitude': longitude,
      'scanned_by': scannedBy,
      'scanned_at': scannedAt.toIso8601String(),
      'device_id': deviceId,
      'location_ref': locationRef,
    };
  }
}
