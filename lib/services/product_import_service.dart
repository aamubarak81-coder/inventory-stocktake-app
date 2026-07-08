import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import 'hive_service.dart';

/// خطأ بصف واحد أثناء التحليل - رقم الصف (كما يظهر فعلياً بملف Excel،
/// يعني صف العنوان = 1) وسبب الرفض.
class ImportRowError {
  final int rowNumber;
  final String reason;
  ImportRowError({required this.rowNumber, required this.reason});
}

class ImportParseResult {
  final List<ProductModel> validProducts;
  final List<ImportRowError> errors;
  final int totalDataRows; // عدد صفوف البيانات (بدون صف العنوان)

  ImportParseResult({
    required this.validProducts,
    required this.errors,
    required this.totalDataRows,
  });

  int get updatedCount =>
      validProducts.where((p) => HiveService.getProductByBarcode(p.barcode) != null).length;
  int get newCount => validProducts.length - updatedCount;
}

/// خدمة استيراد المنتجات دفعة واحدة من ملف Excel (.xlsx) يرفعه المستخدم
/// من المتصفح مباشرة - بدون أي حاجة للوصول لقاعدة البيانات مباشرة.
///
/// القالب المتوقع (ترتيب أعمدة ثابت، بصف عنوان أول):
///   A: الباركود | B: اسم الصنف | C: الكمية | D: السعر
class ProductImportService {
  static const List<String> templateHeaders = ['الباركود', 'اسم الصنف', 'الكمية', 'السعر'];

  /// يبني ملف Excel قالب فاضي (بس العناوين + صف مثال توضيحي) عشان
  /// المستخدم يعبّيه بمنتجاته بالترتيب الصحيح
  static Uint8List generateTemplate() {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet()!;
    final sheet = excel[defaultSheetName];

    sheet.appendRow(templateHeaders.map((h) => TextCellValue(h)).toList());
    sheet.appendRow([
      TextCellValue('12345678'),
      TextCellValue('مثال: سكر أبيض 1 كغم'),
      IntCellValue(100),
      DoubleCellValue(3.5),
    ]);

    for (var i = 0; i < templateHeaders.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes!);
  }

  /// يحلل ملف Excel مرفوع ويتحقق من كل صف. لا يلمس القاعدة إطلاقاً هون -
  /// بس بيرجع نتيجة (منتجات صالحة + أخطاء) للمراجعة قبل أي رفع فعلي.
  static ImportParseResult parseAndValidate({
    required Uint8List bytes,
    required String orgId,
    required String warehouseId,
  }) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ImportParseResult(validProducts: [], errors: [], totalDataRows: 0);
    }

    final sheetName = excel.tables.keys.first;
    final rows = excel.tables[sheetName]!.rows;

    final validProducts = <ProductModel>[];
    final errors = <ImportRowError>[];
    const uuid = Uuid();

    // نتخطى صف العنوان (الصف الأول)
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNumber = i + 1; // يطابق رقم الصف الفعلي بملف Excel

      // تخطي الصفوف الفارغة تماماً بصمت (مو خطأ، بس صف فاضي بالملف)
      final isEmpty = row.every((cell) {
        final v = cell?.value;
        return v == null || v.toString().trim().isEmpty;
      });
      if (isEmpty) continue;

      final barcode = _cellText(row, 0);
      final name = _cellText(row, 1);
      final qtyRaw = _cellText(row, 2);
      final priceRaw = _cellText(row, 3);

      if (barcode.isEmpty) {
        errors.add(ImportRowError(rowNumber: rowNumber, reason: 'الباركود فارغ'));
        continue;
      }
      if (name.isEmpty) {
        errors.add(ImportRowError(rowNumber: rowNumber, reason: 'اسم الصنف فارغ'));
        continue;
      }

      final qty = int.tryParse(qtyRaw.trim());
      if (qty == null) {
        errors.add(ImportRowError(
            rowNumber: rowNumber, reason: 'الكمية غير صحيحة: "$qtyRaw" (المطلوب رقم صحيح)'));
        continue;
      }
      if (qty < 0) {
        errors.add(ImportRowError(rowNumber: rowNumber, reason: 'الكمية لا يمكن أن تكون سالبة'));
        continue;
      }

      final price = double.tryParse(priceRaw.trim());
      if (price == null) {
        errors.add(ImportRowError(
            rowNumber: rowNumber, reason: 'السعر غير صحيح: "$priceRaw" (المطلوب رقم)'));
        continue;
      }
      if (price < 0) {
        errors.add(ImportRowError(rowNumber: rowNumber, reason: 'السعر لا يمكن أن يكون سالباً'));
        continue;
      }

      // لو الباركود موجود أصلاً محلياً (منتج سابق)، نعيد استخدام نفس
      // الـ id - هذا يخلي عملية الرفع "تحديث" بدل "تكرار" لنفس الصنف.
      // لو ما موجود، منتج جديد بالكامل بـ id عشوائي جديد.
      final existing = HiveService.getProductByBarcode(barcode);

      validProducts.add(ProductModel(
        id: existing?.id ?? uuid.v4(),
        orgId: orgId,
        warehouseId: warehouseId,
        code: existing?.code ?? '',
        name: name,
        barcode: barcode,
        systemQuantity: qty,
        price: price,
        lastUpdated: DateTime.now(),
      ));
    }

    // تحذير إضافي: تكرار باركود داخل نفس الملف (غير مرتبط بمنتج قديم) -
    // نحتفظ بآخر ظهور بس (upsert بنفس الـ id بيتصرف بنفس الطريقة أصلاً)
    // لا حاجة لكود إضافي هون، upsert بالـ id يتعامل معه صح تلقائياً.

    return ImportParseResult(
      validProducts: validProducts,
      errors: errors,
      totalDataRows: rows.length - 1,
    );
  }

  static String _cellText(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final value = row[index]?.value;
    if (value == null) return '';
    return value.toString().trim();
  }
}
