import 'package:flutter/material.dart';
import 'stocktake_screen.dart';
import 'results_screen.dart';
import 'products_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSyncing = false;

  Future<void> _handleManualSync() async {
    if (_isSyncing) return; // تفادي ضغط الزر أكثر من مرة أثناء المزامنة

    setState(() => _isSyncing = true);

    final result = await SyncService.syncAll();

    if (!mounted) return; // الشاشة ممكن تكون اتقفلت أثناء انتظار المزامنة
    setState(() => _isSyncing = false);

    final message = result.success
        ? 'تمت المزامنة ✅  (منتجات: ${result.syncedProducts}، جرد: ${result.syncedStocktakes})'
        : 'فشلت المزامنة: ${result.message}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLogout() async {
    // تأكيد قبل الخروج الفعلي، تفادياً لضغطة بالغلط
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك بتسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.logout();

    if (!mounted) return;
    // نمسح كل شاشات التنقل السابقة عشان المستخدم ما يقدر يرجع بزر الرجوع
    // لشاشة كانت تتطلب تسجيل دخول
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام الجرد الذكي'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'مزامنة الآن',
            onPressed: _isSyncing ? null : _handleManualSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.archive_outlined,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'مرحباً بك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // 1️⃣ زر المنتجات
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProductsScreen()),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('المنتجات', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 16),

              // 2️⃣ زر بدء الجرد
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StocktakeScreen()),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('بدء الجرد', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 16),

              // 3️⃣ زر نتائج الجرد
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ResultsScreen()),
                  );
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text('نتائج الجرد', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 16),

              // 4️⃣ زر لوحة تحكم الإدارة
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('لوحة تحكم الإدارة', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}