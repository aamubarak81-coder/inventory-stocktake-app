# ═══════════════════════════════════════════════════════
# بناء نظام التقارير والتصدير - Excel + PDF
# ═══════════════════════════════════════════════════════

Write-Host "`n🚀 جاري بناء نظام التقارير..." -ForegroundColor Cyan

# 1. تحديث pubspec.yaml
$pubspec = @"
name: inventory_app
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: ^3.12.2
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  mobile_scanner: ^3.5.0
  geolocator: ^10.1.0
  intl: ^0.19.0
  supabase_flutter: ^2.15.1
  flutter_secure_storage: ^10.3.1
  connectivity_plus: ^7.2.0
  uuid: ^4.5.3
  excel: ^4.0.6
  pdf: ^3.10.8
  path_provider: ^2.1.5
  share_plus: ^10.0.0
  open_file: ^3.5.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.13
flutter:
  uses-material-design: true
"@
$pubspec | Set-Content "pubspec.yaml" -Encoding UTF8
Write-Host "✅ pubspec.yaml تم تحديثه" -ForegroundColor Green

# 2. إنشاء مجلد التصدير
New-Item -ItemType Directory -Path "lib\services\export" -Force | Out-Null

# 3. Excel Export Service
$excel = @"
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/stocktake_model.dart';
import '../models/product_model.dart';

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
        backgroundColorHex: '#4472C4',
        fontColorHex: '#FFFFFF',
      );

    sheet.appendRow([]);
    final headers = ['#', 'الباركود', 'اسم المنتج', 'الكمية النظامية', 'الكمية المجردة', 'الفرق', 'الحالة'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#B4C7E7',
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    final productsMap = {for (var p in products) p.id: p};

    for (int i = 0; i < stocktakes.length; i++) {
      final st = stocktakes[i];
      final product = productsMap[st.productId];

      final int systemQty = product?.quantity ?? 0;
      final int countedQty = st.countedQuantity;
      final int diff = countedQty - systemQty;

      String status;
      String statusColor;
      if (diff == 0) {
        status = 'مطابق';
        statusColor = '#00B050';
      } else if (diff > 0) {
        status = 'زيادة';
        statusColor = '#4472C4';
      } else {
        status = 'عجز';
        statusColor = '#FF0000';
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
        fontColorHex: diff == 0 ? '#00B050' : diff > 0 ? '#4472C4' : '#FF0000',
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
    sheet.merge(CellIndex.indexByString('A`$totalRow'), CellIndex.indexByString('F`$totalRow'));
    sheet.cell(CellIndex.indexByString('A`$totalRow'))
      ..value = TextCellValue('إجمالي العمليات: ${stocktakes.length}')
      ..cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: '#E7E6E6',
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
        backgroundColorHex: '#4472C4',
        fontColorHex: '#FFFFFF',
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
"@
$excel | Set-Content "lib\services\export\excel_export_service.dart" -Encoding UTF8
Write-Host "✅ Excel Export Service تم إنشاؤه" -ForegroundColor Green

# 4. PDF Export Service
$pdf = @"
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/stocktake_model.dart';
import '../models/product_model.dart';

class PdfExportService {
  static Future<Uint8List> exportStocktakeReport({
    required List<StocktakeModel> stocktakes,
    required List<ProductModel> products,
    required String reportTitle,
  }) async {
    final pdf = pw.Document();
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
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'تاريخ التقرير: ${DateTime.now().toString().split(' ')[0]}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
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

                    final int systemQty = product?.quantity ?? 0;
                    final int countedQty = st.countedQuantity;
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
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي العمليات: ${stocktakes.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('مطابق: ${stocktakes.where((s) {
                    final p = productsMap[s.productId];
                    return s.countedQuantity == (p?.quantity ?? 0);
                  }).length}', style: const pw.TextStyle(color: PdfColors.green)),
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
"@
$pdf | Set-Content "lib\services\export\pdf_export_service.dart" -Encoding UTF8
Write-Host "✅ PDF Export Service تم إنشاؤه" -ForegroundColor Green

# 5. Web Download Service
$webDownload = @"
import 'dart:html' as html;
import 'dart:typed_data';

class WebDownloadService {
  static void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
"@
$webDownload | Set-Content "lib\services\export\web_download_service.dart" -Encoding UTF8
Write-Host "✅ Web Download Service تم إنشاؤه" -ForegroundColor Green

# 6. Reports Screen
$reports = @"
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/stocktake_model.dart';
import '../services/hive_service.dart';
import '../services/export/excel_export_service.dart';
import '../services/export/pdf_export_service.dart';
import '../services/export/web_download_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<ProductModel> _products = [];
  List<StocktakeModel> _stocktakes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _products = HiveService.getProducts();
      _stocktakes = HiveService.getStocktakes();
    });
  }

  Future<void> _exportExcel() async {
    setState(() => _isLoading = true);
    try {
      final bytes = ExcelExportService.exportStocktakeReport(
        stocktakes: _stocktakes,
        products: _products,
        reportTitle: 'تقرير جرد المستودع',
      );
      WebDownloadService.downloadFile(
        bytes: bytes,
        fileName: 'تقرير_الجرد_${DateTime.now().toString().split(' ')[0]}.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      _showSnack('✅ تم تصدير Excel بنجاح!');
    } catch (e) {
      _showSnack('❌ خطأ في التصدير: `$e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _exportPdf() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await PdfExportService.exportStocktakeReport(
        stocktakes: _stocktakes,
        products: _products,
        reportTitle: 'تقرير جرد المستودع',
      );
      WebDownloadService.downloadFile(
        bytes: bytes,
        fileName: 'تقرير_الجرد_${DateTime.now().toString().split(' ')[0]}.pdf',
        mimeType: 'application/pdf',
      );
      _showSnack('✅ تم تصدير PDF بنجاح!');
    } catch (e) {
      _showSnack('❌ خطأ في التصدير: `$e');
    }
    setState(() => _isLoading = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final int totalProducts = _products.length;
    final int totalStocktakes = _stocktakes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والتصدير'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCards(totalProducts, totalStocktakes),
                const SizedBox(height: 24),
                const Text('تصدير التقارير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ExportButton(
                        icon: Icons.table_chart,
                        label: 'تصدير Excel',
                        color: Colors.green,
                        onTap: _exportExcel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ExportButton(
                        icon: Icons.picture_as_pdf,
                        label: 'تصدير PDF',
                        color: Colors.red,
                        onTap: _exportPdf,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('فروقات الجرد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildDiscrepanciesList(),
              ],
            ),
    );
  }

  Widget _buildSummaryCards(int products, int stocktakes) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _SummaryCard(label: 'إجمالي المنتجات', value: '$products', color: Colors.blue, icon: Icons.inventory_2),
        _SummaryCard(label: 'عمليات الجرد', value: '$stocktakes', color: Colors.green, icon: Icons.fact_check),
        _SummaryCard(label: 'غير مزامن', value: '${_products.where((p) => !p.isSynced).length}', color: Colors.red, icon: Icons.cloud_off),
        _SummaryCard(label: 'جرد غير مزامن', value: '${_stocktakes.where((s) => !s.isSynced).length}', color: Colors.orange, icon: Icons.sync_problem),
      ],
    );
  }

  Widget _buildDiscrepanciesList() {
    final productsMap = {for (var p in _products) p.id: p};

    final discrepancies = _stocktakes.where((st) {
      final product = productsMap[st.productId];
      if (product == null) return false;
      return st.countedQuantity != product.quantity;
    }).toList();

    if (discrepancies.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('لا توجد فروقات ✅', style: TextStyle(color: Colors.grey, fontSize: 16))),
        ),
      );
    }

    return Column(
      children: discrepancies.map((st) {
        final product = productsMap[st.productId]!;
        final diff = st.countedQuantity - product.quantity;
        final isSurplus = diff > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              isSurplus ? Icons.add_circle : Icons.remove_circle,
              color: isSurplus ? Colors.blue : Colors.red,
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('الباركود: ${st.barcode}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('نظامي: ${product.quantity}', style: const TextStyle(fontSize: 12)),
                Text('مجرد: ${st.countedQuantity}', style: const TextStyle(fontSize: 12)),
                Text(
                  '${isSurplus ? '+' : ''}$diff',
                  style: TextStyle(
                    color: isSurplus ? Colors.blue : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
"@
$reports | Set-Content "lib\screens\reports_screen.dart" -Encoding UTF8
Write-Host "✅ Reports Screen تم تحديثه" -ForegroundColor Green

Write-Host "`n═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅✅✅ تم بناء نظام التقارير بنجاح!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "`n⚠️  الخطوة التالية:" -ForegroundColor Yellow
Write-Host "   flutter pub get" -ForegroundColor White
Write-Host "`n🚀 بعدها: اضغط R في Terminal ثم Ctrl+F5 في المتصفح" -ForegroundColor Yellow
