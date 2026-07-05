import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/models/product_model.dart';
import 'package:inventory_app/models/stocktake_model.dart';
import 'package:inventory_app/services/discrepancy_calculator.dart';

ProductModel _fakeProduct({String id = 'p1'}) {
  return ProductModel(
    id: id,
    orgId: 'org1',
    code: 'C-001',
    name: 'منتج تجريبي',
    barcode: '123456',
    systemQuantity: 0,
    price: 10,
    lastUpdated: DateTime.now(),
  );
}

StocktakeModel _fakeStocktake({
  int scanned = 0,
  int? expected,
  String productId = 'p1',
}) {
  return StocktakeModel(
    id: 's1',
    sessionId: 'sess1',
    orgId: 'org1',
    productId: productId,
    scannedQuantity: scanned,
    expectedQuantity: expected,
    scannedBy: 'user1',
    scannedAt: DateTime.now(),
  );
}

void main() {
  const threshold = DiscrepancyThreshold(
    percentThreshold: 0.05, // 5%
    quantityThreshold: 10,
  );

  test('يرجع null إذا كان الجرد أعمى (بدون expectedQuantity)', () {
    final result = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 50, expected: null),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(result, isNull);
  });

  test('لا يوجد تنبيه عند تطابق الكمية تماماً', () {
    final result = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 100, expected: 100),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(result!.exceedsThreshold, isFalse);
    expect(result.trigger, DiscrepancyTrigger.none);
  });

  test('لا يوجد تنبيه عند فرق صغير أقل من الحدّين', () {
    // فرق 2 قطعة من أصل 100 = 2% (أقل من 5%) و 2 < 10 قطع
    final result = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 98, expected: 100),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(result!.exceedsThreshold, isFalse);
  });

  test('ينبّه عند تجاوز النسبة المئوية فقط (5%+) مع عدد أقل من 10', () {
    // فرق 6 قطع من أصل 100 = 6% (أكبر من 5%) لكن 6 < 10
    final result = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 94, expected: 100),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(result!.exceedsThreshold, isTrue);
    expect(result.trigger, DiscrepancyTrigger.percent);
  });

  test('ينبّه عند تجاوز العدد الثابت فقط (10+) مع نسبة أقل من 5%', () {
    // فرق 15 قطعة من أصل 1000 = 1.5% (أقل من 5%) لكن 15 >= 10
    final result = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 985, expected: 1000),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(result!.exceedsThreshold, isTrue);
    expect(result.trigger, DiscrepancyTrigger.quantity);
  });

  test('ينبّه عند تجاوز الحدّين معاً', () {
    final result = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 50, expected: 100),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(result!.exceedsThreshold, isTrue);
    expect(result.trigger, DiscrepancyTrigger.both);
  });

  test('يتعامل بأمان مع expectedQuantity = صفر (تفادي القسمة على صفر)', () {
    final resultWithDiff = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 5, expected: 0),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(resultWithDiff!.diffPercent, 1.0);
    expect(resultWithDiff.exceedsThreshold, isTrue);

    final resultNoDiff = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 0, expected: 0),
      product: _fakeProduct(),
      threshold: threshold,
    );
    expect(resultNoDiff!.diffPercent, 0.0);
    expect(resultNoDiff.exceedsThreshold, isFalse);
  });

  test('isShortage و isSurplus تعطي الاتجاه الصحيح للفرق', () {
    final shortage = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 50, expected: 100),
      product: _fakeProduct(),
      threshold: threshold,
    )!;
    expect(shortage.isShortage, isTrue);
    expect(shortage.isSurplus, isFalse);

    final surplus = DiscrepancyCalculator.calculate(
      stocktake: _fakeStocktake(scanned: 150, expected: 100),
      product: _fakeProduct(),
      threshold: threshold,
    )!;
    expect(surplus.isSurplus, isTrue);
    expect(surplus.isShortage, isFalse);
  });

  test('calculateBatch و filterExceeding يشتغلوا صح على دفعة كاملة', () {
    final product = _fakeProduct(id: 'p1');
    final stocktakes = [
      _fakeStocktake(scanned: 100, expected: 100, productId: 'p1'), // ok
      _fakeStocktake(scanned: 50, expected: 100, productId: 'p1'), // exceeds
      _fakeStocktake(scanned: 98, expected: 100, productId: 'p1'), // ok
    ];

    final results = DiscrepancyCalculator.calculateBatch(
      stocktakes: stocktakes,
      productsById: {'p1': product},
      threshold: threshold,
    );
    expect(results.length, 3);

    final exceeding = DiscrepancyCalculator.filterExceeding(results);
    expect(exceeding.length, 1);
    expect(exceeding.first.diffQuantity, -50);
  });
}
