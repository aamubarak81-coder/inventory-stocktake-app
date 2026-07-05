import '../models/product_model.dart';
import '../models/stocktake_model.dart';

/// إعدادات الحد الأدنى (Threshold) لتفعيل تنبيه الفروقات
///
/// التنبيه يتفعّل إذا تحقق أي شرط من الشرطين (أيهما أسبق):
/// - نسبة الفرق ≥ [percentThreshold] (مثلاً 0.05 = 5%)
/// - أو قيمة الفرق المطلقة ≥ [quantityThreshold] (مثلاً 10 قطع)
///
/// هذي القيم لاحقاً رح تجي من جدول `org_settings` بدل ما تكون ثابتة بالكود.
class DiscrepancyThreshold {
  final double percentThreshold;
  final int quantityThreshold;

  const DiscrepancyThreshold({
    required this.percentThreshold,
    required this.quantityThreshold,
  });

  /// قيمة افتراضية معقولة للتجربة والتطوير: 5% أو 10 قطع
  static const DiscrepancyThreshold defaultThreshold = DiscrepancyThreshold(
    percentThreshold: 0.05,
    quantityThreshold: 10,
  );
}

/// سبب تفعيل التنبيه - مفيد لعرض تفاصيل أوضح بلوحة التحكم
enum DiscrepancyTrigger {
  none, // ما تجاوز أي حد
  percent, // تجاوز النسبة فقط
  quantity, // تجاوز العدد الثابت فقط
  both, // تجاوز الاثنين معاً
}

/// نتيجة حساب الفرق لسجل جرد واحد
class DiscrepancyResult {
  final String stocktakeId;
  final String productId;
  final String productName;
  final String barcode;
  final int expectedQuantity;
  final int scannedQuantity;

  /// الفرق بإشارته: موجب = زيادة فعلية عن المتوقع، سالب = نقص
  final int diffQuantity;

  /// نسبة الفرق المطلقة من الكمية المتوقعة (0.05 = 5%)
  final double diffPercent;

  final bool exceedsThreshold;
  final DiscrepancyTrigger trigger;

  DiscrepancyResult({
    required this.stocktakeId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.expectedQuantity,
    required this.scannedQuantity,
    required this.diffQuantity,
    required this.diffPercent,
    required this.exceedsThreshold,
    required this.trigger,
  });

  bool get isShortage => diffQuantity < 0; // نقص (المفقودات)
  bool get isSurplus => diffQuantity > 0; // زيادة
}

/// دالة حساب الفروقات ومقارنتها بالـ Threshold
/// pure logic بالكامل - ما بتعتمد على Supabase ولا Hive، فبنقدر نختبرها لحالها
class DiscrepancyCalculator {
  /// حساب فرق سجل جرد واحد مقابل منتج واحد
  /// يرجع null إذا كان الجرد "أعمى" (blind count) وما في expectedQuantity
  /// أصلاً لمقارنته - هذا السيناريو لازم يُقيّم لاحقاً بعد مطابقته يدوياً
  static DiscrepancyResult? calculate({
    required StocktakeModel stocktake,
    required ProductModel product,
    DiscrepancyThreshold threshold = DiscrepancyThreshold.defaultThreshold,
  }) {
    final expected = stocktake.expectedQuantity;
    if (expected == null) return null;

    final scanned = stocktake.scannedQuantity;
    final diffQty = scanned - expected;
    final absDiffQty = diffQty.abs();

    // تفادي القسمة على صفر: لو الكمية المتوقعة أصلاً صفر،
    // أي فرق عن صفر يعتبر نسبة 100% (أقصى تنبيه ممكن)
    final double diffPercent =
        expected == 0 ? (absDiffQty == 0 ? 0.0 : 1.0) : absDiffQty / expected;

    final exceedsPercent = diffPercent >= threshold.percentThreshold;
    final exceedsQty = absDiffQty >= threshold.quantityThreshold;

    final DiscrepancyTrigger trigger;
    if (exceedsPercent && exceedsQty) {
      trigger = DiscrepancyTrigger.both;
    } else if (exceedsPercent) {
      trigger = DiscrepancyTrigger.percent;
    } else if (exceedsQty) {
      trigger = DiscrepancyTrigger.quantity;
    } else {
      trigger = DiscrepancyTrigger.none;
    }

    return DiscrepancyResult(
      stocktakeId: stocktake.id,
      productId: product.id,
      productName: product.name,
      barcode: product.barcode,
      expectedQuantity: expected,
      scannedQuantity: scanned,
      diffQuantity: diffQty,
      diffPercent: diffPercent,
      exceedsThreshold: trigger != DiscrepancyTrigger.none,
      trigger: trigger,
    );
  }

  /// حساب دفعة كاملة من سجلات الجرد دفعة وحدة
  /// [productsById] خريطة لسرعة البحث O(1) بدل البحث الخطي بكل مرة
  static List<DiscrepancyResult> calculateBatch({
    required List<StocktakeModel> stocktakes,
    required Map<String, ProductModel> productsById,
    DiscrepancyThreshold threshold = DiscrepancyThreshold.defaultThreshold,
  }) {
    final results = <DiscrepancyResult>[];

    for (final s in stocktakes) {
      final product = productsById[s.productId];
      if (product == null) continue; // منتج غير موجود محلياً - تجاهله بأمان

      final result = calculate(
        stocktake: s,
        product: product,
        threshold: threshold,
      );
      if (result != null) results.add(result);
    }

    return results;
  }

  /// فلترة سريعة: فقط الفروقات اللي فعلاً تجاوزت الحد (جاهزة للتنبيه)
  static List<DiscrepancyResult> filterExceeding(
    List<DiscrepancyResult> results,
  ) {
    return results.where((r) => r.exceedsThreshold).toList();
  }
}
