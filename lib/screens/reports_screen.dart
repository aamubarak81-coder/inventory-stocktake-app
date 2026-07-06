import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import '../models/stocktake_model.dart';
import '../services/export/web_download_stub.dart'
    if (dart.library.html) '../services/export/web_download_service.dart';
import '../services/export/pdf_font_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isExporting = false;

  List<StocktakeModel> get _allEntries => HiveService.getStocktakes();

  // يحسب كل الإحصائيات بمرور وحدة بس على القائمة، بدل ما كانت كل إحصائية
  // (المطابق/الزيادة/النقص/غير المتزامن) تعيد قراءة الجرد بالكامل من Hive
  // وتفلتره من الصفر كل وحدة لحالها (5 قراءات + 5 مرورات كاملة منفصلة).
  // مهم جداً مع تاريخ جرد كبير يتراكم عبر شهور/سنين.
  ({int total, int matched, int surplus, int deficit, int unsynced})
      _computeStats(List<StocktakeModel> entries) {
    int matched = 0, surplus = 0, deficit = 0, unsynced = 0;
    for (final e in entries) {
      if (!e.isSynced) unsynced++;
      if (e.expectedQuantity != null) {
        final diff = e.scannedQuantity - e.expectedQuantity!;
        if (diff == 0) {
          matched++;
        } else if (diff > 0) {
          surplus++;
        } else {
          deficit++;
        }
      }
    }
    return (
      total: entries.length,
      matched: matched,
      surplus: surplus,
      deficit: deficit,
      unsynced: unsynced,
    );
  }

  // تصدير Excel
  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['تقرير الجرد'];

      // رأس الجدول
      final headers = [
        'الباركود', 'اسم المنتج', 'معرف المنتج', 'الكمية الفعلية',
        'الكمية الدفترية', 'الفارق', 'الحالة',
        'الموقع', 'تاريخ الجرد', 'المزامنة'
      ];
      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      // البيانات
      final entries = _allEntries;
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final diff = e.expectedQuantity != null
            ? e.scannedQuantity - e.expectedQuantity!
            : 0;
        final status = e.expectedQuantity == null
            ? 'جرد أعمى'
            : diff == 0
                ? 'مطابق'
                : diff > 0
                    ? 'زيادة'
                    : 'نقص';

        final productName =
            HiveService.getProductByBarcode(e.barcode)?.name ?? 'غير معروف';

        final row = [
          e.barcode,
          productName,
          e.productId,
          e.scannedQuantity.toString(),
          e.expectedQuantity?.toString() ?? '-',
          diff.toString(),
          status,
          e.locationRef ?? '-',
          DateFormat('yyyy-MM-dd HH:mm').format(e.scannedAt),
          e.isSynced ? 'متزامن' : 'غير متزامن',
        ];
        for (var j = 0; j < row.length; j++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = TextCellValue(row[j]);
        }
      }

      final bytes = excel.save();
      if (bytes == null) return;
      final fileBytes = Uint8List.fromList(bytes);
      final fileName =
          'تقرير_الجرد_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        WebDownloadService.downloadFile(
          bytes: fileBytes,
          fileName: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'تقرير الجرد الذكي');
      }
    } catch (e) {
      _showError('فشل تصدير Excel: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // تصدير PDF
  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final arabicTheme = await PdfFontService.getArabicTheme();
      final pdf = pw.Document(theme: arabicTheme);
      final entries = _allEntries;
      final stats = _computeStats(entries);
      final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'تقرير الجرد الذكي - $now',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            // ملخص إحصائي
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text('الإجمالي: ${stats.total}'),
                  pw.Text('مطابق: ${stats.matched}'),
                  pw.Text('زيادة: ${stats.surplus}'),
                  pw.Text('نقص: ${stats.deficit}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            // جدول البيانات
            pw.TableHelper.fromTextArray(
              headers: ['الباركود', 'اسم المنتج', 'الفعلي', 'الدفتري', 'الفارق', 'الحالة', 'التاريخ'],
              data: entries.map((e) {
                final diff = e.expectedQuantity != null
                    ? e.scannedQuantity - e.expectedQuantity!
                    : 0;
                final status = e.expectedQuantity == null
                    ? 'أعمى'
                    : diff == 0
                        ? 'مطابق'
                        : diff > 0
                            ? '+$diff'
                            : '$diff';
                final productName =
                    HiveService.getProductByBarcode(e.barcode)?.name ?? 'غير معروف';
                return [
                  e.barcode.isNotEmpty ? e.barcode : e.productId.substring(0, 8),
                  productName,
                  e.scannedQuantity.toString(),
                  e.expectedQuantity?.toString() ?? '-',
                  diff.toString(),
                  status,
                  DateFormat('MM-dd HH:mm').format(e.scannedAt),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange100),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName =
          'تقرير_الجرد_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      if (kIsWeb) {
        WebDownloadService.downloadFile(
          bytes: pdfBytes,
          fileName: fileName,
          mimeType: 'application/pdf',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'تقرير الجرد الذكي');
      }
    } catch (e) {
      _showError('فشل تصدير PDF: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _allEntries;
    final stats = _computeStats(entries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: entries.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 72, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('لا توجد بيانات جرد بعد',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('ابدأ بجرد المنتجات لتظهر التقارير هنا',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // بطاقات الإحصائيات
                    const Text('ملخص الجرد',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2,
                      children: [
                        _StatCard('إجمالي عمليات الجرد', stats.total, Colors.blue, Icons.inventory),
                        _StatCard('مطابق', stats.matched, Colors.green, Icons.check_circle),
                        _StatCard('زيادة في المخزون', stats.surplus, Colors.teal, Icons.add_circle),
                        _StatCard('نقص في المخزون', stats.deficit, Colors.red, Icons.remove_circle),
                        _StatCard('في انتظار المزامنة', stats.unsynced, Colors.orange, Icons.sync),
                        _StatCard('متزامن مع السيرفر', stats.total - stats.unsynced, Colors.purple, Icons.cloud_done),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // أزرار التصدير
                    const Text('تصدير التقرير',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : _exportExcel,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.table_chart),
                            label: const Text('تصدير Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : _exportPdf,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.picture_as_pdf),
                            label: const Text('تصدير PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // آخر 10 عمليات جرد
                    const Text('آخر عمليات الجرد',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...entries.reversed.take(10).map((e) {
                      final diff = e.expectedQuantity != null
                          ? e.scannedQuantity - e.expectedQuantity!
                          : 0;
                      final color = e.expectedQuantity == null
                          ? Colors.grey
                          : diff == 0
                              ? Colors.green
                              : diff > 0
                                  ? Colors.teal
                                  : Colors.red;
                      final productName =
                          HiveService.getProductByBarcode(e.barcode)?.name;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.qr_code, color: color),
                          title: Text(
                            productName ?? (e.barcode.isNotEmpty ? e.barcode : e.productId),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            productName != null && e.barcode.isNotEmpty
                                ? '${e.barcode} • ${DateFormat('yyyy-MM-dd HH:mm').format(e.scannedAt)}'
                                : DateFormat('yyyy-MM-dd HH:mm').format(e.scannedAt),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('الفعلي: ${e.scannedQuantity}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      fontSize: 12)),
                              if (e.expectedQuantity != null)
                                Text('الدفتري: ${e.expectedQuantity}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$value',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
