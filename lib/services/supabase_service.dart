import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String productsTable = 'products';
  static const String stocktakesTable = 'stocktakes';

  static Future<List<ProductModel>> fetchProducts() async {
    final response = await _client.from(productsTable).select();
    return (response as List)
        .map((row) => ProductModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveStocktake(StocktakeModel stocktake) async {
    await _client.from(stocktakesTable).upsert(stocktake.toMap());
  }

  static Future<void> saveProduct(ProductModel product) async {
    await _client.from(productsTable).upsert(product.toMap());
  }
}
