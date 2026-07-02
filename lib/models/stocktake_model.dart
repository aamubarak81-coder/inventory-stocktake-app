import 'package:hive/hive.dart';

part 'stocktake_model.g.dart';

@HiveType(typeId: 1)
class StocktakeModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String sessionId;

  @HiveField(2)
  String productId;

  @HiveField(3)
  String barcode;

  @HiveField(4)
  int countedQuantity;

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  bool isSynced;

  StocktakeModel({
    required this.id,
    required this.sessionId,
    required this.productId,
    required this.barcode,
    required this.countedQuantity,
    required this.timestamp,
    this.isSynced = false,
  });

  factory StocktakeModel.fromMap(Map<String, dynamic> map) {
    return StocktakeModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      productId: map['product_id'] as String,
      barcode: map['barcode'] as String,
      countedQuantity: map['counted_quantity'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: map['is_synced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'product_id': productId,
      'barcode': barcode,
      'counted_quantity': countedQuantity,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
    };
  }
}
