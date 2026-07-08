import 'package:flutter/material.dart';
import '../models/stocktake_result_model.dart';

class ReportProvider extends ChangeNotifier {
  List<StocktakeResultModel> _allResults = [];

  String _selectedBranch = 'كل الفروع';
  String _selectedWarehouse = 'كل المستودعات';
  String _selectedEmployee = 'كل الموظفين';

  List<StocktakeResultModel> get allResults => _allResults;

  String get selectedBranch => _selectedBranch;
  String get selectedWarehouse => _selectedWarehouse;
  String get selectedEmployee => _selectedEmployee;

  List<StocktakeResultModel> get filteredResults {
    return _allResults.where((item) {
      final matchBranch = _selectedBranch == 'كل الفروع' || item.branch == _selectedBranch;
      final matchWarehouse = _selectedWarehouse == 'كل المستودعات' || item.warehouse == _selectedWarehouse;
      final matchEmployee = _selectedEmployee == 'كل الموظفين' || item.employee == _selectedEmployee;
      return matchBranch && matchWarehouse && matchEmployee;
    }).toList();
  }

  int get totalCount => filteredResults.length;
  int get matchedCount => filteredResults.where((r) => r.status == 'مطابق').length;
  int get excessCount => filteredResults.where((r) => r.status == 'زيادة').length;
  int get shortageCount => filteredResults.where((r) => r.status == 'نقص').length;
  int get unsyncedCount => filteredResults.where((r) => r.id.isEmpty).length;

  double get coveragePercent {
    if (totalCount == 0) return 0;
    return (matchedCount / totalCount) * 100;
  }

  List<String> get branches {
    final set = _allResults.map((e) => e.branch).toSet().toList();
    return ['كل الفروع', ...set];
  }

  List<String> get warehouses {
    final set = _allResults.map((e) => e.warehouse).toSet().toList();
    return ['كل المستودعات', ...set];
  }

  List<String> get employees {
    final set = _allResults.map((e) => e.employee).toSet().toList();
    return ['كل الموظفين', ...set];
  }

  void setBranch(String value) {
    _selectedBranch = value;
    notifyListeners();
  }

  void setWarehouse(String value) {
    _selectedWarehouse = value;
    notifyListeners();
  }

  void setEmployee(String value) {
    _selectedEmployee = value;
    notifyListeners();
  }

  void loadData(List<StocktakeResultModel> data) {
    _allResults = data;
    notifyListeners();
  }

  void loadDummyData() {
    _allResults = [
      StocktakeResultModel(
        id: '14160', productName: 'فواصل بلاط 1ملي قولدن فالكون شد 200',
        branch: 'الرياض', warehouse: 'المستودع الرئيسي', employee: 'أحمد',
        expectedQty: 200, actualQty: 212, date: DateTime.now(),
      ),
      StocktakeResultModel(
        id: '12810', productName: 'محبس هواء 3/4 بوصة بينو',
        branch: 'الرياض', warehouse: 'المستودع الرئيسي', employee: 'أحمد',
        expectedQty: 200, actualQty: 50, date: DateTime.now(),
      ),
      StocktakeResultModel(
        id: '12250', productName: 'محبس هواء 3/4 بوصة بينو',
        branch: 'جدة', warehouse: 'مستودع الشمال', employee: 'خالد',
        expectedQty: 200, actualQty: 200, date: DateTime.now(),
      ),
      StocktakeResultModel(
        id: '12254', productName: 'زيادة 525+',
        branch: 'جدة', warehouse: 'مستودع الشمال', employee: 'خالد',
        expectedQty: 525, actualQty: 525, date: DateTime.now(),
      ),
      StocktakeResultModel(
        id: '14161', productName: 'زيادة 18+',
        branch: 'الرياض', warehouse: 'المستودع الرئيسي', employee: 'أحمد',
        expectedQty: 18, actualQty: 32, date: DateTime.now(),
      ),
    ];
    notifyListeners();
  }

  void addResult(StocktakeResultModel result) {
    _allResults.add(result);
    notifyListeners();
  }

  void clearFilters() {
    _selectedBranch = 'كل الفروع';
    _selectedWarehouse = 'كل المستودعات';
    _selectedEmployee = 'كل الموظفين';
    notifyListeners();
  }
}
