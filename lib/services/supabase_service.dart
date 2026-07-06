import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';
import 'auth_service.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String productsTable = 'products';
  static const String stocktakesTable = 'stocktakes';
  static const int _pageSize = 1000; // كانت 500 - صفحة أكبر تعني عدد
      // استعلامات أقل لنفس الكمية، وبالتالي مزامنة أولى أسرع
  static const int _maxConcurrentPages = 6; // حد أقصى للاستعلامات
      // المتوازية بنفس الوقت، عشان ما نضغط السيرفر (خصوصاً بخطط Supabase
      // المجانية اللي عندها حد أقصى لعدد الاتصالات المتزامنة)

  // فلتر الاستعلام المشترك (org + updatedSince)، كدالة تُنشئ Query جديد
  // بكل استدعاء - يضمن كل صفحة تستخدم query builder مستقل (آمن للتوازي،
  // بدون أي حالة مشتركة بين الاستعلامات المتزامنة)
  static PostgrestFilterBuilder<PostgrestList> _baseProductsQuery(
    String orgId,
    DateTime? updatedSince,
  ) {
    var query = _client.from(productsTable).select().eq('org_id', orgId);
    // ملاحظة: لا نفلتر is_deleted هنا عمداً — لازم نجلب السجلات المحذوفة
    // أيضاً (طالما هي ضمن نطاق updatedSince) حتى يعرف الجهاز أنها انحذفت
    // ويحذفها من التخزين المحلي. لو فلترناها هون، لن يعرف الجهاز أبداً
    // أن منتجاً محلياً انحذف على السيرفر.
    if (updatedSince != null) {
      // نستخدم gt (وليس gte) لتفادي إعادة جلب نفس آخر سجل تمت مزامنته
      query = query.gt('updated_at', updatedSince.toUtc().toIso8601String());
    }
    return query;
  }

  static Future<List<ProductModel>> _fetchProductPage(
    String orgId,
    DateTime? updatedSince,
    int from,
  ) async {
    final response = await _baseProductsQuery(orgId, updatedSince)
        .order('updated_at') // الترتيب الأساسي (للمزامنة التدريجية)
        .order('id') // معيار ثانوي فريد - يضمن ترتيب ثابت 100% حتى لو
            // تساوى updated_at بين عدة صفوف (شائع بعد استيراد جماعي)،
            // وإلا pagination بالـ range() ممكن تتخطى أو تكرر صفوف
            // بشكل غير متوقع بين استعلام وتاني
        .range(from, from + _pageSize - 1);

    final data = response as List;
    return data
        .map((row) => ProductModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // جلب منتجات المنظمة الحالية، على دفعات متوازية (بدل التسلسل صفحة
  // صفحة) - يقلّل زمن أول مزامنة كاملة بشكل كبير مع كتالوجات كبيرة.
  // إذا مُرر [updatedSince]، نجلب فقط المنتجات المعدّلة بعد هذا الوقت
  // (مزامنة تدريجية / delta) بدل تحميل كل المنتجات في كل مرة.
  // إذا كانت null، هذه أول مزامنة → نجلب كل شيء.
  static Future<List<ProductModel>> fetchProducts({
    DateTime? updatedSince,
  }) async {
    final orgId = await AuthService.getOrgId();
    if (orgId == null) return [];

    // 1) نجيب العدد الكلي أول شي، عشان نعرف كم صفحة محتاجين ونجيبهم
    // بالتوازي بدل التسلسل. لو فشل العدّ لأي سبب (مثلاً نسخة قديمة من
    // PostgREST لا تدعمه)، نرجع لأسلوب "صفحة وحدة بالتخمين" كـ fallback
    // آمن (يشتغل صح، بس بدون فائدة التوازي).
    int? totalCount;
    try {
      var countQuery = _client.from(productsTable).count().eq('org_id', orgId);
      if (updatedSince != null) {
        countQuery =
            countQuery.gt('updated_at', updatedSince.toUtc().toIso8601String());
      }
      totalCount = await countQuery;
    } catch (_) {
      totalCount = null;
    }

    if (totalCount == 0) return [];

    final List<ProductModel> allProducts = [];

    if (totalCount != null) {
      // مسار سريع: نعرف العدد الكلي مسبقاً، فنجيب كل الصفحات على دفعات
      // متوازية (بحد أقصى _maxConcurrentPages بنفس الوقت)
      final totalPages = (totalCount / _pageSize).ceil();

      for (var batchStart = 0; batchStart < totalPages; batchStart += _maxConcurrentPages) {
        final batchEnd =
            (batchStart + _maxConcurrentPages).clamp(0, totalPages);
        final futures = <Future<List<ProductModel>>>[
          for (var page = batchStart; page < batchEnd; page++)
            _fetchProductPage(orgId, updatedSince, page * _pageSize),
        ];
        final pages = await Future.wait(futures);
        for (final page in pages) {
          allProducts.addAll(page);
        }
      }
    } else {
      // مسار احتياطي: العدّ فشل، نرجع للتسلسل القديم الآمن (صفحة ورا
      // الثانية) بدون التوازي
      var from = 0;
      var hasMore = true;
      while (hasMore) {
        final page = await _fetchProductPage(orgId, updatedSince, from);
        if (page.isEmpty) break;
        allProducts.addAll(page);
        if (page.length < _pageSize) {
          hasMore = false;
        } else {
          from += _pageSize;
        }
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
