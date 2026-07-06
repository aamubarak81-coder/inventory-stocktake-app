import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/stocktake_model.dart';
import '../../models/product_model.dart';
import 'pdf_font_service.dart';

class PdfExportService {
  static Future<Uint8List> exportStocktakeReport({
    required List<StocktakeModel> stocktakes,
    required List<ProductModel> products,
    required String reportTitle,
  }) async {
    final arabicTheme = await PdfFontService.getArabicTheme();
    final pdf = pw.Document(theme: arabicTheme);
    final productsMap = {for (var p in products) p.id: p};

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'تاريخ التقرير: ${DateTime.now().toString().split(' ')[0]}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(4),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(2),
                  6: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    children: [
                      _headerCell('#'),
                      _headerCell('الباركود'),
                      _headerCell('اسم المنتج'),
                      _headerCell('النظامية'),
                      _headerCell('المجردة'),
                      _headerCell('الفرق'),
                      _headerCell('الحالة'),
                    ],
                  ),
                  ...stocktakes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final st = entry.value;
                    final product = productsMap[st.productId];

                    final int systemQty = product?.systemQuantity ?? 0;
                    final int countedQty = st.scannedQuantity;
                    final int diff = countedQty - systemQty;

                    PdfColor statusColor;
                    String status;
                    if (diff == 0) {
                      status = 'مطابق';
                      statusColor = PdfColors.green;
                    } else if (diff > 0) {
                      status = 'زيادة';
                      statusColor = PdfColors.blue;
                    } else {
                      status = 'عجز';
                      statusColor = PdfColors.red;
                    }

                    return pw.TableRow(
                      children: [
                        _dataCell('${i + 1}'),
                        _dataCell(st.barcode),
                        _dataCell(product?.name ?? 'غير معروف'),
                        _dataCell('$systemQty'),
                        _dataCell('$countedQty'),
                        _dataCell('${diff > 0 ? '+' : ''}$diff', color: statusColor),
                        _dataCell(status, color: statusColor),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'إجمالي العمليات: ${stocktakes.length}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'مطابق: ${stocktakes.where((s) {
                      final p = productsMap[s.productId];
                      return s.scannedQuantity == (p?.systemQuantity ?? 0);
                    }).length}',
                    style: const pw.TextStyle(color: PdfColors.green),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
  }

  static pw.Widget _dataCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 9, color: color),
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
  }
}
