import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'main_navigation_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _orgNameCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isLoading = false;
  String _loadingMessage = '';
  String? _errorMessage;

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _adminNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    // تحقق أساسي قبل ما نرسل أي شي
    if (_orgNameCtrl.text.trim().isEmpty ||
        _adminNameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'يرجى تعبئة كل الحقول الإلزامية (*)');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _errorMessage = 'كلمة السر لازم تكون 6 أحرف على الأقل');
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _errorMessage = 'كلمة السر وتأكيدها غير متطابقين');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingMessage = 'جاري إنشاء منظمتك...';
    });

    final signupError = await AuthService.signupOrganization(
      orgName: _orgNameCtrl.text.trim(),
      adminName: _adminNameCtrl.text.trim(),
      adminEmail: _emailCtrl.text.trim(),
      adminPassword: _passwordCtrl.text,
      adminPhone: _phoneCtrl.text.trim(),
    );

    if (!mounted) return;

    if (signupError != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = signupError;
      });
      return;
    }

    // المنظمة والحساب اتعملوا بنجاح على السيرفر - هلق نسجل دخول عادي
    // بنفس البيانات لتفعيل الجلسة بالتطبيق
    setState(() => _loadingMessage = 'جاري تسجيل الدخول...');

    final loginError = await AuthService.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    if (loginError != null) {
      // نادر جداً (لو صار، الحساب موجود فعلياً بس تسجيل الدخول فشل
      // لسبب عابر) - نطلب منه يرجع يسجل دخول يدوياً بدل ما يعيد التسجيل
      setState(() {
        _isLoading = false;
        _errorMessage = 'تم إنشاء الحساب، لكن تعذّر الدخول التلقائي. جرّب تسجيل الدخول يدوياً.';
      });
      return;
    }

    setState(() => _loadingMessage = 'جاري تحميل البيانات...');
    final syncResult = await SyncService.syncAll();
    if (!syncResult.success) {
      debugPrint('Sync failed after signup: ${syncResult.message}');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل منظمة جديدة'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.domain_add, size: 64, color: Colors.blue),
              const SizedBox(height: 8),
              const Text(
                'ابدأ باستخدام نظام الجرد الذكي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const Text(
                'هيتكوّن لك فرع ومستودع افتراضيين تلقائياً، وتقدر تضيف أكتر بعدين',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              const Text('بيانات المنظمة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _orgNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المنظمة / الشركة *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 24),

              const Text('حسابك (المدير العام)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _adminNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسمك الكامل *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة السر (6 أحرف على الأقل) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة السر *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _loadingMessage,
                    style: const TextStyle(color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إنشاء المنظمة والبدء', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('عندك حساب أصلاً؟ سجّل دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
