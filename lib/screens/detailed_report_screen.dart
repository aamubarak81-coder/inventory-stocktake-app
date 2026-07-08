import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/report_provider.dart';
import '../services/export/pdf_export_service.dart';
import '../services/export/excel_service.dart';

class DetailedReportScreen extends StatelessWidget {
  const DetailedReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, report, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'تقارير تفصيلية',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ─── الفلاتر ───
                _buildFilters(report),
                const SizedBox(height: 20),

                // ─── الإحصائيات ───
                _buildStatsRow(report),
                const SizedBox(height: 24),

                // ─── رسم بياني شريطي ───
                _buildBarChart(report),
                const SizedBox(height: 24),

                // ─── رسم بياني دائري ───
                _buildPieChart(report),
                const SizedBox(height: 24),

                // ─── التبويبات ───
                _buildTabs(),
                const SizedBox(height: 16),

                // ─── نسبة التغطية ───
                _buildCoverageSection(report),
                const SizedBox(height: 24),

                // ─── الجدول التفصيلي ───
                _buildDataTable(report),
                const SizedBox(height: 24),

                // ─── أزرار التصدير ───
                _buildExportButtons(report),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(ReportProvider report) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(child: _filterDropdown('الفرع', report.branches, report.selectedBranch, report.setBranch)),
        const SizedBox(width: 10),
        Expanded(child: _filterDropdown('المستودع', report.warehouses, report.selectedWarehouse, report.setWarehouse)),
        const SizedBox(width: 10),
        Expanded(child: _filterDropdown('الموظف', report.employees, report.selectedEmployee, report.setEmployee)),
      ],
    );
  }

  Widget _filterDropdown(String label, List<String> items, String selected, void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selected,
          icon: const Icon(Icons.keyboard_arrow_down),
          hint: Text(label, textDirection: TextDirection.rtl),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

  Widget _buildStatsRow(ReportProvider report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        textDirection: TextDirection.rtl,
        children: [
          _statItem('نقص', report.shortageCount.toString(), Colors.red),
          _statItem('زيادة', report.excessCount.toString(), Colors.green),
          _statItem('مطابق', report.matchedCount.toString(), Colors.blue),
          _statItem('التغطية', '${report.coveragePercent.toStringAsFixed(0)}%', Colors.indigo),
          _statItem('منسي', report.unsyncedCount.toString(), Colors.grey),
          _statItem('تم جرده', report.totalCount.toString(), Colors.orange),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54), textDirection: TextDirection.rtl),
      ],
    );
  }

  // ─── رسم بياني شريطي ───
  Widget _buildBarChart(ReportProvider report) {
    final items = report.filteredResults;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'مقارنة الكميات (الفعلية vs الافتراضية)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: items.map((e) => e.actualQty > e.expectedQty ? e.actualQty : e.expectedQty).reduce((a, b) => a > b ? a : b).toDouble() + 20,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= items.length) return const SizedBox.shrink();
                        return Text(
                          items[index].productName.length > 8
                              ? '${items[index].productName.substring(0, 8)}...'
                              : items[index].productName,
                          style: const TextStyle(fontSize: 9),
                          textDirection: TextDirection.rtl,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(items.length, (i) {
                  final item = items[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: item.expectedQty.toDouble(), color: Colors.blue, width: 8, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: item.actualQty.toDouble(), color: Colors.orange, width: 8, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('الكمية الافتراضية', Colors.blue),
              const SizedBox(width: 16),
              _legendItem('الكمية الفعلية', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  // ─── رسم بياني دائري ───
  Widget _buildPieChart(ReportProvider report) {
    final total = report.totalCount;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'توزيع النتائج حسب الفرع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    color: Colors.green,
                    value: report.matchedCount.toDouble(),
                    title: '${report.matchedCount}',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.orange,
                    value: report.excessCount.toDouble(),
                    title: '${report.excessCount}',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.red,
                    value: report.shortageCount.toDouble(),
                    title: '${report.shortageCount}',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('مطابق', Colors.green),
              const SizedBox(width: 16),
              _legendItem('زيادة', Colors.orange),
              const SizedBox(width: 16),
              _legendItem('نقص', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _tabItem('حسب الصنف', false),
        _tabItem('حسب الموظف', false),
        _tabItem('حسب المستودع', false),
        _tabItem('حسب الفرع', true),
      ],
    );
  }

  Widget _tabItem(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: active ? Colors.blue : Colors.transparent, width: 2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: active ? Colors.blue : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 13),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _buildCoverageSection(ReportProvider report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('نسبة التغطية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
        const SizedBox(height: 12),
        _progressBar('الرياض', report.coveragePercent, Colors.blue),
        const SizedBox(height: 8),
        _progressBar('جدة', report.totalCount > 0 ? 50.0 : 0, Colors.grey),
      ],
    );
  }

  Widget _progressBar(String label, double percent, Color color) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13), textDirection: TextDirection.rtl)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 40, child: Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.left)),
      ],
    );
  }

  Widget _buildDataTable(ReportProvider report) {
    final items = report.filteredResults;
    if (items.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('لا توجد بيانات للعرض')));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
          columns: const [
            DataColumn(label: Text('الفرق', textDirection: TextDirection.rtl)),
            DataColumn(label: Text('التغطية', textDirection: TextDirection.rtl)),
            DataColumn(label: Text('مطابق', textDirection: TextDirection.rtl)),
            DataColumn(label: Text('زيادة', textDirection: TextDirection.rtl)),
            DataColumn(label: Text('نقص', textDirection: TextDirection.rtl)),
            DataColumn(label: Text('تم جرده / الإجمالي', textDirection: TextDirection.rtl)),
            DataColumn(label: Text('الاسم', textDirection: TextDirection.rtl)),
          ],
          rows: items.map((item) {
            return DataRow(cells: [
              DataCell(Text('${item.diff}')),
              DataCell(Text('${item.status == 'مطابق' ? 100 : 0}%')),
              DataCell(Text('${item.status == 'مطابق' ? 1 : 0}')),
              DataCell(Text('${item.status == 'زيادة' ? 1 : 0}')),
              DataCell(Text('${item.status == 'نقص' ? 1 : 0}')),
              DataCell(Text('${item.actualQty} / ${item.expectedQty}')),
              DataCell(Text(item.productName)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExportButtons(ReportProvider report) {
    final items = report.filteredResults;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: items.isEmpty ? null : () => PdfExportService.exportInventoryReport(
              title: 'تقرير تفصيلي',
              items: items.map((e) => {'name': e.productName, 'qty': e.actualQty, 'diff': e.diff}).toList(),
              fileName: 'detailed_report',
            ),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('PDF', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: items.isEmpty ? null : () => ExcelService.export(
              title: 'تقرير تفصيلي',
              items: items.map((e) => {'name': e.productName, 'qty': e.actualQty, 'diff': e.diff}).toList(),
              fileName: 'detailed_report',
            ),
            icon: const Icon(Icons.table_chart, color: Colors.white),
            label: const Text('Excel', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ],
    );
  }
}
