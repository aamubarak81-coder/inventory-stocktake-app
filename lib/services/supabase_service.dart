import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';
import 'auth_service.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String productsTable = 'products';
  static const String stocktakesTable = 'stocktakes';
  static const int _pageSize = 500;

  // جلب منتجات المنظمة الحالية، على دفعات
  // إذا مُرر [updatedSince]، نجلب فقط المنتجات المعدّلة بعد هذا الوقت
  // (مزامنة تدريجية / delta) بدل تحميل كل المنتجات في كل مرة.
  // إذا كانت null، هذه أول مزامنة → نجلب كل شيء كما كان سابقاً.
  static Future<List<ProductModel>> fetchProducts({
    DateTime? updatedSince,
  }) async {
    final orgId = await AuthService.getOrgId();
    if (orgId == null) return [];

    final List<ProductModel> allProducts = [];
    int from = 0;
    bool hasMore = true;

    while (hasMore) {
      var query = _client.from(productsTable).select().eq('org_id', orgId);
      // ملاحظة: لا نفلتر is_deleted هنا عمداً — لازم نجلب السجلات المحذوفة
      // أيضاً (طالما هي ضمن نطاق updatedSince) حتى يعرف الجهاز أنها انحذفت
      // ويحذفها من التخزين المحلي. لو فلترناها هون، لن يعرف الجهاز أبداً
      // أن منتجاً محلياً انحذف على السيرفر.

      if (updatedSince != null) {
        // نستخدم gt (وليس gte) لتفادي إعادة جلب نفس آخر سجل تمت مزامنته
        query = query.gt('updated_at', updatedSince.toUtc().toIso8601String());
      }

      final response = await query
          .order('updated_at') // مهم لضمان ترتيب ثابت عبر الصفحات (pagination)
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
