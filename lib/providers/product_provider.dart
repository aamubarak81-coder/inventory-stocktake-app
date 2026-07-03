import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/hive_service.dart';

class ProductProvider extends ChangeNotifier {
  List<ProductModel> _products = [];

  List<ProductModel> get products => _products;

  // جلب المنتجات من التخزين المحلي (Hive) وعرضها فوراً
  void loadProducts() {
    _products = HiveService.getProducts();
    notifyListeners();
  }

  // إضافة منتج جديد
  Future<void> addProduct(ProductModel product) async {
    await HiveService.saveProduct(product);
    loadProducts();
  }

  // تحديث منتج موجود
  Future<void> updateProduct(ProductModel product) async {
    await HiveService.saveProduct(product);
    loadProducts();
  }

  // تجميد / إلغاء تجميد منتج أثناء الجرد
  Future<void> toggleFreeze(ProductModel product) async {
    product.isFrozen = !product.isFrozen;
    await HiveService.saveProduct(product);
    loadProducts();
  }
}
