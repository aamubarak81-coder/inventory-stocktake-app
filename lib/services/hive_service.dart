import 'package:hive_flutter/hive_flutter.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';

class HiveService {
  static const String productsBoxName = 'products';
  static const String stocktakesBoxName = 'stocktakes';

  static late Box<ProductModel> _productsBox;
  static late Box<StocktakeModel> _stocktakesBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProductModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(StocktakeModelAdapter());
    }

    _productsBox = await Hive.openBox<ProductModel>(productsBoxName);
    _stocktakesBox = await Hive.openBox<StocktakeModel>(stocktakesBoxName);
  }

  static Future<void> saveProducts(List<ProductModel> products) async {
    final Map<String, ProductModel> entries = {
      for (final product in products) product.id: product,
    };
    await _productsBox.putAll(entries);
  }

  static List<ProductModel> getProducts() {
    return _productsBox.values.toList();
  }

  static ProductModel? getProductByBarcode(String barcode) {
    try {
      return _productsBox.values.firstWhere(
        (product) => product.barcode == barcode,
      );
    } catch (_) {
      return null;
    }
  }

  static List<ProductModel> getUnsyncedProducts() {
    return _productsBox.values.where((product) => !product.isSynced).toList();
  }

  static Future<void> markProductSynced(String id) async {
    final product = _productsBox.get(id);
    if (product != null) {
      product.isSynced = true;
      await product.save();
    }
  }

  static Future<void> saveStocktake(StocktakeModel stocktake) async {
    await _stocktakesBox.put(stocktake.id, stocktake);
  }

  static List<StocktakeModel> getStocktakes() {
    return _stocktakesBox.values.toList();
  }

  static List<StocktakeModel> getStocktakesBySession(String sessionId) {
    return _stocktakesBox.values
        .where((stocktake) => stocktake.sessionId == sessionId)
        .toList();
  }

  static List<StocktakeModel> getUnsyncedStocktakes() {
    return _stocktakesBox.values
        .where((stocktake) => !stocktake.isSynced)
        .toList();
  }

  static Future<void> markStocktakeSynced(String id) async {
    final stocktake = _stocktakesBox.get(id);
    if (stocktake != null) {
      stocktake.isSynced = true;
      await stocktake.save();
    }
  }

  static Future<void> clearAll() async {
    await _productsBox.clear();
    await _stocktakesBox.clear();
  }
}
