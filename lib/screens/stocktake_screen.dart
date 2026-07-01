import 'package:flutter/material.dart';
import '../main.dart';

class StocktakeScreen extends StatefulWidget {
  const StocktakeScreen({super.key});

  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  int _quantity = 0;
  bool _isSaving = false;
  Map<String, dynamic>? _selectedProduct;

  Future<void> _saveStocktake() async {
    if (_selectedProduct == null) return;
    setState(() => _isSaving = true);
    try {
      await supabase.from('stocktakes').insert({
        'product_id': _selectedProduct!['id'],
        'counted_quantity': _quantity,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الجرد!'), backgroundColor: Colors.green),
        );
        setState(() {
          _quantity = 0;
          _selectedProduct = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جرد المستودع'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 60, color: Colors.grey),
                    Text('اضغط للمسح'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final data = await supabase.from('products').select();
                final products = List<Map<String, dynamic>>.from(data);
                if (!mounted) return;
                showModalBottomSheet(
                  context: context,
                  builder: (_) => ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(products[i]['name'] ?? ''),
                      subtitle: Text('باركود: ${products[i]['barcode'] ?? ''}'),
                      onTap: () {
                        setState(() => _selectedProduct = products[i]);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('اختر منتج'),
            ),
            if (_selectedProduct != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedProduct!['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Text('باركود: ${_selectedProduct!['barcode'] ?? ''}'),
                      Text('الكمية في النظام: ${_selectedProduct!['system_quantity'] ?? 0}'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    if (_quantity > 0) _quantity--;
                  }),
                  icon: const Icon(Icons.remove_circle),
                  color: Colors.grey,
                  iconSize: 40,
                ),
                Text(
                  '$_quantity',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle),
                  color: Colors.green,
                  iconSize: 40,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving || _selectedProduct == null ? null : _saveStocktake,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('حفظ الجرد', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
