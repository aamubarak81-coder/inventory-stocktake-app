import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نتائج وتقارير الجرد'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Card(
            child: ListTile(
              title: Text(
                'مواسير سباكة 1 انش البلاستيك',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 6.0), // هنا تم تصحيح الخطأ تماماً
                child: Text('الكمية الدفترية: 150 | الجرد الفعلي: 150'),
              ),
              trailing: Icon(Icons.check_circle, color: Colors.green, size: 28),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(
                'كابل كهرباء 4 ملم نحاس',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 6.0), // هنا تم تصحيح الخطأ تماماً
                child: Text('الكمية الدفترية: 85 | الجرد الفعلي: 90'),
              ),
              trailing: Icon(Icons.add_circle, color: Colors.blue, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}