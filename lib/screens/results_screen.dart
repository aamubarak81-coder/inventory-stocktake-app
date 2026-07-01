import 'package:flutter/material.dart';
import '../main.dart';

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
      final data = await supabase
          .from('stocktakes')
          .select('*, products(name, barcode, system_quantity)');
      setState(() {
        _results = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نتائج الجرد'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
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
                            color: diff == 0
                                ? Colors.green
                                : diff > 0
                                    ? Colors.blue
                                    : Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${diff > 0 ? '+' : ''}$diff',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
