import '../services/hive_service.dart';
import '../services/supabase_service.dart';

class ProductRepository {
  static Future<List<dynamic>> getAllProducts() async {
    final local = HiveService.getProducts();
    if (local.isNotEmpty) return local;
    final server = await SupabaseService.fetchProducts();
    await HiveService.saveProducts(server);
    return server;
  }

  static Future<dynamic> getByBarcode(String barcode) async {
    return HiveService.getProductByBarcode(barcode);
  }

  static Future<void> refreshFromServer() async {
    final products = await SupabaseService.fetchProducts();
    await HiveService.saveProducts(products);
  }
}
