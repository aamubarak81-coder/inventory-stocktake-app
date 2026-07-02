import 'package:connectivity_plus/connectivity_plus.dart';
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

    try {
      final serverProducts = await SupabaseService.fetchProducts();
      await HiveService.saveProducts(serverProducts);
      syncedProducts = serverProducts.length;

      final unsyncedStocktakes = HiveService.getUnsyncedStocktakes();
      for (final stocktake in unsyncedStocktakes) {
        await SupabaseService.saveStocktake(stocktake);
        await HiveService.markStocktakeSynced(stocktake.id);
        syncedStocktakes++;
      }

      return SyncResult(
        success: true,
        message: 'Sync completed successfully',
        syncedProducts: syncedProducts,
        syncedStocktakes: syncedStocktakes,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedProducts: syncedProducts,
        syncedStocktakes: syncedStocktakes,
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

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedProducts,
    required this.syncedStocktakes,
  });
}
