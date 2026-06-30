import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://dqyorsbkxxgjctprjjdw.supabase.co',
    anonKey: 'sb_publishable_8RMW-u8_2wdFG_pa4RVjYA_mJ5yx1OF',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام الجرد الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ===== الشاشة الرئيسية =====
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام الجرد الذكي'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('مرحباً بك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            _MenuButton(
              icon: Icons.list_alt,
              label: 'المنتجات',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.qr_code_scanner,
              label: 'بدء الجرد',
              color: Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StocktakeScreen())),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.bar_chart,
              label: 'نتائج الجرد',
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      ),
    );
  }
}

// ===== شاشة المنتجات =====
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final data = await supabase.from('products').select();
      setState(() { _products = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات'), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (_, i) {
                final p = _products[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2, color: Colors.blue),
                    title: Text(p['name'] ?? ''),
                    subtitle: Text('باركود: ${p['barcode'] ?? ''}'),
                    trailing: Text('${p['system_quantity'] ?? 0} قطعة', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
    );
  }
}

// ===== شاشة الجرد =====
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
        setState(() { _quantity = 0; _selectedProduct = null; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جرد المستودع'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.qr_code_scanner, size: 60, color: Colors.grey),
                Text('اضغط للمسح'),
              ])),
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
                      onTap: () { setState(() => _selectedProduct = products[i]); Navigator.pop(context); },
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_selectedProduct!['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Text('باركود: ${_selectedProduct!['barcode'] ?? ''}'),
                    Text('الكمية في النظام: ${_selectedProduct!['system_quantity'] ?? 0}'),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: () => setState(() { if (_quantity > 0) _quantity--; }), icon: const Icon(Icons.remove_circle), color: Colors.grey, iconSize: 40),
              Text('$_quantity', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => setState(() => _quantity++), icon: const Icon(Icons.add_circle), color: Colors.green, iconSize: 40),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isSaving || _selectedProduct == null ? null : _saveStocktake,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ الجرد', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== شاشة النتائج =====
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final data = await supabase.from('stocktakes').select('*, products(name, barcode, system_quantity)');
      setState(() { _results = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نتائج الجرد'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('لا توجد نتائج بعد'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    final product = r['products'] as Map<String, dynamic>?;
                    final systemQty = product?['system_quantity'] ?? 0;
                    final countedQty = r['counted_quantity'] ?? 0;
                    final diff = countedQty - systemQty;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(product?['name'] ?? ''),
                        subtitle: Text('النظام: $systemQty | الجرد: $countedQty'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: diff == 0 ? Colors.green : diff > 0 ? Colors.blue : Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${diff > 0 ? '+' : ''}$diff', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}