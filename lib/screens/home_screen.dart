import 'package:flutter/material.dart';
import 'stocktake_screen.dart';
import 'results_screen.dart';
import 'products_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/hive_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSyncing = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final role = await AuthService.getEmployeeRole();
    final isSuperAdmin = await AuthService.getIsSuperAdmin();
    if (mounted) setState(() => _isAdmin = role == 'admin' || isSuperAdmin);
  }

  Future<void> _handleManualSync() async {
    if (_isSyncing) return; // تفادي ضغط الزر أكثر من مرة أثناء المزامنة

    setState(() => _isSyncing = true);

    final result = await SyncService.syncIfIdle();

    if (!mounted) return; // الشاشة ممكن تكون اتقفلت أثناء انتظار المزامنة
    setState(() => _isSyncing = false);

    // result == null يعني في مزامنة تلقائية شغالة بالخلفية أصلاً (مثلاً
    // بسبب عملية جرد حديثة) - مش خطأ، بس نعلم المستخدم إنها هتخلص لحالها
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('في مزامنة شغالة بالفعل بالخلفية، رح تخلص قريباً ⏳'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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

  void _openScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final productsCount = HiveService.getProducts().length;
    final stocktakes = HiveService.getStocktakes();
    final unsyncedCount = stocktakes.where((s) => !s.isSynced).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(unsyncedCount)),
            SliverToBoxAdapter(child: _buildStatsRow(productsCount, stocktakes.length, unsyncedCount)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text('الوصول السريع',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate([
                  _QuickAccessCard(
                    icon: Icons.qr_code_scanner,
                    label: 'بدء الجرد',
                    color: Colors.green,
                    onTap: () => _openScreen(const StocktakeScreen()),
                  ),
                  _QuickAccessCard(
                    icon: Icons.list_alt,
                    label: 'المنتجات',
                    color: Colors.blue,
                    onTap: () => _openScreen(const ProductsScreen()),
                  ),
                  _QuickAccessCard(
                    icon: Icons.bar_chart,
                    label: 'نتائج الجرد',
                    color: Colors.orange,
                    onTap: () => _openScreen(const ResultsScreen()),
                  ),
                  // لوحة تحكم الإدارة تظهر فقط لـ admin أو مدير عام - تطابق
                  // نفس شرط تبويب 'الإدارة' بالشريط السفلي (main_navigation_screen)
                  if (_isAdmin)
                    _QuickAccessCard(
                      icon: Icons.admin_panel_settings,
                      label: 'لوحة تحكم الإدارة',
                      color: Colors.purple,
                      onTap: () => _openScreen(const AdminDashboardScreen()),
                    ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int unsyncedCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.archive_outlined, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نظام الجرد الذكي',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('مرحباً بك 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ]),
              Row(children: [
                _HeaderIconButton(
                  tooltip: 'مزامنة الآن',
                  onPressed: _isSyncing ? null : _handleManualSync,
                  badge: unsyncedCount > 0 ? unsyncedCount : null,
                  child: _isSyncing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, color: Colors.white),
                ),
                const SizedBox(width: 4),
                _HeaderIconButton(
                  tooltip: 'تسجيل الخروج',
                  onPressed: _handleLogout,
                  child: const Icon(Icons.logout, color: Colors.white),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int productsCount, int stocktakesCount, int unsyncedCount) {
    return Transform.translate(
      offset: const Offset(0, -18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _MiniStat(value: '$productsCount', label: 'منتج', color: Colors.blue)),
              _divider(),
              Expanded(child: _MiniStat(value: '$stocktakesCount', label: 'عملية جرد', color: Colors.green)),
              _divider(),
              Expanded(
                child: _MiniStat(
                  value: '$unsyncedCount',
                  label: unsyncedCount == 0 ? 'الكل متزامن ✓' : 'بانتظار المزامنة',
                  color: unsyncedCount == 0 ? Colors.teal : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: Colors.grey[200]);
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
    ]);
  }
}

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final int? badge;
  const _HeaderIconButton({required this.tooltip, required this.onPressed, required this.child, this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              if (badge != null)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAccessCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
