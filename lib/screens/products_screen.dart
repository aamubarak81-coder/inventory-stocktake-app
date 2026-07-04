import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة المنتجات'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          final products = productProvider.products;

          if (products.isEmpty) {
            return const Center(child: Text('لا توجد منتجات'));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    'الكمية: ${product.systemQuantity} | السعر: ${product.price}'
                    '${product.isFrozen ? ' | 🧊 مجمّد' : ''}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
