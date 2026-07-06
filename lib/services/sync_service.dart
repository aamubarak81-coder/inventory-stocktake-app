import 'dart:async' show unawaited;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import '../models/product_model.dart';
import 'discrepancy_alert_service.dart';
import 'hive_service.dart';
import 'supabase_service.dart';

class SyncService {
  static bool _isSyncing = false;
  static bool _syncAgainRequested = false;

  /// تعكس هل في مزامنة تلقائية (بالخلفية) شغالة حالياً - أي شاشة تقدر
  /// تستمع لها (ValueListenableBuilder) لعرض مؤشر بسيط للمستخدم لو حبت،
  /// بدون ما تكون مضطرة تدير الحالة بنفسها.
  static final ValueNotifier<bool> autoSyncingNotifier = ValueNotifier(false);

  static Future<bool> isOnline() async {
    final dynamic result = await Connectivity().checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }

  /// نسخة "آمنة من التداخل" من syncAll، مخصصة للمزامنة التلقائية بالخلفية
  /// (مثلاً فور تسجيل عملية جرد). لو في مزامنة شغالة أصلاً، ما نبدأ وحدة
  /// جديدة فوق بعض - بس نسجّل طلب "شغّلها كمان مرة" بعد ما تخلص الحالية،
  /// عشان نغطي أي عملية جرد جديدة انسجلت أثناء تنفيذ المزامنة الحالية.
  /// بترجع null لو تخطّت التنفيذ بسبب مزامنة شغالة أصلاً (مو فشل حقيقي).
  static Future<SyncResult?> syncIfIdle() async {
    if (_isSyncing) {
      _syncAgainRequested = true;
      return null;
    }

    _isSyncing = true;
    autoSyncingNotifier.value = true;
    SyncResult result;
    try {
      result = await syncAll();
    } finally {
      _isSyncing = false;
    }

    if (_syncAgainRequested) {
      _syncAgainRequested = false;
      // نطلقها بدون انتظار (fire-and-forget) عشان ما نأخر الاستدعاء الحالي
      unawaited(syncIfIdle());
    } else {
      autoSyncingNotifier.value = false;
    }

    return result;
  }

  static Future<SyncResult> syncAll() async {
    if (!await isOnline()) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
        syncedProducts: 0,
        syncedStocktakes: 0,
      );
    }

    int syncedProducts = 0;
    int syncedStocktakes = 0;
    int syncedAlerts = 0;

    try {
      // 1) رفع الجرد المحلي غير المتزامن أولاً (كما كان سابقاً)
      final unsyncedStocktakes = HiveService.getUnsyncedStocktakes();
      for (final stocktake in unsyncedStocktakes) {
        await SupabaseService.saveStocktake(stocktake);
        await HiveService.markStocktakeSynced(stocktake.id);
        syncedStocktakes++;
      }

      // 1.5) حساب الفروقات لدفعة الجرد يلي انرفعت للتو، وحفظ أي فرق
      // يتجاوز الـ threshold بجدول discrepancy_alerts (بدون تكرار).
      // نستخدم المنتجات الموجودة محلياً حالياً كمرجع - وهذا كافي لأنه
      // كل منتج فيه lastUpdated أحدث من وقت المزامنة الأخيرة لو تغيّر.
      if (unsyncedStocktakes.isNotEmpty) {
        try {
          final productsById = <String, ProductModel>{
            for (final p in HiveService.getProducts()) p.id: p,
          };
          syncedAlerts = await DiscrepancyAlertService.processAndSaveAlerts(
            stocktakes: unsyncedStocktakes,
            productsById: productsById,
          );
        } catch (_) {
          // فشل حساب/حفظ التنبيهات ما لازم يوقف باقي المزامنة
          syncedAlerts = 0;
        }
      }

      // 2) سحب المنتجات: تدريجياً (delta) وليس الكل في كل مرة
      // نأخذ وقت البدء *قبل* الجلب، ونستخدمه كـ "آخر وقت مزامنة" الجديد
      // فقط بعد نجاح الحفظ محلياً - لتفادي فقدان تحديثات لو انقطع الاتصال بالمنتصف
      final syncStartedAt = DateTime.now().toUtc();
      final lastSync = HiveService.getLastProductSync();

      final serverProducts = await SupabaseService.fetchProducts(
        updatedSince: lastSync, // null = أول مزامنة، يرجّع كل شيء كالسابق
      );

      await HiveService.saveProducts(serverProducts);
      syncedProducts = serverProducts.length;

      await HiveService.setLastProductSync(syncStartedAt);

      return SyncResult(
        success: true,
        message: 'Sync completed successfully',
        syncedProducts: syncedProducts,
        syncedStocktakes: syncedStocktakes,
        syncedAlerts: syncedAlerts,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedProducts: syncedProducts,
        syncedStocktakes: syncedStocktakes,
        syncedAlerts: syncedAlerts,
      );
    }
  }

  static Future<void> downloadProducts() async {
    if (!await isOnline()) {
      throw Exception('No internet connection');
    }
    final products = await SupabaseService.fetchProducts();
    await HiveService.saveProducts(products);
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedProducts;
  final int syncedStocktakes;
  final int syncedAlerts;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedProducts,
    required this.syncedStocktakes,
    this.syncedAlerts = 0,
  });
}
