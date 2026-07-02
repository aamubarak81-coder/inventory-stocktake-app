import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';
import '../services/hive_service.dart';

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
  }) async {
    if (_currentSessionId == null) {
      startNewSession();
    }

    final product = HiveService.getProductByBarcode(barcode);
    if (product == null) {
      return null;
    }

    final entry = StocktakeModel(
      id: _uuid.v4(),
      sessionId: _currentSessionId!,
      productId: product.id,
      barcode: barcode,
      countedQuantity: countedQuantity,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    await HiveService.saveStocktake(entry);
    _currentSessionEntries.add(entry);
    notifyListeners();

    return product;
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
