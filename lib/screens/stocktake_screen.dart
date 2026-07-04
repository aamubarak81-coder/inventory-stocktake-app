import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/stocktake_provider.dart';
import '../models/stocktake_model.dart';

class StocktakeScreen extends StatefulWidget {
  const StocktakeScreen({super.key});

  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  final TextEditingController _qtyController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  String? _scannedBarcode;
  String? _scannedProductName;
  bool _isScanning = true;
  bool _isSaving = false;
  bool _isCameraMode = true;

  // وضع الإدخال اليدوي للباركود
  final TextEditingController _manualBarcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // بدء جلسة جرد جديدة عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StocktakeProvider>();
      if (provider.currentSessionId == null) {
        provider.startNewSession();
      }
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _manualBarcodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // جلب إحداثيات GPS بصمت
  Future<Position?> _getLocationSilently() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null; // GPS اختياري، لا نوقف الجرد إذا فشل
    }
  }

  // معالجة الباركود الممسوح
  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_isScanning) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() {
      _isScanning = false;
      _scannedBarcode = barcode;
      _isCameraMode = false;
    });
    _scannerController.stop();
    _lookupProduct(barcode);
  }

  // البحث عن المنتج في قاعدة البيانات المحلية
  void _lookupProduct(String barcode) {
    final provider = context.read<StocktakeProvider>();
    // نستخدم HiveService مباشرة للبحث السريع
    final product = provider.getProductByBarcode(barcode);
    setState(() {
      _scannedProductName = product?.name ?? '⚠️ منتج غير موجود في قاعدة البيانات';
    });
  }

  // حفظ الجرد الفعلي
  Future<void> _saveCount() async {
    if (_scannedBarcode == null) {
      _showSnackBar('يرجى مسح باركود المنتج أولاً', isError: true);
      return;
    }
    final qtyText = _qtyController.text.trim();
    if (qtyText.isEmpty) {
      _showSnackBar('يرجى إدخال الكمية المجرودة', isError: true);
      return;
    }
    final qty = int.tryParse(qtyText);
    if (qty == null || qty < 0) {
      _showSnackBar('يرجى إدخال كمية صحيحة', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    // جلب GPS صامتاً
    final position = await _getLocationSilently();

    // حفظ في Hive عبر StocktakeProvider
    final provider = context.read<StocktakeProvider>();
    final product = await provider.recordCount(
      barcode: _scannedBarcode!,
      countedQuantity: qty,
      isBlindCount: true,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );

    setState(() => _isSaving = false);

    if (product == null) {
      _showSnackBar('⚠️ المنتج غير موجود أو انتهت الجلسة', isError: true);
      return;
    }

    _showSnackBar('✅ تم حفظ جرد "${product.name}" بنجاح');
    _resetForNextScan();
  }

  void _resetForNextScan() {
    setState(() {
      _scannedBarcode = null;
      _scannedProductName = null;
      _isScanning = true;
      _isCameraMode = true;
    });
    _qtyController.clear();
    _manualBarcodeController.clear();
    _scannerController.start();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StocktakeProvider>();
    final sessionCount = provider.currentSessionEntries.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بدء جرد المستودع'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // عداد عمليات الجرد في الجلسة الحالية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$sessionCount جرد',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // زر التبديل بين الكاميرا والإدخال اليدوي
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _isCameraMode = true),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('مسح بالكاميرا'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCameraMode ? Colors.blue : Colors.grey[300],
                        foregroundColor: _isCameraMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _isCameraMode = false),
                      icon: const Icon(Icons.keyboard),
                      label: const Text('إدخال يدوي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isCameraMode ? Colors.blue : Colors.grey[300],
                        foregroundColor: !_isCameraMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // منطقة الكاميرا أو الإدخال اليدوي
              if (_isCameraMode && _scannedBarcode == null) ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: _onBarcodeDetected,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'وجّه الكاميرا نحو الباركود',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ] else if (!_isCameraMode) ...[
                TextField(
                  controller: _manualBarcodeController,
                  decoration: const InputDecoration(
                    labelText: 'أدخل الباركود يدوياً',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  keyboardType: TextInputType.text,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() => _scannedBarcode = value);
                      _lookupProduct(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    final val = _manualBarcodeController.text.trim();
                    if (val.isNotEmpty) {
                      setState(() => _scannedBarcode = val);
                      _lookupProduct(val);
                    }
                  },
                  child: const Text('بحث عن المنتج'),
                ),
              ],

              const SizedBox(height: 12),

              // بطاقة معلومات المنتج الممسوح
              if (_scannedBarcode != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _scannedProductName?.startsWith('⚠️') == true
                        ? Colors.red[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _scannedProductName?.startsWith('⚠️') == true
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الباركود: $_scannedBarcode',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scannedProductName ?? 'جاري البحث...',
                        style: TextStyle(
                          fontSize: 15,
                          color: _scannedProductName?.startsWith('⚠️') == true
                              ? Colors.red
                              : Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // حقل الكمية
              TextField(
                controller: _qtyController,
                decoration: const InputDecoration(
                  labelText: 'الكمية المجرودة الفعلية',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calculate),
                ),
                keyboardType: TextInputType.number,
                autofocus: _scannedBarcode != null,
              ),

              const SizedBox(height: 16),

              // زر الحفظ
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveCount,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'حفظ الكمية المجرودة',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              const SizedBox(height: 8),

              // زر مسح جديد
              if (_scannedBarcode != null)
                OutlinedButton.icon(
                  onPressed: _resetForNextScan,
                  icon: const Icon(Icons.refresh),
                  label: const Text('مسح منتج جديد'),
                ),

              const Spacer(),

              // عرض آخر عمليات الجرد في الجلسة الحالية
              if (sessionCount > 0) ...[
                const Divider(),
                Text(
                  'آخر عمليات الجرد في هذه الجلسة ($sessionCount)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    itemCount: provider.currentSessionEntries.length > 5
                        ? 5
                        : provider.currentSessionEntries.length,
                    itemBuilder: (context, index) {
                      final entry = provider.currentSessionEntries.reversed
                          .toList()[index];
                      return _buildEntryTile(entry);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTile(StocktakeModel entry) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        title: Text(
          entry.barcode.isNotEmpty ? entry.barcode : entry.productId,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Text(
          'الكمية: ${entry.scannedQuantity}',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        subtitle: Text(
          entry.isSynced ? '✅ متزامن' : '🕐 في انتظار المزامنة',
          style: TextStyle(
            fontSize: 11,
            color: entry.isSynced ? Colors.green : Colors.orange,
          ),
        ),
      ),
    );
  }
}
