import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          if (productProvider.products.isEmpty) {
            return const Center(child: Text('لا توجد منتجات'));
          }

          final results = productProvider.filteredProducts;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  onChanged: productProvider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الباركود...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: productProvider.isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              productProvider.setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              if (productProvider.isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${results.length} نتيجة من أصل ${productProvider.products.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('لا توجد نتائج مطابقة للبحث'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final product = results[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                'الباركود: ${product.barcode} | '
                                'الكمية: ${product.systemQuantity} | السعر: ${product.price}'
                                '${product.isFrozen ? ' | 🧊 مجمّد' : ''}',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
