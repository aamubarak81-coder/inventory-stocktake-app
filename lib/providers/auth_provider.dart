import 'package:flutter/material.dart';

class StocktakeModel {
  final String id;
  final String? orgId;
  final String? productId;
  final String? barcode;
  final int? expectedQuantity;
  final int scannedQuantity;
  final String? countedBy;
  final DateTime countedAt;
  final String? notes;
  final String? sessionId;
  final bool isSynced;

  StocktakeModel({
    required this.id,
    this.orgId,
    this.productId,
    this.barcode,
    this.expectedQuantity,
    required this.scannedQuantity,
    this.countedBy,
    required this.countedAt,
    this.notes,
    this.sessionId,
    this.isSynced = false,
  });

  factory StocktakeModel.fromJson(Map<String, dynamic> json) {
    return StocktakeModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString(),
      productId: json['product_id']?.toString(),
      barcode: json['barcode']?.toString(),
      expectedQuantity: json['expected_quantity'],
      scannedQuantity: json['scanned_quantity'] ?? 0,
      countedBy: json['counted_by']?.toString(),
      countedAt: json['counted_at'] != null
          ? DateTime.parse(json['counted_at'])
          : DateTime.now(),
      notes: json['notes']?.toString(),
      sessionId: json['session_id']?.toString(),
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'product_id': productId,
      'barcode': barcode,
      'expected_quantity': expectedQuantity,
      'scanned_quantity': scannedQuantity,
      'counted_by': countedBy,
      'counted_at': countedAt.toIso8601String(),
      'notes': notes,
      'session_id': sessionId,
    };
  }

  Map<String, dynamic> toHive() {
    return {
      ...toJson(),
      'isSynced': isSynced,
    };
  }

  factory StocktakeModel.fromHive(Map<String, dynamic> map) {
    return StocktakeModel(
      id: map['id']?.toString() ?? '',
      orgId: map['org_id']?.toString(),
      productId: map['product_id']?.toString(),
      barcode: map['barcode']?.toString(),
      expectedQuantity: map['expected_quantity'],
      scannedQuantity: map['scanned_quantity'] ?? 0,
      countedBy: map['counted_by']?.toString(),
      countedAt: map['counted_at'] != null
          ? DateTime.parse(map['counted_at'])
          : DateTime.now(),
      notes: map['notes']?.toString(),
      sessionId: map['session_id']?.toString(),
      isSynced: map['isSynced'] ?? false,
    );
  }

  int? get difference {
    if (expectedQuantity == null) return null;
    return scannedQuantity - expectedQuantity!;
  }

  String get status {
    if (expectedQuantity == null) return 'new';
    final diff = difference!;
    if (diff == 0) return 'match';
    if (diff > 0) return 'surplus';
    return 'deficit';
  }

  Color get statusColor {
    if (expectedQuantity == null) return Colors.grey;
    final diff = difference!;
    if (diff == 0) return Colors.green;
    if (diff > 0) return Colors.blue;
    return Colors.red;
  }

  IconData get statusIcon {
    if (expectedQuantity == null) return Icons.help_outline;
    final diff = difference!;
    if (diff == 0) return Icons.check_circle;
    if (diff > 0) return Icons.add_circle;
    return Icons.remove_circle;
  }
}