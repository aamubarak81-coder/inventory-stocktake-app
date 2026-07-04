import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../models/stocktake_model.dart';
import '../../models/product_model.dart';

class ExcelExportService {
  static Uint8List exportStocktakeReport({
    required List<StocktakeModel> stocktakes,
    required List<ProductModel> products,
    required String reportTitle,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['تقرير الجرد'];

    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
    sheet.cell(CellIndex.indexByString('A1'))
      ..value = TextCellValue(reportTitle)
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

    sheet.appendRow([]);
    final headers = ['#', 'الباركود', 'اسم المنتج', 'الكمية النظامية', 'الكمية المجردة', 'الفرق', 'الحالة'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#B4C7E7'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    final productsMap = {for (var p in products) p.id: p};

    for (int i = 0; i < stocktakes.length; i++) {
      final st = stocktakes[i];
      final product = productsMap[st.productId];

      final int systemQty = product?.systemQuantity ?? 0;
      final int countedQty = st.scannedQuantity;
      final int diff = countedQty - systemQty;

      String status;
      ExcelColor statusColor;
      if (diff == 0) {
        status = 'مطابق';
        statusColor = ExcelColor.fromHexString('#00B050');
      } else if (diff > 0) {
        status = 'زيادة';
        statusColor = ExcelColor.fromHexString('#4472C4');
      } else {
        status = 'عجز';
        statusColor = ExcelColor.fromHexString('#FF0000');
      }

      final row = [
        TextCellValue('${i + 1}'),
        TextCellValue(st.barcode),
        TextCellValue(product?.name ?? 'غير معروف'),
        TextCellValue('$systemQty'),
        TextCellValue('$countedQty'),
        TextCellValue('${diff > 0 ? '+' : ''}$diff'),
        TextCellValue(status),
      ];

      sheet.appendRow(row);

      final diffCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 3));
      diffCell.cellStyle = CellStyle(
        fontColorHex: diff == 0 
            ? ExcelColor.fromHexString('#00B050') 
            : diff > 0 
                ? ExcelColor.fromHexString('#4472C4') 
                : ExcelColor.fromHexString('#FF0000'),
        bold: true,
      );

      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 3));
      statusCell.cellStyle = CellStyle(
        fontColorHex: statusColor,
        bold: true,
      );
    }

    sheet.appendRow([]);
    final totalRow = stocktakes.length + 4;
    sheet.merge(CellIndex.indexByString('A$totalRow'), CellIndex.indexByString('F$totalRow'));
    sheet.cell(CellIndex.indexByString('A$totalRow'))
      ..value = TextCellValue('إجمالي العمليات: ${stocktakes.length}')
      ..cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E7E6E6'),
      );

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 12);

    return Uint8List.fromList(excel.encode()!);
  }

  static Uint8List exportProductsReport(List<ProductModel> products) {
    final excel = Excel.createExcel();
    final sheet = excel['قائمة المنتجات'];

    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    sheet.cell(CellIndex.indexByString('A1'))
      ..value = TextCellValue('قائمة المنتجات')
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

    sheet.appendRow([]);
    final headers = ['#', 'الباركود', 'اسم المنتج', 'السعر', 'الكمية'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        TextCellValue(p.barcode),
        TextCellValue(p.name),
        TextCellValue('${p.price.toStringAsFixed(2)} ر.س'),
        TextCellValue('${p.quantity}'),
      ]);
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 35);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);

    return Uint8List.fromList(excel.encode()!);
  }
}