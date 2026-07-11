import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/product_model.dart';
import 'models/stocktake_model.dart';
import 'services/hive_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'providers/product_provider.dart';
import 'providers/stocktake_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة Hive (التخزين المحلي)
  await Hive.initFlutter();

  // 2. تسجيل الموديلات (Adapters)
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(StocktakeModelAdapter());

  // 3. فتح الصناديق (Boxes)
  await Hive.openBox<ProductModel>(HiveService.productBoxName);
  await Hive.openBox<StocktakeModel>(HiveService.stocktakeBoxName);
  await Hive.openBox(HiveService.metaBoxName); // لتخزين آخر وقت مزامنة

  // 4. تهيئة الاتصال بقاعدة بيانات Supabase
  await Supabase.initialize(
    url: 'https://dqyorsbkxxgjctprjjdw.supabase.co',
    publishableKey: 'sb_publishable_8RMW-u8_2wdFG_pa4RVjYA_mJ5yx1OF',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()..loadProducts()),
        ChangeNotifierProvider(create: (_) => StocktakeProvider()),
      ],
      child: MaterialApp(
        title: 'نظام الجرد الذكي',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// يتحقق عند فتح التطبيق إذا في جلسة دخول محفوظة سابقاً (Supabase يحفظها
/// تلقائياً محلياً)، فإذا وجدت يدخل المستخدم مباشرة للرئيسية بدل ما يرجعه
/// لشاشة تسجيل الدخول (ميزة "تذكرني" / البقاء مسجل دخول).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      // لو المستخدم بلّش "تذكرني" (اختار عدم تذكره)، ما منسمحش بالدخول
      // التلقائي بجلسة Supabase المحفوظة - منطلب تسجيل دخول صريح كل مرة
      final rememberMe = await AuthService.getRememberMe();
      if (!rememberMe) {
        await AuthService.logout();
        if (!mounted) return;
        setState(() {
          _loggedIn = false;
          _checking = false;
        });
        return;
      }
      // مزامنة خفيفة بالخلفية عند فتح التطبيق (لا نوقف المستخدم بانتظارها)
      SyncService.syncAll();
    }
    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _loggedIn ? const MainNavigationScreen() : const LoginScreen();
  }
}
