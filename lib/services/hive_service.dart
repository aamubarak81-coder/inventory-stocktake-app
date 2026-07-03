import 'package:hive/hive.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';

class HiveService {
  static const String productBoxName = 'products';
  static const String stocktakeBoxName = 'stocktakes';

  // ==================== المنتجات ====================

  static List<ProductModel> getProducts() {
    return Hive.box<ProductModel>(productBoxName).values.toList();
  }

  static ProductModel? getProductByBarcode(String barcode) {
    final box = Hive.box<ProductModel>(productBoxName);
    try {
      return box.values.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      return null; // ما لقيناش منتج بهاد الباركود
    }
  }

  static Future<void> saveProduct(ProductModel product) async {
    final box = Hive.box<ProductModel>(productBoxName);
    await box.put(product.id, product);
  }

  // حفظ عدة منتجات دفعة وحدة (bulk save)
  static Future<void> saveProducts(List<ProductModel> products) async {
    final box = Hive.box<ProductModel>(productBoxName);
    final Map<String, ProductModel> entries = {
      for (var p in products) p.id: p
    };
    await box.putAll(entries);
  }

  static Future<void> deleteProduct(String id) async {
    final box = Hive.box<ProductModel>(productBoxName);
    await box.delete(id);
  }

  static List<ProductModel> getUnsyncedProducts() {
    return Hive.box<ProductModel>(productBoxName)
        .values
        .where((p) => !p.isSynced)
        .toList();
  }

  static Future<void> markProductSynced(String id) async {
    final box = Hive.box<ProductModel>(productBoxName);
    final product = box.get(id);
    if (product != null) {
      product.isSynced = true;
      await product.save();
    }
  }

  // ==================== الجرد (Stocktakes) ====================

  static List<StocktakeModel> getStocktakes() {
    return Hive.box<StocktakeModel>(stocktakeBoxName).values.toList();
  }

  static List<StocktakeModel> getStocktakesBySession(String sessionId) {
    return Hive.box<StocktakeModel>(stocktakeBoxName)
        .values
        .where((s) => s.sessionId == sessionId)
        .toList();
  }

  static Future<void> saveStocktake(StocktakeModel stocktake) async {
    final box = Hive.box<StocktakeModel>(stocktakeBoxName);
    await box.put(stocktake.id, stocktake);
  }

  static List<StocktakeModel> getUnsyncedStocktakes() {
    return Hive.box<StocktakeModel>(stocktakeBoxName)
        .values
        .where((s) => !s.isSynced)
        .toList();
  }

  static Future<void> markStocktakeSynced(String id) async {
    final box = Hive.box<StocktakeModel>(stocktakeBoxName);
    final stocktake = box.get(id);
    if (stocktake != null) {
      stocktake.isSynced = true;
      await stocktake.save();
    }
  }
}
