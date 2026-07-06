import 'package:hive/hive.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';

class HiveService {
  static const String productBoxName = 'products';
  static const String stocktakeBoxName = 'stocktakes';
  static const String metaBoxName = 'app_meta';
  static const String _lastProductSyncKey = 'lastProductSyncAt';

  // ==================== بيانات المزامنة (Meta) ====================

  // آخر وقت تمت فيه مزامنة ناجحة لجدول المنتجات
  // null = لم تتم أي مزامنة بعد (يجب سحب كل شيء أول مرة)
  static DateTime? getLastProductSync() {
    final box = Hive.box(metaBoxName);
    final value = box.get(_lastProductSyncKey) as String?;
    return value != null ? DateTime.parse(value) : null;
  }

  static Future<void> setLastProductSync(DateTime time) async {
    final box = Hive.box(metaBoxName);
    await box.put(_lastProductSyncKey, time.toUtc().toIso8601String());
  }

  // يمسح وقت آخر مزامنة، فتصير المزامنة التالية "كاملة" (تجيب كل المنتجات
  // من جديد بدل الفرق فقط) - مفيد لإصلاح كاش محلي ناقص أو غير متسق
  static Future<void> clearLastProductSync() async {
    final box = Hive.box(metaBoxName);
    await box.delete(_lastProductSyncKey);
  }

  // ==================== المنتجات ====================

  // فهرس بالذاكرة (barcode -> ProductModel) لتفادي البحث الخطي (O(n))
  // بكل عملية بحث - مهم جداً مع كتالوجات كبيرة (عشرات/مئات آلاف المنتجات).
  // يُبنى مرة عند أول استخدام، ويُعاد بناؤه تلقائياً (lazy) بعد أي تعديل
  // على المنتجات (حفظ/حذف)، فيضمن دايماً يعكس آخر بيانات محلية.
  static Map<String, ProductModel>? _barcodeIndex;

  static Map<String, ProductModel> _buildBarcodeIndex() {
    final box = Hive.box<ProductModel>(productBoxName);
    final index = <String, ProductModel>{};
    for (final p in box.values) {
      if (p.barcode.isNotEmpty) index[p.barcode] = p;
    }
    return index;
  }

  static void _invalidateBarcodeIndex() {
    _barcodeIndex = null;
  }

  static List<ProductModel> getProducts() {
    return Hive.box<ProductModel>(productBoxName).values.toList();
  }

  // بحث بالباركود - O(1) بدل O(n) (مهم جداً مع كتالوجات كبيرة: يُستدعى
  // مرة لكل عملية مسح، وأيضاً مرة لكل صف بالتقارير)
  static ProductModel? getProductByBarcode(String barcode) {
    _barcodeIndex ??= _buildBarcodeIndex();
    return _barcodeIndex![barcode];
  }

  static Future<void> saveProduct(ProductModel product) async {
    final box = Hive.box<ProductModel>(productBoxName);
    await box.put(product.id, product);
    _invalidateBarcodeIndex();
  }

  // حفظ عدة منتجات دفعة وحدة (bulk save)
  // المنتجات المعلّمة isDeleted=true يتم حذفها محلياً بدل حفظها،
  // لأن الجهاز يحتاج فعلياً حذفها من التخزين المحلي وليس الاحتفاظ بها
  static Future<void> saveProducts(List<ProductModel> products) async {
    final box = Hive.box<ProductModel>(productBoxName);

    final toUpsert = <String, ProductModel>{};
    final idsToDelete = <String>[];

    for (final p in products) {
      if (p.isDeleted) {
        idsToDelete.add(p.id);
      } else {
        toUpsert[p.id] = p;
      }
    }

    if (toUpsert.isNotEmpty) await box.putAll(toUpsert);
    if (idsToDelete.isNotEmpty) await box.deleteAll(idsToDelete);
    _invalidateBarcodeIndex();
  }

  static Future<void> deleteProduct(String id) async {
    final box = Hive.box<ProductModel>(productBoxName);
    await box.delete(id);
    _invalidateBarcodeIndex();
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
