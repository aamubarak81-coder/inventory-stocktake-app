import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';
import '../services/hive_service.dart';
import '../services/auth_service.dart';

class StocktakeProvider extends ChangeNotifier {
  final Uuid _uuid = const Uuid();

  String? _currentSessionId;
  List<StocktakeModel> _currentSessionEntries = [];

  String? get currentSessionId => _currentSessionId;
  List<StocktakeModel> get currentSessionEntries => _currentSessionEntries;

  String startNewSession() {
    _currentSessionId = _uuid.v4();
    _currentSessionEntries = [];
    notifyListeners();
    return _currentSessionId!;
  }

  void loadSession(String sessionId) {
    _currentSessionId = sessionId;
    _currentSessionEntries = HiveService.getStocktakesBySession(sessionId);
    notifyListeners();
  }

  Future<ProductModel?> recordCount({
    required String barcode,
    required int countedQuantity,
    bool isBlindCount = true,
    double? latitude,
    double? longitude,
  }) async {
    if (_currentSessionId == null) {
      startNewSession();
    }

    final product = HiveService.getProductByBarcode(barcode);
    if (product == null) {
      return null;
    }

    // جلب بيانات المستخدم الحالي (المنظمة والموظف) من الجلسة المخزنة
    final orgId = await AuthService.getOrgId();
    final employeeId = await AuthService.getEmployeeId();

    if (orgId == null || employeeId == null) {
      return null; // ما فيه مستخدم مسجل دخول حالياً
    }

    final entry = StocktakeModel(
      id: _uuid.v4(),
      sessionId: _currentSessionId!,
      orgId: orgId,
      productId: product.id,
      barcode: barcode,
      scannedQuantity: countedQuantity,
      expectedQuantity: product.systemQuantity,
      isBlindCount: isBlindCount,
      latitude: latitude,
      longitude: longitude,
      scannedBy: employeeId,
      scannedAt: DateTime.now(),
      isSynced: false,
      locationRef: product.locationRef,
    );

    await HiveService.saveStocktake(entry);
    _currentSessionEntries.add(entry);
    notifyListeners();

    return product;
  }

  // دالة مساعدة للبحث عن منتج بالباركود من الشاشة
  ProductModel? getProductByBarcode(String barcode) {
    return HiveService.getProductByBarcode(barcode);
  }

  void removeFromView(String entryId) {
    _currentSessionEntries.removeWhere((entry) => entry.id == entryId);
    notifyListeners();
  }

  void refresh() {
    if (_currentSessionId != null) {
      _currentSessionEntries =
          HiveService.getStocktakesBySession(_currentSessionId!);
      notifyListeners();
    }
  }

  void endSession() {
    _currentSessionId = null;
    _currentSessionEntries = [];
    notifyListeners();
  }
}
