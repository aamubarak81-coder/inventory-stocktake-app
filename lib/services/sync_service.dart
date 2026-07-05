import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/product_model.dart';
import 'discrepancy_alert_service.dart';
import 'hive_service.dart';
import 'supabase_service.dart';

class SyncService {
  static Future<bool> isOnline() async {
    final dynamic result = await Connectivity().checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
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
