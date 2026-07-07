import '../models/product_model.dart';
import '../models/stocktake_model.dart';

/// إحصائية جرد لمجموعة معيّنة (فرع/مستودع بالكامل) - تشمل نسبة التغطية
/// (كم صنف تم جرده من أصل الإجمالي) وتوزيع الحالة (مطابق/زيادة/نقص).
class GroupStat {
  final String id;
  final String name;
  final int totalProducts;
  final int countedProducts;
  final int matched;
  final int surplus;
  final int deficit;

  GroupStat({
    required this.id,
    required this.name,
    required this.totalProducts,
    required this.countedProducts,
    required this.matched,
    required this.surplus,
    required this.deficit,
  });

  int get remaining => totalProducts - countedProducts;

  double get coveragePercent =>
      totalProducts == 0 ? 0 : (countedProducts / totalProducts) * 100;
}

/// إحصائية أداء موظف - كل عملياته الفردية (مش مبنية على "آخر جرد لكل
/// صنف" زي الفروع/المستودعات، لأن الهدف هون قياس نشاط الموظف نفسه).
class EmployeeStat {
  final String id;
  final String name;
  final int totalScans;
  final int distinctProducts;
  final int matched;
  final int surplus;
  final int deficit;

  EmployeeStat({
    required this.id,
    required this.name,
    required this.totalScans,
    required this.distinctProducts,
    required this.matched,
    required this.surplus,
    required this.deficit,
  });
}

/// تفاصيل فرق صنف واحد (الأحدث جرد له) - تُستخدم لعرض/ترتيب الأصناف
/// حسب حجم الفرق (زيادة أو نقص).
class ProductDiscrepancy {
  final String productId;
  final String name;
  final String barcode;
  final int? expectedQuantity;
  final int scannedQuantity;

  ProductDiscrepancy({
    required this.productId,
    required this.name,
    required this.barcode,
    required this.expectedQuantity,
    required this.scannedQuantity,
  });

  int get diff =>
      expectedQuantity == null ? 0 : scannedQuantity - expectedQuantity!;
}

class DetailedReportResult {
  final GroupStat overall;
  final List<GroupStat> byBranch;
  final List<GroupStat> byWarehouse;
  final List<EmployeeStat> byEmployee;
  final List<ProductDiscrepancy> byProduct;

  DetailedReportResult({
    required this.overall,
    required this.byBranch,
    required this.byWarehouse,
    required this.byEmployee,
    required this.byProduct,
  });
}

