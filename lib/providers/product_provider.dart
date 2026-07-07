import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/hive_service.dart';

class ProductProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  String _searchQuery = '';

  List<ProductModel> get products => _products;

  // القائمة بعد تطبيق البحث (بالاسم أو الباركود). لو مافي بحث، بترجع كل
  // المنتجات كما هي. الفلترة بالذاكرة (O(n)) كافية وسريعة حتى مع عشرات
  // آلاف الأصناف - لا تحتاج فهرسة خاصة، النص وحده كافي.
  List<ProductModel> get filteredProducts {
    if (_searchQuery.trim().isEmpty) return _products;
    final q = _searchQuery.trim().toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) || p.barcode.contains(q))
        .toList();
  }

  bool get isSearching => _searchQuery.trim().isNotEmpty;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

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
