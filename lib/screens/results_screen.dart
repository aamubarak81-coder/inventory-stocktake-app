import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stocktake_provider.dart';
import '../models/stocktake_model.dart';
import '../services/hive_service.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نتائج وتقارير الجرد'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'جلسة الجرد الحالية'),
              Tab(text: 'كل عمليات الجرد'),
            ],
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: TabBarView(
            children: [
              _CurrentSessionTab(),
              _AllStocktakesTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// تبويب الجلسة الحالية
class _CurrentSessionTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StocktakeProvider>();
    final entries = provider.currentSessionEntries;

    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'لا توجد عمليات جرد في الجلسة الحالية',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'ابدأ بمسح المنتجات من شاشة الجرد',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // إحصائيات سريعة
    final matched = entries.where((e) =>
        e.expectedQuantity != null && e.scannedQuantity == e.expectedQuantity).length;
    final surplus = entries.where((e) =>
        e.expectedQuantity != null && e.scannedQuantity > e.expectedQuantity!).length;
    final deficit = entries.where((e) =>
        e.expectedQuantity != null && e.scannedQuantity < e.expectedQuantity!).length;
    final unsynced = entries.where((e) => !e.isSynced).length;

    return Column(
      children: [
        // شريط الإحصائيات
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.orange[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(label: 'إجمالي', value: entries.length, color: Colors.blue),
              _StatChip(label: 'مطابق', value: matched, color: Colors.green),
              _StatChip(label: 'زيادة', value: surplus, color: Colors.teal),
              _StatChip(label: 'نقص', value: deficit, color: Colors.red),
              _StatChip(label: 'غير متزامن', value: unsynced, color: Colors.orange),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries.reversed.toList()[index];
              return _StocktakeCard(entry: entry);
            },
          ),
        ),
      ],
    );
  }
}

// تبويب كل عمليات الجرد
class _AllStocktakesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final allEntries = HiveService.getStocktakes();

    if (allEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'لا توجد عمليات جرد مسجلة بعد',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final unsynced = allEntries.where((e) => !e.isSynced).length;

    return Column(
      children: [
        if (unsynced > 0)
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.orange[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '$unsynced عملية في انتظار المزامنة مع السيرفر',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: allEntries.length,
            itemBuilder: (context, index) {
              final entry = allEntries.reversed.toList()[index];
              return _StocktakeCard(entry: entry);
            },
          ),
        ),
      ],
    );
  }
}

// بطاقة عرض عملية جرد واحدة
class _StocktakeCard extends StatelessWidget {
  final StocktakeModel entry;
  const _StocktakeCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasExpected = entry.expectedQuantity != null;
    final diff = hasExpected ? entry.scannedQuantity - entry.expectedQuantity! : 0;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!hasExpected) {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = 'جرد أعمى';
    } else if (diff == 0) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'مطابق';
    } else if (diff > 0) {
      statusColor = Colors.teal;
      statusIcon = Icons.add_circle;
      statusText = 'زيادة +$diff';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.remove_circle;
      statusText = 'نقص $diff';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 32),
        title: Text(
          entry.barcode.isNotEmpty ? entry.barcode : entry.productId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الكمية الفعلية: ${entry.scannedQuantity}'
              '${hasExpected ? ' | الدفترية: ${entry.expectedQuantity}' : ''}',
            ),
            if (entry.locationRef != null && entry.locationRef!.isNotEmpty)
              Text('الموقع: ${entry.locationRef}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              entry.isSynced ? '✅ متزامن' : '🕐 في انتظار المزامنة',
              style: TextStyle(
                fontSize: 11,
                color: entry.isSynced ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            statusText,
            style: TextStyle(
                color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