class DetailedReportsService {
  /// يحسب كل الإحصائيات التفصيلية بمرور واحد أو اثنين بس على البيانات
  /// (مش O(n×m))، حتى مع كتالوجات وتاريخ جرد كبير.
  ///
  /// [products] و [stocktakes] من التخزين المحلي (Hive - تشتغل بدون نت).
  /// [branches]، [warehouses]، [employees] من السيرفر (AdminService -
  /// تحتاج اتصال إنترنت، لأنها بيانات تنظيمية مش مخزّنة محلياً).
  static DetailedReportResult compute({
    required List<ProductModel> products,
    required List<StocktakeModel> stocktakes,
    required List<Map<String, dynamic>> branches,
    required List<Map<String, dynamic>> warehouses,
    required List<Map<String, dynamic>> employees,
  }) {
    // 1) لكل منتج، نحتفظ بس بآخر عملية جرد له (الأحدث توقيتاً) - عشان
    // لو انجرد نفس الصنف أكتر من مرة، نعتبر آخر نتيجة هي "الحالة الحالية"
    // مش نعّد كل محاولة على حدة (وإلا الأرقام تتضخم بشكل مضلل)
    final latestByProduct = <String, StocktakeModel>{};
    for (final s in stocktakes) {
      final existing = latestByProduct[s.productId];
      if (existing == null || s.scannedAt.isAfter(existing.scannedAt)) {
        latestByProduct[s.productId] = s;
      }
    }

    // فهرسة المنتجات بالـ id، عشان نعرف كل منتج تابع لأي مستودع
    final productsById = {for (final p in products) p.id: p};

    // فهرسة المستودعات بالـ id، وربطها بالفرع التابعة له
    final warehousesById = {for (final w in warehouses) w['id'].toString(): w};

    String? branchIdOfProduct(String productId) {
      final product = productsById[productId];
      if (product == null || product.warehouseId.isEmpty) return null;
      final warehouse = warehousesById[product.warehouseId];
      return warehouse?['branch_id']?.toString();
    }

    // 2) نحسب حالة كل منتج (مطابق/زيادة/نقص) من آخر جرد له فقط
    ({int matched, int surplus, int deficit}) statusOf(StocktakeModel s) {
      if (s.expectedQuantity == null) return (matched: 0, surplus: 0, deficit: 0);
      final diff = s.scannedQuantity - s.expectedQuantity!;
      if (diff == 0) return (matched: 1, surplus: 0, deficit: 0);
      if (diff > 0) return (matched: 0, surplus: 1, deficit: 0);
      return (matched: 0, surplus: 0, deficit: 1);
    }

    // 3) تجميع تراكمي لكل مستودع وفرع بمرور واحد على "آخر جرد لكل منتج"
    final warehouseAgg = <String, _Agg>{};
    final branchAgg = <String, _Agg>{};
    int overallMatched = 0, overallSurplus = 0, overallDeficit = 0;

    for (final s in latestByProduct.values) {
      final st = statusOf(s);
      overallMatched += st.matched;
      overallSurplus += st.surplus;
      overallDeficit += st.deficit;

      final product = productsById[s.productId];
      final warehouseId = product?.warehouseId ?? '';
      if (warehouseId.isNotEmpty) {
        final wAgg = warehouseAgg.putIfAbsent(warehouseId, () => _Agg());
        wAgg.counted++;
        wAgg.matched += st.matched;
        wAgg.surplus += st.surplus;
        wAgg.deficit += st.deficit;

        final branchId = branchIdOfProduct(s.productId);
        if (branchId != null && branchId.isNotEmpty) {
          final bAgg = branchAgg.putIfAbsent(branchId, () => _Agg());
          bAgg.counted++;
          bAgg.matched += st.matched;
          bAgg.surplus += st.surplus;
          bAgg.deficit += st.deficit;
        }
      }
    }

    // 4) إجمالي عدد المنتجات لكل مستودع وفرع (بغض النظر عن الجرد) -
    // مطلوب لحساب نسبة التغطية (كم تبقى)
    final warehouseTotals = <String, int>{};
    final branchTotals = <String, int>{};
    for (final p in products) {
      if (p.warehouseId.isEmpty) continue;
      warehouseTotals[p.warehouseId] = (warehouseTotals[p.warehouseId] ?? 0) + 1;
      final warehouse = warehousesById[p.warehouseId];
      final branchId = warehouse?['branch_id']?.toString();
      if (branchId != null && branchId.isNotEmpty) {
        branchTotals[branchId] = (branchTotals[branchId] ?? 0) + 1;
      }
    }

    final byWarehouse = warehouses.map((w) {
      final id = w['id'].toString();
      final agg = warehouseAgg[id] ?? _Agg();
      return GroupStat(
        id: id,
        name: w['name']?.toString() ?? id,
        totalProducts: warehouseTotals[id] ?? 0,
        countedProducts: agg.counted,
        matched: agg.matched,
        surplus: agg.surplus,
        deficit: agg.deficit,
      );
    }).toList();

    final byBranch = branches.map((b) {
      final id = b['id'].toString();
      final agg = branchAgg[id] ?? _Agg();
      return GroupStat(
        id: id,
        name: b['name']?.toString() ?? id,
        totalProducts: branchTotals[id] ?? 0,
        countedProducts: agg.counted,
        matched: agg.matched,
        surplus: agg.surplus,
        deficit: agg.deficit,
      );
    }).toList();

    final overall = GroupStat(
      id: 'overall',
      name: 'الإجمالي',
      totalProducts: products.length,
      countedProducts: latestByProduct.length,
      matched: overallMatched,
      surplus: overallSurplus,
      deficit: overallDeficit,
    );

    // 5) إحصائية الموظفين - على كل العمليات الفردية (بدون تجميع/آخر جرد
    // بس)، لأن الهدف هون قياس نشاط كل موظف الفعلي
    final employeeAgg = <String, _EmployeeAgg>{};
    for (final s in stocktakes) {
      final agg = employeeAgg.putIfAbsent(s.scannedBy, () => _EmployeeAgg());
      agg.totalScans++;
      agg.productIds.add(s.productId);
      final st = statusOf(s);
      agg.matched += st.matched;
      agg.surplus += st.surplus;
      agg.deficit += st.deficit;
    }

    final employeesById = {for (final e in employees) e['id'].toString(): e};
    final byEmployee = employeeAgg.entries.map((entry) {
      final employee = employeesById[entry.key];
      return EmployeeStat(
        id: entry.key,
        name: employee?['name']?.toString() ?? 'موظف غير معروف',
        totalScans: entry.value.totalScans,
        distinctProducts: entry.value.productIds.length,
        matched: entry.value.matched,
        surplus: entry.value.surplus,
        deficit: entry.value.deficit,
      );
    }).toList()
      ..sort((a, b) => b.totalScans.compareTo(a.totalScans));

    // 6) تفصيل كل صنف على حدة (من "آخر جرد لكل صنف") - يُستخدم لعرض/ترتيب
    // الأصناف حسب حجم الفرق (زيادة أو نقص)، من الأقل للأكثر أو العكس
    final byProduct = latestByProduct.values.map((s) {
      final product = productsById[s.productId];
      return ProductDiscrepancy(
        productId: s.productId,
        name: product?.name ?? 'منتج محذوف',
        barcode: product?.barcode ?? s.barcode,
        expectedQuantity: s.expectedQuantity,
        scannedQuantity: s.scannedQuantity,
      );
    }).toList();

    return DetailedReportResult(
      overall: overall,
      byBranch: byBranch,
      byWarehouse: byWarehouse,
      byEmployee: byEmployee,
      byProduct: byProduct,
    );
  }
}

class _Agg {
  int counted = 0;
  int matched = 0;
  int surplus = 0;
  int deficit = 0;
}

class _EmployeeAgg {
  int totalScans = 0;
  int matched = 0;
  int surplus = 0;
  int deficit = 0;
  final Set<String> productIds = {};
}
