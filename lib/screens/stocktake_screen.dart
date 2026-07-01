import 'package:flutter/material.dart';

class StocktakeScreen extends StatefulWidget {
  const StocktakeScreen({super.key});

  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  
  String _statusMessage = 'جاهز لمسح المنتجات وبدء الجرد';

  void _saveCount() {
    if (_barcodeController.text.isEmpty || _qtyController.text.isEmpty) {
      setState(() {
        _statusMessage = '❌ يرجى إدخال الباركود والكمية أولاً!';
      });
      return;
    }

    // محاكاة حفظ الجرد بنجاح
    setState(() {
      _statusMessage = '✅ تم حفظ جرد المنتج بنجاح (وضع تجريبي)';
      _barcodeController.clear();
      _qtyController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الكمية المجرودة بنجاح')),
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بدء جرد المستودع'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'مسح الباركود وإدخال الكمية الفعلية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'الباركود أو رقم المنتج',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyController,
              decoration: const InputDecoration(
                labelText: 'الكمية المجرودة (الفعلية)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calculate),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveCount,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الكمية المجرودة', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}