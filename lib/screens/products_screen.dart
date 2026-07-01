import 'package:flutter/material.dart';
import '../main.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  Future<List<dynamic>> _fetchProducts() async {
    // نجلب البيانات من جدول products
    final response = await supabase.from('products').select('*');
    return response as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة المنتجات'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد منتجات'));
          }

          final products = snapshot.data!;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              // ربط الأسماء بدقة مع أعمدة قاعدة البيانات
              final String name = item['name'] ?? 'بدون اسم';
              final int qty = item['system_quantity'] ?? 0;
              final double price = (item['price'] ?? 0).toDouble();

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text('الكمية: $qty | السعر: $price'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}