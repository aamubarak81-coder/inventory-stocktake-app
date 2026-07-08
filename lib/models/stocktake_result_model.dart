class StocktakeResultModel {
  final String id;
  final String productName;
  final String branch;
  final String warehouse;
  final String employee;
  final int expectedQty;
  final int actualQty;
  final DateTime date;

  StocktakeResultModel({
    required this.id,
    required this.productName,
    required this.branch,
    required this.warehouse,
    required this.employee,
    required this.expectedQty,
    required this.actualQty,
    required this.date,
  });

  int get diff => actualQty - expectedQty;

  String get status {
    if (diff > 0) return 'زيادة';
    if (diff < 0) return 'نقص';
    return 'مطابق';
  }

  int get statusColor {
    if (diff > 0) return 0xFF4CAF50;
    if (diff < 0) return 0xFFF44336;
    return 0xFF2196F3;
  }

  factory StocktakeResultModel.fromJson(Map<String, dynamic> json) {
    return StocktakeResultModel(
      id: json['id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      branch: json['branch']?.toString() ?? 'الرئيسي',
      warehouse: json['warehouse']?.toString() ?? 'المستودع الرئيسي',
      employee: json['employee']?.toString() ?? 'غير محدد',
      expectedQty: int.tryParse(json['expected_qty']?.toString() ?? '0') ?? 0,
      actualQty: int.tryParse(json['actual_qty']?.toString() ?? '0') ?? 0,
      date: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_name': productName,
        'branch': branch,
        'warehouse': warehouse,
        'employee': employee,
        'expected_qty': expectedQty,
        'actual_qty': actualQty,
        'created_at': date.toIso8601String(),
      };
}
