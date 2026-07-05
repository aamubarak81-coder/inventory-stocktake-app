import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';
import 'auth_service.dart';
import 'discrepancy_calculator.dart';

/// الحلقة الوصل بين:
/// - DiscrepancyCalculator (منطق الحساب الصرف)
/// - جدول org_settings (قيم الـ threshold الفعلية لكل منظمة)
/// - جدول discrepancy_alerts (تخزين الفروقات المكتشفة بدون تكرار)
class DiscrepancyAlertService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String orgSettingsTable = 'org_settings';
  static const String alertsTable = 'discrepancy_alerts';

  /// جلب إعدادات الـ threshold الخاصة بالمنظمة الحالية.
  /// لو ما في صف بعد بجدول org_settings (منظمة جديدة لسه ما ضبطت
  /// إعداداتها)، نرجع نفس القيم الافتراضية المستخدمة بالـ Calculator.
  static Future<DiscrepancyThreshold> fetchThreshold() async {
    final orgId = await AuthService.getOrgId();
    if (orgId == null) return DiscrepancyThreshold.defaultThreshold;

    try {
      final row = await _client
          .from(orgSettingsTable)
          .select('alert_threshold_percent, alert_threshold_qty')
          .eq('org_id', orgId)
          .maybeSingle();

      if (row == null) return DiscrepancyThreshold.defaultThreshold;

      return DiscrepancyThreshold(
        percentThreshold: (row['alert_threshold_percent'] as num).toDouble(),
        quantityThreshold: row['alert_threshold_qty'] as int,
      );
    } catch (_) {
      // أي خطأ بجلب الإعدادات (اتصال، صلاحيات...) ما لازم يوقف
      // المزامنة كلها - نرجع القيم الافتراضية بأمان
      return DiscrepancyThreshold.defaultThreshold;
    }
  }

  /// يحسب الفروقات لدفعة سجلات جرد تم رفعها للتو، ويحفظ فقط
  /// الفروقات المتجاوزة للحد بجدول discrepancy_alerts.
  ///
  /// [stocktakes] يجب تكون فقط السجلات يلي انرفعت بنجاح بهذه الدورة
  /// (مش كل تاريخ الجرد) - حتى ما نعيد حساب فروقات قديمة كل مرة.
  ///
  /// الحماية من التكرار على مستويين:
  /// 1. upsert مع onConflict على stocktake_id (هون بالكود)
  /// 2. unique constraint على stocktake_id بالجدول نفسه (بقاعدة البيانات)
  ///
  /// يرجع عدد التنبيهات الجديدة المحفوظة فعلياً.
  static Future<int> processAndSaveAlerts({
    required List<StocktakeModel> stocktakes,
    required Map<String, ProductModel> productsById,
  }) async {
    if (stocktakes.isEmpty) return 0;

    final orgId = await AuthService.getOrgId();
    if (orgId == null) return 0;

    final threshold = await fetchThreshold();

    final results = DiscrepancyCalculator.calculateBatch(
      stocktakes: stocktakes,
      productsById: productsById,
      threshold: threshold,
    );

    final exceeding = DiscrepancyCalculator.filterExceeding(results);
    if (exceeding.isEmpty) return 0;

    final rows = exceeding
        .map((r) => {
              'org_id': orgId,
              'product_id': r.productId,
              'stocktake_id': r.stocktakeId,
              'scanned_quantity': r.scannedQuantity,
              'expected_quantity': r.expectedQuantity,
              'diff_quantity': r.diffQuantity,
              'diff_percent': r.diffPercent,
              'trigger_reason': _triggerToString(r.trigger),
            })
        .toList();

    try {
      await _client.from(alertsTable).upsert(
            rows,
            onConflict: 'stocktake_id',
            ignoreDuplicates: true,
          );
    } catch (e) {
      // فشل حفظ التنبيهات ما لازم يفشّل كل عملية المزامنة -
      // بيانات الجرد نفسها أهم وانحفظت أصلاً بنجاح قبل هالخطوة
      return 0;
    }

    return exceeding.length;
  }

  static String _triggerToString(DiscrepancyTrigger t) {
    switch (t) {
      case DiscrepancyTrigger.percent:
        return 'percent';
      case DiscrepancyTrigger.quantity:
        return 'quantity';
      case DiscrepancyTrigger.both:
        return 'both';
      case DiscrepancyTrigger.none:
        return 'none'; // ما لازم يوصلها أصلاً - filterExceeding بيستبعدها
    }
  }
}
