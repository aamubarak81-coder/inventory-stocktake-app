import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';
import 'auth_service.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String productsTable = 'products';
  static const String stocktakesTable = 'stocktakes';
  static const int _pageSize = 500;

  // جلب كل منتجات المنظمة الحالية فقط، على دفعات
  static Future<List<ProductModel>> fetchProducts() async {
    final orgId = await AuthService.getOrgId();
    if (orgId == null) return [];

    final List<ProductModel> allProducts = [];
    int from = 0;
    bool hasMore = true;

    while (hasMore) {
      final response = await _client
          .from(productsTable)
          .select()
          .eq('org_id', orgId)
          .range(from, from + _pageSize - 1);

      final data = response as List;
      if (data.isEmpty) {
        hasMore = false;
        break;
      }

      allProducts.addAll(
        data.map((row) => ProductModel.fromMap(row as Map<String, dynamic>)),
      );

      if (data.length < _pageSize) {
        hasMore = false;
      } else {
        from += _pageSize;
      }
    }

    return allProducts;
  }

  static Future<void> saveProduct(ProductModel product) async {
    await _client.from(productsTable).upsert(product.toMap());
  }

  static Future<void> saveStocktake(StocktakeModel stocktake) async {
    await _client.from(stocktakesTable).upsert(stocktake.toMap());
  }
}
